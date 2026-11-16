package com.secureshield.secureshield_app

import android.app.*
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * Foreground service that captures screen using MediaProjection API.
 * Started from Flutter via MethodChannel after user grants permission.
 */
class ScreenRecordService : Service() {

    companion object {
        const val ACTION_START  = "START_RECORDING"
        const val ACTION_STOP   = "STOP_RECORDING"
        const val EXTRA_RESULT  = "result_code"
        const val EXTRA_DATA    = "result_data"
        const val CHANNEL_ID    = "screen_record"
        var isRecording = false
        /** True when the running/last recording includes microphone audio. */
        @Volatile var microphoneIncluded = false
        /** Non-null when the last start attempt failed; shown to the user by the Flutter side. */
        @Volatile var lastError: String? = null
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay:  VirtualDisplay?  = null
    private var mediaRecorder:   MediaRecorder?   = null
    private var outputPath: String = ""

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRecording(intent)
            ACTION_STOP  -> stopRecording()
        }
        return START_NOT_STICKY
    }

    private fun startRecording(intent: Intent) {
        lastError = null
        microphoneIncluded = false
        createNotificationChannel()
        startForeground(1001, buildNotification())
        try {
            doStartRecording(intent)
        } catch (e: Exception) {
            // Never crash the process: release everything and tell the UI why nothing is recording.
            lastError = "Screen recording could not start (${e.javaClass.simpleName})"
            stopRecording()
        }
    }

    private fun doStartRecording(intent: Intent) {
        val resultCode = intent.getIntExtra(EXTRA_RESULT, Int.MIN_VALUE)
        val resultData: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_DATA)
        }

        if (resultCode != android.app.Activity.RESULT_OK || resultData == null) {
            lastError = "Screen capture permission was not granted"
            stopRecording()
            return
        }

        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = mpm.getMediaProjection(resultCode, resultData)
        // Android 14+ requires a callback to be registered before capture starts.
        mediaProjection!!.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { stopRecording() }
        }, null)

        val wm      = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getMetrics(metrics)
        val width   = metrics.widthPixels
        val height  = metrics.heightPixels
        val density = metrics.densityDpi

        // Output file
        val dir = File(getExternalFilesDir(null), "ScreenRecordings")
        dir.mkdirs()
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        outputPath = "${dir.absolutePath}/recording_$timestamp.mp4"

        // RECORD_AUDIO is a runtime permission. Without it MediaRecorder.setAudioSource throws, so the screen is
        // recorded without microphone audio instead of failing (the Flutter side tells the user).
        val micGranted = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        mediaRecorder = try {
            buildRecorder(width, height, withAudio = micGranted).also { microphoneIncluded = micGranted }
        } catch (e: Exception) {
            if (!micGranted) throw e
            // Microphone busy/unavailable: fall back to video only.
            buildRecorder(width, height, withAudio = false).also { microphoneIncluded = false }
        }

        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "SecureShieldCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            mediaRecorder!!.surface,
            null, null
        )

        mediaRecorder!!.start()
        isRecording = true
    }

    private fun buildRecorder(width: Int, height: Int, withAudio: Boolean): MediaRecorder {
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        try {
            recorder.apply {
                if (withAudio) setAudioSource(MediaRecorder.AudioSource.MIC)
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setOutputFile(outputPath)
                setVideoSize(width, height)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                if (withAudio) setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setVideoEncodingBitRate(5_000_000)
                setVideoFrameRate(30)
                prepare()
            }
        } catch (e: Exception) {
            recorder.release()
            throw e
        }
        return recorder
    }

    private fun stopRecording() {
        // stop() throws if the recorder never started; release() must still run.
        try { if (isRecording) mediaRecorder?.stop() } catch (_: Exception) {}
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder = null
        // A failed start must not leave an empty/corrupt file in the recordings list.
        if (lastError != null && outputPath.isNotEmpty()) {
            try { File(outputPath).delete() } catch (_: Exception) {}
        }

        virtualDisplay?.release()
        virtualDisplay = null

        mediaProjection?.stop()
        mediaProjection = null

        isRecording = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, ScreenRecordService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("SecureShield — Screen Recording")
            .setContentText("Tap to stop recording")
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPi)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Screen Recording", NotificationManager.IMPORTANCE_LOW
            )
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

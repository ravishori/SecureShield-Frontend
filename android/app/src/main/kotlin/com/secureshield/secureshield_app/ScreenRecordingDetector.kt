package com.secureshield.secureshield_app

import android.app.Activity
import android.os.Build
import android.view.WindowManager
import androidx.annotation.RequiresApi
import java.util.function.Consumer

/**
 * Detects whether this app's window content is being captured by a screen recording.
 *
 * What is (and is not) possible: Android only exposes this through Activity.registerScreenRecordingCallback,
 * added in **Android 15 (API 35)** and guarded by the DETECT_SCREEN_RECORDING permission. It reports whether this
 * activity's content is visible in a recording (MediaProjection / system recorder). Before Android 15 there is no
 * supported API, so [isSupported] is false there and the UI says so instead of pretending.
 */
class ScreenRecordingDetector(private val activity: Activity) {

    companion object {
        /** True on Android 15+ (API 35). */
        val isSupported: Boolean get() = Build.VERSION.SDK_INT >= 35
    }

    @Volatile
    var isRecording: Boolean = false
        private set

    private var callback: Any? = null
    private var listener: ((Boolean) -> Unit)? = null

    /** Starts watching. [onChange] runs on the main thread whenever the state changes. */
    fun start(onChange: (Boolean) -> Unit) {
        if (!isSupported) return
        stop()
        listener = onChange
        register()
    }

    fun stop() {
        if (!isSupported) return
        unregister()
        listener = null
    }

    @RequiresApi(35)
    private fun register() {
        val cb = Consumer<Int> { state ->
            val visible = state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
            val changed = visible != isRecording
            isRecording = visible
            if (changed) listener?.invoke(visible)
        }
        callback = cb
        val wm = activity.getSystemService(WindowManager::class.java)
        val initial = wm.addScreenRecordingCallback(activity.mainExecutor, cb)
        isRecording = initial == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
        listener?.invoke(isRecording)
    }

    @RequiresApi(35)
    private fun unregister() {
        @Suppress("UNCHECKED_CAST")
        (callback as? Consumer<Int>)?.let { activity.getSystemService(WindowManager::class.java).removeScreenRecordingCallback(it) }
        callback = null
    }
}

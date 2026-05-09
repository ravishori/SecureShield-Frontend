package com.secureshield.secureshield_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * AppMonitorService — foreground service that listens for package installs/updates/removals.
 *
 * Lifecycle:
 *  • Started by MainActivity via APP_MONITOR_CHANNEL "startMonitor"
 *  • Registers a dynamic BroadcastReceiver (catches all package events, including Play Store)
 *  • On every event: runs AppInstallAnalyzer in a background thread
 *  • Broadcasts ACTION_INSTALL_ANALYSIS with the full analysis map
 *  • MainActivity's EventChannel picks that broadcast up and streams it to Flutter
 *  • ElderlyProtectionManager checks the result and shows a blocking dialog if needed
 *
 * Play Store compliance:
 *  • Uses FOREGROUND_SERVICE permission (declared in manifest)
 *  • Does NOT intercept payload content — only reads PackageManager metadata
 *  • Users can stop the service at any time via the persistent notification
 */
class AppMonitorService : android.app.Service() {

    companion object {
        const val ACTION_START            = "START_MONITOR"
        const val ACTION_STOP             = "STOP_MONITOR"
        const val ACTION_INSTALL_ANALYSIS = "com.secureshield.INSTALL_ANALYSIS"

        const val CHANNEL_ID = "app_monitor"
        const val NOTIF_ID   = 3001

        var isRunning = false
    }

    private var packageReceiver: BroadcastReceiver? = null
    private val analyzerThread = java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startMonitoring()
            ACTION_STOP  -> stopMonitoring()
        }
        return START_STICKY   // restart if killed
    }

    private fun startMonitoring() {
        if (isRunning) return
        isRunning = true

        createChannel()
        startForeground(NOTIF_ID, buildNotification())

        // Register dynamic receiver for package events
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addDataScheme("package")
        }

        packageReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val pkg       = intent.data?.schemeSpecificPart ?: return
                val replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)

                val eventType = when (intent.action) {
                    Intent.ACTION_PACKAGE_ADDED    -> if (replacing) "updated" else "installed"
                    Intent.ACTION_PACKAGE_REPLACED -> "updated"
                    Intent.ACTION_PACKAGE_REMOVED  -> if (replacing) return else "removed"
                    else -> return
                }

                // Heavy analysis off the main thread
                analyzerThread.submit {
                    val result = AppInstallAnalyzer.analyze(applicationContext, pkg, eventType)
                        ?: return@submit

                    // Notify elderly protection manager (may show blocking dialog)
                    ElderlyProtectionManager.onNewInstall(applicationContext, result)

                    // Show notification for risky apps
                    if (result.localRiskLevel != "safe" || result.cloneVerdict != "safe") {
                        showRiskNotification(result)
                    }

                    // Broadcast full analysis for Flutter EventChannel
                    val broadcast = Intent(ACTION_INSTALL_ANALYSIS).apply {
                        `package` = applicationContext.packageName
                        // Flatten the map into extras for broadcast compatibility
                        result.toMap().forEach { (k, v) ->
                            when (v) {
                                is String        -> putExtra(k, v)
                                is Boolean       -> putExtra(k, v)
                                is Int           -> putExtra(k, v)
                                is Long          -> putExtra(k, v)
                                is List<*>       -> putExtra(k, v.map { it.toString() }.toTypedArray())
                                null             -> putExtra(k, null as String?)
                            }
                        }
                    }
                    sendBroadcast(broadcast)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(packageReceiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(packageReceiver, filter)
        }
    }

    private fun stopMonitoring() {
        isRunning = false
        try { unregisterReceiver(packageReceiver) } catch (_: Exception) {}
        packageReceiver = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun showRiskNotification(result: AppInstallAnalyzer.AnalysisResult) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val (title, text) = when {
            result.cloneVerdict in listOf("confirmed_clone", "likely_clone") ->
                "🚨 Fake App Detected!" to
                "'${result.appName}' appears to be a clone of ${result.cloneTargetName}. Tap to review."
            result.localRiskLevel == "danger" ->
                "⚠️ High-Risk App Installed" to
                "'${result.appName}' has ${result.localRiskTags.firstOrNull() ?: "multiple risk signals"}."
            else ->
                "⚠️ Suspicious App" to
                "'${result.appName}' has some risk signals. Tap to review."
        }

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("navigate_to", "/app-monitor")
        }
        val pi = PendingIntent.getActivity(
            this, result.packageName.hashCode(), openIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        nm.notify(result.packageName.hashCode() + 10_000, notif)
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, AppMonitorService::class.java).apply { action = ACTION_STOP }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle("SecureShield — App Monitor")
            .setContentText("Monitoring installed apps for threats")
            .addAction(android.R.drawable.ic_delete, "Stop", stopPi)
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "App Install Monitor", NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Monitors app installs for security threats" }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }

    override fun onDestroy() {
        stopMonitoring()
        analyzerThread.shutdownNow()
        super.onDestroy()
    }
}

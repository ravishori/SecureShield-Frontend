package com.secureshield.secureshield_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

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
 *  • Declared in the manifest as a non-exported specialUse foreground service (FOREGROUND_SERVICE and
 *    FOREGROUND_SERVICE_SPECIAL_USE only); the persistent notification is the user-visible disclosure
 *  • Does NOT intercept payload content — only reads PackageManager metadata
 *  • Users can stop the service at any time via the persistent notification
 *
 * Lifecycle rules (see [MonitorLifecycle], unit-tested):
 *  • START_NOT_STICKY: after the process is killed the monitor is OFF until the user turns it on again; nothing restarts
 *    silently, and the UI reads the real state from [isRunning] instead of assuming.
 *  • A duplicate start never registers a second receiver; it only re-asserts the foreground notification.
 *  • If the foreground promotion is refused the start is rolled back and the service stops itself.
 */
class AppMonitorService : android.app.Service() {

    companion object {
        const val ACTION_START            = "START_MONITOR"
        const val ACTION_STOP             = "STOP_MONITOR"
        const val ACTION_INSTALL_ANALYSIS = "com.secureshield.INSTALL_ANALYSIS"

        const val CHANNEL_ID        = "app_monitor"          // low importance: the persistent "monitor is on" notice
        const val ALERT_CHANNEL_ID  = "app_risk_alerts"       // high importance: a risky app was found
        const val NOTIF_ID   = 3001
        private const val TAG = "AppMonitorService"

        val lifecycle = MonitorLifecycle()

        /** True only while the service has actually been promoted to foreground and registered its receiver. */
        val isRunning: Boolean get() = lifecycle.running
    }

    private var packageReceiver: BroadcastReceiver? = null
    private val analyzerThread = java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startMonitoring()
            ACTION_STOP  -> stopMonitoring()
            else -> if (!isRunning) stopSelf()   // null/unknown intent (e.g. a restart): never linger as a hidden service
        }
        return START_NOT_STICKY
    }

    private fun startMonitoring() {
        createChannels()
        // Visibility is decided BEFORE the lifecycle flag is set, so nothing can ever observe "running" for a monitor that
        // is about to be refused. startForeground() must still be called (startForegroundService() obliges it), then the
        // service stops itself again.
        val visible = NotificationVisibility.check(this)
        try {
            // Always (re)assert the foreground state: startForegroundService() obliges the service to do so, even on a
            // duplicate start. Android 14+ requires the type to match the manifest declaration.
            ServiceCompat.startForeground(
                this, NOTIF_ID, buildNotification(),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0,
            )
        } catch (e: Exception) {
            Log.e(TAG, "foreground promotion refused: ${e.javaClass.simpleName}")
            stopSelf()
            return
        }
        if (!visible) {
            Log.w(TAG, "notifications are off: monitoring cannot be disclosed, not starting")
            stopMonitoring() // clears the preference, ends the lifecycle, removes the notification, stops the service
            return
        }
        val outcome = lifecycle.begin()
        if (outcome == MonitorLifecycle.StartOutcome.ALREADY_RUNNING) return

        // Register dynamic receiver for package events
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addDataScheme("package")
        }

        packageReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                // Every event re-checks that the user can still see the monitor: if not, stop and process nothing.
                if (!NotificationVisibility.check(applicationContext)) {
                    stopMonitoring()
                    return
                }
                val pkg       = intent.data?.schemeSpecificPart ?: return
                val replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)

                val eventType = when (intent.action) {
                    Intent.ACTION_PACKAGE_ADDED    -> if (replacing) "updated" else "installed"
                    Intent.ACTION_PACKAGE_REPLACED -> "updated"
                    Intent.ACTION_PACKAGE_REMOVED  -> if (replacing) return else "removed"
                    else -> return
                }

                // Stage 2B: stored FIRST (before analysis or any notification), so a process death cannot lose it.
                val storedId = MonitorEvents.recordFirst(applicationContext, pkg, eventType)

                // Heavy analysis off the main thread
                analyzerThread.submit {
                    if (!isRunning) return@submit // stopped while this event was queued: no analysis, no guardian alert
                    val result = AppInstallAnalyzer.analyze(applicationContext, pkg, eventType)
                        ?: return@submit
                    MonitorEvents.attach(applicationContext, storedId, result)
                    if (!NotificationVisibility.check(applicationContext)) return@submit // revoked mid-analysis

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

        try {
            // Package events are system broadcasts; they reach a NOT_EXPORTED receiver, so nothing else can address it.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(packageReceiver, filter, RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(packageReceiver, filter)
            }
        } catch (e: Exception) {
            Log.e(TAG, "receiver registration failed: ${e.javaClass.simpleName}")
            packageReceiver = null
            lifecycle.failed()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun stopMonitoring() {
        MonitorPreference.set(applicationContext, false)   // an explicit stop or a visibility pause turns monitoring OFF
        lifecycle.end()
        packageReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
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

        val notif = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
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

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "App Install Monitor", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Shows that SecureShield is watching for app installs" },
            )
            nm.createNotificationChannel(
                NotificationChannel(ALERT_CHANNEL_ID, "Risky app alerts", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "Warns you when a risky or fake app is installed" },
            )
        }
    }

    override fun onDestroy() {
        lifecycle.end()
        packageReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        packageReceiver = null
        analyzerThread.shutdownNow()
        super.onDestroy()
    }
}

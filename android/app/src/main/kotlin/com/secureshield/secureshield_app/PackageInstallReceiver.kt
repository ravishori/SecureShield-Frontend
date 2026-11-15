package com.secureshield.secureshield_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Detects newly installed packages and sends a security alert notification, but ONLY while the user has turned app
 * monitoring on ([MonitorPreference], fail closed). While the foreground service is running it handles the event itself, so
 * this receiver stays silent to avoid a duplicate notification. Declared non-exported: package broadcasts are protected
 * system broadcasts and still reach it.
 */
class PackageInstallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val enabled = MonitorPreference.isEnabled(context)
        // Checked at the moment of the event, so a revoked permission is noticed even though the app was not running.
        val visible = enabled && NotificationVisibility.check(context)
        val decision = MonitorPolicy.decide(
            action = intent.action,
            replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false),
            monitoringEnabled = enabled,
            notificationsVisible = visible,
            serviceRunning = AppMonitorService.isRunning,
        )
        if (decision == MonitorPolicy.Decision.PAUSE_NOTIFICATIONS_OFF) {
            MonitorPause.pause(context) // monitoring cannot be disclosed: stop, clear the preference, process nothing
            return
        }
        if (decision != MonitorPolicy.Decision.HANDLE) return

        val packageName = intent.data?.schemeSpecificPart ?: return

        // F19 Stage 2B: the event is stored FIRST, before analysis or the notification, so a process death cannot
        // lose it. Nothing is stored while no account is signed in; the local alert below still runs.
        MonitorEvents.recordFirst(context, packageName, "installed")

        val pm      = context.packageManager
        val appName = try {
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (_: Exception) { packageName }

        val isFromUnknownSource = try {
            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pm.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(packageName)
            }
            val knownStores = setOf(
                "com.android.vending", "com.amazon.venezia",
                "com.sec.android.app.samsungapps", "org.fdroid.fdroid"
            )
            installer == null || !knownStores.contains(installer)
        } catch (_: Exception) { true }

        // Show immediate notification
        showNewAppAlert(context, appName, packageName, isFromUnknownSource)
    }

    private fun showNewAppAlert(
        context: Context, appName: String, pkg: String, isUnknown: Boolean
    ) {
        val channelId = "new_app_alert"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "New App Alerts", NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Alert when a new app is installed" }
            nm.createNotificationChannel(channel)
        }

        val title = if (isUnknown) "⚠️ Unknown Source App Installed" else "New App Installed"
        val text  = if (isUnknown)
            "$appName was installed from an unknown source. Tap to review security."
        else
            "$appName installed. SecureShield will scan it shortly."

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(if (isUnknown) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        nm.notify(pkg.hashCode(), notification)
    }
}

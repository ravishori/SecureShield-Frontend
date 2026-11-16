package com.secureshield.secureshield_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat

/**
 * The ONE persisted monitoring preference ("the user turned app monitoring on"), plus the pure rules that read it.
 *
 * Written only by the user's own actions: set true after the service CONFIRMS it started (MainActivity), set false by any
 * stop (screen button, notification Stop, failed restore) and by [MonitorPause]. It is NOT cleared when Android kills the
 * process (never from onDestroy), so background package events keep being handled while the app UI is closed; the app UI
 * restores the service (or turns the preference off) the next time it opens.
 *
 * Fail closed: a missing, wrong-typed or unreadable value means "monitoring is OFF". Writes are skipped when the value would
 * not change, so repeated stops do not rewrite the file.
 */
object MonitorPreference {
    private const val FILE = "secureshield_app_monitor"
    const val KEY = "monitoring_enabled"

    fun isEnabled(ctx: Context): Boolean = try {
        MonitorPolicy.parse(ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE).all[KEY])
    } catch (_: Throwable) {
        false
    }

    fun set(ctx: Context, enabled: Boolean) {
        try {
            if (isEnabled(ctx) == enabled) return
            ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(KEY, enabled).commit()
        } catch (_: Throwable) {
            // cannot persist: the safe reading on the next start is "off"
        }
    }
}

/** Pure (Android-free) rules, unit-tested on the JVM. */
object MonitorPolicy {
    const val ACTION_PACKAGE_ADDED = "android.intent.action.PACKAGE_ADDED"
    private const val IMPORTANCE_NONE = 0
    private const val API_O = 26

    enum class Decision {
        /** Monitoring is off (or its state is unreadable): do nothing, no analysis, no warning, no guardian alert. */
        IGNORE_MONITORING_OFF,

        /** Monitoring is on but the user could not SEE it (notifications or the monitor channel are off): stop and clear. */
        PAUSE_NOTIFICATIONS_OFF,

        /** Not a fresh install this receiver handles. */
        IGNORE_NOT_APPLICABLE,

        /** The foreground service is running and handles the event itself (richer analysis, one notification). */
        LEFT_TO_SERVICE,

        /** Monitoring is on but the service is not running (process was killed): the manifest receiver handles it. */
        HANDLE,
    }

    /** Only a stored boolean `true` enables monitoring; null, strings, numbers and anything else mean off. */
    fun parse(raw: Any?): Boolean = raw == true

    /**
     * Can the user see that monitoring is on? [appEnabled] is the app-level notification state (null = the check failed);
     * [channelImportance] is the monitor channel's importance (null = the channel is missing or could not be read).
     * Anything unknown means NOT visible (fail closed).
     */
    fun isVisible(appEnabled: Boolean?, sdk: Int, channelImportance: Int?): Boolean = when {
        appEnabled != true -> false
        sdk < API_O -> true // no channels before Android 8: the app-level switch is the whole story
        channelImportance == null -> false
        else -> channelImportance != IMPORTANCE_NONE
    }

    fun decide(
        action: String?,
        replacing: Boolean,
        monitoringEnabled: Boolean,
        notificationsVisible: Boolean,
        serviceRunning: Boolean,
    ): Decision = when {
        !monitoringEnabled -> Decision.IGNORE_MONITORING_OFF
        !notificationsVisible -> Decision.PAUSE_NOTIFICATIONS_OFF
        action != ACTION_PACKAGE_ADDED || replacing -> Decision.IGNORE_NOT_APPLICABLE
        serviceRunning -> Decision.LEFT_TO_SERVICE
        else -> Decision.HANDLE
    }
}

/** Reads the real notification state from Android. Any failure means "not visible". */
object NotificationVisibility {
    fun check(ctx: Context): Boolean = try {
        val app = NotificationManagerCompat.from(ctx).areNotificationsEnabled()
        val importance: Int? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .getNotificationChannel(AppMonitorService.CHANNEL_ID)?.importance
        } else {
            null
        }
        MonitorPolicy.isVisible(app, Build.VERSION.SDK_INT, importance)
    } catch (_: Throwable) {
        false
    }

    /** App-level switch only (used before the monitor channel exists, i.e. before the first start). */
    fun appLevelEnabled(ctx: Context): Boolean = try {
        NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    } catch (_: Throwable) {
        false
    }
}

/** Turns monitoring OFF once: clears the preference and stops the service, each only if it is still on. */
object MonitorPause {
    fun pause(ctx: Context): Boolean {
        var changed = false
        if (MonitorPreference.isEnabled(ctx)) {
            MonitorPreference.set(ctx, false)
            changed = true
        }
        if (AppMonitorService.isRunning) {
            try {
                ctx.startService(Intent(ctx, AppMonitorService::class.java).setAction(AppMonitorService.ACTION_STOP))
            } catch (_: Throwable) {
                // already stopping; the service re-checks visibility on its own events anyway
            }
            changed = true
        }
        return changed
    }
}

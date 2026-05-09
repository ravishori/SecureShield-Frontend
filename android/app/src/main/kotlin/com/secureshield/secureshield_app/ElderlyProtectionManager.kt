package com.secureshield.secureshield_app

import android.app.AlertDialog
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * ElderlyProtectionManager — singleton managing elderly / guardian mode.
 *
 * Responsibilities:
 *  1. Store elderly-mode config in SharedPreferences for offline-first operation
 *  2. Intercept high-risk install events and show a large, simplified alert dialog
 *  3. If "block_risky_installs" is true, prompt user to uninstall immediately
 *  4. Broadcast ACTION_GUARDIAN_ALERT so Flutter can call the backend guardian-alert endpoint
 *
 * Design constraints:
 *  • Dialog must run on the main thread (use Handler(Looper.getMainLooper()))
 *  • We do NOT auto-uninstall — we guide the user to do it themselves (Play Store policy)
 *  • The dialog uses simple, large text with only two buttons: "Keep" / "Uninstall"
 */
object ElderlyProtectionManager {

    const val ACTION_GUARDIAN_ALERT = "com.secureshield.GUARDIAN_ALERT"

    private const val PREFS_NAME      = "elderly_prefs"
    private const val KEY_ENABLED     = "enabled"
    private const val KEY_THRESHOLD   = "alert_threshold"
    private const val KEY_BLOCK       = "block_risky"
    private const val KEY_AUTO_ALERT  = "auto_alert"
    private const val KEY_GUARDIAN_NAME  = "guardian_name"
    private const val KEY_GUARDIAN_PHONE = "guardian_phone"
    private const val CHANNEL_ID      = "elderly_alerts"

    // ── Config accessors ──────────────────────────────────────────────────────

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isEnabled(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_ENABLED, false)

    fun applyConfig(
        ctx: Context,
        enabled: Boolean,
        alertThreshold: Int = 40,
        blockRiskyInstalls: Boolean = true,
        autoAlertGuardian: Boolean = true,
        guardianName: String? = null,
        guardianPhone: String? = null,
    ) {
        prefs(ctx).edit().apply {
            putBoolean(KEY_ENABLED, enabled)
            putInt(KEY_THRESHOLD, alertThreshold)
            putBoolean(KEY_BLOCK, blockRiskyInstalls)
            putBoolean(KEY_AUTO_ALERT, autoAlertGuardian)
            if (guardianName != null) putString(KEY_GUARDIAN_NAME, guardianName)
            if (guardianPhone != null) putString(KEY_GUARDIAN_PHONE, guardianPhone)
        }.apply()
    }

    fun getConfigMap(ctx: Context): Map<String, Any?> {
        val p = prefs(ctx)
        return mapOf(
            "enabled"          to p.getBoolean(KEY_ENABLED, false),
            "alertThreshold"   to p.getInt(KEY_THRESHOLD, 40),
            "blockRisky"       to p.getBoolean(KEY_BLOCK, true),
            "autoAlert"        to p.getBoolean(KEY_AUTO_ALERT, true),
            "guardianName"     to p.getString(KEY_GUARDIAN_NAME, null),
            "guardianPhone"    to p.getString(KEY_GUARDIAN_PHONE, null),
        )
    }

    // ── Core logic ────────────────────────────────────────────────────────────

    /**
     * Called by AppMonitorService on every install/update event.
     * Checks config and takes action if elderly mode is active.
     */
    fun onNewInstall(ctx: Context, result: AppInstallAnalyzer.AnalysisResult) {
        val p = prefs(ctx)
        if (!p.getBoolean(KEY_ENABLED, false)) return
        if (result.eventType == "removed") return

        val threshold = p.getInt(KEY_THRESHOLD, 40)
        val riskScore = result.localRiskScore
        val isClone   = result.cloneVerdict in listOf("confirmed_clone", "likely_clone")

        if (riskScore < threshold && !isClone) return   // below alert threshold

        // Broadcast for Flutter to call the backend guardian-alert endpoint
        if (p.getBoolean(KEY_AUTO_ALERT, true)) {
            broadcastGuardianAlert(ctx, result)
        }

        // Show the simplified blocking dialog (must run on UI thread)
        Handler(Looper.getMainLooper()).post {
            showElderlyAlert(ctx, result, p.getBoolean(KEY_BLOCK, true))
        }
    }

    // ── Simplified alert dialog ───────────────────────────────────────────────

    private fun showElderlyAlert(
        ctx: Context,
        result: AppInstallAnalyzer.AnalysisResult,
        shouldPromptUninstall: Boolean,
    ) {
        // Build simple message — no technical jargon
        val reason = when {
            result.cloneVerdict in listOf("confirmed_clone", "likely_clone") ->
                "This app looks like a FAKE copy of '${result.cloneTargetName}'.\n" +
                "Scammers use fake apps to steal your money and passwords."
            result.localRiskLevel == "danger" ->
                "This app has been installed from an unsafe source and requests\n" +
                "access to your messages, contacts, or camera."
            else ->
                "This app has some security concerns that you should review."
        }

        val title = if (result.cloneVerdict in listOf("confirmed_clone", "likely_clone"))
            "⚠️  FAKE APP DETECTED!" else "⚠️  RISKY APP INSTALLED"

        try {
            val builder = AlertDialog.Builder(ctx, android.R.style.Theme_Material_Dialog_Alert)
                .setTitle(title)
                .setMessage(
                    "'${result.appName}' was just installed.\n\n" +
                    reason + "\n\n" +
                    "Please ask a family member for help."
                )
                .setCancelable(false)

            if (shouldPromptUninstall) {
                builder.setPositiveButton("REMOVE THIS APP") { _, _ ->
                    val intent = Intent(Intent.ACTION_DELETE,
                        Uri.parse("package:${result.packageName}")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    ctx.startActivity(intent)
                }
            }

            builder.setNegativeButton("I'll Check Later") { dialog, _ -> dialog.dismiss() }
            builder.show()
        } catch (_: Exception) {
            // Fallback: show a high-priority notification if dialog fails
            showElderlyNotification(ctx, result)
        }
    }

    // ── Guardian alert broadcast ──────────────────────────────────────────────

    private fun broadcastGuardianAlert(ctx: Context, result: AppInstallAnalyzer.AnalysisResult) {
        ctx.sendBroadcast(Intent(ACTION_GUARDIAN_ALERT).apply {
            `package` = ctx.packageName
            putExtra("packageName",   result.packageName)
            putExtra("appName",       result.appName)
            putExtra("riskScore",     result.localRiskScore)
            putExtra("riskLevel",     result.localRiskLevel)
            putExtra("riskTags",      result.localRiskTags.toTypedArray())
            putExtra("cloneVerdict",  result.cloneVerdict)
            putExtra("cloneTarget",   result.cloneTargetName)
        })
    }

    // ── Fallback notification ─────────────────────────────────────────────────

    private fun showElderlyNotification(ctx: Context, result: AppInstallAnalyzer.AnalysisResult) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Elderly Alerts", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "Critical alerts for elderly mode" }
            nm.createNotificationChannel(ch)
        }
        val notif = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Risky App — Ask for Help")
            .setContentText("'${result.appName}' may be unsafe. Please ask a family member to check it.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .build()
        nm.notify(result.packageName.hashCode() + 20_000, notif)
    }
}

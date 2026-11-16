package com.secureshield.secureshield_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.app.Notification
import android.os.Bundle

/**
 * Listens to all notifications and detects bank OTPs.
 * Sends detected OTPs to Flutter via broadcast (MainActivity picks them up).
 */
class SecureShieldNotificationListener : NotificationListenerService() {

    companion object {
        const val ACTION_BANK_OTP = "com.secureshield.BANK_OTP_DETECTED"
        const val EXTRA_OTP       = "otp_text"
        const val EXTRA_BANK      = "bank_name"
        const val EXTRA_PACKAGE   = "source_package"

        // Known bank/financial notification sender patterns
        private val BANK_SENDERS = listOf(
            "sbi", "hdfc", "icici", "axis", "kotak", "pnb", "bob", "canara",
            "union", "idbi", "yes", "indusind", "federal", "rbl", "paytm",
            "phonepe", "gpay", "bhim", "amazon", "flipkart", "swiggy", "zomato",
            "ola", "uber", "razorpay", "cashfree", "instamojo"
        )

        private val OTP_PATTERNS = listOf(
            Regex("""(?i)otp\s*(?:is|:|-)?\s*(\d{4,8})"""),
            Regex("""(?i)your\s+(?:otp|one.time.password)\s*(?:is|:|-)?\s*(\d{4,8})"""),
            Regex("""(?i)(\d{4,8})\s+is\s+your\s+otp"""),
            Regex("""(?i)use\s+(\d{4,8})\s+(?:for|to)"""),
            Regex("""(?i)verification\s+code\s*(?:is|:|-)?\s*(\d{4,8})"""),
            Regex("""(?i)(\d{4,8})\s+is\s+the\s+(?:otp|code|pin)"""),
            Regex("""(?i)security\s+code[:\s]+(\d{4,8})"""),
            Regex("""(?i)transaction\s+pin[:\s]+(\d{4,8})"""),
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            android.util.Log.d("SSNotif", "onNotificationPosted from ${sbn.packageName}")
            val pkg   = sbn.packageName ?: return
            val extras: Bundle = sbn.notification?.extras ?: return

            // getString() returns null for SpannableString values (most real notifications); use CharSequence.
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text  = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
            val full  = "$title $text"

            // Check if it looks like a bank/financial message
            val isBankApp = BANK_SENDERS.any { keyword ->
                pkg.contains(keyword, ignoreCase = true) ||
                title.contains(keyword, ignoreCase = true)
            }
            val hasOtpKeyword = full.contains("otp", ignoreCase = true) ||
                                full.contains("one time", ignoreCase = true) ||
                                full.contains("verification code", ignoreCase = true) ||
                                full.contains("security code", ignoreCase = true)

            android.util.Log.d("SSNotif", "posted pkg=$pkg bank=$isBankApp otpKeyword=$hasOtpKeyword")
            if (!isBankApp && !hasOtpKeyword) return

            // Extract OTP digits
            val otp = OTP_PATTERNS.firstNotNullOfOrNull { pattern ->
                pattern.find(full)?.groupValues?.getOrNull(1)
            } ?: return

            android.util.Log.d("SSNotif", "OTP pattern matched; broadcasting (value not logged)")
            // Broadcast to app
            val intent = android.content.Intent(ACTION_BANK_OTP).apply {
                putExtra(EXTRA_OTP,     otp)
                putExtra(EXTRA_BANK,    guessBank(pkg, title))
                putExtra(EXTRA_PACKAGE, pkg)
                `package` = applicationContext.packageName
            }
            sendBroadcast(intent)

        } catch (_: Exception) { /* never crash */ }
    }

    private fun guessBank(pkg: String, title: String): String {
        val combined = "$pkg $title".lowercase()
        return when {
            combined.contains("sbi")       -> "SBI"
            combined.contains("hdfc")      -> "HDFC Bank"
            combined.contains("icici")     -> "ICICI Bank"
            combined.contains("axis")      -> "Axis Bank"
            combined.contains("kotak")     -> "Kotak Bank"
            combined.contains("paytm")     -> "Paytm"
            combined.contains("phonepe")   -> "PhonePe"
            combined.contains("gpay")      -> "Google Pay"
            combined.contains("amazon")    -> "Amazon Pay"
            combined.contains("pnb")       -> "PNB"
            combined.contains("bob")       -> "Bank of Baroda"
            combined.contains("canara")    -> "Canara Bank"
            combined.contains("indusind")  -> "IndusInd Bank"
            combined.contains("yes")       -> "Yes Bank"
            combined.contains("federal")   -> "Federal Bank"
            else                           -> title.ifBlank { "Bank" }
        }
    }
}

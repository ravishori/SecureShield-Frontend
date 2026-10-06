package com.secureshield.secureshield_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import java.io.FileInputStream
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * SecureShield local VPN service for outbound traffic monitoring.
 *
 * Architecture — blocklist mode (changed after device testing):
 *  • The tun interface is given routes ONLY for the known-bad IP ranges in SUSPICIOUS_IP_PREFIXES.
 *    All other traffic bypasses the VPN and flows normally.
 *  • A packet that reaches the tun is a connection attempt to a flagged range; it is read (header only),
 *    reported to Flutter via ACTION_VPN_TRAFFIC, and dropped, i.e. the connection is blocked.
 *
 * WHY: the first version routed 0.0.0.0/0 into the tun and never wrote packets back, so while the monitor was on
 * the phone had NO internet at all (reproduced on the emulator: the app could not even reach its own API).
 * A real "see every destination" monitor needs a user-space TCP/UDP forwarder, which this app does not have.
 * Consequence: domain-based detection (SUSPICIOUS_DOMAINS) no longer sees traffic; only IP ranges are monitored.
 *
 * Privacy: packet payloads are never read or stored — only destination IPs.
 *
 * **Crash hardening (v2):**
 *  - All public lifecycle methods wrapped in try/catch — never let an exception
 *    bubble out of onStartCommand or onDestroy (Android will kill the app).
 *  - startForeground uses ServiceCompat.startForeground with explicit
 *    FOREGROUND_SERVICE_TYPE for Android 14+ compatibility.
 *  - establish() failure cleans up the foreground notification before stopping.
 */
class SecureShieldVpnService : VpnService() {

    companion object {
        private const val TAG = "SecureShieldVpn"
        const val ACTION_START        = "START_VPN"
        const val ACTION_STOP         = "STOP_VPN"
        const val ACTION_VPN_TRAFFIC  = "com.secureshield.VPN_TRAFFIC"
        const val EXTRA_DEST_IP       = "dest_ip"
        const val EXTRA_DEST_DOMAIN   = "dest_domain"
        const val EXTRA_THREAT_LEVEL  = "threat_level"    // safe / suspicious / malicious
        const val EXTRA_APP_NAME      = "app_name"
        const val CHANNEL_ID          = "vpn_monitor"
        const val NOTIFICATION_ID     = 2001

        @Volatile
        var isRunning                 = false
            private set

        // Well-known malicious / suspicious IP ranges and domains
        private val SUSPICIOUS_DOMAINS = setOf(
            "track.adtrue.com", "adservice.google.com.ua", "update-service.info",
            "mobile-analytics.net", "stats-collector.biz", "phone-tracker.xyz",
            "yourmobilespy.com", "mspy.com", "hoverwatch.com", "flexispy.com",
            "spyera.com", "ikeymonitor.com", "spyic.com", "cocospy.com",
            "thetruthspy.com", "highster.mobile.com", "copy9.com",
            "spapp-monitoring.com", "familytime.io", "famisafe.com",
        )

        private val SUSPICIOUS_IP_PREFIXES = listOf(
            "185.220.",
            "45.142.",
            "91.108.56",
        )

        // The same ranges as CIDR routes (keep in sync with SUSPICIOUS_IP_PREFIXES).
        private val BLOCKED_ROUTES = listOf(
            "185.220.0.0" to 16,
            "45.142.0.0" to 16,
            "91.108.56.0" to 24,
        )

        private val KNOWN_SAFE_DOMAINS = setOf(
            "google.com", "googleapis.com", "gstatic.com",
            "apple.com", "icloud.com",
            "microsoft.com", "windows.com",
            "amazon.com", "amazonaws.com",
            "cloudflare.com", "cloudfront.net",
            "akamai.com", "akamaiedge.net",
            "facebook.com", "instagram.com", "whatsapp.com",
            "twitter.com", "x.com",
            "youtube.com", "ytimg.com",
            "razorpay.com", "paytm.com", "phonepe.com",
            "sbi.co.in", "hdfcbank.com", "icicibank.com",
            "gov.in", "nic.in",
        )

        // Resolves the correct foregroundServiceType bitmask for the running API level.
        // We declare systemExempted|dataSync|specialUse in the manifest; here we pick
        // the most appropriate at runtime.
        @JvmStatic
        private fun resolveForegroundServiceType(): Int {
            return when {
                // Android 14+ (API 34): use SYSTEM_EXEMPTED for security/privacy VPN
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE ->
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                // Android 10-13: use DATA_SYNC (introduced API 29)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                // Older: no type needed
                else -> 0
            }
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private val running        = AtomicBoolean(false)

    private var readThread: Thread? = null
    private val checkExecutor = Executors.newCachedThreadPool()

    override fun onCreate() {
        super.onCreate()
        // Channel must exist before any startForeground call.
        try { createNotificationChannel() } catch (e: Exception) {
            Log.e(TAG, "Failed to create notification channel", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // CRITICAL: any exception that escapes from here kills the host process.
        try {
            // Android 8+: we MUST call startForeground within ~5s of being started
            // via startForegroundService. Do it FIRST, before any other work, to
            // avoid ForegroundServiceDidNotStartInTimeException.
            promoteToForeground()

            when (intent?.action) {
                ACTION_START -> startVpn()
                ACTION_STOP  -> stopVpn()
                else         -> {
                    // Unknown action — fall through to STOP so we don't leak the FGS.
                    stopVpn()
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "onStartCommand failed", e)
            safeStop()
        }
        return START_NOT_STICKY
    }

    private fun promoteToForeground() {
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(),
                resolveForegroundServiceType()
            )
        } catch (e: Throwable) {
            Log.e(TAG, "startForeground failed", e)
            // Don't rethrow — the service will simply not be a foreground service.
            // The system may then kill it sooner, but the app won't crash.
        }
    }

    private fun startVpn() {
        if (running.get()) return

        val iface: ParcelFileDescriptor? = try {
            val builder = Builder()
                .setSession("SecureShield Traffic Monitor")
                .addAddress("10.250.1.1", 32)
                .setMtu(1500)
                .setBlocking(false)

            // Only flagged ranges are routed into the tun (see class comment).
            for ((address, prefix) in BLOCKED_ROUTES) {
                try { builder.addRoute(address, prefix) } catch (e: Exception) {
                    Log.w(TAG, "addRoute failed for $address/$prefix", e)
                }
            }

            // Bypass our own traffic to prevent looping. protect() before
            // establish() is the documented order.
            try {
                val sock = DatagramSocket()
                try { protect(sock) } finally {
                    try { sock.close() } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                Log.w(TAG, "protect() socket failed (continuing)", e)
            }

            builder.establish()
        } catch (e: Throwable) {
            Log.e(TAG, "VPN Builder.establish() failed", e)
            null
        }

        if (iface == null) {
            Log.w(TAG, "establish() returned null — VPN permission likely revoked or another VPN active")
            safeStop()
            return
        }

        vpnInterface = iface
        running.set(true)
        isRunning = true

        readThread = Thread({ readPacketsSafely() }, "secureshield-vpn-reader").apply {
            isDaemon = true
            start()
        }
    }

    private fun stopVpn() {
        running.set(false)
        isRunning = false
        try { readThread?.interrupt() } catch (_: Exception) {}
        readThread = null
        try { vpnInterface?.close() } catch (_: Exception) {}
        vpnInterface = null
        try { ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        try { stopSelf() } catch (_: Exception) {}
    }

    /**
     * Last-resort cleanup. Called from catch blocks where we don't know what
     * state we're in. Idempotent and exception-proof.
     */
    private fun safeStop() {
        try {
            running.set(false)
            isRunning = false
            try { readThread?.interrupt() } catch (_: Exception) {}
            readThread = null
            try { vpnInterface?.close() } catch (_: Exception) {}
            vpnInterface = null
            try { ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
            try { stopSelf() } catch (_: Exception) {}
        } catch (_: Throwable) {
            // Truly last resort — swallow.
        }
    }

    /**
     * Outer wrapper that guarantees the reader thread cannot crash the process.
     */
    private fun readPacketsSafely() {
        try {
            readPackets()
        } catch (e: Throwable) {
            Log.e(TAG, "Reader thread crashed", e)
        }
    }

    /**
     * Reads raw IP packets from the tun interface.
     * Extracts only destination IP from IP header (bytes 16-19).
     * Checks against threat lists and broadcasts results.
     */
    private fun readPackets() {
        val iface = vpnInterface ?: return

        val inputStream = try {
            FileInputStream(iface.fileDescriptor)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to open VPN file descriptor", e)
            return
        }

        val buffer    = ByteArray(32768)
        val recentIps = LinkedHashMap<String, Long>()

        try {
            while (running.get()) {
                try {
                    val length = try { inputStream.read(buffer) }
                        catch (_: java.io.InterruptedIOException) { break }
                        catch (_: java.io.IOException) { -1 }
                    if (length <= 0) {
                        try { Thread.sleep(5) } catch (_: InterruptedException) { break }
                        continue
                    }

                    val version = (buffer[0].toInt() and 0xFF) shr 4
                    if (version != 4) continue
                    if (length < 20) continue

                    val destIp = String.format(
                        "%d.%d.%d.%d",
                        buffer[16].toInt() and 0xFF,
                        buffer[17].toInt() and 0xFF,
                        buffer[18].toInt() and 0xFF,
                        buffer[19].toInt() and 0xFF,
                    )

                    if (isPrivateIp(destIp)) continue

                    val now = System.currentTimeMillis()
                    if ((recentIps[destIp] ?: 0L) > now - 30_000L) continue
                    recentIps[destIp] = now
                    if (recentIps.size > 500) {
                        try {
                            val oldest = recentIps.entries.iterator().next()
                            recentIps.remove(oldest.key)
                        } catch (_: Exception) {}
                    }

                    if (!checkExecutor.isShutdown) {
                        try {
                            checkExecutor.submit { checkAndBroadcastSafely(destIp) }
                        } catch (_: java.util.concurrent.RejectedExecutionException) {
                            // Executor is shutting down — drop the work.
                        }
                    }

                } catch (_: InterruptedException) { break }
                catch (e: Throwable) {
                    // Never let an unexpected throwable kill the reader.
                    Log.w(TAG, "Transient read error (continuing)", e)
                }
            }
        } finally {
            try { inputStream.close() } catch (_: Exception) {}
        }
    }

    private fun checkAndBroadcastSafely(destIp: String) {
        try { checkAndBroadcast(destIp) } catch (e: Throwable) {
            Log.w(TAG, "checkAndBroadcast failed for $destIp", e)
        }
    }

    private fun checkAndBroadcast(destIp: String) {
        val domain = try {
            InetAddress.getByName(destIp).canonicalHostName
        } catch (_: Exception) { destIp }

        val threatLevel = classifyThreat(destIp, domain)

        try {
            sendBroadcast(Intent(ACTION_VPN_TRAFFIC).apply {
                putExtra(EXTRA_DEST_IP,      destIp)
                putExtra(EXTRA_DEST_DOMAIN,  domain)
                putExtra(EXTRA_THREAT_LEVEL, threatLevel)
                `package` = applicationContext.packageName
            })
        } catch (e: Exception) {
            Log.w(TAG, "sendBroadcast failed", e)
        }

        if (threatLevel == "malicious") {
            try { showThreatNotification(domain, destIp) } catch (_: Exception) {}
        }
    }

    private fun classifyThreat(ip: String, domain: String): String {
        val domainLower = domain.lowercase()

        val isSafe = KNOWN_SAFE_DOMAINS.any { safe ->
            domainLower == safe || domainLower.endsWith(".$safe")
        }
        if (isSafe) return "safe"

        val isMalicious = SUSPICIOUS_DOMAINS.any { bad ->
            domainLower == bad || domainLower.endsWith(".$bad")
        }
        if (isMalicious) return "malicious"

        val isSuspiciousIp = SUSPICIOUS_IP_PREFIXES.any { prefix -> ip.startsWith(prefix) }
        if (isSuspiciousIp) return "suspicious"

        val suspiciousTlds = listOf(".xyz", ".tk", ".ml", ".ga", ".cf", ".top", ".pw", ".cc")
        if (suspiciousTlds.any { domainLower.endsWith(it) }) return "suspicious"

        return "safe"
    }

    private fun isPrivateIp(ip: String): Boolean {
        return ip.startsWith("10.") ||
               ip.startsWith("192.168.") ||
               ip.startsWith("172.") ||
               ip.startsWith("127.") ||
               ip.startsWith("169.254.") ||
               ip == "0.0.0.0"
    }

    private fun showThreatNotification(domain: String, ip: String) {
        try {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("⚠️ Suspicious Connection Detected")
                .setContentText("Your device connected to: $domain ($ip)")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()
            nm.notify(ip.hashCode(), notification)
        } catch (e: Exception) {
            Log.w(TAG, "showThreatNotification failed", e)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, SecureShieldVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("SecureShield — Traffic Monitor")
            .setContentText("Monitoring network traffic for threats")
            .addAction(android.R.drawable.ic_delete, "Stop", stopPi)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "VPN Traffic Monitor", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Background VPN traffic monitoring" }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    override fun onRevoke() {
        try { safeStop() } catch (_: Throwable) {}
        try { super.onRevoke() } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        try { safeStop() } catch (_: Throwable) {}
        try { checkExecutor.shutdownNow() } catch (_: Throwable) {}
        try { super.onDestroy() } catch (_: Throwable) {}
    }
}

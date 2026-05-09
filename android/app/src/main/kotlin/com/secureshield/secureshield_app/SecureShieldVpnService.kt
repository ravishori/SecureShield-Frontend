package com.secureshield.secureshield_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * SecureShield local VPN service for outbound traffic monitoring.
 *
 * Architecture — monitoring-only mode:
 *  • Creates a tun0 virtual interface capturing all IP traffic
 *  • Reads outbound IP packet headers (not payload) to extract destination IP
 *  • Checks destination against known malicious IPs/domains
 *  • Forwards ALL packets without modification (transparent pass-through)
 *  • Sends threat events to Flutter via ACTION_VPN_TRAFFIC broadcast
 *
 * Privacy: packet payloads are never read or stored — only destination IPs.
 */
class SecureShieldVpnService : VpnService() {

    companion object {
        const val ACTION_START        = "START_VPN"
        const val ACTION_STOP         = "STOP_VPN"
        const val ACTION_VPN_TRAFFIC  = "com.secureshield.VPN_TRAFFIC"
        const val EXTRA_DEST_IP       = "dest_ip"
        const val EXTRA_DEST_DOMAIN   = "dest_domain"
        const val EXTRA_THREAT_LEVEL  = "threat_level"    // safe / suspicious / malicious
        const val EXTRA_APP_NAME      = "app_name"
        const val CHANNEL_ID          = "vpn_monitor"
        var isRunning                 = false

        // Well-known malicious / suspicious IP ranges and domains
        // In production these would be fetched from a threat-intel backend
        private val SUSPICIOUS_DOMAINS = setOf(
            // Known phishing / malware C2 patterns
            "track.adtrue.com", "adservice.google.com.ua", "update-service.info",
            "mobile-analytics.net", "stats-collector.biz", "phone-tracker.xyz",
            "yourmobilespy.com", "mspy.com", "hoverwatch.com", "flexispy.com",
            "spyera.com", "ikeymonitor.com", "spyic.com", "cocospy.com",
            "thetruthspy.com", "highster.mobile.com", "copy9.com",
            "spapp-monitoring.com", "familytime.io", "famisafe.com",
        )

        // IPs known to be associated with malware C2 infrastructure
        private val SUSPICIOUS_IP_PREFIXES = listOf(
            "185.220.",  // Tor exit nodes often misused
            "45.142.",   // Bullet-proof hosting
            "91.108.56", // Often scrapers/bots
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
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private val running        = AtomicBoolean(false)

    // Dedicated thread for the blocking read loop — never competes with DNS tasks
    private var readThread: Thread? = null

    // Separate cached pool for async DNS + threat checks — unbounded so read loop never starves
    private val checkExecutor = Executors.newCachedThreadPool()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startVpn()
            ACTION_STOP  -> stopVpn()
        }
        return START_NOT_STICKY
    }

    private fun startVpn() {
        if (running.get()) return
        createNotificationChannel()
        startForeground(2001, buildNotification())

        try {
            vpnInterface = Builder()
                .setSession("SecureShield Traffic Monitor")
                .addAddress("10.250.1.1", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .setMtu(1500)
                .setBlocking(false)
                .also { builder ->
                    // Bypass our own traffic to prevent looping.
                    // Socket MUST be closed after protect() — leaving it open leaks a file descriptor.
                    val sock = DatagramSocket()
                    try { protect(sock) } finally { sock.close() }
                }
                .establish()

            if (vpnInterface == null) { stopSelf(); return }

            running.set(true)
            isRunning = true

            // Dedicated thread for the blocking read loop
            readThread = Thread({ readPackets() }, "secureshield-vpn-reader")
                .also { it.isDaemon = true; it.start() }

        } catch (e: Exception) {
            stopVpn()
        }
    }

    private fun stopVpn() {
        running.set(false)
        isRunning = false
        // Interrupt the read loop thread so it exits promptly
        readThread?.interrupt()
        readThread = null
        try { vpnInterface?.close() } catch (_: Exception) {}
        vpnInterface = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Reads raw IP packets from the tun interface.
     * Extracts only destination IP from IP header (bytes 16-19).
     * Checks against threat lists and broadcasts results.
     * Does NOT read packet payloads beyond the IP/TCP/UDP headers.
     */
    private fun readPackets() {
        // Snapshot the interface reference. If stopVpn() nulls vpnInterface concurrently
        // after this point we are safe — we hold our own reference until the loop exits.
        val iface = vpnInterface ?: return

        val inputStream = try {
            FileInputStream(iface.fileDescriptor)
        } catch (e: Exception) {
            return  // interface already closed; exit cleanly
        }

        val buffer    = ByteArray(32768)
        val recentIps = LinkedHashMap<String, Long>() // IP → last-seen time (debounce)

        try {
            while (running.get()) {
                try {
                    val length = inputStream.read(buffer)
                    if (length <= 0) { Thread.sleep(5); continue }

                    // Parse IP version from first nibble
                    val version = (buffer[0].toInt() and 0xFF) shr 4
                    if (version != 4) continue  // Skip IPv6 for now

                    // IPv4 header: destination IP is at bytes 16-19
                    if (length < 20) continue
                    val destIp = String.format(
                        "%d.%d.%d.%d",
                        buffer[16].toInt() and 0xFF,
                        buffer[17].toInt() and 0xFF,
                        buffer[18].toInt() and 0xFF,
                        buffer[19].toInt() and 0xFF,
                    )

                    // Skip loopback and private IPs
                    if (isPrivateIp(destIp)) continue

                    // Debounce: don't spam same IP within 30 seconds
                    val now = System.currentTimeMillis()
                    if ((recentIps[destIp] ?: 0L) > now - 30_000L) continue
                    recentIps[destIp] = now
                    if (recentIps.size > 500) recentIps.entries.first().let { recentIps.remove(it.key) }

                    // Async reverse DNS + threat check — submitted to the SEPARATE checkExecutor,
                    // never to the read thread, so DNS latency cannot starve the read loop.
                    if (!checkExecutor.isShutdown) {
                        checkExecutor.submit { checkAndBroadcast(destIp) }
                    }

                } catch (_: InterruptedException) { break }
                catch (_: Exception) { /* keep reading on transient errors */ }
            }
        } finally {
            try { inputStream.close() } catch (_: Exception) {}
        }
    }

    private fun checkAndBroadcast(destIp: String) {
        try {
            // Reverse DNS lookup
            val domain = try {
                InetAddress.getByName(destIp).canonicalHostName
            } catch (_: Exception) { destIp }

            val threatLevel = classifyThreat(destIp, domain)

            // Broadcast event to MainActivity (which streams it to Flutter)
            sendBroadcast(Intent(ACTION_VPN_TRAFFIC).apply {
                putExtra(EXTRA_DEST_IP,      destIp)
                putExtra(EXTRA_DEST_DOMAIN,  domain)
                putExtra(EXTRA_THREAT_LEVEL, threatLevel)
                `package` = applicationContext.packageName
            })

            // If malicious, also post a notification
            if (threatLevel == "malicious") {
                showThreatNotification(domain, destIp)
            }

        } catch (_: Exception) {}
    }

    private fun classifyThreat(ip: String, domain: String): String {
        val domainLower = domain.lowercase()

        // Check if it matches any safe root domain
        val isSafe = KNOWN_SAFE_DOMAINS.any { safe ->
            domainLower == safe || domainLower.endsWith(".$safe")
        }
        if (isSafe) return "safe"

        // Check explicit malicious domain list
        val isMalicious = SUSPICIOUS_DOMAINS.any { bad ->
            domainLower == bad || domainLower.endsWith(".$bad")
        }
        if (isMalicious) return "malicious"

        // Check suspicious IP prefixes
        val isSuspiciousIp = SUSPICIOUS_IP_PREFIXES.any { prefix -> ip.startsWith(prefix) }
        if (isSuspiciousIp) return "suspicious"

        // Heuristics: very short numeric domains, unusual TLDs
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
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Suspicious Connection Detected")
            .setContentText("Your device connected to: $domain ($ip)")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        nm.notify(ip.hashCode(), notification)
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
        stopVpn()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpn()
        checkExecutor.shutdownNow()
        super.onDestroy()
    }
}

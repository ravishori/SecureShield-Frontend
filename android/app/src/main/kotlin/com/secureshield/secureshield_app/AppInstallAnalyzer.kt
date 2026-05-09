package com.secureshield.secureshield_app

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.pm.PackageInfoCompat

/**
 * AppInstallAnalyzer — pure analysis engine; no Android service lifecycle.
 *
 * Responsibilities:
 *  1. Extract detailed metadata (permissions, installer, overlay, etc.) for a package
 *  2. Run local clone detection using Levenshtein + Jaccard heuristics
 *  3. Compute a preliminary local risk score (0-100) so the UI can display
 *     something immediately before the server refines it
 *
 * This class is thread-safe.  Call [analyze] from any thread.
 */
object AppInstallAnalyzer {

    // ── Known-legitimate app catalogue (mirrors backend clone_analyzer.py) ────
    private val KNOWN_APPS: Map<String, String> = mapOf(
        "com.whatsapp"                           to "WhatsApp",
        "com.whatsapp.w4b"                       to "WhatsApp Business",
        "com.google.android.gm"                  to "Gmail",
        "com.google.android.apps.maps"           to "Google Maps",
        "com.phonepe.app"                        to "PhonePe",
        "net.one97.paytm"                        to "Paytm",
        "com.google.android.apps.nbu.paisa.user" to "Google Pay",
        "com.amazon.mShop.android.shopping"      to "Amazon Shopping",
        "com.flipkart.android"                   to "Flipkart",
        "com.snapchat.android"                   to "Snapchat",
        "com.instagram.android"                  to "Instagram",
        "com.facebook.katana"                    to "Facebook",
        "com.twitter.android"                    to "X (Twitter)",
        "org.telegram.messenger"                 to "Telegram",
        "com.truecaller"                         to "Truecaller",
        "com.ola.client"                         to "Ola",
        "com.ubercab"                            to "Uber",
        "com.swiggy.android"                     to "Swiggy",
        "com.zomato.android"                     to "Zomato",
        "com.netflix.mediaclient"                to "Netflix",
        "in.startv.hotstar"                      to "Disney+ Hotstar",
        "com.google.android.youtube"             to "YouTube",
        "com.spotify.music"                      to "Spotify",
        "us.zoom.videomeetings"                  to "Zoom",
        "com.microsoft.teams"                    to "Microsoft Teams",
        "com.razorpay.payments.app"              to "Razorpay",
        "com.irctc.rajdhani.prod"                to "IRCTC",
        "in.gov.uidai.mAadhaarPlus"              to "mAadhaar",
        "in.digilocker.android"                  to "DigiLocker",
        "com.sbi.SBIFreedomPlus"                 to "SBI YONO",
        "com.csam.icici.bank.imobile"            to "iMobile Pay",
        "com.axis.mobile"                        to "Axis Mobile",
        "com.hdfcbank.app"                       to "HDFC Bank",
        "com.kotak.mahindra.kotak_mobile"        to "Kotak Mobile",
        "com.makemytrip"                         to "MakeMyTrip",
        "com.bookmyshow.app"                     to "BookMyShow",
        "com.google.android.apps.meetings"       to "Google Meet",
        "com.myntra.android"                     to "Myntra",
        "com.ajio.app"                           to "Ajio",
        "com.jio.myjio"                          to "MyJio",
        "com.airtel.android.phone"               to "Airtel Thanks",
        "com.cred.club"                          to "CRED",
        "com.groww.app"                          to "Groww",
        "com.zerodha.kite3"                      to "Zerodha Kite",
        "com.upstox.stocks"                      to "Upstox",
    )

    private val KNOWN_STORES = setOf(
        "com.android.vending",
        "com.amazon.venezia",
        "com.sec.android.app.samsungapps",
        "org.fdroid.fdroid",
        "com.huawei.appmarket",
        "com.xiaomi.market",
    )

    private val DANGEROUS_PERMISSIONS = setOf(
        "android.permission.READ_SMS",
        "android.permission.SEND_SMS",
        "android.permission.RECEIVE_SMS",
        "android.permission.READ_CONTACTS",
        "android.permission.READ_CALL_LOG",
        "android.permission.RECORD_AUDIO",
        "android.permission.CAMERA",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_BACKGROUND_LOCATION",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.PROCESS_OUTGOING_CALLS",
        "android.permission.READ_PHONE_STATE",
        "android.permission.GET_ACCOUNTS",
    )

    // ── Public API ────────────────────────────────────────────────────────────

    data class AnalysisResult(
        val packageName:      String,
        val appName:          String,
        val versionName:      String,
        val eventType:        String,          // installed / updated / removed
        val installerPackage: String?,
        val isUnknownSource:  Boolean,
        val isSystemApp:      Boolean,
        val dangerousPerms:   List<String>,
        val permCount:        Int,
        val hasOverlay:       Boolean,
        val firstInstallTime: Long,
        // Clone analysis
        val cloneProbability: Int,             // 0-100
        val cloneTargetPkg:   String?,
        val cloneTargetName:  String?,
        val cloneVerdict:     String,          // safe / suspicious / likely_clone / confirmed_clone
        val cloneSignals:     List<String>,
        // Local preliminary risk
        val localRiskScore:   Int,             // 0-100
        val localRiskLevel:   String,          // safe / warning / danger
        val localRiskTags:    List<String>,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "packageName"      to packageName,
            "appName"          to appName,
            "versionName"      to versionName,
            "eventType"        to eventType,
            "installerPackage" to installerPackage,
            "isUnknownSource"  to isUnknownSource,
            "isSystemApp"      to isSystemApp,
            "dangerousPerms"   to dangerousPerms,
            "permCount"        to permCount,
            "hasOverlay"       to hasOverlay,
            "firstInstallTime" to firstInstallTime,
            "cloneProbability" to cloneProbability,
            "cloneTargetPkg"   to cloneTargetPkg,
            "cloneTargetName"  to cloneTargetName,
            "cloneVerdict"     to cloneVerdict,
            "cloneSignals"     to cloneSignals,
            "localRiskScore"   to localRiskScore,
            "localRiskLevel"   to localRiskLevel,
            "localRiskTags"    to localRiskTags,
            "timestamp"        to System.currentTimeMillis(),
        )
    }

    fun analyze(context: Context, packageName: String, eventType: String): AnalysisResult? {
        val pm = context.packageManager

        // For removals, we can't inspect the package anymore — emit a minimal event
        if (eventType == "removed") {
            return AnalysisResult(
                packageName=packageName, appName=packageName, versionName="",
                eventType="removed", installerPackage=null, isUnknownSource=false,
                isSystemApp=false, dangerousPerms=emptyList(), permCount=0,
                hasOverlay=false, firstInstallTime=0L,
                cloneProbability=0, cloneTargetPkg=null, cloneTargetName=null,
                cloneVerdict="safe", cloneSignals=emptyList(),
                localRiskScore=0, localRiskLevel="safe", localRiskTags=emptyList(),
            )
        }

        val pkgInfo: PackageInfo = try {
            val flags = PackageManager.GET_PERMISSIONS
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, flags)
            }
        } catch (_: Exception) { return null }

        val ai = pkgInfo.applicationInfo ?: return null

        val appName = pm.getApplicationLabel(ai).toString()
        val versionName = pkgInfo.versionName ?: ""

        val isSystem = (ai.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

        val installer: String? = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pm.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(packageName)
            }
        } catch (_: Exception) { null }

        val isUnknown = installer == null || !KNOWN_STORES.contains(installer)

        // Dangerous permissions
        val granted = pkgInfo.requestedPermissions
            ?.filterIndexed { i, perm ->
                DANGEROUS_PERMISSIONS.contains(perm) &&
                ((pkgInfo.requestedPermissionsFlags?.getOrNull(i) ?: 0)
                    and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
            } ?: emptyList()

        // Overlay permission (AppOpsManager)
        val hasOverlay = try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(android.app.AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, ai.uid, packageName)
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(android.app.AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, ai.uid, packageName)
            }
            mode == android.app.AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) { false }

        // ── Clone detection ───────────────────────────────────────────────────
        val cloneResult = detectClone(packageName, appName)

        // ── Local risk scoring ─────────────────────────────────────────────────
        val risk = localRiskScore(
            permCount   = granted.size,
            isUnknown   = isUnknown,
            cloneScore  = cloneResult.probability,
            hasOverlay  = hasOverlay,
        )

        return AnalysisResult(
            packageName      = packageName,
            appName          = appName,
            versionName      = versionName,
            eventType        = eventType,
            installerPackage = installer,
            isUnknownSource  = isUnknown,
            isSystemApp      = isSystem,
            dangerousPerms   = granted,
            permCount        = granted.size,
            hasOverlay       = hasOverlay,
            firstInstallTime = pkgInfo.firstInstallTime,
            cloneProbability = cloneResult.probability,
            cloneTargetPkg   = cloneResult.targetPkg,
            cloneTargetName  = cloneResult.targetName,
            cloneVerdict     = cloneResult.verdict,
            cloneSignals     = cloneResult.signals,
            localRiskScore   = risk.score,
            localRiskLevel   = risk.level,
            localRiskTags    = risk.tags,
        )
    }

    // ── Clone detection ───────────────────────────────────────────────────────

    private data class CloneResult(
        val probability: Int,       // 0-100
        val targetPkg:   String?,
        val targetName:  String?,
        val verdict:     String,
        val signals:     List<String>,
    )

    private fun detectClone(packageName: String, appName: String): CloneResult {
        // Exact match in catalogue → it's the legitimate app (skip cert check locally)
        if (KNOWN_APPS.containsKey(packageName)) {
            return CloneResult(0, packageName, KNOWN_APPS[packageName], "safe", emptyList())
        }

        var bestPkg: String? = null
        var bestName: String? = null
        var bestNSim = 0
        var bestPSim = 0

        for ((knownPkg, knownName) in KNOWN_APPS) {
            val nsim = nameSimilarity(appName, knownName)
            val psim = pkgSimilarity(packageName, knownPkg)
            val combined = (nsim * 0.55 + psim * 0.45).toInt()
            if (combined > (bestNSim * 0.55 + bestPSim * 0.45).toInt()) {
                bestNSim = nsim; bestPSim = psim
                bestPkg = knownPkg; bestName = knownName
            }
        }

        val overall = (bestNSim * 0.55 + bestPSim * 0.45).toInt()
        val signals = mutableListOf<String>()
        if (bestNSim >= 80) signals.add("Name ${bestNSim}% similar to '$bestName'")
        if (bestPSim >= 70) signals.add("Package resembles '$bestPkg'")

        val verdict = when {
            overall >= 85 -> "confirmed_clone"
            overall >= 65 -> "likely_clone"
            overall >= 40 -> "suspicious"
            else          -> "safe"
        }
        if (verdict == "safe") signals.clear()

        return CloneResult(overall, bestPkg, bestName, verdict, signals)
    }

    // ── String similarity helpers ─────────────────────────────────────────────

    private fun levenshtein(s: String, t: String): Int {
        val m = s.length; val n = t.length
        val dp = IntArray(n + 1) { it }
        for (i in 1..m) {
            val prev = dp.copyOf()
            dp[0] = i
            for (j in 1..n) {
                val cost = if (s[i-1] == t[j-1]) 0 else 1
                dp[j] = minOf(dp[j] + 1, dp[j-1] + 1, prev[j-1] + cost)
            }
        }
        return dp[n]
    }

    private fun nameSimilarity(a: String, b: String): Int {
        val la = a.lowercase().trim(); val lb = b.lowercase().trim()
        if (la == lb) return 100
        val maxLen = maxOf(la.length, lb.length, 1)
        return ((1 - levenshtein(la, lb).toDouble() / maxLen) * 100).toInt()
    }

    private fun pkgSimilarity(pkgA: String, pkgB: String): Int {
        fun tok(p: String): Set<String> =
            p.lowercase().replace("-", ".").replace("_", ".").split(".")
             .filter { it.isNotEmpty() && it !in setOf("com", "in", "org", "net") }.toSet()
        val ta = tok(pkgA); val tb = tok(pkgB)
        if (ta.isEmpty() || tb.isEmpty()) return 0
        return ((ta.intersect(tb).size.toDouble() / ta.union(tb).size) * 100).toInt()
    }

    // ── Local risk scoring ────────────────────────────────────────────────────

    private data class RiskResult(val score: Int, val level: String, val tags: List<String>)

    private fun localRiskScore(
        permCount: Int,
        isUnknown: Boolean,
        cloneScore: Int,
        hasOverlay: Boolean,
    ): RiskResult {
        val tags = mutableListOf<String>()

        val permPts = (minOf(1.0, permCount / 5.0) * 100 * 0.35).toInt()
        if (permCount >= 3) tags.add("$permCount sensitive permissions")

        val srcPts = if (isUnknown) (100 * 0.25).toInt() else 0
        if (isUnknown) tags.add("Installed from unknown source")

        val clonePts = (cloneScore * 0.30).toInt()
        if (cloneScore >= 65) tags.add("High similarity to a known app")

        val behavPts = if (hasOverlay) (100 * 0.10).toInt() else 0
        if (hasOverlay) tags.add("Can draw over other apps")

        val total = minOf(100, permPts + srcPts + clonePts + behavPts)
        val level = when {
            total >= 67 -> "danger"
            total >= 34 -> "warning"
            else        -> "safe"
        }
        return RiskResult(total, level, tags)
    }
}

package com.secureshield.secureshield_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.TrafficStats
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val WINDOW_CHANNEL  = "secureshield/window_flags"
        private const val SCANNER_CHANNEL = "secureshield/device_scanner"

        /** Permissions we consider "dangerous" for risk scoring */
        private val DANGEROUS_PERMISSIONS = setOf(
            "android.permission.READ_SMS",
            "android.permission.SEND_SMS",
            "android.permission.RECEIVE_SMS",
            "android.permission.READ_CONTACTS",
            "android.permission.WRITE_CONTACTS",
            "android.permission.READ_CALL_LOG",
            "android.permission.WRITE_CALL_LOG",
            "android.permission.RECORD_AUDIO",
            "android.permission.CAMERA",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.ACCESS_COARSE_LOCATION",
            "android.permission.ACCESS_BACKGROUND_LOCATION",
            "android.permission.READ_EXTERNAL_STORAGE",
            "android.permission.WRITE_EXTERNAL_STORAGE",
            "android.permission.PROCESS_OUTGOING_CALLS",
            "android.permission.READ_PHONE_STATE",
            "android.permission.GET_ACCOUNTS",
            "android.permission.USE_CREDENTIALS",
            "android.permission.MANAGE_ACCOUNTS",
        )

        /** Known legitimate installer package names */
        private val KNOWN_STORES = setOf(
            "com.android.vending",            // Google Play
            "com.amazon.venezia",             // Amazon Appstore
            "com.sec.android.app.samsungapps",// Samsung Galaxy Store
            "org.fdroid.fdroid",              // F-Droid
            "com.huawei.appmarket",           // Huawei AppGallery
            "com.xiaomi.market",              // Xiaomi Mi Store
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Screenshot prevention ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WINDOW_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecure" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disableSecure" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Device scanner ───────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps"        -> result.success(getInstalledApps())
                    "getAccessibilityServices"-> result.success(getAccessibilityServices())
                    "uninstallApp"            -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        uninstallApp(pkg)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ────────────────────────────────────────────────────────────────────────
    // Gather all installed (non-own) packages with security-relevant metadata
    // ────────────────────────────────────────────────────────────────────────
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm    = packageManager
        val flags = PackageManager.GET_PERMISSIONS or PackageManager.GET_META_DATA
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

        val packages: List<PackageInfo> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(flags)
            }

        val output = mutableListOf<Map<String, Any?>>()

        for (pkg in packages) {
            val ai      = pkg.applicationInfo ?: continue
            val pkgName = pkg.packageName
            if (pkgName == application.packageName) continue   // skip self

            val isSystem        = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isUpdatedSystem = (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

            // Where was it installed from?
            val installer: String? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgName)
                }
            } catch (_: Exception) { null }

            // Dangerous permissions that are actually GRANTED
            val grantedDangerousPerms: List<String> =
                pkg.requestedPermissions
                    ?.filterIndexed { i, perm ->
                        DANGEROUS_PERMISSIONS.contains(perm) &&
                        (pkg.requestedPermissionsFlags?.getOrNull(i)
                            ?.and(PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0)
                    }?.toList() ?: emptyList()

            // App visible in launcher?
            val hasLauncher = pm.getLaunchIntentForPackage(pkgName) != null

            // Cumulative network usage since boot (no special permission needed)
            val uid     = ai.uid
            val rxBytes = TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L)
            val txBytes = TrafficStats.getUidTxBytes(uid).coerceAtLeast(0L)

            // SYSTEM_ALERT_WINDOW (overlay) permission granted?
            val hasOverlay = try {
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(
                        AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, uid, pkgName)
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, uid, pkgName)
                }
                mode == AppOpsManager.MODE_ALLOWED
            } catch (_: Exception) { false }

            val isFromKnownStore = installer != null && KNOWN_STORES.contains(installer)

            output.add(
                mapOf(
                    "packageName"          to pkgName,
                    "appName"              to pm.getApplicationLabel(ai).toString(),
                    "isSystem"             to isSystem,
                    "isUpdatedSystem"      to isUpdatedSystem,
                    "installer"            to installer,
                    "isFromKnownStore"     to isFromKnownStore,
                    "grantedDangerousPerms"to grantedDangerousPerms,
                    "hasLauncher"          to hasLauncher,
                    "firstInstallTime"     to pkg.firstInstallTime,
                    "lastUpdateTime"       to pkg.lastUpdateTime,
                    "rxBytes"              to rxBytes,
                    "txBytes"              to txBytes,
                    "hasOverlay"           to hasOverlay,
                    "uid"                  to uid,
                    "versionName"          to (pkg.versionName ?: ""),
                )
            )
        }

        return output
    }

    // ────────────────────────────────────────────────────────────────────────
    // Return list of enabled accessibility service component names
    // ────────────────────────────────────────────────────────────────────────
    private fun getAccessibilityServices(): List<String> {
        val raw = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return emptyList()
        return raw.split(":").filter { it.isNotBlank() }
    }

    // ────────────────────────────────────────────────────────────────────────
    // Launch system uninstall dialog for a package
    // ────────────────────────────────────────────────────────────────────────
    private fun uninstallApp(packageName: String) {
        if (packageName.isBlank()) return
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$packageName"))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}

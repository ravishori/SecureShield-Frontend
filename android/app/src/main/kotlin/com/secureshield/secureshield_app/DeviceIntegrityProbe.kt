package com.secureshield.secureshield_app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.provider.Settings
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Defense-in-depth device integrity checks for SecureShield.
 *
 * Each probe is conservative — false-positive cost is high (we'd block a
 * legitimate user) so we only return true when the signal is unambiguous.
 *
 * **Magisk Hide bypasses every file-path check.** The most reliable way
 * to detect a rooted device in production is server-side Play Integrity
 * attestation. These probes catch the rest (casual root, dev tooling,
 * runtime instrumentation).
 */
object DeviceIntegrityProbe {
    private const val TAG = "DeviceIntegrity"

    // ── Magisk detection ─────────────────────────────────────────────────────
    /**
     * Looks for filesystem and mount artefacts left by Magisk. Magisk Hide
     * scrubs most of these but stock Magisk leaves them in place.
     */
    fun isMagiskPresent(ctx: Context): Boolean {
        // 1. Filesystem markers Magisk drops at install time
        val markers = listOf(
            "/sbin/.magisk",
            "/cache/.magisk",
            "/data/adb/magisk",
            "/data/adb/modules",
            "/data/adb/post-fs-data.d",
            "/dev/.magisk.unblock",
            "/system/addon.d/99-magisk.sh",
        )
        for (m in markers) {
            if (runCatching { File(m).exists() }.getOrDefault(false)) {
                Log.d(TAG, "Magisk marker found: $m")
                return true
            }
        }
        // 2. Magisk Manager package (renamed package names are a strong signal)
        val pkgs = listOf(
            "com.topjohnwu.magisk",
            "com.topjohnwu.magisk.delta",
            "io.github.huskydg.magisk",
        )
        for (p in pkgs) {
            try {
                ctx.packageManager.getPackageInfo(p, 0)
                Log.d(TAG, "Magisk package found: $p")
                return true
            } catch (_: Throwable) { /* not installed */ }
        }
        // 3. Mounts list — Magisk uses bind-mounts to overlay system
        return runCatching {
            File("/proc/self/mounts").readText().contains("magisk")
        }.getOrDefault(false)
    }

    // ── Xposed detection ─────────────────────────────────────────────────────
    /**
     * Xposed and its successors (LSPosed, EdXposed) load classes into every
     * process. We probe for those classes via Class.forName.
     */
    fun isXposedPresent(): Boolean {
        val classes = listOf(
            "de.robv.android.xposed.XposedBridge",
            "de.robv.android.xposed.XposedHelpers",
            "de.robv.android.xposed.XC_MethodHook",
            "org.lsposed.lspd.core.Main",
        )
        for (cls in classes) {
            try {
                Class.forName(cls)
                Log.d(TAG, "Xposed class loaded: $cls")
                return true
            } catch (_: Throwable) { /* not loaded */ }
        }
        return false
    }

    // ── Frida detection ──────────────────────────────────────────────────────
    /**
     * Frida server typically listens on TCP 27042 (default) or 27043. A
     * successful connect = active runtime instrumentation. We also look for
     * the frida-agent .so in the process's loaded libraries.
     */
    fun isFridaPresent(): Boolean {
        // 1. Loaded libraries — frida-gadget.so is the most common
        val libs = runCatching {
            File("/proc/self/maps").readText()
        }.getOrDefault("")
        if (libs.contains("frida") || libs.contains("gum-js-loop")) {
            Log.d(TAG, "Frida library found in /proc/self/maps")
            return true
        }
        // 2. Default frida-server TCP port (27042 and 27043)
        for (port in listOf(27042, 27043)) {
            if (canConnectLocally(port)) {
                Log.d(TAG, "Frida server detected on port $port")
                return true
            }
        }
        return false
    }

    private fun canConnectLocally(port: Int): Boolean = runCatching {
        Socket().use { sock ->
            sock.connect(InetSocketAddress("127.0.0.1", port), 150)
            sock.isConnected
        }
    }.getOrDefault(false)

    // ── Developer mode / debugging / mock locations ──────────────────────────

    /** True when this build was compiled with debuggable=true. */
    fun isDebuggable(ctx: Context): Boolean {
        return (ctx.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    fun isDeveloperMode(ctx: Context): Boolean = runCatching {
        Settings.Global.getInt(
            ctx.contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0,
        ) == 1
    }.getOrDefault(false)

    fun isUsbDebuggingEnabled(ctx: Context): Boolean = runCatching {
        Settings.Global.getInt(
            ctx.contentResolver,
            Settings.Global.ADB_ENABLED,
            0,
        ) == 1
    }.getOrDefault(false)

    /**
     * On Android 6.0+, mock locations are configured per-app via a special
     * app-op. Pre-6, there was a global toggle.
     */
    @Suppress("DEPRECATION")
    fun isMockLocationEnabled(ctx: Context): Boolean = runCatching {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Settings.Secure.getString(
                ctx.contentResolver,
                Settings.Secure.ALLOW_MOCK_LOCATION,
            ) != "0"
        } else {
            // Modern: any app holding ACCESS_MOCK_LOCATION is suspicious
            val pm = ctx.packageManager
            val installed = pm.getInstalledApplications(0)
            installed.any { app ->
                try {
                    val perms = pm.getPackageInfo(
                        app.packageName,
                        android.content.pm.PackageManager.GET_PERMISSIONS,
                    ).requestedPermissions ?: emptyArray()
                    perms.contains("android.permission.ACCESS_MOCK_LOCATION")
                } catch (_: Throwable) { false }
            }
        }
    }.getOrDefault(false)

    // ── Aggregate scan ───────────────────────────────────────────────────────

    /** One-shot report returned to Flutter as a Map for easy serialisation. */
    fun fullScan(ctx: Context): Map<String, Any> {
        return mapOf(
            "magiskPresent"        to isMagiskPresent(ctx),
            "xposedPresent"        to isXposedPresent(),
            "fridaPresent"         to isFridaPresent(),
            "debuggableBuild"      to isDebuggable(ctx),
            "developerMode"        to isDeveloperMode(ctx),
            "usbDebuggingEnabled"  to isUsbDebuggingEnabled(ctx),
            "mockLocationEnabled"  to isMockLocationEnabled(ctx),
            "androidVersion"       to Build.VERSION.SDK_INT,
            "buildTags"            to (Build.TAGS ?: ""),
            "buildFingerprint"     to (Build.FINGERPRINT ?: ""),
        )
    }
}

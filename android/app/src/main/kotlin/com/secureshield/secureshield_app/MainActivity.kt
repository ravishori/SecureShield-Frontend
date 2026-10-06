package com.secureshield.secureshield_app

import android.app.Activity
import android.app.AppOpsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.TrafficStats
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private var screenRecordingSink: EventChannel.EventSink? = null
    private val screenRecordingDetector by lazy { ScreenRecordingDetector(this) }

    companion object {
        private const val WINDOW_CHANNEL          = "secureshield/window_flags"
        private const val SCANNER_CHANNEL         = "secureshield/device_scanner"
        private const val CALL_STATE_CHANNEL      = "secureshield/call_state"
        private const val REMOTE_DETECT_CHANNEL   = "secureshield/remote_detector"
        private const val SCREEN_RECORD_CHANNEL   = "secureshield/screen_record"
        private const val SCREEN_DETECT_CHANNEL   = "secureshield/screen_recording_detector"
        private const val SCREEN_DETECT_EVENTS    = "secureshield/screen_recording_events"
        private const val BANK_OTP_CHANNEL        = "secureshield/bank_otp_events"
        private const val VPN_CHANNEL             = "secureshield/vpn_monitor"
        private const val VPN_EVENTS_CHANNEL      = "secureshield/vpn_events"
        private const val PKG_EVENTS_CHANNEL      = "secureshield/package_events"
        private const val SYSTEM_CHANNEL            = "secureshield/system"
        private const val APP_MONITOR_CHANNEL       = "secureshield/app_monitor"
        private const val INSTALL_ANALYSIS_CHANNEL  = "secureshield/install_analysis"
        private const val ELDERLY_CHANNEL           = "secureshield/elderly"
        private const val SIM_INTEGRITY_CHANNEL     = "secureshield/sim_integrity"
        private const val DEVICE_INTEGRITY_CHANNEL  = "secureshield/device_integrity"
        private const val MEDIA_PROJECTION_REQUEST  = 1001
        private const val VPN_PERMISSION_REQUEST    = 1002

        private val KNOWN_REMOTE_CONTROL_APPS = listOf(
            "com.anydesk.anydeskandroid",
            "com.teamviewer.quicksupport.market",
            "com.teamviewer.quicksupport.samsung",
            "com.teamviewer.host.market",
            "com.airdroid.airdroid",
            "com.airdroid.airdroidpro",
            "com.awind.screen.mirror.receiver",
            "com.scopia.desktop.inmeetingapp",
            "com.logmein.join",
            "com.rescue.LogMeInRescue",
            "com.rsupport.rs.activity.rsupport",
            "com.remoteutilities.viewer",
            "com.mobizen.mirroring",
            "com.koushikdutta.vysor",
            "io.vysor.standalone",
            "com.splashtop.remote.tablet.v02",
            "com.bsquare.teamviewer",
            "com.ammyy.client",
        )

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

        private val KNOWN_STORES = setOf(
            "com.android.vending",
            "com.amazon.venezia",
            "com.sec.android.app.samsungapps",
            "org.fdroid.fdroid",
            "com.huawei.appmarket",
            "com.xiaomi.market",
        )
    }

    // Screen recording
    private var screenRecordResultHandler: MethodChannel.Result? = null

    // Bank OTP event stream
    private var bankOtpEventSink: EventChannel.EventSink? = null
    private var bankOtpReceiver: BroadcastReceiver? = null

    // VPN traffic event stream
    private var vpnEventSink: EventChannel.EventSink? = null
    private var vpnReceiver: BroadcastReceiver? = null
    private var vpnPermissionResult: MethodChannel.Result? = null

    // Package install event stream
    private var pkgEventSink: EventChannel.EventSink? = null
    private var pkgReceiver: BroadcastReceiver? = null

    // App Monitor full-analysis event stream
    private var analysisEventSink: EventChannel.EventSink? = null
    private var analysisReceiver: BroadcastReceiver? = null

    // Elderly mode guardian-alert event stream
    private var elderlyEventSink: EventChannel.EventSink? = null
    private var elderlyReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Screen-recording detector (Android 15+ only; see ScreenRecordingDetector) ─────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_DETECT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(ScreenRecordingDetector.isSupported)
                    "isRecording" -> result.success(screenRecordingDetector.isRecording)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_DETECT_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    screenRecordingSink = events
                    screenRecordingDetector.start { recording -> screenRecordingSink?.success(recording) }
                }

                override fun onCancel(arguments: Any?) {
                    screenRecordingDetector.stop()
                    screenRecordingSink = null
                }
            })

        // ── Screenshot prevention ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WINDOW_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecure"  -> { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                    "disableSecure" -> { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                    else            -> result.notImplemented()
                }
            }

        // ── Call state detection ─────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_STATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCallState" -> {
                        try {
                            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                            result.success(tm.callState)
                        } catch (_: Exception) { result.success(0) }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Device scanner ───────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps"         -> result.success(getInstalledApps())
                    "getAccessibilityServices" -> result.success(getAccessibilityServices())
                    "uninstallApp"             -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        uninstallApp(pkg)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Remote control detector ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMOTE_DETECT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRemoteControlApps"             -> result.success(getRemoteControlApps())
                    "isAdbEnabled"                     -> result.success(isAdbEnabled())
                    "getDeviceAdminApps"               -> result.success(getDeviceAdminApps())
                    "isNotificationListenerEnabled"    -> result.success(isNotificationListenerEnabled())
                    "openNotificationListenerSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                    "openUsageAccessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                    "checkUsageStatsPermission" -> {
                        result.success(hasUsageStatsPermission())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Screen recording ─────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_RECORD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        screenRecordResultHandler = result
                        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        startActivityForResult(mpm.createScreenCaptureIntent(), MEDIA_PROJECTION_REQUEST)
                    }
                    "stopRecording" -> {
                        startService(Intent(this, ScreenRecordService::class.java).apply {
                            action = ScreenRecordService.ACTION_STOP
                        })
                        result.success(true)
                    }
                    "isRecording" -> result.success(ScreenRecordService.isRecording)
                    else -> result.notImplemented()
                }
            }

        // ── Bank OTP Event Stream ────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BANK_OTP_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    bankOtpEventSink = events
                    val filter = IntentFilter(SecureShieldNotificationListener.ACTION_BANK_OTP)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(getBankOtpReceiver(), filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        @Suppress("UnspecifiedRegisterReceiverFlag")
                        registerReceiver(getBankOtpReceiver(), filter)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(bankOtpReceiver) } catch (_: Exception) {}
                    bankOtpReceiver = null
                    bankOtpEventSink = null
                }
            })

        // ── VPN Monitor ──────────────────────────────────────────────────────
        // CRITICAL: every native call here is wrapped in try/catch — a thrown
        // ForegroundServiceStartNotAllowedException / SecurityException out of
        // startForegroundService kills the host activity if it escapes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startVpn" -> {
                            val prepare = try { VpnService.prepare(this) } catch (e: Exception) {
                                android.util.Log.e("SecureShieldVpn", "VpnService.prepare failed", e)
                                result.success(false); return@setMethodCallHandler
                            }
                            if (prepare == null) {
                                val started = startVpnServiceSafely()
                                result.success(started)
                            } else {
                                vpnPermissionResult = result
                                try {
                                    startActivityForResult(prepare, VPN_PERMISSION_REQUEST)
                                } catch (e: Exception) {
                                    android.util.Log.e("SecureShieldVpn", "Failed to launch VPN consent", e)
                                    vpnPermissionResult = null
                                    result.success(false)
                                }
                            }
                        }
                        "stopVpn" -> {
                            try {
                                startService(Intent(this, SecureShieldVpnService::class.java).apply {
                                    action = SecureShieldVpnService.ACTION_STOP
                                })
                            } catch (e: Exception) {
                                android.util.Log.w("SecureShieldVpn", "stopVpn dispatch failed", e)
                            }
                            result.success(true)
                        }
                        "isVpnRunning" -> result.success(SecureShieldVpnService.isRunning)
                        else -> result.notImplemented()
                    }
                } catch (e: Throwable) {
                    android.util.Log.e("SecureShieldVpn", "VPN channel handler crashed", e)
                    try { result.error("VPN_ERROR", e.message, null) } catch (_: Exception) {}
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    // Guard against double-register on hot-reload / re-subscribe.
                    if (vpnReceiver != null) {
                        try { unregisterReceiver(vpnReceiver) } catch (_: Exception) {}
                        vpnReceiver = null
                    }
                    vpnEventSink = events
                    try {
                        val filter = IntentFilter(SecureShieldVpnService.ACTION_VPN_TRAFFIC)
                        val rcvr = buildVpnReceiver()
                        vpnReceiver = rcvr
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            registerReceiver(rcvr, filter, RECEIVER_NOT_EXPORTED)
                        } else {
                            @Suppress("UnspecifiedRegisterReceiverFlag")
                            registerReceiver(rcvr, filter)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("SecureShieldVpn", "VPN event registerReceiver failed", e)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(vpnReceiver) } catch (_: Exception) {}
                    vpnReceiver = null
                    vpnEventSink = null
                }
            })

        // ── System settings helpers ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openLocationSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                result.success(true)
                            } catch (_: Exception) { result.success(false) }
                        }
                    }
                    "openWifiSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_WIFI_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── App Monitor control ──────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_MONITOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitor" -> {
                        val intent = Intent(this, AppMonitorService::class.java).apply {
                            action = AppMonitorService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopMonitor" -> {
                        startService(Intent(this, AppMonitorService::class.java).apply {
                            action = AppMonitorService.ACTION_STOP
                        })
                        result.success(true)
                    }
                    "isRunning" -> result.success(AppMonitorService.isRunning)
                    "analyzePackage" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.success(null)
                        val analysis = AppInstallAnalyzer.analyze(this, pkg, "installed")
                        result.success(analysis?.toMap())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Install analysis event stream (full AppInstallAnalyzer results) ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_ANALYSIS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    analysisEventSink = events
                    val filter = IntentFilter(AppMonitorService.ACTION_INSTALL_ANALYSIS)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(getAnalysisReceiver(), filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        @Suppress("UnspecifiedRegisterReceiverFlag")
                        registerReceiver(getAnalysisReceiver(), filter)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(analysisReceiver) } catch (_: Exception) {}
                    analysisReceiver = null; analysisEventSink = null
                }
            })

        // ── APK Signature Verifier ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secureshield/apk_signature")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSignatureSha256" -> {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val hash = ApkSignatureVerifier.getSignatureSha256(this, packageName)
                        result.success(hash)
                    }
                    "verifySignature" -> {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val expectedHash = call.argument<String>("expectedHash") ?: ""
                        val isValid = ApkSignatureVerifier.verifySignature(this, packageName, expectedHash)
                        result.success(isValid)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Elderly mode control ─────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ELDERLY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setConfig" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        ElderlyProtectionManager.applyConfig(
                            ctx                = this,
                            enabled            = args["enabled"] as? Boolean ?: false,
                            alertThreshold     = (args["alertThreshold"] as? Int) ?: 40,
                            blockRiskyInstalls = args["blockRisky"] as? Boolean ?: true,
                            autoAlertGuardian  = args["autoAlert"] as? Boolean ?: true,
                            guardianName       = args["guardianName"] as? String,
                            guardianPhone      = args["guardianPhone"] as? String,
                        )
                        result.success(true)
                    }
                    "getConfig"   -> result.success(ElderlyProtectionManager.getConfigMap(this))
                    "isEnabled"   -> result.success(ElderlyProtectionManager.isEnabled(this))
                    else          -> result.notImplemented()
                }
            }

        // ── SIM Integrity ────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_INTEGRITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readSimFingerprints" -> {
                        try {
                            val records = SimFingerprintProvider.read(this)
                            val list = records.map { r ->
                                mapOf(
                                    "slotIndex"     to r.slotIndex,
                                    "carrierName"   to r.carrierName,
                                    "countryIso"    to r.countryIso,
                                    "mccMnc"        to r.mccMnc,
                                    "fingerprint"   to r.fingerprintSha256,
                                    "hasFullId"     to r.hasFullId,
                                )
                            }
                            result.success(list)
                        } catch (e: Throwable) {
                            android.util.Log.e("SimIntegrity", "readSimFingerprints failed", e)
                            result.success(emptyList<Any>())
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Enhanced Device Integrity ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INTEGRITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isMagiskPresent"       -> result.success(DeviceIntegrityProbe.isMagiskPresent(this))
                        "isXposedPresent"       -> result.success(DeviceIntegrityProbe.isXposedPresent())
                        "isFridaPresent"        -> result.success(DeviceIntegrityProbe.isFridaPresent())
                        "isDebuggable"          -> result.success(DeviceIntegrityProbe.isDebuggable(this))
                        "isDeveloperMode"       -> result.success(DeviceIntegrityProbe.isDeveloperMode(this))
                        "isUsbDebuggingEnabled" -> result.success(DeviceIntegrityProbe.isUsbDebuggingEnabled(this))
                        "isMockLocationEnabled" -> result.success(DeviceIntegrityProbe.isMockLocationEnabled(this))
                        "fullScan"              -> result.success(DeviceIntegrityProbe.fullScan(this))
                        else -> result.notImplemented()
                    }
                } catch (e: Throwable) {
                    android.util.Log.e("DeviceIntegrity", "${call.method} failed", e)
                    result.success(false)
                }
            }

        // Elderly guardian-alert event stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secureshield/elderly_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    elderlyEventSink = events
                    val filter = IntentFilter(ElderlyProtectionManager.ACTION_GUARDIAN_ALERT)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(getElderlyReceiver(), filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        @Suppress("UnspecifiedRegisterReceiverFlag")
                        registerReceiver(getElderlyReceiver(), filter)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(elderlyReceiver) } catch (_: Exception) {}
                    elderlyReceiver = null; elderlyEventSink = null
                }
            })

        // ── Package Install Events ───────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PKG_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    pkgEventSink = events
                    val filter = IntentFilter(Intent.ACTION_PACKAGE_ADDED).apply {
                        addDataScheme("package")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(getPkgReceiver(), filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        @Suppress("UnspecifiedRegisterReceiverFlag")
                        registerReceiver(getPkgReceiver(), filter)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(pkgReceiver) } catch (_: Exception) {}
                    pkgReceiver = null
                    pkgEventSink = null
                }
            })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == MEDIA_PROJECTION_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val serviceIntent = Intent(this, ScreenRecordService::class.java).apply {
                    action = ScreenRecordService.ACTION_START
                    putExtra(ScreenRecordService.EXTRA_RESULT, resultCode)
                    putExtra(ScreenRecordService.EXTRA_DATA, data)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                screenRecordResultHandler?.success(true)
            } else {
                screenRecordResultHandler?.success(false)
            }
            screenRecordResultHandler = null
        }

        if (requestCode == VPN_PERMISSION_REQUEST) {
            val started = if (resultCode == Activity.RESULT_OK) startVpnServiceSafely() else false
            try { vpnPermissionResult?.success(started) } catch (_: Exception) {}
            vpnPermissionResult = null
        }
    }

    // ── Helper: start VPN service safely ─────────────────────────────────────
    /**
     * Starts SecureShieldVpnService. Returns true if dispatch succeeded;
     * NEVER throws — all exceptions are logged and converted to a false return
     * so the UI gets a clean "couldn't start" instead of a process crash.
     *
     * Possible exceptions caught:
     *   - ForegroundServiceStartNotAllowedException (Android 12+) — app not in fg
     *   - SecurityException — missing FOREGROUND_SERVICE_* sub-permission (Android 14+)
     *   - MissingForegroundServiceTypeException — manifest doesn't declare type
     *   - IllegalStateException — service already starting / device shutting down
     */
    private fun startVpnServiceSafely(): Boolean {
        return try {
            val intent = Intent(this, SecureShieldVpnService::class.java).apply {
                action = SecureShieldVpnService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (e: Throwable) {
            android.util.Log.e("SecureShieldVpn", "startVpnService failed", e)
            false
        }
    }

    // ── Receiver factories ───────────────────────────────────────────────────

    private fun getBankOtpReceiver(): BroadcastReceiver {
        if (bankOtpReceiver == null) {
            bankOtpReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    bankOtpEventSink?.success(mapOf(
                        "otp"     to (intent.getStringExtra(SecureShieldNotificationListener.EXTRA_OTP) ?: ""),
                        "bank"    to (intent.getStringExtra(SecureShieldNotificationListener.EXTRA_BANK) ?: ""),
                        "package" to (intent.getStringExtra(SecureShieldNotificationListener.EXTRA_PACKAGE) ?: ""),
                    ))
                }
            }
        }
        return bankOtpReceiver!!
    }

    /**
     * Builds a fresh receiver each time onListen is invoked. This avoids the
     * double-register problem where the same instance gets registered twice
     * (which leaks and crashes on later unregister).
     */
    private fun buildVpnReceiver(): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                try {
                    val sink = vpnEventSink ?: return
                    sink.success(mapOf(
                        "destIp"      to (intent.getStringExtra(SecureShieldVpnService.EXTRA_DEST_IP)      ?: ""),
                        "destDomain"  to (intent.getStringExtra(SecureShieldVpnService.EXTRA_DEST_DOMAIN)  ?: ""),
                        "threatLevel" to (intent.getStringExtra(SecureShieldVpnService.EXTRA_THREAT_LEVEL) ?: "safe"),
                    ))
                } catch (e: Exception) {
                    android.util.Log.w("SecureShieldVpn", "VPN receiver dispatch failed", e)
                }
            }
        }
    }

    private fun getPkgReceiver(): BroadcastReceiver {
        if (pkgReceiver == null) {
            pkgReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val pkg     = intent.data?.schemeSpecificPart ?: return
                    val replace = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
                    val pm      = packageManager
                    val appName = try {
                        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                    } catch (_: Exception) { pkg }
                    val isUnknown = try {
                        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            pm.getInstallSourceInfo(pkg).installingPackageName
                        } else {
                            @Suppress("DEPRECATION") pm.getInstallerPackageName(pkg)
                        }
                        installer == null || !KNOWN_STORES.contains(installer)
                    } catch (_: Exception) { true }

                    pkgEventSink?.success(mapOf(
                        "packageName"     to pkg,
                        "appName"         to appName,
                        "isReplacing"     to replace,
                        "isUnknownSource" to isUnknown,
                        "timestamp"       to System.currentTimeMillis(),
                    ))
                }
            }
        }
        return pkgReceiver!!
    }

    // ── Remote control detection ─────────────────────────────────────────────

    private fun getRemoteControlApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val result = mutableListOf<Map<String, Any?>>()
        for (knownPkg in KNOWN_REMOTE_CONTROL_APPS) {
            try {
                val ai = pm.getApplicationInfo(knownPkg, 0)
                result.add(mapOf(
                    "packageName" to knownPkg,
                    "appName"     to pm.getApplicationLabel(ai).toString(),
                    "isEnabled"   to ai.enabled,
                ))
            } catch (_: Exception) {}
        }
        return result
    }

    private fun isAdbEnabled(): Boolean {
        return try {
            Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        } catch (_: Exception) { false }
    }

    private fun getDeviceAdminApps(): List<String> {
        return try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            dpm.activeAdmins?.map { it.packageName } ?: emptyList()
        } catch (_: Exception) { emptyList() }
    }

    private fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) { false }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.contains(packageName)
    }

    // ── Installed apps scanner ───────────────────────────────────────────────

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm     = packageManager
        val flags  = PackageManager.GET_PERMISSIONS or PackageManager.GET_META_DATA
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
            if (pkgName == application.packageName) continue

            val isSystem        = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isUpdatedSystem = (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

            val installer: String? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgName)
                }
            } catch (_: Exception) { null }

            val grantedDangerousPerms: List<String> =
                pkg.requestedPermissions
                    ?.filterIndexed { i, perm ->
                        DANGEROUS_PERMISSIONS.contains(perm) &&
                        (pkg.requestedPermissionsFlags?.getOrNull(i)
                            ?.and(PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0)
                    }?.toList() ?: emptyList()

            val hasLauncher = pm.getLaunchIntentForPackage(pkgName) != null

            val uid     = ai.uid
            val rxBytes = TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L)
            val txBytes = TrafficStats.getUidTxBytes(uid).coerceAtLeast(0L)

            val hasOverlay = try {
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, uid, pkgName)
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, uid, pkgName)
                }
                mode == AppOpsManager.MODE_ALLOWED
            } catch (_: Exception) { false }

            val isFromKnownStore = installer != null && KNOWN_STORES.contains(installer)

            output.add(mapOf(
                "packageName"           to pkgName,
                "appName"               to pm.getApplicationLabel(ai).toString(),
                "isSystem"              to isSystem,
                "isUpdatedSystem"       to isUpdatedSystem,
                "installer"             to installer,
                "isFromKnownStore"      to isFromKnownStore,
                "grantedDangerousPerms" to grantedDangerousPerms,
                "hasLauncher"           to hasLauncher,
                "firstInstallTime"      to pkg.firstInstallTime,
                "lastUpdateTime"        to pkg.lastUpdateTime,
                "rxBytes"               to rxBytes,
                "txBytes"               to txBytes,
                "hasOverlay"            to hasOverlay,
                "uid"                   to uid,
                "versionName"           to (pkg.versionName ?: ""),
            ))
        }

        return output
    }

    private fun getAccessibilityServices(): List<String> {
        val raw = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return emptyList()
        return raw.split(":").filter { it.isNotBlank() }
    }

    private fun uninstallApp(packageName: String) {
        if (packageName.isBlank()) return
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$packageName"))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // ── Analysis receiver — forwards AppMonitorService broadcast to Flutter ──
    private fun getAnalysisReceiver(): BroadcastReceiver {
        if (analysisReceiver == null) {
            analysisReceiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    // Rebuild map from broadcast extras
                    val extras = intent.extras ?: return
                    val map = mutableMapOf<String, Any?>()
                    for (key in extras.keySet()) {
                        map[key] = when (val v = extras.get(key)) {
                            is Array<*> -> v.toList()
                            else        -> v
                        }
                    }
                    analysisEventSink?.success(map)
                }
            }
        }
        return analysisReceiver!!
    }

    // ── Elderly guardian-alert receiver ──────────────────────────────────────
    private fun getElderlyReceiver(): BroadcastReceiver {
        if (elderlyReceiver == null) {
            elderlyReceiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    val extras = intent.extras ?: return
                    val map = mutableMapOf<String, Any?>()
                    for (key in extras.keySet()) {
                        map[key] = when (val v = extras.get(key)) {
                            is Array<*> -> v.toList()
                            else        -> v
                        }
                    }
                    elderlyEventSink?.success(map)
                }
            }
        }
        return elderlyReceiver!!
    }
}

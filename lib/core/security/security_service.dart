import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of a full device security scan.
class SecurityReport {
  // Legacy fields kept for backward compatibility
  final bool isRooted;
  final bool isEmulator;
  final bool isScreenRecording;
  final bool hasUnknownSources;

  // New (v2) fields from the enhanced integrity probe
  final bool magiskPresent;
  final bool xposedPresent;
  final bool fridaPresent;
  final bool debuggableBuild;
  final bool developerMode;
  final bool usbDebuggingEnabled;
  final bool mockLocationEnabled;

  /// 'danger'  — hard block (rooted, Magisk, Frida instrumented, Xposed)
  /// 'warning' — soft warn (emulator, dev mode, USB debug, mock locations)
  /// 'safe'    — no risks detected
  final String riskLevel;

  /// Human-readable list of detected risks (empty when riskLevel == 'safe').
  final List<String> riskReasons;

  const SecurityReport({
    required this.isRooted,
    required this.isEmulator,
    required this.isScreenRecording,
    required this.hasUnknownSources,
    this.magiskPresent       = false,
    this.xposedPresent       = false,
    this.fridaPresent        = false,
    this.debuggableBuild     = false,
    this.developerMode       = false,
    this.usbDebuggingEnabled = false,
    this.mockLocationEnabled = false,
    required this.riskLevel,
    required this.riskReasons,
  });
}

class SecurityService {
  SecurityService._();

  static const _integrityChannel = MethodChannel('secureshield/device_integrity');

  // ---------------------------------------------------------------------------
  // Public entry-point
  // ---------------------------------------------------------------------------

  /// Run all security checks and return a [SecurityReport].
  ///
  /// Never throws — any exception inside a sub-check is caught and treated
  /// as the safe default so that a buggy check never blocks the app on
  /// good devices.
  static Future<SecurityReport> runChecks() async {
    bool rooted = false;
    bool emulator = false;
    bool screenRecording = false;
    bool unknownSources = false;

    // Legacy probes (Dart-side path / build-tags root, emulator fingerprints)
    try { rooted = await _checkRooted(); } catch (_) {}
    try { emulator = await _checkEmulator(); } catch (_) {}
    try { screenRecording = _checkScreenRecording(); } catch (_) {}
    try { unknownSources = await _checkUnknownSources(); } catch (_) {}

    // New native probes
    final native = await _runNativeIntegrityScan();

    final reasons = <String>[];

    // Hard-block findings
    if (rooted)               reasons.add('Device appears to be rooted');
    if (native.magiskPresent) reasons.add('Magisk root framework detected');
    if (native.xposedPresent) reasons.add('Xposed / LSPosed framework detected (runtime modification)');
    if (native.fridaPresent)  reasons.add('Frida runtime instrumentation detected');

    // Soft warnings
    if (emulator)                     reasons.add('Running on an emulator or simulator');
    if (screenRecording)              reasons.add('Screen recording may be active');
    if (unknownSources)               reasons.add('Unknown sources installation is enabled');
    if (native.developerMode)         reasons.add('Developer options are enabled');
    if (native.usbDebuggingEnabled)   reasons.add('USB debugging is enabled');
    if (native.mockLocationEnabled)   reasons.add('A mock-location app is installed');
    if (native.debuggableBuild)       reasons.add('App build is debuggable');

    final hardBlock = rooted ||
                      native.magiskPresent ||
                      native.xposedPresent ||
                      native.fridaPresent;
    final softWarn = emulator ||
                     native.developerMode ||
                     native.usbDebuggingEnabled ||
                     native.mockLocationEnabled ||
                     screenRecording ||
                     unknownSources ||
                     native.debuggableBuild;

    final riskLevel = hardBlock ? 'danger' : (softWarn ? 'warning' : 'safe');

    return SecurityReport(
      isRooted: rooted,
      isEmulator: emulator,
      isScreenRecording: screenRecording,
      hasUnknownSources: unknownSources,
      magiskPresent:       native.magiskPresent,
      xposedPresent:       native.xposedPresent,
      fridaPresent:        native.fridaPresent,
      debuggableBuild:     native.debuggableBuild,
      developerMode:       native.developerMode,
      usbDebuggingEnabled: native.usbDebuggingEnabled,
      mockLocationEnabled: native.mockLocationEnabled,
      riskLevel: riskLevel,
      riskReasons: reasons,
    );
  }

  // ---------------------------------------------------------------------------
  // Native integrity scan via DeviceIntegrityProbe (Kotlin)
  // ---------------------------------------------------------------------------

  static Future<_NativeIntegrity> _runNativeIntegrityScan() async {
    if (!Platform.isAndroid) return const _NativeIntegrity.allClear();
    try {
      final raw = await _integrityChannel.invokeMapMethod<String, dynamic>('fullScan');
      if (raw == null) return const _NativeIntegrity.allClear();
      return _NativeIntegrity(
        magiskPresent:       raw['magiskPresent']        as bool? ?? false,
        xposedPresent:       raw['xposedPresent']        as bool? ?? false,
        fridaPresent:        raw['fridaPresent']         as bool? ?? false,
        debuggableBuild:     raw['debuggableBuild']      as bool? ?? false,
        developerMode:       raw['developerMode']        as bool? ?? false,
        usbDebuggingEnabled: raw['usbDebuggingEnabled']  as bool? ?? false,
        mockLocationEnabled: raw['mockLocationEnabled']  as bool? ?? false,
      );
    } catch (e) {
      debugPrint('[SecurityService] Native integrity scan failed: $e');
      return const _NativeIntegrity.allClear();
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy Dart-side root detection (kept for resilience even when the
  // native channel fails to register)
  // ---------------------------------------------------------------------------

  static Future<bool> _checkRooted() async {
    if (!Platform.isAndroid) return false;

    const suspiciousPaths = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/dev/com.koushikdutta.superuser.daemon/',
      '/system/app/SuperSU.apk',
      '/system/etc/init.d/99SuperSUDaemon',
      '/system/bin/.ext/.su',
    ];

    for (final path in suspiciousPaths) {
      try {
        if (File(path).existsSync()) {
          debugPrint('[SecurityService] Root indicator found: $path');
          return true;
        }
      } catch (_) {}
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final tags = androidInfo.tags;
      if (tags.contains('test-keys')) {
        debugPrint('[SecurityService] Root indicator: test-keys build');
        return true;
      }
    } catch (_) {}

    return false;
  }

  // ---------------------------------------------------------------------------
  // Emulator detection
  // ---------------------------------------------------------------------------

  static Future<bool> _checkEmulator() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (!androidInfo.isPhysicalDevice) return true;

      final model = androidInfo.model.toLowerCase();
      const emulatorKeywords = [
        'emulator', 'android sdk', 'google_sdk',
        'sdk_gphone', 'sdk built for', 'generic',
      ];
      for (final keyword in emulatorKeywords) {
        if (model.contains(keyword)) return true;
      }

      final fingerprint = androidInfo.fingerprint.toLowerCase();
      if (fingerprint.contains('generic') ||
          fingerprint.contains('unknown') ||
          fingerprint.contains('emulator')) {
        return true;
      }
    } catch (e) {
      debugPrint('[SecurityService] Emulator check error: $e');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Screen recording / Unknown sources — placeholders kept for future native
  // implementations (would need MediaProjection / Settings.Secure queries).
  // ---------------------------------------------------------------------------

  static bool _checkScreenRecording() => false;
  static Future<bool> _checkUnknownSources() async => false;
}

/// Internal bag holding the native integrity flags.
class _NativeIntegrity {
  final bool magiskPresent;
  final bool xposedPresent;
  final bool fridaPresent;
  final bool debuggableBuild;
  final bool developerMode;
  final bool usbDebuggingEnabled;
  final bool mockLocationEnabled;

  const _NativeIntegrity({
    required this.magiskPresent,
    required this.xposedPresent,
    required this.fridaPresent,
    required this.debuggableBuild,
    required this.developerMode,
    required this.usbDebuggingEnabled,
    required this.mockLocationEnabled,
  });

  const _NativeIntegrity.allClear()
      : magiskPresent = false,
        xposedPresent = false,
        fridaPresent = false,
        debuggableBuild = false,
        developerMode = false,
        usbDebuggingEnabled = false,
        mockLocationEnabled = false;
}

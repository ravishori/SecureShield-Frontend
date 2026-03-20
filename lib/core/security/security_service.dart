import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Result of a full device security scan.
class SecurityReport {
  final bool isRooted;
  final bool isEmulator;
  final bool isScreenRecording;
  final bool hasUnknownSources;

  /// 'danger'  — device is rooted (blocks app launch)
  /// 'warning' — emulator detected (warn but allow — could be a developer)
  /// 'safe'    — no risks detected
  final String riskLevel;

  /// Human-readable list of detected risks (empty when riskLevel == 'safe').
  final List<String> riskReasons;

  const SecurityReport({
    required this.isRooted,
    required this.isEmulator,
    required this.isScreenRecording,
    required this.hasUnknownSources,
    required this.riskLevel,
    required this.riskReasons,
  });
}

class SecurityService {
  SecurityService._();

  // ---------------------------------------------------------------------------
  // Public entry-point
  // ---------------------------------------------------------------------------

  /// Run all security checks and return a [SecurityReport].
  ///
  /// Never throws — any exception inside a sub-check is caught and treated as
  /// the safe default so that a buggy check never blocks the app on good devices.
  static Future<SecurityReport> runChecks() async {
    bool rooted = false;
    bool emulator = false;
    bool screenRecording = false;
    bool unknownSources = false;

    try {
      rooted = await _checkRooted();
    } catch (_) {
      rooted = false;
    }

    try {
      emulator = await _checkEmulator();
    } catch (_) {
      emulator = false;
    }

    try {
      screenRecording = _checkScreenRecording();
    } catch (_) {
      screenRecording = false;
    }

    try {
      unknownSources = await _checkUnknownSources();
    } catch (_) {
      unknownSources = false;
    }

    // Build risk summary
    final reasons = <String>[];
    if (rooted) reasons.add('Device appears to be rooted');
    if (emulator) reasons.add('Running on an emulator or simulator');
    if (screenRecording) reasons.add('Screen recording may be active');
    if (unknownSources) reasons.add('Unknown sources installation is enabled');

    String riskLevel;
    if (rooted) {
      riskLevel = 'danger';
    } else if (emulator) {
      riskLevel = 'warning';
    } else {
      riskLevel = 'safe';
    }

    return SecurityReport(
      isRooted: rooted,
      isEmulator: emulator,
      isScreenRecording: screenRecording,
      hasUnknownSources: unknownSources,
      riskLevel: riskLevel,
      riskReasons: reasons,
    );
  }

  // ---------------------------------------------------------------------------
  // Root detection
  // ---------------------------------------------------------------------------

  static Future<bool> _checkRooted() async {
    if (!Platform.isAndroid) return false;

    // Check for common su / Superuser binaries
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
      } catch (_) {
        // Permission denied is fine — means we can't access it
      }
    }

    // Check build tags for test-keys signature
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final tags = androidInfo.tags ?? '';
      if (tags.contains('test-keys')) {
        debugPrint('[SecurityService] Root indicator: build signed with test-keys');
        return true;
      }
    } catch (_) {
      // Ignore device info errors
    }

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

      // Primary: isPhysicalDevice = false means emulator
      if (!androidInfo.isPhysicalDevice) {
        debugPrint('[SecurityService] Emulator detected: isPhysicalDevice=false');
        return true;
      }

      // Secondary: model string fingerprints
      final model = (androidInfo.model ?? '').toLowerCase();
      const emulatorKeywords = [
        'emulator',
        'android sdk',
        'google_sdk',
        'sdk_gphone',
        'sdk built for',
        'generic',
      ];
      for (final keyword in emulatorKeywords) {
        if (model.contains(keyword)) {
          debugPrint('[SecurityService] Emulator detected: model contains "$keyword"');
          return true;
        }
      }

      // Tertiary: fingerprint
      final fingerprint = (androidInfo.fingerprint ?? '').toLowerCase();
      if (fingerprint.contains('generic') ||
          fingerprint.contains('unknown') ||
          fingerprint.contains('emulator')) {
        debugPrint('[SecurityService] Emulator detected: fingerprint=$fingerprint');
        return true;
      }
    } catch (e) {
      debugPrint('[SecurityService] Emulator check error: $e');
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Screen recording (placeholder — real impl needs platform channel)
  // ---------------------------------------------------------------------------

  /// Returns false by default. A real implementation would use a platform
  /// channel to query MediaProjection on Android / ReplayKit on iOS.
  static bool _checkScreenRecording() {
    return false;
  }

  // ---------------------------------------------------------------------------
  // Unknown sources (placeholder — requires platform channel / Device Policy)
  // ---------------------------------------------------------------------------

  /// Returns false by default. A real implementation would query
  /// Settings.Secure.INSTALL_NON_MARKET_APPS on Android.
  static Future<bool> _checkUnknownSources() async {
    return false;
  }
}

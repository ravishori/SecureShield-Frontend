import 'device_scanner_service.dart';
import 'fake_app_detector.dart';

// ────────────────────────────────────────────────────────────────────────────
// Risk levels (ordered low → high)
// ────────────────────────────────────────────────────────────────────────────
enum AppRiskLevel { safe, low, medium, high, critical }

extension AppRiskLevelExt on AppRiskLevel {
  String get label {
    switch (this) {
      case AppRiskLevel.safe:     return 'Safe';
      case AppRiskLevel.low:      return 'Low Risk';
      case AppRiskLevel.medium:   return 'Medium Risk';
      case AppRiskLevel.high:     return 'High Risk';
      case AppRiskLevel.critical: return 'Critical';
    }
  }

  bool get shouldWarn => index >= AppRiskLevel.medium.index;
  bool get isHighOrAbove => index >= AppRiskLevel.high.index;
}

// ────────────────────────────────────────────────────────────────────────────
// Result of scoring a single app
// ────────────────────────────────────────────────────────────────────────────
class AppRiskResult {
  final DeviceAppInfo app;
  final AppRiskLevel level;
  final List<String> reasons; // human-readable explanations

  const AppRiskResult({
    required this.app,
    required this.level,
    required this.reasons,
  });

  bool get canUninstall => app.isUserApp;
}

// ────────────────────────────────────────────────────────────────────────────
// Overall device scan summary
// ────────────────────────────────────────────────────────────────────────────
class ScanSummary {
  final List<AppRiskResult> results;
  final int totalScanned;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int safeCount;

  const ScanSummary({
    required this.results,
    required this.totalScanned,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.safeCount,
  });

  int get warningCount => criticalCount + highCount + mediumCount;
  bool get hasHighRisk  => criticalCount > 0 || highCount > 0;

  /// All results that have warnings, sorted high → low
  List<AppRiskResult> get riskResults => results
      .where((r) => r.level.shouldWarn)
      .toList()
    ..sort((a, b) => b.level.index.compareTo(a.level.index));
}

// ────────────────────────────────────────────────────────────────────────────
// Packages whose accessibility use is considered legitimate
// ────────────────────────────────────────────────────────────────────────────
const _whitelistedAccessibility = {
  'com.google.android.marvin.talkback',
  'com.android.talkback',
  'com.google.android.accessibility',
  'com.samsung.accessibility',
  'com.samsung.android.accessibility',
  'com.samsung.android.app.talkback',
  'com.google.android.apps.accessibility.magnifier',
  'com.android.switchaccess',
};

// SMS-related dangerous permissions
const _smsPerms = {
  'android.permission.READ_SMS',
  'android.permission.SEND_SMS',
  'android.permission.RECEIVE_SMS',
};

// ────────────────────────────────────────────────────────────────────────────
// Risk scoring engine
// ────────────────────────────────────────────────────────────────────────────
class AppRiskEngine {
  /// Score all apps given the list of enabled accessibility service component names.
  static ScanSummary analyze(
    List<DeviceAppInfo> apps,
    List<String> accessibilityComponents,
  ) {
    // Build set of packages that have an accessibility service enabled
    final accessibilityPackages = accessibilityComponents
        .map((c) => c.split('/').first.trim())
        .where((p) => p.isNotEmpty)
        .toSet();

    // Mark accessibility flag on each app
    for (final app in apps) {
      app.usesAccessibility = accessibilityPackages.contains(app.packageName);
    }

    final results = apps.map((app) => _score(app)).toList();

    int critical = 0, high = 0, medium = 0, low = 0, safe = 0;
    for (final r in results) {
      switch (r.level) {
        case AppRiskLevel.critical: critical++; break;
        case AppRiskLevel.high:     high++;     break;
        case AppRiskLevel.medium:   medium++;   break;
        case AppRiskLevel.low:      low++;      break;
        case AppRiskLevel.safe:     safe++;     break;
      }
    }

    return ScanSummary(
      results:       results,
      totalScanned:  results.length,
      criticalCount: critical,
      highCount:     high,
      mediumCount:   medium,
      lowCount:      low,
      safeCount:     safe,
    );
  }

  static AppRiskResult _score(DeviceAppInfo app) {
    final reasons = <String>[];
    var level = AppRiskLevel.safe;

    void elevate(AppRiskLevel l, String reason) {
      reasons.add(reason);
      if (l.index > level.index) level = l;
    }

    final perms        = app.grantedDangerousPerms;
    final sideloaded   = !app.isFromKnownStore && !app.isSystem;
    final hasSmsPerms  = perms.any((p) => _smsPerms.contains(p));

    // ── CRITICAL ─────────────────────────────────────────────────────────────
    // Sideloaded + uses accessibility service (classic spyware/banking trojan)
    if (sideloaded && app.usesAccessibility &&
        !_whitelistedAccessibility.contains(app.packageName)) {
      elevate(AppRiskLevel.critical,
          'Sideloaded app using Accessibility Service — high spyware risk');
    }

    // Sideloaded + SMS permissions (OTP/message stealer)
    if (sideloaded && hasSmsPerms) {
      elevate(AppRiskLevel.critical,
          'Sideloaded app with SMS access — potential OTP or message thief');
    }

    // ── HIGH ─────────────────────────────────────────────────────────────────
    // Fake/clone app detected (impersonating a legitimate app)
    final fakeAnalysis = FakeAppDetector.analyze(app.packageName, app.appName);
    if (fakeAnalysis.risk == FakeAppRisk.probablyFake) {
      elevate(AppRiskLevel.critical,
          '🚨 Fake app detected: Impersonating ${fakeAnalysis.impersonatesApp} (${fakeAnalysis.reasons.join(", ")})');
    } else if (fakeAnalysis.risk == FakeAppRisk.likelyFake) {
      elevate(AppRiskLevel.high,
          '⚠️ Likely fake app: May be impersonating ${fakeAnalysis.impersonatesApp}');
    } else if (fakeAnalysis.risk == FakeAppRisk.suspected) {
      elevate(AppRiskLevel.medium,
          '🔍 Suspected clone: Similar to ${fakeAnalysis.impersonatesApp} (manual verification recommended)');
    }

    // Play Store app using accessibility but not whitelisted
    if (!sideloaded && app.usesAccessibility &&
        !_whitelistedAccessibility.contains(app.packageName) && !app.isSystem) {
      elevate(AppRiskLevel.high,
          'Uses Accessibility Service — can read screen and auto-click');
    }

    // Sideloaded + overlay (draw-over-app phishing)
    if (sideloaded && app.hasOverlay) {
      elevate(AppRiskLevel.high,
          'Sideloaded app with Overlay permission — can display fake UI over other apps');
    }

    // Sideloaded + 4+ dangerous permissions
    if (sideloaded && perms.length >= 4) {
      elevate(AppRiskLevel.high,
          'Sideloaded app with ${perms.length} dangerous permissions');
    }

    // Hidden app (no launcher) + sideloaded
    if (sideloaded && !app.hasLauncher && !app.isSystem) {
      elevate(AppRiskLevel.high,
          'Hidden app (no launcher icon) installed from unknown source');
    }

    // ── MEDIUM ────────────────────────────────────────────────────────────────
    // Any sideloaded user app (not from known store)
    if (sideloaded && app.isUserApp && level.index < AppRiskLevel.medium.index) {
      elevate(AppRiskLevel.medium, 'Installed from unknown source (not Play Store)');
    }

    // Play Store app with overlay permission
    if (!sideloaded && app.hasOverlay && !app.isSystem) {
      elevate(AppRiskLevel.medium,
          'Has permission to draw over other apps (overlay)');
    }

    // Play Store app with SMS permissions
    if (!sideloaded && hasSmsPerms && !app.isSystem) {
      elevate(AppRiskLevel.medium, 'Has SMS read/send permissions');
    }

    // Very high data usage (> 500 MB received) for non-system sideloaded app
    if (sideloaded && app.rxMb > 500) {
      elevate(AppRiskLevel.medium,
          'High data usage (${app.rxMb.toStringAsFixed(0)} MB received) from unknown source');
    }

    // ── LOW ───────────────────────────────────────────────────────────────────
    // Recently installed app (within 72 hours) — just flag for awareness
    final now          = DateTime.now().millisecondsSinceEpoch;
    final hoursOld     = (now - app.firstInstallTime) / (1000 * 3600);
    if (hoursOld < 72 && app.isUserApp && level == AppRiskLevel.safe) {
      elevate(AppRiskLevel.low,
          'Recently installed (${hoursOld.toStringAsFixed(0)}h ago)');
    }

    // Play Store app with many dangerous permissions — low concern
    if (!sideloaded && perms.length >= 5 && !app.isSystem &&
        level.index < AppRiskLevel.low.index) {
      elevate(AppRiskLevel.low,
          'Has ${perms.length} dangerous permissions');
    }

    return AppRiskResult(app: app, level: level, reasons: reasons);
  }
}

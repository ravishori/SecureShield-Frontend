/// Banking Threat Correlator.
///
/// Correlates "user is about to / just opened a banking app" with the
/// presence of any active attack vector that could compromise that
/// session:
///   • Remote-access apps installed AND enabled (AnyDesk, TeamViewer, …)
///   • USB debugging enabled (allows ADB screen mirroring)
///   • Untrusted apps with Accessibility service enabled
///   • Known banking-trojan accessibility services active
///   • Apps with overlay permission that could draw fake login screens
///
/// One-shot API today (called from the Banking Protection screen). Can
/// later be wired to a foreground service that polls UsageStatsManager
/// every few seconds while a banking app is in focus.
library;

import 'package:flutter/foundation.dart';

import 'accessibility_abuse_catalog.dart';
import 'device_scanner_service.dart';
import 'trusted_app_catalog.dart';
import '../../features/remote_detector/remote_detector_service.dart';

enum BankingThreatLevel { safe, suspicious, critical }

extension BankingThreatLevelX on BankingThreatLevel {
  String get label {
    switch (this) {
      case BankingThreatLevel.safe:       return 'No Active Threats';
      case BankingThreatLevel.suspicious: return 'Possible Risk';
      case BankingThreatLevel.critical:   return 'Critical Risk — Do Not Bank';
    }
  }
}

/// One actionable threat surfaced by the correlator. Carries enough context
/// for the UI to recommend a fix (e.g. "Disable accessibility for X").
@immutable
class BankingThreatItem {
  /// Stable code for analytics / programmatic handling.
  final String code;
  /// Human-readable description shown in the UI.
  final String message;
  /// Severity contribution toward the overall verdict.
  final BankingThreatLevel severity;
  /// Optional package name when the threat is tied to a specific app.
  final String? packageName;
  /// Concrete action the user can take to resolve.
  final String recommendedAction;

  const BankingThreatItem({
    required this.code,
    required this.message,
    required this.severity,
    required this.recommendedAction,
    this.packageName,
  });
}

@immutable
class BankingThreatReport {
  final BankingThreatLevel level;
  final List<BankingThreatItem> threats;
  final List<DeviceAppInfo> openableBankingApps;

  const BankingThreatReport({
    required this.level,
    required this.threats,
    required this.openableBankingApps,
  });

  /// True only when there are threats AND a banking app is installed.
  ///
  /// Generic device-level risks (untrusted accessibility apps, overlay
  /// permission, USB debugging) don't constitute a "banking risk" if there
  /// is no banking session to compromise. Suppressing the strip when no
  /// banking app is present prevents the false-positive warning on the
  /// Welcome / Dashboard screen.
  ///
  /// Once the user installs a banking/UPI app and the next scan runs, the
  /// same pre-existing threats will correctly start firing.
  bool get hasThreats => threats.isNotEmpty && openableBankingApps.isNotEmpty;

  /// Whether the device has any threats at all, ignoring banking-app
  /// presence. Use this for the in-Banking-Protection-screen threat list,
  /// where surfacing the device-level threats is still useful even before
  /// a banking app is installed.
  bool get hasRawThreats => threats.isNotEmpty;

  int get criticalCount =>
      threats.where((t) => t.severity == BankingThreatLevel.critical).length;
  int get suspiciousCount =>
      threats.where((t) => t.severity == BankingThreatLevel.suspicious).length;
}

class BankingThreatCorrelator {
  BankingThreatCorrelator._();

  static const Set<String> _bankingCategories = {
    'banking', 'upi', 'payments',
  };

  /// Run a one-shot scan. Never throws — all errors logged and treated as
  /// "safe" for the affected sub-check so the user never sees a runtime
  /// error on the Banking Protection screen.
  static Future<BankingThreatReport> scan() async {
    final threats     = <BankingThreatItem>[];
    final bankingApps = <DeviceAppInfo>[];

    List<DeviceAppInfo> installed = const [];
    try {
      installed = await DeviceScannerService.getInstalledApps();
    } catch (e) {
      debugPrint('[BankingThreatCorrelator] failed to list apps: $e');
    }

    // ── 1. Inventory: which banking apps are present on device? ────────────
    for (final app in installed) {
      final trusted = TrustedAppCatalog.lookup(app.packageName);
      if (trusted != null && _bankingCategories.contains(trusted.category)) {
        bankingApps.add(app);
      }
    }

    // ── 2. Active remote-access threats ────────────────────────────────────
    try {
      final remote = await RemoteDetectorService().scan();
      for (final r in remote.remoteApps.where((r) => r.isEnabled)) {
        threats.add(BankingThreatItem(
          code: 'REMOTE_ACCESS_ACTIVE',
          severity: BankingThreatLevel.critical,
          packageName: r.packageName,
          message:
              'Remote-access app "${r.appName}" is enabled. A scammer with '
              'access can see and operate your screen during banking.',
          recommendedAction:
              'Disable or uninstall ${r.appName} before opening any banking app.',
        ));
      }
      if (remote.adbEnabled) {
        threats.add(const BankingThreatItem(
          code: 'USB_DEBUGGING',
          severity: BankingThreatLevel.suspicious,
          message:
              'USB debugging is enabled — a connected computer could '
              'mirror your screen during banking.',
          recommendedAction:
              'Disable USB debugging in Settings → Developer options.',
        ));
      }
      // Device admin apps not in the trusted catalog are highly suspicious.
      for (final pkg in remote.deviceAdminApps) {
        final trusted = TrustedAppCatalog.lookup(pkg);
        if (trusted == null) {
          threats.add(BankingThreatItem(
            code: 'UNTRUSTED_DEVICE_ADMIN',
            severity: BankingThreatLevel.critical,
            packageName: pkg,
            message:
                'Untrusted app "$pkg" is a Device Admin — it could prevent '
                'uninstall and lock your screen.',
            recommendedAction:
                'Settings → Security → Device admin apps → revoke for $pkg.',
          ));
        }
      }
    } catch (e) {
      debugPrint('[BankingThreatCorrelator] remote scan failed: $e');
    }

    // ── 3. Accessibility-based threats ─────────────────────────────────────
    try {
      final a11yComponents = await DeviceScannerService.getAccessibilityServices();
      final a11yPackages = a11yComponents
          .map((c) => c.split('/').first.trim())
          .where((p) => p.isNotEmpty)
          .toSet();

      // 3a. Known-bad signatures from the abuse catalog
      final knownBad = AccessibilityAbuseCatalog.matchSignatures(
        components: a11yComponents,
        installedApps: installed,
      );
      for (final bad in knownBad) {
        threats.add(BankingThreatItem(
          code: 'KNOWN_TROJAN_${bad.familyId}',
          severity: BankingThreatLevel.critical,
          packageName: bad.packageName,
          message:
              'Known banking-trojan signature: ${bad.familyName}'
              '${bad.packageName != null ? " ($bad.packageName})" : ""}. '
              '${bad.description}',
          recommendedAction:
              'Uninstall this app immediately and run a full device scan. '
              'Consider a factory reset if banking credentials may have been entered.',
        ));
      }
      final knownBadPkgs = knownBad.map((b) => b.packageName).toSet();

      // 3b. Other untrusted apps with accessibility — generic suspicion
      for (final pkg in a11yPackages) {
        if (knownBadPkgs.contains(pkg)) continue; // already flagged above
        if (TrustedAppCatalog.lookup(pkg) != null) continue;
        if (AccessibilityAbuseCatalog.isKnownLegitimate(pkg)) continue;

        final app = installed.firstWhere(
          (a) => a.packageName == pkg,
          orElse: () => DeviceAppInfo(
            packageName: pkg,
            appName: pkg,
            isSystem: false,
            isUpdatedSystem: false,
            installer: null,
            isFromKnownStore: false,
            grantedDangerousPerms: const [],
            hasLauncher: true,
            firstInstallTime: 0,
            lastUpdateTime: 0,
            rxBytes: 0,
            txBytes: 0,
            hasOverlay: false,
            uid: 0,
            versionName: '',
          ),
        );

        // Accessibility + overlay is the classic banking-overlay attack pattern.
        final sev = app.hasOverlay
            ? BankingThreatLevel.critical
            : BankingThreatLevel.suspicious;
        threats.add(BankingThreatItem(
          code: 'UNTRUSTED_A11Y',
          severity: sev,
          packageName: pkg,
          message:
              'Untrusted app "${app.appName}" uses Accessibility'
              '${app.hasOverlay ? " AND can draw overlays" : ""}.'
              ' Accessibility lets it read every screen, type on your behalf, '
              'and click buttons silently.',
          recommendedAction:
              'Settings → Accessibility → Installed services → turn off ${app.appName}. '
              'Uninstall if you don\'t recognise the app.',
        ));
      }
    } catch (e) {
      debugPrint('[BankingThreatCorrelator] a11y scan failed: $e');
    }

    // ── 4. Overlay-permission abuse on untrusted apps ──────────────────────
    for (final app in installed) {
      if (!app.hasOverlay) continue;
      if (TrustedAppCatalog.lookup(app.packageName) != null) continue;
      if (app.isSystem) continue;
      // Skip if we already added an accessibility+overlay alert for this pkg
      if (threats.any((t) =>
          t.packageName == app.packageName && t.code == 'UNTRUSTED_A11Y')) {
        continue;
      }
      threats.add(BankingThreatItem(
        code: 'UNTRUSTED_OVERLAY',
        severity: BankingThreatLevel.suspicious,
        packageName: app.packageName,
        message:
            'Untrusted app "${app.appName}" can draw over other apps. '
            'This can be used to show a fake banking login screen.',
        recommendedAction:
            'Settings → Apps → ${app.appName} → "Display over other apps" → turn off.',
      ));
    }

    // ── 5. Compute overall verdict ─────────────────────────────────────────
    final hasCritical =
        threats.any((t) => t.severity == BankingThreatLevel.critical);
    final hasAny = threats.isNotEmpty;
    final level = hasCritical
        ? BankingThreatLevel.critical
        : (hasAny ? BankingThreatLevel.suspicious : BankingThreatLevel.safe);

    return BankingThreatReport(
      level: level,
      threats: threats,
      openableBankingApps: bankingApps,
    );
  }
}

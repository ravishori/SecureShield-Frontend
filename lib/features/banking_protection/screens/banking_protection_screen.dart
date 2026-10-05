/// Banking App Protection Screen
///
/// Dedicated view for Indian banking/UPI apps.
/// Shows authenticity status, signature verification, and recommended actions.
///
/// Uses [RiskUiTokens] + [A11ySizing] so it stays readable in every theme
/// (Senior Citizen and Nature Green included).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/risk_ui_tokens.dart';
import '../../../core/theme/theme_provider.dart' show themeProvider;
import '../../../core/security/app_risk_engine.dart';
import '../../../core/security/banking_threat_correlator.dart';
import '../../../core/security/device_scanner_service.dart';
import '../../../core/security/trusted_app_catalog.dart';
import '../../../core/security/fake_app_detector.dart';
import '../../../core/services/notification_service.dart';

class BankingProtectionScreen extends ConsumerStatefulWidget {
  const BankingProtectionScreen({super.key});

  @override
  ConsumerState<BankingProtectionScreen> createState() =>
      _BankingProtectionScreenState();
}

class _BankingProtectionScreenState
    extends ConsumerState<BankingProtectionScreen> {
  static const _signatureChannel = MethodChannel('secureshield/apk_signature');

  List<DeviceAppInfo>? _installedApps;
  final Map<String, FakeAppAnalysis> _fakeAppAnalyses = {};
  final Map<String, String?> _appSignatures = {};
  BankingThreatReport? _threatReport;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBankingApps();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadBankingApps();
  }

  Future<void> _loadBankingApps() async {
    try {
      // Run the threat correlator in parallel with the app inventory —
      // they hit different system APIs so we can save ~200-300ms.
      final threatFuture = BankingThreatCorrelator.scan();

      final apps = await DeviceScannerService.getInstalledApps();
      final bankingApps = apps.where((a) {
        final trusted = TrustedAppCatalog.lookup(a.packageName);
        final isBankingFromCatalog = trusted != null &&
            (trusted.category == 'banking' ||
             trusted.category == 'upi' ||
             trusted.category == 'payments');
        final isBankingRelated = _isBankingRelated(a.appName.toLowerCase());
        return isBankingFromCatalog || isBankingRelated;
      }).toList();

      // Await the threat scan and store it (errors handled inside the
      // correlator — it returns a "safe" report on failure rather than
      // throwing).
      final threatReport = await threatFuture;
      _threatReport = threatReport;

      // Fire one critical notification on first scan if a critical-tier
      // threat is present, so the user is alerted even before they read
      // the screen.
      if (threatReport.level == BankingThreatLevel.critical && mounted) {
        try {
          await NotificationService.showBankingAlert(
            bankName: 'Banking Protection',
            alertType: 'Active Threat Detected',
            details:
                'Active threats are running on your device that could '
                'compromise banking sessions. Open SecureShield to review.',
          );
        } catch (_) {/* notification failures must not break the scan */}
      }

      for (final app in bankingApps) {
        // Pass isSystem so the detector short-circuits system apps.
        final analysis = FakeAppDetector.analyze(
          app.packageName,
          app.appName,
          isSystem: app.isSystem,
        );
        _fakeAppAnalyses[app.packageName] = analysis;

        // Fire banking-alert ONLY when the detector returns a genuine
        // impersonation signal (suspected or higher). Trusted catalog apps,
        // system apps, and same-publisher variants all return notFake by
        // design, so they won't trigger.
        if (analysis.risk.shouldWarn &&
            analysis.impersonatesApp != null) {
          final bankName =
              TrustedAppCatalog.lookup(app.packageName)?.label ?? app.appName;
          await NotificationService.showBankingAlert(
            bankName: bankName,
            alertType: analysis.risk == FakeAppRisk.probablyFake
                ? 'Fake App Detected'
                : analysis.risk == FakeAppRisk.likelyFake
                    ? 'Likely Fake App'
                    : 'Suspicious App',
            details: 'This app may be impersonating $bankName. '
                'Reasons: ${analysis.reasons.join(", ")}',
          );
        }

        try {
          final sig = await _signatureChannel.invokeMethod<String>(
              'getSignatureSha256', {'packageName': app.packageName});
          _appSignatures[app.packageName] = sig;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _installedApps = bankingApps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isBankingRelated(String label) {
    const banking = [
      'paytm', 'phonepe', 'google pay', 'bhim', 'upi',
      'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'yes bank',
      'bank of baroda', 'idbi', 'indusind', 'federal bank',
      'airtel payments', 'amazon pay', 'gpay', 'whatsapp business',
    ];
    final lowerLabel = label.toLowerCase();
    return banking.any((b) => lowerLabel.contains(b));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeType = ref.watch(themeProvider).themeType;
    final sizing = A11ySizing.forTheme(themeType);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          '🏦 Banking App Protection',
          style: TextStyle(
            fontSize: 18 * sizing.textScale,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        actions: [
          IconButton(
            tooltip: 'Re-scan threats',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _refresh,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : (_installedApps == null || _installedApps!.isEmpty)
                ? _buildEmptyState(cs, sizing)
                : _buildBankingAppsList(cs, sizing),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, A11ySizing s) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24 * s.padScale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_outlined,
                size: 64 * s.textScale, color: cs.primary),
            SizedBox(height: 16 * s.padScale),
            Text(
              'No banking apps found',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 20 * s.textScale,
              ),
            ),
            SizedBox(height: 8 * s.padScale),
            Text(
              'Install SBI, HDFC, ICICI, Paytm, PhonePe, '
              'Google Pay, BHIM, or other banking/UPI apps',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13 * s.textScale,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankingAppsList(ColorScheme cs, A11ySizing s) {
    // Build the safety banner using SAFE-tier tokens so it always reads well
    final safe = RiskUiTokens.of(context, AppRiskLevel.safe);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16 * s.padScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active-threat correlator banner (only when not safe) ────
          if (_threatReport != null && _threatReport!.hasThreats) ...[
            _buildThreatCorrelatorBanner(_threatReport!, s),
            SizedBox(height: 16 * s.padScale),
          ],

          // ── Safety tips banner ──────────────────────────────────────
          Container(
            padding: EdgeInsets.all(14 * s.padScale),
            decoration: BoxDecoration(
              color: safe.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: safe.cardBorder,
                width: 1.5 + s.extraBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: safe.iconFg, size: 22 * s.textScale),
                SizedBox(width: 12 * s.padScale),
                Expanded(
                  child: Text(
                    'Download banking apps ONLY from the Google Play Store.\n'
                    'Always verify the publisher is the official bank.',
                    style: TextStyle(
                      color: safe.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13 * s.textScale,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20 * s.padScale),

          // ── Section title ───────────────────────────────────────────
          Text(
            'Installed Banking Apps',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: 0.5,
              fontSize: 15 * s.textScale,
            ),
          ),
          SizedBox(height: 12 * s.padScale),

          // ── List ────────────────────────────────────────────────────
          if (_installedApps!.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24 * s.padScale),
              child: Center(
                child: Text(
                  'No banking apps installed',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13 * s.textScale,
                  ),
                ),
              ),
            )
          else
            ..._installedApps!.map((app) => _buildBankingAppCard(app, cs, s)),
        ],
      ),
    );
  }

  /// Renders the live "Active Threats" banner from [BankingThreatCorrelator].
  ///
  /// Style:
  ///   • CRITICAL  → red salmon background, big AlertOctagon icon
  ///   • SUSPICIOUS → orange background, smaller WarningAmber icon
  ///   • SAFE      → not shown (filtered out by the caller)
  Widget _buildThreatCorrelatorBanner(
    BankingThreatReport report,
    A11ySizing s,
  ) {
    final isCritical = report.level == BankingThreatLevel.critical;
    final level = isCritical ? AppRiskLevel.critical : AppRiskLevel.medium;
    final t = RiskUiTokens.of(context, level);

    return Container(
      padding: EdgeInsets.all(14 * s.padScale),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.cardBorder,
          width: 1.8 + s.extraBorder,
        ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: t.cardBorder.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              Icon(
                isCritical
                    ? Icons.gpp_bad_rounded
                    : Icons.warning_amber_rounded,
                color: t.iconFg,
                size: 28 * s.textScale,
              ),
              SizedBox(width: 10 * s.padScale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCritical
                          ? 'Do NOT Open Banking Apps'
                          : 'Possible Risk Detected',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5 * s.textScale,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2 * s.padScale),
                    Text(
                      '${report.threats.length} active '
                      '${report.threats.length == 1 ? "threat" : "threats"} '
                      'on this device',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12 * s.textScale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * s.padScale),
          Divider(color: t.cardBorder, height: 1),
          SizedBox(height: 10 * s.padScale),

          // ── Threat list (collapsible if many) ────────────────────────
          ...report.threats.take(5).map(
                (threat) => Padding(
                  padding: EdgeInsets.only(bottom: 10 * s.padScale),
                  child: _buildThreatRow(threat, t, s),
                ),
              ),
          if (report.threats.length > 5)
            Padding(
              padding: EdgeInsets.only(top: 2 * s.padScale),
              child: Text(
                '+ ${report.threats.length - 5} more',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11.5 * s.textScale,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // ── Bottom call-to-action ───────────────────────────────────
          SizedBox(height: 6 * s.padScale),
          Container(
            padding: EdgeInsets.all(10 * s.padScale),
            decoration: BoxDecoration(
              color: t.badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_moon_rounded,
                  color: t.badgeText,
                  size: 18 * s.textScale,
                ),
                SizedBox(width: 8 * s.padScale),
                Expanded(
                  child: Text(
                    isCritical
                        ? 'Resolve every threat above before opening any '
                            'banking or UPI app. Your screen, taps, and SMS '
                            'may be visible to an attacker right now.'
                        : 'Review and resolve the items above before doing '
                            'any sensitive banking action.',
                    style: TextStyle(
                      color: t.badgeText,
                      fontSize: 12.5 * s.textScale,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatRow(
    BankingThreatItem threat,
    RiskUiTokens t,
    A11ySizing s,
  ) {
    final isCritical = threat.severity == BankingThreatLevel.critical;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6 * s.textScale,
          height: 6 * s.textScale,
          margin: EdgeInsets.only(top: 8 * s.padScale, right: 10 * s.padScale),
          decoration: BoxDecoration(
            color: isCritical ? t.iconFg : t.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                threat.message,
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13 * s.textScale,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 3 * s.padScale),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 13 * s.textScale,
                    color: t.textSecondary,
                  ),
                  SizedBox(width: 4 * s.padScale),
                  Expanded(
                    child: Text(
                      threat.recommendedAction,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11.5 * s.textScale,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankingAppCard(DeviceAppInfo app, ColorScheme cs, A11ySizing s) {
    final analysis = _fakeAppAnalyses[app.packageName];
    final isTrusted = TrustedAppCatalog.lookup(app.packageName) != null;
    final isFake = analysis != null && analysis.risk != FakeAppRisk.notFake;

    // Pick the risk level for this card so the whole tile uses one palette
    final level = isFake
        ? (analysis.risk == FakeAppRisk.probablyFake
            ? AppRiskLevel.critical
            : analysis.risk == FakeAppRisk.likelyFake
                ? AppRiskLevel.high
                : AppRiskLevel.medium)
        : (isTrusted ? AppRiskLevel.safe : AppRiskLevel.medium);

    final t = RiskUiTokens.of(context, level);
    final statusLabel = isFake
        ? (level == AppRiskLevel.critical
            ? '⚠ Fake'
            : level == AppRiskLevel.high
                ? '⚠ Likely Fake'
                : '⚠ Suspicious')
        : (isTrusted ? '✓ Verified' : 'Check Publisher');

    return Container(
      margin: EdgeInsets.only(bottom: 12 * s.padScale),
      padding: EdgeInsets.all(14 * s.padScale),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.cardBorder,
          width: 1.5 + s.extraBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40 * s.textScale,
                height: 40 * s.textScale,
                decoration: BoxDecoration(
                  color: t.iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.cardBorder, width: 1),
                ),
                child: Icon(
                  isTrusted ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                  color: t.iconFg,
                  size: 22 * s.textScale,
                ),
              ),
              SizedBox(width: 12 * s.padScale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                        fontSize: 16 * s.textScale,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2 * s.padScale),
                    Text(
                      app.packageName,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11.5 * s.textScale,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * s.padScale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * s.padScale,
                  vertical: 5 * s.padScale,
                ),
                decoration: BoxDecoration(
                  color: t.badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: t.badgeBorder,
                    width: 1.5 + s.extraBorder,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: t.badgeText,
                    fontSize: 11 * s.textScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          // ── Risk reasons ────────────────────────────────────────────
          if (analysis != null && isFake) ...[
            SizedBox(height: 10 * s.padScale),
            Container(
              padding: EdgeInsets.all(10 * s.padScale),
              decoration: BoxDecoration(
                color: t.badgeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.badgeBorder, width: 1),
              ),
              child: Text(
                analysis.reasons.join('\n• '),
                style: TextStyle(
                  fontSize: 12.5 * s.textScale,
                  color: t.badgeText,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          // ── Signature hash chip ─────────────────────────────────────
          if (_appSignatures[app.packageName] != null) ...[
            SizedBox(height: 10 * s.padScale),
            GestureDetector(
              onLongPress: () {
                final fullHash = _appSignatures[app.packageName] ?? '';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'SHA-256: $fullHash',
                    style: TextStyle(
                      fontSize: 10 * s.textScale,
                      fontFamily: 'monospace',
                    ),
                  ),
                  duration: const Duration(seconds: 5),
                  backgroundColor: cs.inverseSurface,
                ));
              },
              child: Container(
                padding: EdgeInsets.all(10 * s.padScale),
                decoration: BoxDecoration(
                  color: t.iconBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fingerprint_rounded,
                        size: 16 * s.textScale, color: t.iconFg),
                    SizedBox(width: 8 * s.padScale),
                    Expanded(
                      child: Text(
                        'SHA256: '
                        '${(_appSignatures[app.packageName] ?? '').substring(0, 12)}…',
                        style: TextStyle(
                          fontSize: 11 * s.textScale,
                          color: t.textSecondary,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.touch_app_rounded,
                        size: 14 * s.textScale, color: t.iconFg),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

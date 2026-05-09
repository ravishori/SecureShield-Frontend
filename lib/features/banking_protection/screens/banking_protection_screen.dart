/// Banking App Protection Screen
///
/// Dedicated view for Indian banking/UPI apps.
/// Shows authenticity status, signature verification, and recommended actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/theme/app_theme_enum.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../core/security/device_scanner_service.dart';
import '../../../core/security/trusted_app_catalog.dart';
import '../../../core/security/fake_app_detector.dart';
import '../../../core/services/notification_service.dart';
import 'package:flutter/services.dart';

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
  Map<String, FakeAppAnalysis> _fakeAppAnalyses = {};
  Map<String, String?> _appSignatures = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBankingApps();
  }

  Future<void> _loadBankingApps() async {
    try {
      final apps = await DeviceScannerService.getInstalledApps();
      final bankingApps = apps
          .where((a) {
            final trusted = TrustedAppCatalog.lookup(a.packageName);
            // Include only if it's a banking/UPI/payments app, not just any popular app
            final isBankingFromCatalog = trusted != null &&
                (trusted.category == 'banking' ||
                 trusted.category == 'upi' ||
                 trusted.category == 'payments');
            // Also include if app name contains banking keywords
            final isBankingRelated = _isBankingRelated(a.appName.toLowerCase());
            return isBankingFromCatalog || isBankingRelated;
          })
          .toList();

      // Analyze each for fake-app indicators
      for (final app in bankingApps) {
        final analysis = FakeAppDetector.analyze(app.packageName, app.appName);
        _fakeAppAnalyses[app.packageName] = analysis;

        // Trigger alert if fake banking app detected
        if (analysis.risk != FakeAppRisk.notFake && analysis.impersonatesApp != null) {
          final bankName = TrustedAppCatalog.lookup(app.packageName)?.label ?? app.appName;
          await NotificationService.showBankingAlert(
            bankName: bankName,
            alertType: analysis.risk == FakeAppRisk.probablyFake
                ? 'Fake App Detected'
                : analysis.risk == FakeAppRisk.likelyFake
                    ? 'Likely Fake App'
                    : 'Suspicious App',
            details:
                'This app may be impersonating $bankName. Reasons: ${analysis.reasons.join(", ")}',
          );
        }

        // Try to get signature SHA-256 (optional)
        try {
          final sig = await _signatureChannel
              .invokeMethod<String>('getSignatureSha256', {
            'packageName': app.packageName,
          });
          _appSignatures[app.packageName] = sig;
        } catch (_) {}
      }

      setState(() {
        _installedApps = bankingApps;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  bool _isBankingRelated(String label) {
    final banking = [
      'paytm',
      'phonepe',
      'google pay',
      'bhim',
      'upi',
      'sbi',
      'hdfc',
      'icici',
      'axis',
      'kotak',
      'yes bank',
      'bank of baroda',
      'idbi',
      'indusind',
      'federal bank',
      'airtel payments',
      'amazon pay',
      'gpay',
      'whatsapp business',
    ];
    final lowerLabel = label.toLowerCase();
    return banking.any((b) => lowerLabel.contains(b));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏦 Banking App Protection'),
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
              ),
            )
          : _installedApps == null || _installedApps!.isEmpty
              ? _buildEmptyState()
              : _buildBankingAppsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No banking apps found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Install SBI, HDFC, ICICI, Paytm, PhonePe, Google Pay, BHIM, or other banking/UPI apps',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBankingAppsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Safety tips card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Download banking apps ONLY from Google Play Store.\nVerify the publisher is the official bank.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Banking apps list ──────────────────────────────────────────────
          Text(
            'Installed Banking Apps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 12),
          if (_installedApps!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No banking apps installed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ),
            )
          else
            ..._installedApps!
                .map((app) => _buildBankingAppCard(app))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildBankingAppCard(DeviceAppInfo app) {
    final analysis = _fakeAppAnalyses[app.packageName];
    final isTrusted = TrustedAppCatalog.lookup(app.packageName) != null;
    final isFake = analysis?.risk != FakeAppRisk.notFake;

    // Get colors from theme
    final accentColor = Theme.of(context).colorScheme.secondary;
    final threatColor = AppThemeType.dark.threatColor();
    final safeColor = AppThemeType.dark.safeColor();

    // Color scheme based on security status
    final cardBgColor = isFake
        ? threatColor.withOpacity(0.08)  // Light red background
        : safeColor.withOpacity(0.08);   // Light green background
    final borderColor = isFake
        ? threatColor.withOpacity(0.4)   // Red border
        : safeColor.withOpacity(0.4);    // Green border
    final statusColor = isFake ? threatColor : safeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon, name, status ────────────────────────────────────
          Row(
            children: [
              Icon(
                isTrusted ? Icons.verified_user : Icons.warning_amber_rounded,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    Text(
                      app.packageName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace',
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  isTrusted ? '✓ Safe' : '⚠️ Alert',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // ── Risk reasons ───────────────────────────────────────────────────
          if (analysis != null && isFake) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                analysis.reasons.join('\n'),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFF8888),
                  height: 1.4,
                ),
              ),
            ),
          ],

          // ── Signature hash ─────────────────────────────────────────────────
          if (_appSignatures[app.packageName] != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onLongPress: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'SHA-256: ${_appSignatures[app.packageName]}',
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                  ),
                  duration: const Duration(seconds: 5),
                  backgroundColor: AppTheme.cardColor,
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 14,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'SHA256: ${(_appSignatures[app.packageName] ?? '').substring(0, 12)}...',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.tap_and_play,
                      size: 12,
                      color: AppTheme.accent,
                    ),
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

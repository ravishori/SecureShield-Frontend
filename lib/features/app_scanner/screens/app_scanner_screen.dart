import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/security/fake_app_detector.dart';
import '../app_scanner_api.dart';

class AppScannerScreen extends StatefulWidget {
  const AppScannerScreen({super.key});

  @override
  State<AppScannerScreen> createState() => _AppScannerScreenState();
}

class _AppScannerScreenState extends State<AppScannerScreen> {
  final _api = AppScannerApi();
  List<dynamic> _results = [];
  bool _loading = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _loading = true);
    try {
      final results = await _api.getResults();
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanApps() async {
    setState(() => _scanning = true);
    try {
      // Simulate app list (in real app, use installed_apps package)
      final mockApps = [
        {
          'package_name': 'com.example.app1',
          'app_name': 'Example App 1',
          'version_name': '1.0.0',
          'permissions': ['android.permission.INTERNET', 'android.permission.READ_SMS'],
          'is_system_app': false,
        },
        {
          'package_name': 'com.google.android.gms',
          'app_name': 'Google Play Services',
          'version_name': '23.0',
          'permissions': ['android.permission.INTERNET'],
          'is_system_app': true,
        },
        {
          'package_name': 'com.suspicious.tracker',
          'app_name': 'Suspicious Tracker',
          'version_name': '2.1',
          'permissions': [
            'android.permission.READ_SMS',
            'android.permission.READ_CALL_LOG',
            'android.permission.ACCESS_FINE_LOCATION',
            'android.permission.CAMERA',
            'android.permission.RECORD_AUDIO',
            'android.permission.READ_CONTACTS',
          ],
          'is_system_app': false,
        },
      ];

      final result = await _api.scanApps(apps: mockApps);
      await _loadResults();

      if (mounted) {
        final highRisk = result['high_risk_count'] as int? ?? 0;
        final criticalRisk = result['critical_risk_count'] as int? ?? 0;

        // Check for fake/clone apps and trigger notifications
        final detailedResults = (result['detailed_results'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        for (final appResult in detailedResults) {
          final packageName = appResult['package_name'] as String? ?? '';
          final appName = appResult['app_name'] as String? ?? '';
          final riskLevel = appResult['risk_level'] as String? ?? 'safe';

          // Check for fake app
          if (packageName.isNotEmpty) {
            final fakeAnalysis = FakeAppDetector.analyze(packageName, appName);
            if (fakeAnalysis.risk != FakeAppRisk.notFake && fakeAnalysis.impersonatesApp != null) {
              await NotificationService.showFakeAppAlert(
                appName: appName,
                impersonatesApp: fakeAnalysis.impersonatesApp!,
                packageName: packageName,
                reason: fakeAnalysis.reasons.isNotEmpty ? fakeAnalysis.reasons.first : 'Name impersonation',
              );
            }
          }

          // Check for critical/high risk and notify
          if (riskLevel == 'critical') {
            final reasons = (appResult['reasons'] as List<dynamic>?)?.cast<String>() ?? [];
            await NotificationService.showSecurityWarning(
              title: '🚨 Critical Risk: $appName',
              message: reasons.isNotEmpty ? reasons.first : 'Critical security threat detected',
              action: 'Review',
            );
          } else if (riskLevel == 'high') {
            final reasons = (appResult['reasons'] as List<dynamic>?)?.cast<String>() ?? [];
            await NotificationService.showSecurityWarning(
              title: '⚠️ High Risk: $appName',
              message: reasons.isNotEmpty ? reasons.first : 'High security risk detected',
              action: 'Review',
            );
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan complete! ${result['total_apps']} apps, $criticalRisk critical, $highRisk high risk'),
            backgroundColor: criticalRisk > 0 ? const Color(0xFFFF1744) : (highRisk > 0 ? AppTheme.warning : AppTheme.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scan button area
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _scanApps,
            icon: _scanning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.radar),
            label: Text(_scanning ? 'Scanning...' : 'Scan All Apps'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accent)))
        else if (_results.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apps, size: 64, color: AppTheme.accent),
                  const SizedBox(height: 16),
                  const Text('No scan results yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  const Text('Tap "Scan All Apps" to begin', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final app = _results[index] as Map<String, dynamic>;
                return _AppTile(app: app);
              },
            ),
          ),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  final Map<String, dynamic> app;
  const _AppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final riskLevel = app['risk_level'] as String? ?? 'safe';
    final riskScore = (app['risk_score'] as num?)?.toDouble() ?? 0.0;
    final color = AppTheme.riskColor(riskLevel);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
          ),
          child: Icon(Icons.android, color: color, size: 24),
        ),
        title: Text(
          app['app_name'] as String? ?? '',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          app['package_name'] as String? ?? '',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.6), width: 1),
              ),
              child: Text(
                riskLevel.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${riskScore.toStringAsFixed(0)}/100',
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ),
        onTap: () => context.push('/app-detail', extra: app),
      ),
    );
  }
}

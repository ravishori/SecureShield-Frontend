import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class AppDetailScreen extends StatelessWidget {
  final Map<String, dynamic> scanResult;
  const AppDetailScreen({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final appName = scanResult['app_name'] as String? ?? 'Unknown App';
    final riskLevel = scanResult['risk_level'] as String? ?? 'safe';
    final riskScore = (scanResult['risk_score'] as num?)?.toDouble() ?? 0.0;
    final permissions = (scanResult['permissions'] as List?)?.cast<String>() ?? [];
    final threatTags = (scanResult['threat_tags'] as List?)?.cast<String>() ?? [];
    final isMalicious = scanResult['is_malicious'] as bool? ?? false;
    final color = AppTheme.riskColor(riskLevel);

    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Risk summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Icon(
                    isMalicious ? Icons.dangerous : Icons.shield,
                    size: 56,
                    color: color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    riskLevel.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Risk Score: ${riskScore.toStringAsFixed(0)}/100',
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (isMalicious) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'MALICIOUS APP DETECTED',
                        style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Threat tags
            if (threatTags.isNotEmpty) ...[
              Text('Threat Tags', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: threatTags.map((tag) => Chip(
                  label: Text(tag.replaceAll('_', ' ').toUpperCase()),
                  backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
                  side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.6), width: 1),
                  labelStyle: const TextStyle(color: AppTheme.errorColor, fontSize: 11, fontWeight: FontWeight.bold),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Permissions
            Text('Permissions (${permissions.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            ...permissions.map((perm) {
              final isDangerous = _isDangerous(perm);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDangerous ? AppTheme.warning.withValues(alpha: 0.08) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDangerous ? AppTheme.warning.withValues(alpha: 0.4) : const Color(0xFF2A3560),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDangerous ? Icons.warning_amber : Icons.check_circle_outline,
                      size: 16,
                      color: isDangerous ? AppTheme.warning : AppTheme.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        perm.split('.').last,
                        style: TextStyle(
                          color: isDangerous ? AppTheme.warning : const Color.fromARGB(222, 255, 255, 255),
                          fontSize: 12,
                          fontWeight: isDangerous ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Recommendation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recommendation', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 8),
                  Text(
                    _getRecommendation(riskLevel, isMalicious),
                    style: const TextStyle(color: Color.fromARGB(222, 255, 255, 255), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDangerous(String perm) {
    const dangerousPerms = ['SMS', 'CALL_LOG', 'CAMERA', 'RECORD_AUDIO', 'LOCATION', 'CONTACTS', 'ACCESSIBILITY', 'DEVICE_ADMIN'];
    return dangerousPerms.any((d) => perm.toUpperCase().contains(d));
  }

  String _getRecommendation(String riskLevel, bool isMalicious) {
    if (isMalicious) return 'This app is identified as potentially malicious. Uninstall it immediately and run a full device security scan.';
    switch (riskLevel) {
      case 'critical': return 'This app has critical risk. Consider uninstalling it unless it is from a trusted source.';
      case 'high': return 'This app requests many sensitive permissions. Review if these permissions are necessary for its function.';
      case 'medium': return 'This app has moderate risk. Monitor its behavior and check if it is from a verified publisher.';
      case 'low': return 'This app has low risk. It appears to be generally safe to use.';
      default: return 'This app appears safe. No significant threats detected.';
    }
  }
}

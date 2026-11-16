import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../remote_detector_service.dart';
import 'package:secureshield_app/core/utils/safe_error.dart';

class RemoteDetectorScreen extends ConsumerWidget {
  const RemoteDetectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(remoteThreatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Control Detector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(remoteThreatProvider),
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
          child: Text(safeErrorMessage(e, prefix: 'Scan failed'),
            style: const TextStyle(color: AppTheme.errorColor)),
        ),
        data: (data) => _buildReport(context, ref, data),
      ),
    );
  }

  Widget _buildReport(BuildContext context, WidgetRef ref, RemoteThreatReport data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                data.hasThreat ? AppTheme.errorColor.withValues(alpha: 0.8) : AppTheme.success.withValues(alpha: 0.8),
                data.hasThreat ? AppTheme.errorColor.withValues(alpha: 0.4) : AppTheme.success.withValues(alpha: 0.4),
              ]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  data.hasThreat ? Icons.warning_amber : Icons.shield,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  data.hasThreat ? 'Remote Access Risk Detected!' : 'No Remote Access Detected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (data.hasThreat) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${data.threatCount} threat(s) found',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Remote apps
          const Text('Remote Control Apps', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (data.remoteApps.isEmpty)
            _emptyCard('No remote control apps installed')
          else
            ...data.remoteApps.map((app) => _remoteAppCard(context, app)),

          const SizedBox(height: 16),

          // ADB status
          const Text('Developer Settings', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          _statusCard(
            icon: Icons.developer_mode,
            title: 'USB Debugging (ADB)',
            value: data.adbEnabled ? 'ENABLED — Risk!' : 'Disabled — OK',
            color: data.adbEnabled ? AppTheme.errorColor : AppTheme.success,
            description: data.adbEnabled
                ? 'ADB is enabled. Scammers can use it to control your device. Disable in Settings > Developer options.'
                : 'USB debugging is off. Your device is safe from ADB-based attacks.',
          ),

          const SizedBox(height: 16),

          // Device admin apps
          const Text('Device Administrator Apps', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (data.deviceAdminApps.isEmpty)
            _emptyCard('No device admin apps found')
          else
            ...data.deviceAdminApps.map((pkg) => _adminCard(pkg)),

          const SizedBox(height: 16),

          // Safety tips
          _safetyTipsCard(),
        ],
      ),
    );
  }

  Widget _remoteAppCard(BuildContext context, RemoteApp app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.desktop_access_disabled, color: AppTheme.errorColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.appName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(app.packageName,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('INSTALLED',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title on its own line — full width, no competition
                Text(title, style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
                const SizedBox(height: 4),
                // Value badge + description on the same level
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(description, style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    // Fixed-width chip — never competes with title/description
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(value,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminCard(String pkg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: AppTheme.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(pkg,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
              style: const TextStyle(color: AppTheme.success, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _safetyTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates, color: AppTheme.accent, size: 18),
              SizedBox(width: 8),
              Text('Safety Tips', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            'Never allow anyone to install AnyDesk/TeamViewer claiming to be from your bank.',
            'Legitimate banks NEVER ask for remote access to your device.',
            'If you find a remote app you didn\'t install — uninstall it immediately.',
            'Disable ADB (USB Debugging) when not needed by a developer.',
            'Report scam attempts to 1930 (National Cybercrime Helpline).',
          ].map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_right, color: AppTheme.accent, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(tip,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

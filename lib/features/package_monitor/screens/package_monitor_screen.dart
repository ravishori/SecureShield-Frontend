import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../package_monitor_service.dart';

class PackageMonitorScreen extends ConsumerWidget {
  const PackageMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(packageInstallHistoryProvider);

    // Keep stream alive + show snackbar on new install
    ref.listen(packageInstallStreamProvider, (_, next) {
      next.whenData((event) {
        if (!context.mounted) return;
        final isHigh = event.isUnknownSource;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isHigh ? AppTheme.errorColor : AppTheme.warning,
            content: Row(children: [
              Icon(isHigh ? Icons.warning : Icons.system_update_alt,
                color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                isHigh
                    ? '⚠️ Unknown source app installed: ${event.appName}'
                    : 'New app installed: ${event.appName}',
                style: const TextStyle(color: Colors.white),
              )),
            ]),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Scan',
              textColor: Colors.white,
              onPressed: () => context.push('/home/scanner'),
            ),
          ),
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Install Monitor'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => ref.read(packageInstallHistoryProvider.notifier).clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info + stats
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(children: [
                  const Icon(Icons.sensors, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Monitoring app installations in real-time. '
                      'Unknown-source installs are flagged as high risk.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ]),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('${history.length}', 'Total', AppTheme.accent),
                      _stat(
                        '${history.where((e) => e.isUnknownSource).length}',
                        'Unknown Src', AppTheme.errorColor,
                      ),
                      _stat(
                        '${history.where((e) => !e.isReplacing && !e.isUnknownSource).length}',
                        'Play Store', AppTheme.success,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Install History', style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                )),
                const Spacer(),
                if (history.any((e) => e.isUnknownSource))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${history.where((e) => e.isUnknownSource).length} HIGH RISK',
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.app_registration,
                          size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('No app installs detected yet',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                        const SizedBox(height: 8),
                        const Text(
                          'New installations will appear here automatically',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (_, i) => _InstallCard(event: history[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(
        color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    ]);
  }
}

class _InstallCard extends StatelessWidget {
  final PackageInstallEvent event;
  const _InstallCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isHigh = event.isUnknownSource;
    final isUpdate = event.isReplacing;
    final color = isHigh
        ? AppTheme.errorColor
        : isUpdate
            ? AppTheme.textSecondary
            : AppTheme.success;

    final age = DateTime.now().difference(event.timestamp);
    final timeStr = age.inMinutes < 1
        ? 'Just now'
        : age.inHours < 1
            ? '${age.inMinutes}m ago'
            : age.inDays < 1
                ? '${age.inHours}h ago'
                : '${age.inDays}d ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isHigh ? Border.all(color: AppTheme.errorColor.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isHigh
                  ? Icons.warning_amber
                  : isUpdate
                      ? Icons.system_update_alt
                      : Icons.install_mobile,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.appName, style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
                Text(event.packageName, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 2),
                Text(timeStr, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isHigh ? 'HIGH RISK' : isUpdate ? 'UPDATE' : 'NEW',
                  style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              if (isHigh) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push('/home/scanner'),
                  child: const Text('Scan now',
                    style: TextStyle(color: AppTheme.accent, fontSize: 11)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

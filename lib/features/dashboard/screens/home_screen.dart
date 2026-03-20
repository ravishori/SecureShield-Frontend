import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../features/auth/auth_provider.dart';
import '../dashboard_api.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  final _api = DashboardApi();
  Map<String, dynamic>? _report;
  List<dynamic> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await _api.getDailyReport();
      final alerts = await _api.getRecentAlerts();
      if (mounted) {
        setState(() {
          _report = report;
          _alerts = alerts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    final riskScore = (_report?['overall_risk_score'] as num?)?.toDouble() ?? 0.0;
    final threats = _report?['threats_detected'] ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Score Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    riskScore > 60 ? AppTheme.errorColor.withOpacity(0.7) : AppTheme.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Security Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            '${(100 - riskScore).toStringAsFixed(0)}/100',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Icon(
                        riskScore < 30 ? Icons.shield : riskScore < 60 ? Icons.shield_outlined : Icons.warning_amber,
                        size: 60,
                        color: riskScore < 30 ? AppTheme.success : riskScore < 60 ? AppTheme.warning : AppTheme.errorColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statChip(Icons.warning, '$threats', 'Threats'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statChip(Icons.apps, '${_report?['apps_scanned'] ?? 0}', 'Apps'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statChip(Icons.link, '${_report?['links_scanned'] ?? 0}', 'Links'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _actionCard(context, Icons.lock, 'OTP Vault', AppTheme.accent, '/otp-vault'),
                _actionCard(context, Icons.link, 'Link Scan', AppTheme.warning, '/link-scanner'),
                _actionCard(context, Icons.wifi, 'Wi-Fi Check', AppTheme.success, '/wifi-scanner'),
                _actionCard(context, Icons.folder_special, 'Evidence', AppTheme.primary.withOpacity(0.8), '/evidence'),
                _actionCard(context, Icons.family_restroom, 'Family', const Color(0xFF9C27B0), '/family'),
                _actionCard(context, Icons.settings, 'Settings', AppTheme.textSecondary, '/settings'),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Alerts
            if (_alerts.isNotEmpty) ...[
              Text('Recent Alerts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._alerts.take(3).map((alert) => _alertTile(context, alert)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String label, Color color, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertTile(BuildContext context, Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final color = AppTheme.severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(
            severity == 'critical' ? Icons.error : severity == 'warning' ? Icons.warning : Icons.info,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] as String? ?? '',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alert['message'] as String? ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  final Widget child;
  final String location;

  const HomeScreen({super.key, required this.child, required this.location});

  int _selectedIndex(String location) {
    if (location.startsWith('/home/scanner')) return 1;
    if (location.startsWith('/home/alerts')) return 2;
    if (location.startsWith('/home/reports')) return 3;
    if (location.startsWith('/home/ai-coach')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _selectedIndex(location);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            const Text('SecureShield AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.accent),
            onPressed: () => context.push('/home/alerts'),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          switch (i) {
            case 0: context.go('/home'); break;
            case 1: context.go('/home/scanner'); break;
            case 2: context.go('/home/alerts'); break;
            case 3: context.go('/home/reports'); break;
            case 4: context.go('/home/ai-coach'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI Coach'),
        ],
      ),
    );
  }
}

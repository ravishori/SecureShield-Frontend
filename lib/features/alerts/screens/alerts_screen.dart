import 'package:secureshield_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../alerts_api.dart';
import 'package:secureshield_app/core/utils/safe_error.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _api = AlertsApi();
  List<dynamic> _alerts = [];
  // ignore: unused_field
  int _total = 0;
  final int _page = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getAlerts(page: _page);
      if (mounted) {
        setState(() {
          _alerts = data['items'] as List<dynamic>? ?? [];
          _total = data['total'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerPanic() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocalizations.of(context).panicTitle, style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
        content: Text(
          AppLocalizations.of(context).panicBody,
          style: const TextStyle(color: Color.fromARGB(222, 255, 255, 255)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.triggerPanic(message: 'Emergency! I need help!');
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).panicSent),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(safeErrorMessage(e, prefix: 'Failed')), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context).sendAlert),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggerPanic,
        backgroundColor: AppTheme.errorColor,
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text('PANIC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 64, color: AppTheme.success),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context).noAlerts, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                      Text(AppLocalizations.of(context).youAreSafe, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index] as Map<String, dynamic>;
                      return _AlertCard(alert: alert, onDismiss: () async {
                        await _api.dismiss(alert['id'] as String);
                        await _load();
                      });
                    },
                  ),
                ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onDismiss;
  const _AlertCard({required this.alert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] as String? ?? 'info';
    final alertType = alert['alert_type'] as String? ?? '';
    final color = AppTheme.severityColor(severity);
    final isRead = alert['is_read'] as bool? ?? false;

    IconData icon;
    switch (alertType) {
      case 'phishing': icon = Icons.link_off; break;
      case 'scam_call': icon = Icons.phone_disabled; break;
      case 'app_risk': icon = Icons.android; break;
      case 'wifi_unsafe': icon = Icons.wifi_off; break;
      case 'panic': icon = Icons.sos; break;
      default: icon = Icons.warning_amber;
    }

    return Dismissible(
      key: Key(alert['id'] as String),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppTheme.errorColor,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: isRead ? [] : [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert['title'] as String? ?? '',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert['message'] as String? ?? '',
                    style: const TextStyle(color: Color.fromARGB(222, 255, 255, 255), fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

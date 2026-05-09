import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../app_monitor_service.dart';
import '../models/install_event.dart';

class AppMonitorScreen extends ConsumerStatefulWidget {
  const AppMonitorScreen({super.key});
  @override
  ConsumerState<AppMonitorScreen> createState() => _AppMonitorScreenState();
}

class _AppMonitorScreenState extends ConsumerState<AppMonitorScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _checkRunning();
    // Subscribe to live stream so provider activates
    ref.read(installEventStreamProvider);
  }

  Future<void> _checkRunning() async {
    final running = await ref.read(appMonitorServiceProvider).isRunning();
    if (mounted) ref.read(monitorRunningProvider.notifier).state = running;
  }

  Future<void> _toggle() async {
    setState(() => _starting = true);
    final svc     = ref.read(appMonitorServiceProvider);
    final running = ref.read(monitorRunningProvider);
    if (running) {
      await svc.stopMonitor();
      ref.read(monitorRunningProvider.notifier).state = false;
    } else {
      final ok = await svc.startMonitor();
      ref.read(monitorRunningProvider.notifier).state = ok;
    }
    // Sync any queued events
    await svc.syncQueue();
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final running   = ref.watch(monitorRunningProvider);
    final events    = ref.watch(liveEventsProvider);
    final summaryAV = ref.watch(monitorSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Install Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync to server',
            onPressed: () async {
              final n = await ref.read(appMonitorServiceProvider).syncQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Synced $n events')));
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _statusCard(running),
          const SizedBox(height: 16),
          summaryAV.when(
            data:    (s) => _summaryRow(s),
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Live Events (this session)', events.length),
          const SizedBox(height: 8),
          if (events.isEmpty)
            _emptyCard('No installs detected yet.\nMonitor is watching in real time.')
          else
            ...events.map((e) => _eventCard(context, e)),
        ]),
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────
  Widget _statusCard(bool running) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          (running ? AppTheme.success : AppTheme.textSecondary).withOpacity(0.8),
          (running ? AppTheme.success : AppTheme.textSecondary).withOpacity(0.4),
        ]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Icon(running ? Icons.security : Icons.security_outlined,
            size: 48, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          running ? 'Monitor Active' : 'Monitor Off',
          style: const TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          running
              ? 'Watching for app installs, updates & clones'
              : 'Tap below to start real-time monitoring',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _starting
            ? const CircularProgressIndicator(color: Colors.white)
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: running ? AppTheme.success : AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _toggle,
                icon: Icon(running ? Icons.stop : Icons.play_arrow),
                label: Text(running ? 'Stop Monitor' : 'Start Monitor',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
      ]),
    );
  }

  // ── Summary row ───────────────────────────────────────────────────────────
  Widget _summaryRow(Map<String, dynamic> s) {
    return Row(children: [
      _summaryTile('Monitored', '${s['total_monitored'] ?? 0}', AppTheme.accent),
      const SizedBox(width: 8),
      _summaryTile('Danger', '${s['danger_count'] ?? 0}', AppTheme.errorColor),
      const SizedBox(width: 8),
      _summaryTile('Clones', '${s['clone_count'] ?? 0}', AppTheme.warning),
    ]);
  }

  Widget _summaryTile(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ]),
    ),
  );

  // ── Event card ────────────────────────────────────────────────────────────
  Widget _eventCard(BuildContext context, InstallEvent ev) {
    final color = _riskColor(ev);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_riskIcon(ev), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ev.appName,
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(ev.riskLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(ev.packageName,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        if (ev.isFakeApp) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.warning_amber, color: AppTheme.errorColor, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Likely fake copy of ${ev.cloneTargetName}',
                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
        if (ev.localRiskTags.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...ev.localRiskTags.take(2).map((t) => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              const Icon(Icons.arrow_right, color: AppTheme.textSecondary, size: 14),
              Expanded(child: Text(t,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
            ]),
          )),
        ],
        const SizedBox(height: 6),
        Row(children: [
          _badge(ev.eventType.toUpperCase(), AppTheme.accent),
          const SizedBox(width: 6),
          if (ev.isUnknownSource) _badge('SIDELOADED', AppTheme.warning),
          const Spacer(),
          Text(_timeAgo(ev.timestamp),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, int count) => Row(children: [
    Text(title,
        style: const TextStyle(color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold, fontSize: 14)),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(color: AppTheme.accent,
          fontSize: 12, fontWeight: FontWeight.bold)),
    ),
  ]);

  Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
    ]),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 9,
        fontWeight: FontWeight.bold)),
  );

  Color _riskColor(InstallEvent ev) {
    if (ev.isFakeApp)    return AppTheme.errorColor;
    if (ev.isDanger)     return AppTheme.errorColor;
    if (ev.isWarning)    return AppTheme.warning;
    if (ev.isSuspicious) return AppTheme.warning;
    return AppTheme.success;
  }

  IconData _riskIcon(InstallEvent ev) {
    if (ev.isFakeApp) return Icons.dangerous;
    if (ev.isDanger)  return Icons.warning_amber;
    if (ev.isWarning) return Icons.info;
    return Icons.check_circle;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

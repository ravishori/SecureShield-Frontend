import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../app_monitor_service.dart';
import '../monitor_sync_coordinator.dart';
import '../../auth/auth_provider.dart';
import '../models/install_event.dart';

class AppMonitorScreen extends ConsumerStatefulWidget {
  const AppMonitorScreen({super.key});
  @override
  ConsumerState<AppMonitorScreen> createState() => _AppMonitorScreenState();
}

class _AppMonitorScreenState extends ConsumerState<AppMonitorScreen>
    with WidgetsBindingObserver {
  bool _starting = false;
  String? _error;
  bool _permissionDenied = false;
  bool _paused =
      false; // monitoring was switched off because notifications are off
  Map<String, dynamic> _stats =
      const {}; // counts from the native event store (no package or account text)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkRunning();
    _loadStats();
    // Subscribe to live stream so provider activates
    ref.read(installEventStreamProvider);
  }

  Future<void> _loadStats() async {
    await ref.read(monitorSyncProvider).restoreEndpointState(); // a problem recorded before a restart
    final st = await ref.read(monitorSyncProvider).stats();
    if (mounted) setState(() => _stats = st);
  }

  int _n(String k) => (_stats[k] as num?)?.toInt() ?? 0;

  /// Failures and rejections the person can see, so events that did not sync are never invisible.
  Widget _problemsCard() {
    final failed = _n('historyFailed'), rejected = _n('historyRejected');
    final lost = _n('lostFailed') + _n('lostRejected') + _n('lostUnsent');
    final resets = _n(
        'dbRecoveries'); // times the event database was damaged and had to be recreated
    final endpoint = ref.read(monitorSyncProvider).endpointProblem;
    final coordinator = ref.read(monitorSyncProvider);
    final storageCard = !coordinator.endpointStateUnreadable
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Card(
                key: const Key('monitorStorageProblem'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Sync is paused', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(storageProblemMessage()),
                    Text('Diagnostic code: prefs_unreadable (${coordinator.storageFailures} failed reads)',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            ),
          );
    final writeCard = !coordinator.endpointWriteFailed
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Card(
                key: const Key('monitorWriteProblem'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Sync is paused', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(writeProblemMessage()),
                    Text('Diagnostic code: prefs_write_failed (${coordinator.writeFailures} failed saves)',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            ),
          );
    final endpointCard = endpoint == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Card(
                key: const Key('monitorEndpointProblem'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sync is not working',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(endpointProblemMessage(endpoint)),
                        Text('Diagnostic code: $endpoint',
                            style: const TextStyle(fontSize: 12)),
                      ]),
                ),
              ),
            ),
          );
    if (failed + rejected + lost + resets == 0) return Column(children: [storageCard, writeCard, endpointCard]);
    final codes = (_stats['errorCodes'] is Map)
        ? (_stats['errorCodes'] as Map).keys.take(4).join(', ')
        : '';
    return Column(children: [
      storageCard,
      writeCard,
      endpointCard,
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          liveRegion: true,
          child: Card(
            key: const Key('monitorProblems'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Some events did not sync',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (failed > 0)
                      Text(
                          '$failed could not be synced after repeated attempts.'),
                    if (rejected > 0)
                      Text('$rejected were rejected by the server.'),
                    if (lost > 0)
                      Text(
                          '$lost were removed from this device before they could sync.'),
                    if (resets > 0)
                      Text(
                          'The event storage was damaged and reset $resets time(s); events in it were lost.'),
                    if (codes.isNotEmpty)
                      Text('Reason codes: $codes',
                          style: const TextStyle(fontSize: 12)),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The service can be stopped from its notification, or die with the process, while this screen is in the background:
  /// whenever the app comes back, ask the native side again instead of trusting the last answer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkRunning();
  }

  Future<void> _checkRunning() async {
    final svc = ref.read(appMonitorServiceProvider);
    // First: if monitoring was ON but the user can no longer see it, it has been paused natively; say so.
    final paused = await svc.enforceVisibility();
    if (paused && mounted) {
      setState(() {
        _paused = true;
        _permissionDenied = true;
      });
    }
    var running = await svc.isRunning();
    // Monitoring was left ON but Android ended the process (the service is gone): bring the service back, or - if that is
    // not possible (for example notifications were turned off) - record that monitoring is OFF. The screen never shows
    // Active unless the service is really running.
    if (!running && await svc.isEnabled()) {
      final r = await svc.start();
      running = r.running;
      if (!running) {
        await svc.stopMonitor();
        if (mounted) setState(() => _error = r.message);
      }
    }
    if (mounted) ref.read(monitorRunningProvider.notifier).state = running;
  }

  Future<void> _toggle() async {
    setState(() {
      _starting = true;
      _error = null;
      _permissionDenied = false;
      _paused = false;
    });
    final svc = ref.read(appMonitorServiceProvider);
    final running = ref.read(monitorRunningProvider);
    if (running) {
      await svc.stopMonitor();
      // The shown state is whatever the native service reports afterwards, not what was requested.
      ref.read(monitorRunningProvider.notifier).state = await svc.isRunning();
    } else {
      // The native store must know the signed-in account BEFORE monitoring is enabled, so every event is attributed.
      final auth = ref.read(authProvider);
      final ownerOk = auth.isAuthenticated &&
          await ref.read(monitorSyncProvider).setOwner(auth.userId);
      if (!ownerOk) {
        _error =
            'Sign in again to start monitoring. Monitoring was not started.';
        if (mounted) setState(() => _starting = false);
        return;
      }
      final r = await svc.start();
      // "Active" only when the native service confirmed it.
      ref.read(monitorRunningProvider.notifier).state = r.running;
      if (!r.running) {
        _error = r.message;
        _permissionDenied =
            r.failure == MonitorStartFailure.notificationPermissionDenied ||
                r.failure == MonitorStartFailure.notificationsDisabled;
      }
    }
    // Sync any queued events; a failed sync must never leave the screen stuck in its busy state
    try {
      await ref.read(monitorSyncProvider).sync(manual: true);
    } catch (_) {}
    await _loadStats();
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(monitorRunningProvider);
    final events = ref.watch(liveEventsProvider);
    final summaryAV = ref.watch(monitorSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Install Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync to server',
            onPressed: () async {
              final r = await ref.read(monitorSyncProvider).sync(manual: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(syncMessage(r))));
              }
              _loadStats();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _statusCard(running),
          _problemsCard(),
          if (_paused) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: const Text(
                'Monitoring is paused because notifications for SecureShield are off. Nothing is being monitored. '
                'Turn notifications back on, then start the monitor again.',
                key: Key('monitorPaused'),
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
            TextButton(
              key: const Key('monitorPausedOpenSettings'),
              onPressed: () =>
                  ref.read(appMonitorServiceProvider).openSettings(),
              child: const Text('Open app settings'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(_error!,
                  key: const Key('monitorError'),
                  style: const TextStyle(color: Colors.redAccent)),
            ),
            if (_permissionDenied)
              TextButton(
                key: const Key('monitorOpenSettings'),
                onPressed: () =>
                    ref.read(appMonitorServiceProvider).openSettings(),
                child: const Text('Open app settings'),
              ),
          ],
          const SizedBox(height: 16),
          _disclosureCard(),
          const SizedBox(height: 16),
          summaryAV.when(
            data: (s) => _summaryRow(s),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Live Events (this session)', events.length),
          const SizedBox(height: 8),
          if (events.isEmpty)
            _emptyCard(
                'No installs detected yet.\nMonitor is watching in real time.')
          else
            ...events.map((e) => _eventCard(context, e)),
        ]),
      ),
    );
  }

  // -- Disclosure: what this does, shown before and while it runs
  Widget _disclosureCard() {
    return Container(
      key: const Key('monitorDisclosure'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border:
            Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'What this does: while it is on, SecureShield notices when an app is installed, updated or removed and checks '
        'the app name, permissions and signature on your phone. Risky or fake apps trigger a warning. App names and '
        'risk results are saved on this phone and uploaded to your SecureShield account when you sync. It does not read '
        'the contents of your apps or messages. A notification stays visible while it runs; you can stop it there or '
        'with the button above at any time. If Android or you stop the app, monitoring is off until you turn it on again.',
        style: TextStyle(fontSize: 12, height: 1.4),
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
          (running ? AppTheme.success : AppTheme.textSecondary)
              .withValues(alpha: 0.8),
          (running ? AppTheme.success : AppTheme.textSecondary)
              .withValues(alpha: 0.4),
        ]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Icon(running ? Icons.security : Icons.security_outlined,
            size: 48, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          running ? 'Monitor Active' : 'Monitor Off',
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                  foregroundColor:
                      running ? AppTheme.success : AppTheme.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
      _summaryTile(
          'Monitored', '${s['total_monitored'] ?? 0}', AppTheme.accent),
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
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_riskIcon(ev), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ev.appName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(ev.riskLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(ev.packageName,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        if (ev.isFakeApp) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.warning_amber,
                color: AppTheme.errorColor, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Likely fake copy of ${ev.cloneTargetName}',
                  style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
        if (ev.localRiskTags.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...ev.localRiskTags.take(2).map((t) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.arrow_right,
                      color: AppTheme.textSecondary, size: 14),
                  Expanded(
                      child: Text(t,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11))),
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
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, int count) => Row(children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]);

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.info_outline,
              color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13))),
        ]),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  Color _riskColor(InstallEvent ev) {
    if (ev.isFakeApp) return AppTheme.errorColor;
    if (ev.isDanger) return AppTheme.errorColor;
    if (ev.isWarning) return AppTheme.warning;
    if (ev.isSuspicious) return AppTheme.warning;
    return AppTheme.success;
  }

  IconData _riskIcon(InstallEvent ev) {
    if (ev.isFakeApp) return Icons.dangerous;
    if (ev.isDanger) return Icons.warning_amber;
    if (ev.isWarning) return Icons.info;
    return Icons.check_circle;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

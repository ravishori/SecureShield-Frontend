import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../clone_detector_api.dart';
import '../models/clone_result.dart';
import '../../app_monitor/app_monitor_service.dart';

final _historyProvider = FutureProvider<List<CloneResult>>((ref) async {
  return CloneDetectorApi().fetchHistory();
});

class CloneDetectorScreen extends ConsumerStatefulWidget {
  const CloneDetectorScreen({super.key});
  @override
  ConsumerState<CloneDetectorScreen> createState() => _CloneDetectorScreenState();
}

class _CloneDetectorScreenState extends ConsumerState<CloneDetectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _api      = CloneDetectorApi();
  final _pkgCtrl  = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _scanning  = false;
  CloneResult? _scanResult;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pkgCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final pkg  = _pkgCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (pkg.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter package name and app name')));
      return;
    }
    setState(() { _scanning = true; _scanResult = null; });
    final result = await _api.scanApp(packageName: pkg, appName: name);
    setState(() { _scanning = false; _scanResult = result; });
  }

  // One-tap scan of any installed app via AppMonitorService
  // ignore: unused_element
  Future<void> _scanInstalled(String packageName) async {
    final ev = await ref.read(appMonitorServiceProvider).analyzePackage(packageName);
    if (ev == null || !context.mounted) return;
    setState(() {
      _pkgCtrl.text  = ev.packageName;
      _nameCtrl.text = ev.appName;
    });
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clone / Fake App Detector'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Scan App'), Tab(text: 'History')],
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _scanTab(),
        _historyTab(),
      ]),
    );
  }

  // ── Scan tab ──────────────────────────────────────────────────────────────
  Widget _scanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _infoCard(),
        const SizedBox(height: 16),
        _inputCard(),
        const SizedBox(height: 16),
        if (_scanning) const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        if (_scanResult != null) _resultCard(_scanResult!),
      ]),
    );
  }

  Widget _infoCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
    ),
    child: const Row(children: [
      Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
      SizedBox(width: 10),
      Expanded(child: Text(
        'Enter the package name and app name of any installed app to check if it is a genuine app or a clone.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      )),
    ]),
  );

  Widget _inputCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      TextField(
        controller: _pkgCtrl,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: _inputDeco('Package Name', 'e.g. com.example.app', Icons.apps),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: _inputDeco('App Name', 'e.g. My Banking App', Icons.label),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _scanning ? null : _scan,
          icon: const Icon(Icons.search, color: Colors.black),
          label: const Text('Detect Clone',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );

  Widget _resultCard(CloneResult r) {
    final color = r.isClone
        ? AppTheme.errorColor
        : r.verdict == 'suspicious'
            ? AppTheme.warning
            : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Verdict header
        Row(children: [
          Icon(r.isClone ? Icons.dangerous : Icons.check_circle,
              color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.verdictLabel,
                  style: TextStyle(color: color, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              if (r.targetName != null)
                Text('Possibly impersonating: ${r.targetName}',
                    style: const TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // Score bars
        _scoreLine('Name similarity',    r.nameSimilarity,    color),
        const SizedBox(height: 8),
        _scoreLine('Package similarity', r.packageSimilarity, color),
        const SizedBox(height: 8),
        _scoreLine('Overall clone risk', r.overallScore,      color),
        // Signals
        if (r.signals.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Findings:',
              style: TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          ...r.signals.map((s) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(Icons.arrow_right, color: color, size: 16),
              Expanded(child: Text(s,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
            ]),
          )),
        ],
        // Actions
        if (r.isClone) ...[
          const SizedBox(height: 14),
          const Text('Recommended action:',
              style: TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor)),
                onPressed: () => _submitFeedback(r, true, 'uninstalled'),
                icon: const Icon(Icons.delete, color: AppTheme.errorColor, size: 16),
                label: const Text('Mark & Uninstall',
                    style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.textSecondary)),
                onPressed: () => _submitFeedback(r, false, 'ignored'),
                icon: const Icon(Icons.thumb_down_outlined,
                    color: AppTheme.textSecondary, size: 16),
                label: const Text('Not a Clone',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _scoreLine(String label, int value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
        Text('$value%', style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value / 100,
          minHeight: 6,
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ],
  );

  // ── History tab ───────────────────────────────────────────────────────────
  Widget _historyTab() {
    final histAV = ref.watch(_historyProvider);
    return histAV.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error:   (e, _) => Center(child: Text('Error: $e',
          style: const TextStyle(color: AppTheme.errorColor))),
      data:    (results) {
        if (results.isEmpty) {
          return const Center(child: Text('No scans yet',
              style: TextStyle(color: AppTheme.textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _historyItem(results[i]),
        );
      },
    );
  }

  Widget _historyItem(CloneResult r) {
    final color = r.isClone ? AppTheme.errorColor
        : r.verdict == 'suspicious' ? AppTheme.warning : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(r.isClone ? Icons.dangerous : Icons.shield, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.appName, style: const TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13)),
            Text(r.packageName, style: const TextStyle(color: AppTheme.textSecondary,
                fontSize: 10)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(r.verdictLabel,
                style: const TextStyle(color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text('${r.overallScore}% risk',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  InputDecoration _inputDeco(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText:  hint,
        prefixIcon: Icon(icon, color: AppTheme.accent, size: 20),
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        hintStyle:  const TextStyle(color: AppTheme.textSecondary),
        enabledBorder:  OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.accent)),
      );

  Future<void> _submitFeedback(
      CloneResult r, bool confirmed, String action) async {
    await _api.submitFeedback(
        reportId: r.id, userConfirmed: confirmed, actionTaken: action);
    ref.invalidate(_historyProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback recorded — thank you!')));
    }
  }
}

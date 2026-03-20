import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/security/app_risk_engine.dart';
import '../../../core/security/device_scanner_service.dart';
import '../scan_provider.dart';

// ────────────────────────────────────────────────────────────────────────────
// Filter options
// ────────────────────────────────────────────────────────────────────────────
enum _Filter { all, critical, high, medium, safe }

extension _FilterExt on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:      return 'All';
      case _Filter.critical: return 'Critical';
      case _Filter.high:     return 'High';
      case _Filter.medium:   return 'Medium';
      case _Filter.safe:     return 'Safe';
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────────────────
class ScanResultScreen extends ConsumerStatefulWidget {
  final ScanSummary summary;
  const ScanResultScreen({super.key, required this.summary});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  _Filter _filter = _Filter.all;

  List<AppRiskResult> get _filtered {
    final all = widget.summary.results;
    switch (_filter) {
      case _Filter.all:      return all..sort((a, b) => b.level.index.compareTo(a.level.index));
      case _Filter.critical: return all.where((r) => r.level == AppRiskLevel.critical).toList();
      case _Filter.high:     return all.where((r) => r.level == AppRiskLevel.high).toList();
      case _Filter.medium:   return all.where((r) => r.level == AppRiskLevel.medium).toList();
      case _Filter.safe:     return all.where((r) => r.level == AppRiskLevel.safe || r.level == AppRiskLevel.low).toList();
    }
  }

  void _proceed() {
    ref.read(deviceScanDoneProvider.notifier).state = true;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _buildHeader(s),

            // ── Summary cards ──────────────────────────────────────────────
            _buildSummaryRow(s),

            // ── Filter chips ───────────────────────────────────────────────
            _buildFilterRow(),

            // ── App list ───────────────────────────────────────────────────
            Expanded(child: _buildList()),

            // ── Bottom action ─────────────────────────────────────────────
            _buildBottomBar(s),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(ScanSummary s) {
    final icon  = s.hasHighRisk ? Icons.warning_amber_rounded : Icons.verified_rounded;
    final color = s.hasHighRisk ? AppTheme.warning : AppTheme.success;
    final title = s.hasHighRisk
        ? '${s.warningCount} Risk${s.warningCount == 1 ? '' : 's'} Found'
        : 'Device Looks Clean';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: const Color(0xFF2A3560))),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.totalScanned} apps scanned',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Summary row ────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(ScanSummary s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          _StatCard(count: s.criticalCount, label: 'Critical', color: AppTheme.errorColor),
          _StatCard(count: s.highCount,     label: 'High',     color: const Color(0xFFFF6D00)),
          _StatCard(count: s.mediumCount,   label: 'Medium',   color: AppTheme.warning),
          _StatCard(count: s.safeCount + s.lowCount, label: 'Safe', color: AppTheme.success),
        ],
      ),
    );
  }

  // ── Filter row ─────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _Filter.values.map((f) {
          final selected = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppTheme.accent : const Color(0xFF2A3560),
                ),
              ),
              child: Center(
                child: Text(
                  f.label,
                  style: TextStyle(
                    color: selected ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── App list ───────────────────────────────────────────────────────────────
  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No apps in this category',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: items.length,
      itemBuilder: (_, i) => _AppRiskCard(
        result: items[i],
        onUninstall: () => _confirmUninstall(items[i]),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(ScanSummary s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: const Color(0xFF2A3560))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.hasHighRisk)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'High-risk apps detected. We recommend removing them before continuing.',
                      style: TextStyle(
                          color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _proceed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                s.hasHighRisk ? 'Continue Anyway' : 'Continue to SecureShield',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    s.hasHighRisk ? AppTheme.warning : AppTheme.accent,
                foregroundColor: AppTheme.background,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Uninstall confirmation dialog ──────────────────────────────────────────
  Future<void> _confirmUninstall(AppRiskResult result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            const Text('Uninstall App'),
          ],
        ),
        content: Text(
          'Remove "${result.app.appName}"?\n\nThis will open your device\'s uninstall screen.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DeviceScannerService.uninstallApp(result.app.packageName);
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Stat card widget
// ────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatCard({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
              ),
            ],
          ),
        ),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Per-app risk card
// ────────────────────────────────────────────────────────────────────────────
class _AppRiskCard extends StatefulWidget {
  final AppRiskResult result;
  final VoidCallback onUninstall;

  const _AppRiskCard({required this.result, required this.onUninstall});

  @override
  State<_AppRiskCard> createState() => _AppRiskCardState();
}

class _AppRiskCardState extends State<_AppRiskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final app   = widget.result.app;
    final level = widget.result.level;
    final color = _levelColor(level);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // ── Main row ─────────────────────────────────────────────────
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: _AppAvatar(name: app.appName, color: color),
            title: Text(
              app.appName,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              app.packageName,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RiskBadge(level: level, color: color),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // ── Expanded details ─────────────────────────────────────────
          if (_expanded) _buildDetails(app, color),
        ],
      ),
    );
  }

  Widget _buildDetails(DeviceAppInfo app, Color color) {
    final reasons = widget.result.reasons;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0xFF2A3560)),

          // Risk reasons
          if (reasons.isNotEmpty) ...[
            const Text('Why flagged:',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_rounded, size: 13, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Meta info
          _MetaRow('Source',
              app.installer ?? 'Unknown (sideloaded)', Icons.store_rounded),
          _MetaRow('Data used',
              '${_formatBytes(app.rxBytes)} received', Icons.network_check),
          if (app.usesAccessibility)
            _MetaRow('Accessibility', 'Service enabled',
                Icons.accessibility_new, color: AppTheme.errorColor),
          if (app.hasOverlay)
            _MetaRow('Overlay', 'Draw-over-apps enabled',
                Icons.layers_rounded, color: AppTheme.warning),

          // Uninstall button
          if (widget.result.canUninstall) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onUninstall,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: BorderSide(color: AppTheme.errorColor.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Uninstall App',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _levelColor(AppRiskLevel level) => switch (level) {
        AppRiskLevel.critical => AppTheme.errorColor,
        AppRiskLevel.high     => const Color(0xFFFF6D00),
        AppRiskLevel.medium   => AppTheme.warning,
        AppRiskLevel.low      => const Color(0xFF69F0AE),
        AppRiskLevel.safe     => AppTheme.success,
      };

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ────────────────────────────────────────────────────────────────────────────
class _AppAvatar extends StatelessWidget {
  final String name;
  final Color color;
  const _AppAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 22,
        backgroundColor: color.withOpacity(0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
}

class _RiskBadge extends StatelessWidget {
  final AppRiskLevel level;
  final Color color;
  const _RiskBadge({required this.level, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          level.label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _MetaRow(this.label, this.value, this.icon, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color ?? AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text('$label: ',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: color ?? AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

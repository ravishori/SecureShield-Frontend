import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/risk_ui_tokens.dart';
import '../../../core/theme/theme_provider.dart' show themeProvider;
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

  AppRiskLevel? get level {
    switch (this) {
      case _Filter.all:      return null;
      case _Filter.critical: return AppRiskLevel.critical;
      case _Filter.high:     return AppRiskLevel.high;
      case _Filter.medium:   return AppRiskLevel.medium;
      case _Filter.safe:     return AppRiskLevel.safe;
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
      case _Filter.all:      return [...all]..sort((a, b) => b.level.index.compareTo(a.level.index));
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
    final themeType = ref.watch(themeProvider).themeType;
    final sizing = A11ySizing.forTheme(themeType);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(s, cs, sizing),
            _buildSummaryRow(s, sizing),
            _buildFilterRow(cs, sizing),
            Expanded(child: _buildList(cs, sizing)),
            _buildBottomBar(s, cs, sizing),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(ScanSummary s, ColorScheme cs, A11ySizing sizing) {
    // Use risk-level palette so the header colour matches the overall verdict.
    final hint = s.criticalCount > 0
        ? AppRiskLevel.critical
        : s.highCount > 0
            ? AppRiskLevel.high
            : s.mediumCount > 0
                ? AppRiskLevel.medium
                : AppRiskLevel.safe;
    final t = RiskUiTokens.of(context, hint);

    final icon  = s.hasHighRisk ? Icons.warning_amber_rounded : Icons.verified_rounded;
    final title = s.hasHighRisk
        ? '${s.warningCount} Risk${s.warningCount == 1 ? '' : 's'} Found'
        : 'Device Looks Clean';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20 * sizing.padScale, 20 * sizing.padScale,
        20 * sizing.padScale, 16 * sizing.padScale,
      ),
      decoration: BoxDecoration(
        color: t.cardBg,
        border: Border(bottom: BorderSide(
          color: t.cardBorder,
          width: 1.5 + sizing.extraBorder,
        )),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48 * sizing.textScale, color: t.iconFg),
          SizedBox(height: 8 * sizing.padScale),
          Text(
            title,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 20 * sizing.textScale,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * sizing.padScale),
          Text(
            '${s.totalScanned} apps scanned',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 13 * sizing.textScale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary row ────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(ScanSummary s, A11ySizing sizing) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 * sizing.padScale, 12 * sizing.padScale,
        12 * sizing.padScale, 4 * sizing.padScale,
      ),
      child: Row(
        children: [
          _StatCard(count: s.criticalCount, label: 'Critical',
                    level: AppRiskLevel.critical, sizing: sizing),
          SizedBox(width: 8 * sizing.padScale),
          _StatCard(count: s.highCount, label: 'High',
                    level: AppRiskLevel.high, sizing: sizing),
          SizedBox(width: 8 * sizing.padScale),
          _StatCard(count: s.mediumCount, label: 'Medium',
                    level: AppRiskLevel.medium, sizing: sizing),
          SizedBox(width: 8 * sizing.padScale),
          _StatCard(count: s.safeCount + s.lowCount, label: 'Safe',
                    level: AppRiskLevel.safe, sizing: sizing),
        ],
      ),
    );
  }

  // ── Filter row ─────────────────────────────────────────────────────────────
  Widget _buildFilterRow(ColorScheme cs, A11ySizing sizing) {
    return SizedBox(
      height: 50 * sizing.padScale,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12 * sizing.padScale),
        children: _Filter.values.map((f) {
          final selected = f == _filter;
          // Tinted chip in the filter's risk colour when selected
          final t = f.level != null
              ? RiskUiTokens.of(context, f.level!)
              : null;
          final bg = selected
              ? (t?.badgeBg ?? cs.primaryContainer)
              : cs.surface;
          final border = selected
              ? (t?.badgeBorder ?? cs.primary)
              : cs.outlineVariant;
          final fg = selected
              ? (t?.badgeText ?? cs.onPrimaryContainer)
              : cs.onSurfaceVariant;

          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                right: 8 * sizing.padScale,
                top: 6 * sizing.padScale,
                bottom: 6 * sizing.padScale,
              ),
              padding: EdgeInsets.symmetric(horizontal: 14 * sizing.padScale),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: border,
                  width: 1.5 + sizing.extraBorder,
                ),
              ),
              child: Center(
                child: Text(
                  f.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12 * sizing.textScale,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.2,
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
  Widget _buildList(ColorScheme cs, A11ySizing sizing) {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No apps in this category',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 14 * sizing.textScale,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        12 * sizing.padScale, 6 * sizing.padScale,
        12 * sizing.padScale, 8 * sizing.padScale,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _AppRiskCard(
        result: items[i],
        sizing: sizing,
        onUninstall: () => _confirmUninstall(items[i]),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(ScanSummary s, ColorScheme cs, A11ySizing sizing) {
    final warnToken = RiskUiTokens.of(context, AppRiskLevel.high);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * sizing.padScale),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(
          color: cs.outlineVariant,
          width: 1 + sizing.extraBorder,
        )),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.hasHighRisk)
            Container(
              margin: EdgeInsets.only(bottom: 10 * sizing.padScale),
              padding: EdgeInsets.all(10 * sizing.padScale),
              decoration: BoxDecoration(
                color: warnToken.badgeBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: warnToken.badgeBorder,
                  width: 1.5 + sizing.extraBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18 * sizing.textScale,
                      color: warnToken.badgeText),
                  SizedBox(width: 8 * sizing.padScale),
                  Expanded(
                    child: Text(
                      'High-risk apps detected. We recommend removing them before continuing.',
                      style: TextStyle(
                        color: warnToken.textPrimary,
                        fontSize: 12.5 * sizing.textScale,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: sizing.minTouchTarget,
            child: ElevatedButton.icon(
              onPressed: _proceed,
              icon: Icon(Icons.arrow_forward_rounded,
                  size: 18 * sizing.textScale),
              label: Text(
                s.hasHighRisk ? 'Continue Anyway' : 'Continue to SecureShield',
                style: TextStyle(
                  fontSize: 15 * sizing.textScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: s.hasHighRisk
                    ? warnToken.badgeBorder
                    : cs.primary,
                foregroundColor: s.hasHighRisk
                    ? Colors.white
                    : cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Uninstall confirmation dialog ──────────────────────────────────────────
  Future<void> _confirmUninstall(AppRiskResult result) async {
    final cs = Theme.of(context).colorScheme;
    final critToken = RiskUiTokens.of(context, AppRiskLevel.critical);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: critToken.badgeText),
            const SizedBox(width: 8),
            Text('Uninstall App', style: TextStyle(color: cs.onSurface)),
          ],
        ),
        content: Text(
          'Remove "${result.app.appName}"?\n\nThis will open your device\'s uninstall screen.',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: critToken.badgeBorder,
              foregroundColor: Colors.white,
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
// Stat card — adaptive risk-level styling
// ────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final AppRiskLevel level;
  final A11ySizing sizing;

  const _StatCard({
    required this.count,
    required this.label,
    required this.level,
    required this.sizing,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiskUiTokens.of(context, level);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12 * sizing.padScale),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: t.cardBorder,
            width: 1.5 + sizing.extraBorder,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: t.scoreText,
                fontSize: 22 * sizing.textScale,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            SizedBox(height: 4 * sizing.padScale),
            Text(
              label,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 11 * sizing.textScale,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Per-app risk card — adaptive, expandable
// ────────────────────────────────────────────────────────────────────────────
class _AppRiskCard extends StatefulWidget {
  final AppRiskResult result;
  final A11ySizing sizing;
  final VoidCallback onUninstall;

  const _AppRiskCard({
    required this.result,
    required this.sizing,
    required this.onUninstall,
  });

  @override
  State<_AppRiskCard> createState() => _AppRiskCardState();
}

class _AppRiskCardState extends State<_AppRiskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.result.app;
    final level = widget.result.level;
    final t = RiskUiTokens.of(context, level);
    final s = widget.sizing;

    return Padding(
      padding: EdgeInsets.only(bottom: 10 * s.padScale),
      child: Material(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: t.cardBorder,
              width: 1.5 + s.extraBorder,
            ),
          ),
          child: Column(
            children: [
              // ── Main row ───────────────────────────────────────────────
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: EdgeInsets.all(12 * s.padScale),
                  child: Row(
                    children: [
                      _AppAvatar(name: app.appName, tokens: t, sizing: s),
                      SizedBox(width: 12 * s.padScale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              app.appName,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5 * s.textScale,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3 * s.padScale),
                            Text(
                              app.packageName,
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 11.5 * s.textScale,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * s.padScale),
                      _RiskBadge(level: level, tokens: t, sizing: s),
                      SizedBox(width: 4 * s.padScale),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 22 * s.textScale,
                        color: t.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded details ───────────────────────────────────────
              if (_expanded) _buildDetails(app, t, s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(DeviceAppInfo app, RiskUiTokens t, A11ySizing s) {
    final reasons = widget.result.reasons;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14 * s.padScale, 0, 14 * s.padScale, 12 * s.padScale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: t.cardBorder, height: 1, thickness: 1),
          SizedBox(height: 10 * s.padScale),

          if (reasons.isNotEmpty) ...[
            Text(
              'Why flagged:',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 12 * s.textScale,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 6 * s.padScale),
            ...reasons.map((r) => Padding(
                  padding: EdgeInsets.only(bottom: 4 * s.padScale),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          size: 8 * s.textScale, color: t.iconFg),
                      SizedBox(width: 8 * s.padScale),
                      Expanded(
                        child: Text(
                          r,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 12.5 * s.textScale,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            SizedBox(height: 10 * s.padScale),
          ],

          _MetaRow('Source',
              app.installer ?? 'Unknown (sideloaded)',
              Icons.store_rounded, tokens: t, sizing: s),
          _MetaRow('Data used',
              '${_formatBytes(app.rxBytes)} received',
              Icons.network_check, tokens: t, sizing: s),
          if (app.usesAccessibility)
            _MetaRow('Accessibility', 'Service enabled',
                Icons.accessibility_new,
                tokens: t, sizing: s, emphasize: true),
          if (app.hasOverlay)
            _MetaRow('Overlay', 'Draw-over-apps enabled',
                Icons.layers_rounded,
                tokens: t, sizing: s, emphasize: true),

          if (widget.result.canUninstall) ...[
            SizedBox(height: 12 * s.padScale),
            SizedBox(
              width: double.infinity,
              height: s.minTouchTarget,
              child: OutlinedButton.icon(
                onPressed: widget.onUninstall,
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.badgeText,
                  side: BorderSide(
                    color: t.badgeBorder,
                    width: 1.5 + s.extraBorder,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12 * s.padScale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.delete_outline, size: 18 * s.textScale),
                label: Text(
                  'Uninstall App',
                  style: TextStyle(
                    fontSize: 13.5 * s.textScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
  final RiskUiTokens tokens;
  final A11ySizing sizing;
  const _AppAvatar({required this.name, required this.tokens, required this.sizing});

  @override
  Widget build(BuildContext context) => Container(
        width: 42 * sizing.textScale,
        height: 42 * sizing.textScale,
        decoration: BoxDecoration(
          color: tokens.iconBg,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.cardBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: tokens.iconFg,
            fontWeight: FontWeight.w800,
            fontSize: 17 * sizing.textScale,
          ),
        ),
      );
}

class _RiskBadge extends StatelessWidget {
  final AppRiskLevel level;
  final RiskUiTokens tokens;
  final A11ySizing sizing;
  const _RiskBadge({required this.level, required this.tokens, required this.sizing});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * sizing.padScale,
          vertical: 5 * sizing.padScale,
        ),
        decoration: BoxDecoration(
          color: tokens.badgeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tokens.badgeBorder,
            width: 1.5 + sizing.extraBorder,
          ),
        ),
        child: Text(
          level.label.toUpperCase(),
          style: TextStyle(
            color: tokens.badgeText,
            fontSize: 10 * sizing.textScale,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final RiskUiTokens tokens;
  final A11ySizing sizing;
  final bool emphasize;

  const _MetaRow(this.label, this.value, this.icon,
      {required this.tokens, required this.sizing, this.emphasize = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * sizing.padScale),
        child: Row(
          children: [
            Icon(icon,
                size: 14 * sizing.textScale,
                color: emphasize ? tokens.iconFg : tokens.textSecondary),
            SizedBox(width: 8 * sizing.padScale),
            Text('$label: ',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12 * sizing.textScale,
                  fontWeight: FontWeight.w500,
                )),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: emphasize ? tokens.iconFg : tokens.textPrimary,
                  fontSize: 12 * sizing.textScale,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

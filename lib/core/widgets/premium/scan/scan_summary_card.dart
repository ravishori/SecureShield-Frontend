import 'package:flutter/material.dart';

import '../count_up_number.dart';
import '../glass_card.dart';
import '../security_score_gauge.dart';

/// Rich post-scan security intelligence card, replacing the plain
/// "Scan complete" snackbar. Shows an overall Security Score gauge on the
/// left and a category breakdown grid on the right / below.
///
/// Reinforces SecureShield's value even when 0 threats are found — the
/// user sees what the scan actually inspected and can trust the result.
///
///   • Overall Device Security Score (0-100 gauge)
///   • Total apps scanned + scan duration
///   • Per-category tiles: Safe / Sensitive Permissions / Camera /
///     Microphone / Location / High-Risk
///
/// All numbers animate up via [CountUpNumber]. Theme-aware.
class ScanSummaryCard extends StatelessWidget {
  final ScanSummaryData data;
  final VoidCallback? onRescan;
  final VoidCallback? onViewDetails;

  const ScanSummaryCard({
    super.key,
    required this.data,
    this.onRescan,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final score = data.securityScore.clamp(0, 100);
    final scoreLabel = score >= 85 ? 'EXCELLENT'
                     : score >= 70 ? 'GOOD'
                     : score >= 50 ? 'FAIR' : 'AT RISK';
    final scoreColor = score >= 75 ? const Color(0xFF22C55E)
                     : score >= 50 ? const Color(0xFFF59E0B)
                     : const Color(0xFFEF4444);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: check icon + title + scan meta ────────────────────
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.verified_rounded, color: scoreColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan Complete',
                      style: t.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.totalApps} apps · ${_formatDuration(data.scanDuration)} · ${_formatTimeAgo(data.completedAt)}',
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Score + gauge row ──────────────────────────────────────────
          Row(
            children: [
              // Left: score label + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEVICE SECURITY SCORE',
                      style: t.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(scoreLabel,
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_scoreDescription(score.toInt()),
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110, height: 110,
                child: SecurityScoreGauge(
                  value: score.toDouble(),
                  label: scoreLabel,
                  icon: Icons.shield_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Divider ───────────────────────────────────────────────────
          Divider(color: scheme.outline, height: 1),
          const SizedBox(height: 16),

          Text('SECURITY INTELLIGENCE',
            style: t.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),

          // ── Category grid (3x2) ────────────────────────────────────────
          _CategoryGrid(data: data),
          const SizedBox(height: 14),

          // ── Actions ────────────────────────────────────────────────────
          if (onRescan != null || onViewDetails != null)
            Row(
              children: [
                if (onViewDetails != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const Text('View details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                if (onRescan != null && onViewDetails != null)
                  const SizedBox(width: 8),
                if (onRescan != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRescan,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Scan again'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _scoreDescription(int s) {
    if (s >= 85) return 'Your device is well protected. Keep it updated.';
    if (s >= 70) return 'Good posture. A few items are worth reviewing.';
    if (s >= 50) return 'Fair. Address the items below to raise your score.';
    return 'At risk. Take action on the flagged items immediately.';
  }

  static String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s scan';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s}s scan';
  }

  static String _formatTimeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data class the caller populates from real scan output. No coupling to
// the risk engine — feed it whatever numbers you have.
// ═══════════════════════════════════════════════════════════════════════════

class ScanSummaryData {
  final int totalApps;
  final int safeApps;
  final int highRiskApps;
  final int appsWithSensitivePerms;
  final int cameraApps;
  final int micApps;
  final int locationApps;
  final int securityScore; // 0-100
  final Duration scanDuration;
  final DateTime completedAt;

  const ScanSummaryData({
    required this.totalApps,
    required this.safeApps,
    required this.highRiskApps,
    required this.appsWithSensitivePerms,
    required this.cameraApps,
    required this.micApps,
    required this.locationApps,
    required this.securityScore,
    required this.scanDuration,
    required this.completedAt,
  });
}

class _CategoryGrid extends StatelessWidget {
  final ScanSummaryData data;
  const _CategoryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _CategoryTile.tile('Safe Apps', data.safeApps,
          Icons.verified_user_rounded, const Color(0xFF22C55E)),
      _CategoryTile.tile('High Risk', data.highRiskApps,
          Icons.gpp_bad_rounded, const Color(0xFFEF4444)),
      _CategoryTile.tile('Sensitive Perms', data.appsWithSensitivePerms,
          Icons.key_rounded, const Color(0xFFF59E0B)),
      _CategoryTile.tile('Camera Access', data.cameraApps,
          Icons.camera_alt_rounded, const Color(0xFF00C2FF)),
      _CategoryTile.tile('Microphone', data.micApps,
          Icons.mic_rounded, const Color(0xFF8B5CF6)),
      _CategoryTile.tile('Location', data.locationApps,
          Icons.location_on_rounded, const Color(0xFFEC4899)),
    ];

    return LayoutBuilder(
      builder: (context, cons) {
        // 3 columns on typical phones, 2 columns on very narrow.
        final cols = cons.maxWidth < 320 ? 2 : 3;
        const gap = 8.0;
        final tileW = (cons.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileW, child: tile),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _CategoryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  factory _CategoryTile.tile(String label, int value, IconData icon, Color color) =>
      _CategoryTile(label: label, value: value, icon: icon, color: color);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
              CountUpNumber(
                value: value,
                duration: const Duration(milliseconds: 900),
                style: t.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: t.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

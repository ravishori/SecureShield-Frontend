/// Compact banking-threat strip — designed for the home dashboard.
///
/// Hides itself when the report has no threats, so callers can drop it
/// into any layout without a conditional wrapping it. When threats are
/// present it renders a single-line attention-grabbing card that taps
/// through to the full Banking Protection screen.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/app_risk_engine.dart';
import '../../../core/security/banking_threat_correlator.dart';
import '../../../core/theme/risk_ui_tokens.dart';

class BankingThreatStrip extends StatelessWidget {
  final BankingThreatReport? report;
  final EdgeInsets margin;

  const BankingThreatStrip({
    super.key,
    required this.report,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final r = report;
    // No report yet (scan still in flight) OR no threats → render nothing.
    if (r == null || !r.hasThreats) return const SizedBox.shrink();

    final isCritical = r.level == BankingThreatLevel.critical;
    final level = isCritical ? AppRiskLevel.critical : AppRiskLevel.medium;
    final t = RiskUiTokens.of(context, level);

    final count = r.threats.length;
    final title = isCritical
        ? 'Stop! Banking is unsafe right now'
        : 'Banking risk detected';
    final subtitle = isCritical
        ? '$count active ${count == 1 ? "threat" : "threats"} can compromise '
            'your banking session. Tap to review.'
        : '$count ${count == 1 ? "item" : "items"} need attention before you '
            'open any banking app.';

    return Padding(
      padding: margin,
      child: Material(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        elevation: isCritical ? 4 : 1,
        shadowColor: isCritical ? t.cardBorder.withValues(alpha: 0.5) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/banking-protection'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.cardBorder, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Icon w/ pulsing halo for critical ──────────────────
                _PulsingIcon(
                  icon: isCritical
                      ? Icons.gpp_bad_rounded
                      : Icons.warning_amber_rounded,
                  color: t.iconFg,
                  enabled: isCritical,
                ),
                const SizedBox(width: 12),

                // ── Text column ─────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Severity pill + chevron ─────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.badgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: t.badgeBorder, width: 1.2),
                      ),
                      child: Text(
                        isCritical ? 'CRITICAL' : 'WARNING',
                        style: TextStyle(
                          color: t.badgeText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: t.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle pulsing wrapper around the alert icon — only animates when
/// [enabled] is true (critical tier). Reduces motion fatigue for
/// non-critical alerts.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.enabled,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.enabled) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing halo (only when critical + enabled)
          if (widget.enabled)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final scale = 1.0 + (_ctrl.value * 0.45);
                final opacity = (1.0 - _ctrl.value) * 0.5;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 1.5),
            ),
            child: Icon(widget.icon, color: widget.color, size: 18),
          ),
        ],
      ),
    );
  }
}

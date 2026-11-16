import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';
import 'count_up_number.dart';
import 'glass_card.dart';

/// The 3 metric cards displayed under the dashboard hero.
///
///   MetricCard(
///     icon: Icons.security_rounded,
///     label: 'Security Score',
///     value: 98,
///     suffix: '/100',
///     accent: SecurityStatusColors.safe,
///     trend: 4,
///   )
class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final num value;
  final String suffix;
  final Color accent;
  final num? trend;      // optional weekly delta shown as a small pill
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.suffix = '',
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: RadiusTokens.xl,
      glowColor: accent.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  borderRadius: RadiusTokens.mdBR,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.35),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
              if (trend != null) _TrendPill(delta: trend!),
            ],
          ),
          const SizedBox(height: 14),
          // FittedBox.scaleDown lets "100/100" collapse the sub-pixel amount
          // needed to fit inside the ~83dp column on narrow phones, without
          // us having to hand-tune the font size for every possible value.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUpNumber(
                value: value,
                suffix: '',
                style: t.headlineMedium?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  height: 1,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: t.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
            ],
            ),   // Row
          ),     // FittedBox
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(
              fontSize: 11.5,
              color: onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  final num delta;
  const _TrendPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final color = positive
        ? SecurityStatusColors.safe
        : SecurityStatusColors.critical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: RadiusTokens.pillBR,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(positive ? Icons.trending_up : Icons.trending_down,
              size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '${positive ? '+' : ''}$delta',
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

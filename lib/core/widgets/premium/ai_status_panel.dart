import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';
import 'glass_card.dart';

/// Compact "AI engine live" status card — sits somewhere below the hero
/// on the dashboard. Purely presentational.
///
///   AIStatusPanel(
///     monitoringCount: 84,
///     scanIntervalSeconds: 3,
///     lastThreatBlocked: '2 minutes ago',
///     definitionsUpdated: 'Today',
///   )
class AIStatusPanel extends StatelessWidget {
  final int monitoringCount;
  final int scanIntervalSeconds;
  final String lastThreatBlocked;
  final String definitionsUpdated;

  const AIStatusPanel({
    super.key,
    required this.monitoringCount,
    this.scanIntervalSeconds = 3,
    this.lastThreatBlocked = 'Never',
    this.definitionsUpdated = 'Today',
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      borderRadius: RadiusTokens.xl,
      glowColor: SecurityStatusColors.aiAccent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pulseBadge(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI ENGINE ACTIVE',
                      style: t.labelSmall?.copyWith(
                        color: SecurityStatusColors.aiAccent,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Monitoring $monitoringCount apps',
                      style: t.titleMedium?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SecurityStatusColors.aiAccent.withValues(alpha: 0.15),
                  borderRadius: RadiusTokens.pillBR,
                  border: Border.all(color: SecurityStatusColors.aiAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 12, color: SecurityStatusColors.aiAccent),
                    SizedBox(width: 4),
                    Text('REAL-TIME',
                      style: TextStyle(
                        color: SecurityStatusColors.aiAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Divider(color: Theme.of(context).colorScheme.outline, height: 1),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Expanded(
                child: _statRow(context, Icons.autorenew_rounded,
                    'Scan interval', 'Every ${scanIntervalSeconds}s'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statRow(context, Icons.gpp_good_rounded,
                    'Last blocked', lastThreatBlocked),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          _statRow(context, Icons.cloud_done_rounded, 'Definitions', definitionsUpdated),
        ],
      ),
    );
  }

  Widget _pulseBadge() {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SecurityStatusColors.aiAccent.withValues(alpha: 0.5),
            SecurityStatusColors.aiAccent.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(color: SecurityStatusColors.aiAccent.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: SecurityStatusColors.aiAccent.withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: -3,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 18),
    );
  }

  Widget _statRow(BuildContext context, IconData icon, String label, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 14, color: onSurface.withValues(alpha: 0.55)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

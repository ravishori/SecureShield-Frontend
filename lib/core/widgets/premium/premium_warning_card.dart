import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';
import 'glass_card.dart';

/// Premium amber warning card — used when a threat needs user action.
///
/// Layout:
///   ┌────────────────────────────────────┐
///   │  ⚠  RISK LEVEL  MEDIUM             │
///   │  Threat Category                   │
///   │  Recommended action …              │
///   │  ⏱ ~2 minutes           [Resolve →]│
///   └────────────────────────────────────┘
class PremiumWarningCard extends StatelessWidget {
  final WarningLevel level;
  final String category;
  final String recommendation;
  final String estimatedTime;
  final VoidCallback onResolve;

  const PremiumWarningCard({
    super.key,
    required this.level,
    required this.category,
    required this.recommendation,
    required this.onResolve,
    this.estimatedTime = '~2 min',
  });

  Color get _accent {
    switch (level) {
      case WarningLevel.info:     return SecurityStatusColors.info;
      case WarningLevel.warning:  return SecurityStatusColors.warning;
      case WarningLevel.critical: return SecurityStatusColors.critical;
    }
  }

  String get _label {
    switch (level) {
      case WarningLevel.info:     return 'INFO';
      case WarningLevel.warning:  return 'MEDIUM';
      case WarningLevel.critical: return 'HIGH';
    }
  }

  IconData get _icon {
    switch (level) {
      case WarningLevel.info:     return Icons.info_rounded;
      case WarningLevel.warning:  return Icons.warning_amber_rounded;
      case WarningLevel.critical: return Icons.gpp_bad_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      borderRadius: RadiusTokens.xl,
      glowColor: _accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: RadiusTokens.mdBR,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_accent.withValues(alpha: 0.4), _accent.withValues(alpha: 0.1)],
                  ),
                  border: Border.all(color: _accent.withValues(alpha: 0.5)),
                ),
                child: Icon(_icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text('RISK LEVEL',
                style: t.labelSmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.55),
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.20),
                  borderRadius: RadiusTokens.pillBR,
                  border: Border.all(color: _accent.withValues(alpha: 0.5)),
                ),
                child: Text(_label,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(category,
            style: t.titleMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(recommendation,
            style: t.bodySmall?.copyWith(
              color: onSurface.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: onSurface.withValues(alpha: 0.55)),
              const SizedBox(width: 4),
              Text(estimatedTime,
                style: t.labelSmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _ResolveButton(color: _accent, onTap: onResolve),
            ],
          ),
        ],
      ),
    );
  }
}

enum WarningLevel { info, warning, critical }

class _ResolveButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  const _ResolveButton({required this.color, required this.onTap});
  @override
  State<_ResolveButton> createState() => _ResolveButtonState();
}

class _ResolveButtonState extends State<_ResolveButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: MotionTokens.instant,
      curve: MotionTokens.press,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withValues(alpha: 0.75)],
            ),
            borderRadius: RadiusTokens.pillBR,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Resolve',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

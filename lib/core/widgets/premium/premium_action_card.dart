import 'package:flutter/material.dart';
import 'glass_card.dart';

/// Frosted-glass quick-action tile for the dashboard grid.
///
/// Layout:
///   ┌──────────────────┐
///   │  ●  icon         │  ← gradient icon chip, top-left
///   │                  │
///   │  Title           │  ← titleMedium
///   │  Subtitle        │  ← bodySmall
///   │              [→] │  ← optional CTA arrow, bottom-right
///   └──────────────────┘
///
/// Tapping calls [onTap]. Also supports a small [badge] chip (e.g. "AI", "NEW").
class PremiumActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
  final bool showArrow;

  const PremiumActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.showArrow = true,
  });

  @override
  State<PremiumActionCard> createState() => _PremiumActionCardState();
}

class _PremiumActionCardState extends State<PremiumActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          glowColor: widget.accent.withValues(alpha: 0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _IconChip(icon: widget.icon, color: widget.accent),
                  const Spacer(),
                  if (widget.badge != null)
                    _BadgePill(text: widget.badge!, color: widget.accent),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: t.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: t.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (widget.showArrow) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: widget.accent.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconChip({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.10)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String text;
  final Color color;
  const _BadgePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

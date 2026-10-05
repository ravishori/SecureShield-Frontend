import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';

/// Horizontal chip row of quick actions — sits above the feature grid.
/// Chips scale slightly on press and glow in their accent colour.
///
///   QuickActionChips(actions: [
///     QuickAction(Icons.radar_rounded, 'Scan Now', color, () => ...),
///     ...
///   ])
class QuickActionChips extends StatelessWidget {
  final List<QuickAction> actions;
  final EdgeInsets padding;

  const QuickActionChips({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.sm),
        itemBuilder: (context, i) => _QuickChip(action: actions[i]),
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const QuickAction(this.icon, this.label, this.color, this.onTap);
}

class _QuickChip extends StatefulWidget {
  final QuickAction action;
  const _QuickChip({required this.action});
  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: MotionTokens.instant,
      curve: MotionTokens.press,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: a.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            // On light themes: use a much subtler tint and no gradient (a
            // 20% purple gradient on white looks like a birthday balloon,
            // not enterprise UI).
            color: isDark ? null : a.color.withValues(alpha: 0.10),
            gradient: isDark
                ? LinearGradient(colors: [a.color.withValues(alpha: 0.20), a.color.withValues(alpha: 0.06)])
                : null,
            borderRadius: RadiusTokens.pillBR,
            border: Border.all(color: a.color.withValues(alpha: isDark ? 0.45 : 0.35), width: 1),
            // Colored glow only on dark themes.
            boxShadow: isDark
                ? [BoxShadow(color: a.color.withValues(alpha: 0.25), blurRadius: 14, spreadRadius: -6)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.icon, color: a.color, size: 15),
              const SizedBox(width: 6),
              Text(
                a.label,
                style: TextStyle(
                  color: isDark ? onSurface.withValues(alpha: 0.95) : onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

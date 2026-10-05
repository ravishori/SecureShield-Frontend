import 'package:flutter/material.dart';

/// Skeleton shimmer placeholder — used to replace CircularProgressIndicator
/// on dashboard and list screens. Pure Flutter, no external package.
///
/// Wrap a fixed-size Container with rounded corners:
///
///   const ShimmerBlock(width: 120, height: 20, radius: 6)
class ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Shimmer color depends on brightness: on dark, wash the panel with
    // low-opacity white; on light, dark neutral instead so it's visible.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06));
    final hi = widget.highlightColor ??
        (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.03));
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _ctrl.value, 0),
              end: Alignment(1 + 2 * _ctrl.value, 0),
              colors: [base, hi, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Reusable full-card skeleton for dashboard hero while data loads.
class DashboardHeroSkeleton extends StatelessWidget {
  const DashboardHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBlock(width: double.infinity, height: 220, radius: 22),
          const SizedBox(height: 16),
          const ShimmerBlock(width: 160, height: 18, radius: 6),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                child: const ShimmerBlock(width: 78, height: 72, radius: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

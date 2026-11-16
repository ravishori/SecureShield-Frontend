import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom circular progress ring used inside `ScanExperience`.
///
/// Different from `SecurityScoreGauge` — this one is designed for scans
/// in progress rather than a static score:
///   • Progress driven by external [progress] in [0..1]
///   • Center shows a large animated percentage
///   • Below the % — a small caption (e.g. "Scanning applications…")
///   • Two-tone stroke (base blue → cyan) with a **soft glow only on the
///     moving indicator arc**, never on the dim track
///   • Rounded stroke caps
///
/// Rebuilds only when [progress] changes, so it stays cheap even inside
/// an outer `AnimatedBuilder` driving the parent animation.
class AnimatedProgressRing extends StatelessWidget {
  /// Scan progress in [0..1]. Values outside are clamped.
  final double progress;

  /// Optional caption below the percentage. Empty = no caption.
  final String caption;

  /// Ring diameter in dp.
  final double size;

  /// Ring stroke thickness in dp.
  final double thickness;

  /// Gradient colours for the moving arc. Default = electric blue → cyan.
  final List<Color>? colors;

  const AnimatedProgressRing({
    super.key,
    required this.progress,
    this.caption = '',
    this.size = 160,
    this.thickness = 10,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final v = progress.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ringColors = colors ?? const [Color(0xFF00C2FF), Color(0xFF00E5FF)];

    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dim track — always full circle, never glows.
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: 1,
              thickness: thickness,
              gradientColors: [
                scheme.onSurface.withValues(alpha: 0.08),
                scheme.onSurface.withValues(alpha: 0.08),
              ],
            ),
          ),
          // Moving indicator arc — glow ONLY here.
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: 0, end: v),
            builder: (context, animated, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: animated,
                thickness: thickness,
                gradientColors: ringColors,
                glowColor: ringColors.last,
              ),
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Big animated percentage — TweenAnimationBuilder gives smooth
              // interpolation from the previous value to the new one.
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                tween: Tween<double>(begin: 0, end: v * 100),
                builder: (context, val, _) => Text(
                  '${val.round()}',
                  style: t.headlineLarge?.copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text('%',
                style: t.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final double thickness;
  final List<Color> gradientColors;
  final Color? glowColor;

  _RingPainter({
    required this.progress,
    required this.thickness,
    required this.gradientColors,
    this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final arc = 2 * math.pi * progress;

    // Optional soft glow underneath the arc — draws first so the crisp arc
    // sits on top. Very subtle so it doesn't smear on light backgrounds.
    if (glowColor != null && progress > 0.005) {
      final glow = Paint()
        ..color = glowColor!.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        arc,
        false,
        glow,
      );
    }

    final stroke = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: gradientColors.length == 1
            ? [gradientColors.first, gradientColors.first]
            : gradientColors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      arc,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.thickness != thickness ||
      old.glowColor != glowColor;
}

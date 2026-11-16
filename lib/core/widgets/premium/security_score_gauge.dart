import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Circular animated security-score gauge (0-100).
///
///   • Sweep animates from 0 to [value] on first build and on value changes
///   • Colour ramps green → amber → red based on score
///   • Two concentric arcs: dim track underneath, coloured fill on top
///   • Center label + optional trend indicator
///
/// Sized by whatever constraints the parent gives; give it a fixed
/// `SizedBox(width: 180, height: 180)` for the dashboard hero.
class SecurityScoreGauge extends StatefulWidget {
  final double value;          // 0..100
  final String? label;         // e.g. "PROTECTED"
  final IconData? icon;        // shown above the score number
  final double thickness;      // stroke thickness
  final Duration duration;
  final double? trend;         // +/- delta from last week (nullable)

  const SecurityScoreGauge({
    super.key,
    required this.value,
    this.label,
    this.icon,
    this.thickness = 12,
    this.duration = const Duration(milliseconds: 1200),
    this.trend,
  });

  @override
  State<SecurityScoreGauge> createState() => _SecurityScoreGaugeState();
}

class _SecurityScoreGaugeState extends State<SecurityScoreGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value.clamp(0, 100))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant SecurityScoreGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _anim.value;
      _anim = Tween<double>(begin: _from, end: widget.value.clamp(0, 100))
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorFor(double v) {
    if (v >= 75) return const Color(0xFF22C55E); // success
    if (v >= 50) return const Color(0xFF00C2FF); // electric blue
    if (v >= 30) return const Color(0xFFF59E0B); // warning
    return const Color(0xFFEF4444);              // danger
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        final color = _colorFor(v);
        // Track colour needs to be visible on both dark AND light bg.
        final trackColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.08);
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, constraints.maxHeight);
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dim background track — theme-aware for contrast
                  CustomPaint(
                    size: Size.square(size),
                    painter: _RingPainter(
                      progress: 1,
                      color: trackColor,
                      thickness: widget.thickness,
                    ),
                  ),
                  // Animated fill
                  CustomPaint(
                    size: Size.square(size),
                    painter: _RingPainter(
                      progress: v / 100,
                      color: color,
                      thickness: widget.thickness,
                      glow: color.withValues(alpha: 0.5),
                    ),
                  ),
                  // Center content
                  _CenterLabel(
                    value: v,
                    label: widget.label,
                    icon: widget.icon,
                    color: color,
                    trend: widget.trend,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CenterLabel extends StatelessWidget {
  final double value;
  final String? label;
  final IconData? icon;
  final Color color;
  final double? trend;
  const _CenterLabel({
    required this.value,
    required this.color,
    this.label,
    this.icon,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Padding keeps the label off the ring stroke; FittedBox lets the whole
    // stack shrink proportionally when the gauge is small (as small as ~96dp
    // on narrow phones) instead of triggering a 3-4 px vertical overflow.
    return Padding(
      padding: const EdgeInsets.all(6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, color: color, size: 22),
        Text(
          value.toStringAsFixed(0),
          style: t.headlineLarge?.copyWith(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: onSurface,
            height: 1,
          ),
        ),
        Text('/ 100',
            style: t.labelSmall?.copyWith(
              color: onSurface.withValues(alpha: 0.55),
              letterSpacing: 1.2,
            )),
        if (label != null) ...[
          const SizedBox(height: 2),
          Text(label!,
              style: t.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 11,
              )),
        ],
        if (trend != null) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 12,
                  color: trend! >= 0
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444)),
              const SizedBox(width: 3),
              Text('${trend! >= 0 ? '+' : ''}${trend!.toStringAsFixed(0)}',
                  style: t.labelSmall?.copyWith(
                    color: trend! >= 0
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ],
      ],
        ),   // Column
      ),     // FittedBox
    );       // Padding
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color? glow;
  final double thickness;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.thickness,
    this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - thickness) / 2;

    // Optional soft glow underneath the arc
    if (glow != null && progress > 0) {
      final glowPaint = Paint()
        ..color = glow!
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        glowPaint,
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.thickness != thickness;
}

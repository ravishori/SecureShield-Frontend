import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Very subtle faint digital grid that slowly drifts — placed behind the
/// dashboard content to add depth without competing.
///
///   Stack(children: [
///     const AnimatedGridBackground(),  // fills the whole thing
///     ... your content ...
///   ])
class AnimatedGridBackground extends StatefulWidget {
  final Color lineColor;
  final double cellSize;
  final double opacity;

  const AnimatedGridBackground({
    super.key,
    this.lineColor = const Color(0xFF00C2FF),
    this.cellSize = 42,
    this.opacity = 0.04,
  });

  @override
  State<AnimatedGridBackground> createState() => _AnimatedGridBackgroundState();
}

class _AnimatedGridBackgroundState extends State<AnimatedGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enterprise light themes (Microsoft 365 Admin, Google Workspace Admin,
    // ServiceNow, Salesforce) NEVER decorate their canvas. A drifting grid
    // on white looks like cheap wallpaper, not enterprise software.
    if (Theme.of(context).brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _GridPainter(
              t: _ctrl.value,
              color: widget.lineColor.withValues(alpha: widget.opacity),
              cellSize: widget.cellSize,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double t;         // 0..1
  final Color color;
  final double cellSize;

  _GridPainter({required this.t, required this.color, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;

    // Slow drift diagonally — makes the grid feel alive without being distracting.
    final drift = t * cellSize;

    // Vertical lines
    for (double x = -cellSize + drift; x <= size.width + cellSize; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = -cellSize + drift; y <= size.height + cellSize; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Sparse dot accents at intersections — one every ~7 cells
    final dotPaint = Paint()..color = color.withValues(alpha: 0.6);
    for (double x = -cellSize + drift; x <= size.width + cellSize; x += cellSize) {
      for (double y = -cellSize + drift; y <= size.height + cellSize; y += cellSize) {
        // Pseudo-random using stable hash of grid cell coords
        final h = (x.round() * 73856093) ^ (y.round() * 19349663);
        if ((h.abs() % 47) == 0) {
          canvas.drawCircle(
            Offset(x, y),
            0.9 + 0.4 * math.sin(t * math.pi * 2 + h),
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.t != t || old.color != color || old.cellSize != cellSize;
}

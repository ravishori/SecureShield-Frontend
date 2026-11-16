import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pulsing AI security shield with soft radial glow.
///
///   • [protected] = true  → cyan/green calm pulse
///   • [protected] = false → red urgent pulse
/// The shield gently scales, and 2 concentric rings expand outward like sonar.
class AnimatedShield extends StatefulWidget {
  final double size;
  final bool protected;
  final IconData icon;

  const AnimatedShield({
    super.key,
    this.size = 96,
    this.protected = true,
    this.icon = Icons.shield_rounded,
  });

  @override
  State<AnimatedShield> createState() => _AnimatedShieldState();
}

class _AnimatedShieldState extends State<AnimatedShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color => widget.protected
      ? const Color(0xFF00E5FF)
      : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Two expanding sonar rings, offset by half a cycle
              _sonarRing(_ctrl.value),
              _sonarRing((_ctrl.value + 0.5) % 1.0),
              // The shield itself, gently breathing
              Transform.scale(
                scale: 1 + 0.04 * math.sin(_ctrl.value * math.pi * 2),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _color.withValues(alpha: 0.25),
                        _color.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.4),
                        blurRadius: 36,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    color: _color,
                    size: widget.size * 0.55,
                    shadows: [
                      Shadow(color: _color.withValues(alpha: 0.7), blurRadius: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sonarRing(double t) {
    // t ∈ [0,1] — scale from 0.9 → 1.55, opacity 0.5 → 0
    final scale = 0.9 + t * 0.65;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.5;
    return Opacity(
      opacity: opacity,
      child: Container(
        width: widget.size * scale,
        height: widget.size * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _color, width: 1.2),
        ),
      ),
    );
  }
}

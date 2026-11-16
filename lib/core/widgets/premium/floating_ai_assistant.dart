import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Persistent bottom-right AI orb. Circular, purple/blue gradient,
/// gently pulses. Tap opens the AI Coach.
///
/// Overlay this on top of the ShellRoute — sits above the bottom nav.
class FloatingAIAssistant extends StatefulWidget {
  final VoidCallback onTap;
  final String greeting;

  const FloatingAIAssistant({
    super.key,
    required this.onTap,
    this.greeting = 'How can I help protect you today?',
  });

  @override
  State<FloatingAIAssistant> createState() => _FloatingAIAssistantState();
}

class _FloatingAIAssistantState extends State<FloatingAIAssistant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressed = false;

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Breath scale 1.0 ± 0.06
        final scale = (_pressed ? 0.92 : 1) +
            0.06 * math.sin(t * math.pi * 2);
        return Semantics(
          label: 'AI security assistant',
          button: true,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: Transform.scale(
              scale: scale,
              child: _orb(t),
            ),
          ),
        );
      },
    );
  }

  Widget _orb(double t) {
    return SizedBox(
      width: 76, height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sonar ring
          Opacity(
            opacity: (1 - t) * 0.55,
            child: Container(
              width: 40 + t * 44,
              height: 40 + t * 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF8B5CF6),
                  width: 1.4,
                ),
              ),
            ),
          ),
          // The orb itself
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00C2FF), Color(0xFF8B5CF6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                  blurRadius: 26,
                  spreadRadius: -3,
                ),
                BoxShadow(
                  color: const Color(0xFF00C2FF).withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner highlight
                Positioned(
                  top: 8,
                  left: 12,
                  child: Container(
                    width: 22, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

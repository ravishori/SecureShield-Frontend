import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';

/// Rotates through a list of AI-status phrases with a fade+slide transition.
/// Sits below the hero title to convey "the engine is doing something right now".
///
///   RotatingStatusText(items: [
///     StatusPhrase(Icons.radar_rounded, 'AI Monitoring Device'),
///     StatusPhrase(Icons.wifi_rounded,  'Scanning Network'),
///     ...
///   ])
class RotatingStatusText extends StatefulWidget {
  final List<StatusPhrase> items;
  final Duration interval;
  final TextStyle? textStyle;

  const RotatingStatusText({
    super.key,
    required this.items,
    this.interval = const Duration(seconds: 3),
    this.textStyle,
  });

  @override
  State<RotatingStatusText> createState() => _RotatingStatusTextState();
}

class _RotatingStatusTextState extends State<RotatingStatusText> {
  int _idx = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    Future.delayed(widget.interval, () {
      if (_disposed || !mounted || widget.items.length < 2) return;
      setState(() => _idx = (_idx + 1) % widget.items.length);
      _schedule();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final current = widget.items[_idx];
    // Text color derived from the current theme so it stays legible on both
    // dark navy and light corporate surfaces.
    final style = widget.textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            );

    return AnimatedSwitcher(
      duration: MotionTokens.normal,
      switchInCurve: MotionTokens.enter,
      switchOutCurve: MotionTokens.exit,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Row(
        key: ValueKey(_idx),
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing dot next to the icon — signals "live"
          _PulseDot(color: current.color),
          const SizedBox(width: 8),
          Icon(current.icon, color: current.color, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              current.text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPhrase {
  final IconData icon;
  final String text;
  final Color color;
  const StatusPhrase(
    this.icon,
    this.text, {
    this.color = const Color(0xFF00E5FF),
  });
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
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
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 + 0.4 * t),
                blurRadius: 6 + 6 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';

/// Animated number counter — counts from 0 (or [from]) up to [value] on
/// first build, then smoothly re-animates whenever [value] changes.
///
///   CountUpNumber(value: 127, style: t.headlineMedium)
class CountUpNumber extends StatefulWidget {
  final num value;
  final num from;
  final Duration duration;
  final TextStyle? style;
  final String suffix;
  final String prefix;
  final int decimals;

  const CountUpNumber({
    super.key,
    required this.value,
    this.from = 0,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.suffix = '',
    this.prefix = '',
    this.decimals = 0,
  });

  @override
  State<CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<CountUpNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.from.toDouble();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: _from, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: MotionTokens.enter));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant CountUpNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _anim.value;
      _anim = Tween<double>(begin: _from, end: widget.value.toDouble())
          .animate(CurvedAnimation(parent: _ctrl, curve: MotionTokens.enter));
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Text(
          '${widget.prefix}${_anim.value.toStringAsFixed(widget.decimals)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

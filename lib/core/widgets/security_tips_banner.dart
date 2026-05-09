import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/security_tips.dart';
import '../theme.dart';

/// Animated rotating security awareness banner.
///
/// Picks a random tip on mount, then rotates through the full list in random
/// order every [interval] seconds with a smooth fade + slide animation.
class SecurityTipsBanner extends StatefulWidget {
  /// How long each tip is displayed (default 7 seconds).
  final Duration interval;

  const SecurityTipsBanner({
    super.key,
    this.interval = const Duration(seconds: 7),
  });

  @override
  State<SecurityTipsBanner> createState() => _SecurityTipsBannerState();
}

class _SecurityTipsBannerState extends State<SecurityTipsBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  late Timer   _timer;
  late List<int> _indices;  // shuffled order
  int _pos = 0;

  (String, String) get _currentTip => kSecurityTips[_indices[_pos]];

  void _buildShuffledList() {
    final rng = Random();
    _indices = List.generate(kSecurityTips.length, (i) => i)
      ..shuffle(rng);
  }

  @override
  void initState() {
    super.initState();
    _buildShuffledList();
    // Start from a random position
    _pos = Random().nextInt(_indices.length);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    _timer = Timer.periodic(widget.interval, (_) => _nextTip());
  }

  Future<void> _nextTip() async {
    await _ctrl.reverse();
    if (!mounted) return;
    setState(() {
      _pos = (_pos + 1) % _indices.length;
      // Reshuffle when we complete one full cycle
      if (_pos == 0) _buildShuffledList();
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _timer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent  = AppTheme.accentOf(context);
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final tip     = _currentTip;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Emoji circle
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(tip.$1, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SECURITY TIP',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tip.$2,
                        style: TextStyle(
                          color: onSurf.withOpacity(0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 16, color: accent.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

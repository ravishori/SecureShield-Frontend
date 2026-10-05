import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';

/// Horizontal auto-scrolling "live security intelligence" feed —
/// small pills showing what the AI has confirmed in the last minute.
///
///   LiveActivityFeed(items: [
///     LiveActivity('Malware database updated', Icons.shield_moon_rounded),
///     LiveActivity('Banking shield enabled',    Icons.account_balance_rounded),
///     ...
///   ])
///
/// Items fade-in one-by-one, then the strip is scrollable by touch.
class LiveActivityFeed extends StatefulWidget {
  final List<LiveActivity> items;
  final Duration cascadeDelay;

  const LiveActivityFeed({
    super.key,
    required this.items,
    this.cascadeDelay = const Duration(milliseconds: 120),
  });

  @override
  State<LiveActivityFeed> createState() => _LiveActivityFeedState();
}

class _LiveActivityFeedState extends State<LiveActivityFeed> {
  int _visibleCount = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _cascade();
  }

  void _cascade() async {
    for (var i = 0; i < widget.items.length; i++) {
      if (_disposed || !mounted) return;
      await Future.delayed(widget.cascadeDelay);
      if (_disposed || !mounted) return;
      setState(() => _visibleCount = i + 1);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.sm),
        itemBuilder: (context, i) {
          final visible = i < _visibleCount;
          return AnimatedOpacity(
            duration: MotionTokens.normal,
            curve: MotionTokens.enter,
            opacity: visible ? 1 : 0,
            child: AnimatedSlide(
              duration: MotionTokens.normal,
              curve: MotionTokens.enter,
              offset: visible ? Offset.zero : const Offset(0, 0.3),
              child: _ActivityPill(item: widget.items[i]),
            ),
          );
        },
      ),
    );
  }
}

class LiveActivity {
  final String text;
  final IconData icon;
  final Color color;
  const LiveActivity(
    this.text,
    this.icon, {
    this.color = const Color(0xFF22C55E), // default: emerald (success/check)
  });
}

class _ActivityPill extends StatelessWidget {
  final LiveActivity item;
  const _ActivityPill({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: isDark ? 0.10 : 0.08),
        borderRadius: RadiusTokens.pillBR,
        border: Border.all(color: item.color.withValues(alpha: isDark ? 0.30 : 0.35), width: 1),
        // No colored glow on light themes — user requirement.
        boxShadow: isDark
            ? [BoxShadow(color: item.color.withValues(alpha: 0.20), blurRadius: 12, spreadRadius: -6)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 12, color: item.color),
          ),
          const SizedBox(width: 6),
          Text(
            item.text,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 4),
          Icon(item.icon, size: 12, color: item.color.withValues(alpha: 0.75)),
        ],
      ),
    );
  }
}

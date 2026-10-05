import 'package:flutter/material.dart';
import 'glass_card.dart';

/// Continuously-scrolling live threat ticker for the dashboard.
///
/// Autoplays through the provided [items] left-to-right at a slow, readable
/// cadence. Each item is a short headline like:
///   "🇮🇳 CERT-In: Fake KYC SMS campaign impersonating SBI"
///
/// This is presentation-only — feed it whatever the parent has fetched.
/// Pass `items: []` and it renders nothing.
class ThreatTicker extends StatefulWidget {
  final List<ThreatTickerItem> items;
  final Duration itemDuration; // how long each headline stays fully visible

  const ThreatTicker({
    super.key,
    required this.items,
    this.itemDuration = const Duration(seconds: 5),
  });

  @override
  State<ThreatTicker> createState() => _ThreatTickerState();
}

class _ThreatTickerState extends State<ThreatTicker> {
  final _controller = PageController();
  int _idx = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(widget.itemDuration, () {
      if (_disposed || !mounted || widget.items.length < 2) return;
      _idx = (_idx + 1) % widget.items.length;
      _controller.animateToPage(
        _idx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
      );
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      borderRadius: 18,
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            const SizedBox(width: 14),
            _LivePill(),
            const SizedBox(width: 12),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: widget.items.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, i) {
                  final it = widget.items[i];
                  return Row(
                    children: [
                      Icon(it.icon, size: 16, color: it.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          it.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class ThreatTickerItem {
  final String text;
  final IconData icon;
  final Color color;
  const ThreatTickerItem({
    required this.text,
    this.icon = Icons.campaign_rounded,
    this.color = const Color(0xFFF59E0B),
  });
}

class _LivePill extends StatefulWidget {
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: const Icon(Icons.circle,
                size: 8, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

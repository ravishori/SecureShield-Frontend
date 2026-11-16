import 'package:flutter/material.dart';

/// Compact checklist that reveals scan stages one by one as the parent
/// scan progresses. The current stage animates in with a fade+slide;
/// previous stages remain visible with a filled ✓; upcoming stages are
/// dimmed. The last 4 completed stages stay on screen so the UI has
/// history — that's what makes it feel like a real scanner and not a
/// single spinning label.
///
/// Feed it the whole [stages] list once at construction time, then update
/// [currentIndex] as the scan progresses. Rebuilds are cheap (only the
/// rendered rows change; the list itself is const at the call site).
class ScanStageTicker extends StatelessWidget {
  /// All scan stages in order. Displayed via [currentIndex].
  final List<String> stages;

  /// Index of the stage currently in progress. Stages < [currentIndex] are
  /// shown as completed (✓ filled). Stage == [currentIndex] is highlighted.
  /// Clamped to [0..stages.length - 1].
  final int currentIndex;

  /// How many previously completed stages to show above the active one.
  /// Defaults to 3 so the ticker stays compact.
  final int historyDepth;

  /// Optional accent color for the active row. Defaults to `secondary`.
  final Color? accent;

  const ScanStageTicker({
    super.key,
    required this.stages,
    required this.currentIndex,
    this.historyDepth = 3,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final idx = currentIndex.clamp(0, stages.length - 1);
    final acc = accent ?? scheme.secondary;

    final start = (idx - historyDepth).clamp(0, stages.length);
    final visible = stages.sublist(start, idx + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++)
          _StageRow(
            key: ValueKey('stage-${start + i}'),
            text: visible[i],
            isActive: i == visible.length - 1,
            accent: acc,
            onSurface: scheme.onSurface,
            textStyle: t.bodyMedium,
          ),
      ],
    );
  }
}

class _StageRow extends StatefulWidget {
  final String text;
  final bool isActive;
  final Color accent;
  final Color onSurface;
  final TextStyle? textStyle;

  const _StageRow({
    super.key,
    required this.text,
    required this.isActive,
    required this.accent,
    required this.onSurface,
    this.textStyle,
  });

  @override
  State<_StageRow> createState() => _StageRowState();
}

class _StageRowState extends State<_StageRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = !widget.isActive;
    final iconBg = widget.isActive
        ? widget.accent.withValues(alpha: 0.16)
        : widget.accent.withValues(alpha: 0.10);
    final iconFg = widget.accent;
    final textColor = widget.isActive
        ? widget.onSurface
        : widget.onSurface.withValues(alpha: 0.55);
    final weight = widget.isActive ? FontWeight.w600 : FontWeight.w500;

    return FadeTransition(
      opacity: _in,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _in, curve: Curves.easeOut)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // ✓ chip — filled when done, hollow-ish when active
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: iconFg, width: 1),
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 12, color: iconFg)
                    : _ActiveDot(color: iconFg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.textStyle?.copyWith(
                    color: textColor,
                    fontWeight: weight,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny pulsing dot used inside the active stage's circle.
class _ActiveDot extends StatefulWidget {
  final Color color;
  const _ActiveDot({required this.color});
  @override
  State<_ActiveDot> createState() => _ActiveDotState();
}

class _ActiveDotState extends State<_ActiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

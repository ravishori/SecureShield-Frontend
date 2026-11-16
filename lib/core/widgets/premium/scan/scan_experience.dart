import 'dart:async';
import 'package:flutter/material.dart';

import '../animated_shield.dart';
import '../glass_card.dart';
import 'animated_progress_ring.dart';
import 'scan_stage_ticker.dart';

/// The scripted multi-stage scanning experience shown while `Scan All Apps`
/// runs. Modeled after Microsoft Defender / Bitdefender / CrowdStrike.
///
///   • Animated shield with rotating radar (top-left)
///   • Custom AnimatedProgressRing (center)
///   • Rotating floating status message (below ring)
///   • Stage ticker checklist with the last 4 stages (fades between them)
///   • 4 live counters — Apps Scanned / Threats / Perms / Risky APIs
///
/// Timing model — this is the key to making the perceived experience feel
/// premium and never abrupt:
///
///   1. The real scan work runs in the background as soon as the widget
///      mounts (via the supplied `scanFuture`).
///   2. A separate animation clock drives visible progress 0 → 92% over
///      [minDuration]. This gives the user constant feedback even if the
///      real scan is a fast native call.
///   3. When BOTH the real scan has completed AND the animation has
///      reached ≥ 92%, we smoothly interpolate to 100% (in ~500 ms) and
///      fire [onComplete] with the [result] the future produced.
///   4. If the real scan takes LONGER than [minDuration], we hold at 92%
///      and wait; the moment the scan completes we finish the ring.
///
/// This decoupling guarantees:
///   • Fast scans still feel like an AI scan (not instant → complete).
///   • Slow scans never leave the user staring at a full ring while work
///     is still happening.
///   • Failure surfaces cleanly — if `scanFuture` throws, [onError] fires
///     with the exception and this widget stops animating.
class ScanExperience<T> extends StatefulWidget {
  /// Kick off + await the real scan. Fired ONCE when this widget mounts.
  final Future<T> Function() scanFuture;

  /// Called after the animation completes to 100%.
  final void Function(T result) onComplete;

  /// Called if `scanFuture` throws. Widget stops animating.
  final void Function(Object error, StackTrace stack)? onError;

  /// The scripted stages shown in the ticker.
  final List<String> stages;

  /// Rotating floating status messages (bigger tagline below the ring).
  final List<String> floatingMessages;

  /// Provider for the live counters. Called every ~120 ms as the animation
  /// progresses; return whatever values you want to show for each frame.
  final ScanCounters Function(double progress) countersFor;

  /// Minimum animation duration for the scripted experience.
  final Duration minDuration;

  const ScanExperience({
    super.key,
    required this.scanFuture,
    required this.onComplete,
    required this.stages,
    required this.floatingMessages,
    required this.countersFor,
    this.onError,
    this.minDuration = const Duration(milliseconds: 4200),
  });

  @override
  State<ScanExperience<T>> createState() => _ScanExperienceState<T>();
}

class _ScanExperienceState<T> extends State<ScanExperience<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  T? _realResult;
  bool _finished = false;
  int _msgIdx = 0;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();

    // Scripted animation runs 0 → 0.92 over minDuration, then holds.
    _anim = AnimationController(vsync: this, duration: widget.minDuration)
      ..addListener(() {
        setState(() {}); // for counters + stage index
        if (_anim.value >= 0.92 && _realResult != null && !_finished) {
          _finishToHundred();
        }
      });

    // Rotate floating status messages every 2.4 s.
    _msgTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted || widget.floatingMessages.isEmpty) return;
      setState(() {
        _msgIdx = (_msgIdx + 1) % widget.floatingMessages.length;
      });
    });

    // Fire off the real scan in parallel.
    widget.scanFuture().then((result) {
      if (!mounted) return;
      _realResult = result;
      if (_anim.value >= 0.92 && !_finished) {
        _finishToHundred();
      }
    }).catchError((e, s) {
      if (!mounted) return;
      widget.onError?.call(e, s as StackTrace);
      _anim.stop();
    });

    _anim.animateTo(0.92, curve: Curves.easeInOutCubic);
  }

  Future<void> _finishToHundred() async {
    _finished = true;
    _msgTimer?.cancel();
    // 500 ms smooth glide to 100%.
    await _anim.animateTo(1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic);
    // Brief hold on 100% before handing off.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || _realResult == null) return;
    widget.onComplete(_realResult as T);
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final progress = _anim.value;
    final counters = widget.countersFor(progress);
    final stageIdx =
        (progress * (widget.stages.length - 1)).round().clamp(0, widget.stages.length - 1);
    final currentMsg = widget.floatingMessages.isEmpty
        ? ''
        : widget.floatingMessages[_msgIdx];

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top row: shield + title/subtitle ────────────────────────────
          Row(
            children: [
              const SizedBox(
                width: 74, height: 74,
                child: AnimatedShield(size: 44, icon: Icons.shield_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: scheme.secondary.withValues(alpha: 0.40)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 12, color: scheme.secondary),
                              const SizedBox(width: 3),
                              Text('AI SECURITY SCAN',
                                style: TextStyle(
                                  color: scheme.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Inspecting device applications',
                      style: t.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Advanced threat inspection in progress',
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Progress ring ────────────────────────────────────────────────
          Center(
            child: AnimatedProgressRing(
              progress: progress,
              caption: currentMsg,
              size: 168,
              thickness: 10,
              colors: [scheme.primary, scheme.secondary],
            ),
          ),
          const SizedBox(height: 20),

          // ── Live counter grid ────────────────────────────────────────────
          _CountersRow(counters: counters),
          const SizedBox(height: 18),

          // ── Stage checklist ──────────────────────────────────────────────
          ScanStageTicker(
            stages: widget.stages,
            currentIndex: stageIdx,
            accent: scheme.secondary,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Live counters — value + label pair rendered inside a subtle bordered box.
// Uses TweenAnimationBuilder for smooth number interpolation between frames.
// ═══════════════════════════════════════════════════════════════════════════

/// The 4 counter values shown live during scan. Consumers compute these
/// from the current `progress` (0..1) so they ramp up as the ring fills.
class ScanCounters {
  final int appsScanned;
  final int totalApps;
  final int threatsFound;
  final int permissionsChecked;
  final int riskyApis;

  const ScanCounters({
    required this.appsScanned,
    required this.totalApps,
    required this.threatsFound,
    required this.permissionsChecked,
    required this.riskyApis,
  });
}

class _CountersRow extends StatelessWidget {
  final ScanCounters counters;
  const _CountersRow({required this.counters});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Counter(
            label: 'Apps Scanned',
            value: counters.appsScanned,
            suffix: ' / ${counters.totalApps}',
            color: const Color(0xFF00C2FF),
          )),
          const SizedBox(width: 8),
          Expanded(child: _Counter(
            label: 'Threats',
            value: counters.threatsFound,
            color: counters.threatsFound > 0
                ? const Color(0xFFEF4444)
                : const Color(0xFF22C55E),
          )),
          const SizedBox(width: 8),
          Expanded(child: _Counter(
            label: 'Permissions',
            value: counters.permissionsChecked,
            color: const Color(0xFF8B5CF6),
          )),
          const SizedBox(width: 8),
          Expanded(child: _Counter(
            label: 'Risky APIs',
            value: counters.riskyApis,
            color: const Color(0xFFF59E0B),
          )),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  final Color color;
  const _Counter({
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            builder: (context, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '${v.round()}',
                      style: t.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1,
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      TextSpan(text: suffix,
                        style: t.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: t.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

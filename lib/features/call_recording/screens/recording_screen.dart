import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../call_recording_provider.dart';
import '../services/recording_service.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  /// When true the screen auto-starts after consent (e.g. SOS trigger).
  final bool autoStart;

  const RecordingScreen({super.key, this.autoStart = false});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _isInCall = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _checkCallState();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConsentDialog());
    }
  }

  Future<void> _checkCallState() async {
    final inCall = await RecordingService.isInActiveCall();
    if (mounted) setState(() => _isInCall = inCall);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    ref.read(callRecordingProvider.notifier).reset();
    super.dispose();
  }

  // ── Consent dialog ─────────────────────────────────────────────────────────

  Future<void> _showConsentDialog() async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mic_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Recording Consent',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: const Text(
          'You are about to record audio using the microphone.\n\n'
          '• This recording will be encrypted and stored securely on your device.\n'
          '• You are responsible for ensuring all parties consent to being recorded.\n'
          '• Recording calls without consent may be illegal in your jurisdiction.\n\n'
          'Do you consent to proceed?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I Consent, Record'),
          ),
        ],
      ),
    );

    if (agreed == true && mounted) {
      await ref.read(callRecordingProvider.notifier).startRecording();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handlePauseResume(RecordingStatus status) async {
    final notifier = ref.read(callRecordingProvider.notifier);
    if (status == RecordingStatus.recording) {
      await notifier.pauseRecording();
    } else {
      await notifier.resumeRecording();
    }
  }

  Future<void> _handleStop() async {
    await ref.read(callRecordingProvider.notifier).stopRecording();
    if (mounted) {
      context.push('/recording-preview');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callRecordingProvider);
    final isRecording = state.status == RecordingStatus.recording;
    final isPaused = state.status == RecordingStatus.paused;
    final isActive = isRecording || isPaused;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Recorder'),
        actions: [
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _RecordingBadge(controller: _pulseCtrl),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── OS limitation notice ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Android 9+ restricts system call audio. '
                        'This records microphone audio only.',
                        style: TextStyle(
                            color: AppTheme.warning.withValues(alpha: 0.9),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isInCall) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.call, color: AppTheme.success, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Active call detected',
                        style: TextStyle(
                            color: AppTheme.success.withValues(alpha: 0.9),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Waveform visualiser ─────────────────────────────────────
              Expanded(
                child: _WaveformVisualiser(
                  amplitude: state.amplitude,
                  isActive: isRecording,
                ),
              ),

              // ── Timer ────────────────────────────────────────────────────
              Text(
                _formatDuration(state.elapsed),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 52,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                isRecording
                    ? 'Recording in progress...'
                    : isPaused
                        ? 'Paused'
                        : state.status == RecordingStatus.error
                            ? state.errorMessage ?? 'Error'
                            : 'Tap the microphone to begin',
                style: TextStyle(
                  color: isRecording
                      ? AppTheme.errorColor
                      : AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 48),

              // ── Controls ─────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Stop button (shown when active)
                  if (isActive)
                    _ControlButton(
                      icon: Icons.stop_rounded,
                      label: 'Stop',
                      color: AppTheme.errorColor,
                      size: 56,
                      onTap: _handleStop,
                    )
                  else
                    const SizedBox(width: 56),

                  // Main mic button
                  _MicButton(
                    isRecording: isRecording,
                    isPaused: isPaused,
                    onTap: isActive
                        ? null
                        : () => _showConsentDialog(),
                  ),

                  // Pause / Resume
                  if (isActive)
                    _ControlButton(
                      icon: isRecording
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      label: isRecording ? 'Pause' : 'Resume',
                      color: AppTheme.accent,
                      size: 56,
                      onTap: () => _handlePauseResume(state.status),
                    )
                  else
                    const SizedBox(width: 56),
                ],
              ),

              const SizedBox(height: 32),

              // ── Legal disclaimer ─────────────────────────────────────────
              Text(
                '⚠ Ensure all parties consent. Check local laws before recording.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _RecordingBadge extends StatelessWidget {
  final AnimationController controller;
  const _RecordingBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.errorColor
                  .withValues(alpha: 0.4 + 0.6 * controller.value),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'REC',
            style: TextStyle(
              color: AppTheme.errorColor.withValues(alpha: 0.7 + 0.3 * controller.value),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformVisualiser extends StatefulWidget {
  final double amplitude;
  final bool isActive;

  const _WaveformVisualiser({required this.amplitude, required this.isActive});

  @override
  State<_WaveformVisualiser> createState() => _WaveformVisualiserState();
}

class _WaveformVisualiserState extends State<_WaveformVisualiser>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<double> _bars = List.filled(30, 0.05);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..addListener(_updateBars);
    if (widget.isActive) _ctrl.repeat();
  }

  void _updateBars() {
    if (!widget.isActive) return;
    setState(() {
      _bars.removeAt(0);
      final rng = math.Random();
      final base = widget.amplitude;
      final jitter = base > 0.05
          ? (rng.nextDouble() * 0.3 - 0.15)
          : 0.0;
      _bars.add((base + jitter).clamp(0.03, 1.0));
    });
  }

  @override
  void didUpdateWidget(_WaveformVisualiser old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isActive && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _bars.asMap().entries.map((e) {
          final idx = e.key;
          final val = e.value;
          final isMid = (idx - 14).abs() < 6;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 5,
              height: (val * (isMid ? 160 : 100)).clamp(4.0, 160.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.accent,
                    AppTheme.accent.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback? onTap;

  const _MicButton({
    required this.isRecording,
    required this.isPaused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording
        ? AppTheme.errorColor
        : isPaused
            ? AppTheme.warning
            : AppTheme.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isRecording
              ? Icons.mic_rounded
              : isPaused
                  ? Icons.mic_off_rounded
                  : Icons.mic_none_rounded,
          color: color,
          size: 40,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

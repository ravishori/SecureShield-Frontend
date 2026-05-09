import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../call_recording_provider.dart';
import '../services/recording_service.dart';

class RecordingPreviewScreen extends ConsumerStatefulWidget {
  const RecordingPreviewScreen({super.key});

  @override
  ConsumerState<RecordingPreviewScreen> createState() =>
      _RecordingPreviewScreenState();
}

class _RecordingPreviewScreenState
    extends ConsumerState<RecordingPreviewScreen> {
  final AudioPlayer _player = AudioPlayer();

  // Playback state
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Save state
  bool _isSaving = false;
  final _titleCtrl = TextEditingController();

  // Playback source — decrypted temp path
  String? _playbackPath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlayback());
  }

  Future<void> _loadPlayback() async {
    final state = ref.read(callRecordingProvider);
    if (state.tempPath == null) return;
    // tempPath is still the raw unencrypted temp file at this point
    _playbackPath = state.tempPath;
    await _player.setSource(DeviceFileSource(_playbackPath!));
    final dur = await _player.getDuration();
    if (mounted && dur != null) setState(() => _duration = dur);
    // Set a default title
    _titleCtrl.text =
        'Recording ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
  }

  @override
  void dispose() {
    _player.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_playbackPath == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(_playbackPath!));
    }
  }

  Future<void> _seek(double value) async {
    final pos = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _player.seek(pos);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveSecurely() async {
    await _player.stop();

    if (!mounted) return;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save Recording',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: _titleCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Recording title',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background),
            onPressed: () => Navigator.pop(context, _titleCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    setState(() => _isSaving = true);
    final meta = await ref.read(callRecordingProvider.notifier).saveEncrypted(
          title: title,
        );
    if (mounted) {
      setState(() => _isSaving = false);
      if (meta != null) {
        _showSnack('Recording saved securely', success: true);
        // Refresh saved list
        ref.invalidate(savedRecordingsProvider);
        if (mounted) context.go('/home');
      } else {
        _showSnack('Failed to save recording');
      }
    }
  }

  // ── Discard ────────────────────────────────────────────────────────────────

  Future<void> _discard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Discard Recording?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'The recording will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _player.stop();
    final state = ref.read(callRecordingProvider);
    if (state.tempPath != null) {
      await RecordingService.deleteTempFile(state.tempPath!);
    }
    ref.read(callRecordingProvider.notifier).reset();
    if (mounted) context.go('/home');
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? AppTheme.success : AppTheme.errorColor,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(callRecordingProvider);
    final elapsed = recState.elapsed;

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Recording'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _discard,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Recording info card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.audio_file_rounded,
                        color: AppTheme.accent, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      _formatDuration(elapsed),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Audio Recording',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Player ──────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Seek bar
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbColor: AppTheme.accent,
                        activeTrackColor: AppTheme.accent,
                        inactiveTrackColor:
                            AppTheme.accent.withOpacity(0.2),
                        overlayColor: AppTheme.accent.withOpacity(0.1),
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: progress.toDouble(),
                        onChanged: _seek,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          Text(_formatDuration(_duration),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Play/Pause button
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withOpacity(0.15),
                          border: Border.all(color: AppTheme.accent, width: 2),
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppTheme.accent,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Encryption badge ────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_rounded,
                        color: AppTheme.success, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Will be encrypted with AES-256 before saving',
                      style: TextStyle(
                          color: AppTheme.success, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Action buttons ──────────────────────────────────────────
              _isSaving
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accent))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _saveSecurely,
                          icon: const Icon(Icons.lock_rounded),
                          label: const Text('Save Securely',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(
                                color: AppTheme.errorColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => context.push('/emergency-share'),
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share Immediately',
                              style: TextStyle(fontSize: 15)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _discard,
                          child: const Text('Discard Recording',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ),
                      ],
                    ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

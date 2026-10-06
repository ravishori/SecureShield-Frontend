import 'package:secureshield_app/l10n/app_localizations.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../screen_recorder_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class ScreenRecorderScreen extends ConsumerStatefulWidget {
  const ScreenRecorderScreen({super.key});

  @override
  ConsumerState<ScreenRecorderScreen> createState() =>
      _ScreenRecorderScreenState();
}

class _ScreenRecorderScreenState extends ConsumerState<ScreenRecorderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(screenRecorderProvider.notifier).checkState();
      ref.read(recordingsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final notifier    = ref.read(screenRecorderProvider.notifier);
    final isRecording = ref.read(screenRecorderProvider);

    if (isRecording) {
      await notifier.stopRecording();
      // Reload recordings list after stopping
      await ref.read(recordingsProvider.notifier).load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(AppLocalizations.of(context).srSaved),
          ),
        );
      }
    } else {
      final ok = await notifier.startRecording();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text(AppLocalizations.of(context).srDenied),
          ),
        );
      }
    }
  }

  void _playRecording(File file) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _VideoPlayerScreen(file: file),
    ));
  }

  Future<void> _shareRecording(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Screen recording from SecureShield AI — evidence capture',
        subject: 'SecureShield Recording',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'),
            backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _deleteRecording(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).srDeleteQ),
        content: Text(
          'Delete "${_fileName(file)}"?\nThis cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel,
              style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor),
            child: Text(AppLocalizations.of(context).gDelete,
              style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(recordingsProvider.notifier).delete(file);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fileName(File f) => f.path.split('/').last;

  String _fileDate(File f) {
    try {
      final dt = f.lastModifiedSync();
      return DateFormat('dd MMM yyyy  hh:mm a').format(dt);
    } catch (_) { return ''; }
  }

  String _fileSize(File f) {
    try {
      final bytes = f.lengthSync();
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) { return ''; }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(screenRecorderProvider);
    final recordings  = ref.watch(recordingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).srTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(recordingsProvider.notifier).load(),
            tooltip: AppLocalizations.of(context).srRefresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Purpose card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline, color: AppTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).srPurpose, style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Record your screen as evidence when dealing with scammers, '
                    'documenting fraud, or reporting suspicious activity. '
                    'Recordings include audio from your microphone.',
                    style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Record button ────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: ScaleTransition(
                  scale: isRecording
                      ? _pulse
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        isRecording ? AppTheme.errorColor : AppTheme.accent,
                        isRecording
                            ? AppTheme.errorColor.withValues(alpha: 0.4)
                            : AppTheme.accent.withValues(alpha: 0.4),
                      ]),
                      boxShadow: [
                        BoxShadow(
                          color: isRecording
                              ? AppTheme.errorColor.withValues(alpha: 0.5)
                              : AppTheme.accent.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRecording
                              ? Icons.stop_rounded
                              : Icons.fiber_manual_record,
                          size: 52,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isRecording ? 'STOP' : 'RECORD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Status label ─────────────────────────────────────────────
            Center(
              child: isRecording
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                            color: AppTheme.errorColor, size: 10),
                          SizedBox(width: 8),
                          Text('Recording in progress…',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                        ],
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context).srTapStart,
                      style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
            ),
            const SizedBox(height: 28),

            // ── Legal notice ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.35)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel, color: AppTheme.warning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Legal Notice: Record only your own activity or with explicit '
                      'consent from all parties. Use recordings only for fraud '
                      'reporting and legal evidence.',
                      style: TextStyle(
                        color: AppTheme.warning, fontSize: 11, height: 1.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Past Recordings ──────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.video_library,
                  color: AppTheme.accent, size: 16),
                const SizedBox(width: 6),
                Text(AppLocalizations.of(context).srPast, style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
                const Spacer(),
                if (recordings.isNotEmpty)
                  Text('${recordings.length} file${recordings.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),

            if (recordings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.videocam_off,
                      size: 44, color: AppTheme.textSecondary),
                    const SizedBox(height: 10),
                    Text(AppLocalizations.of(context).srNone,
                      style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(AppLocalizations.of(context).srTapRecordAbove,
                      style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                      textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ...recordings.map((file) => _recordingCard(file)),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Recording card ─────────────────────────────────────────────────────────

  Widget _recordingCard(File file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // ── Thumbnail / play area ──────────────────────────────────────
          GestureDetector(
            onTap: () => _playRecording(file),
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 38),
                    ),
                    const SizedBox(height: 10),
                    Text(AppLocalizations.of(context).srTapPlay,
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          // ── File info + actions ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.videocam,
                  color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName(file),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(_fileDate(file),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_fileSize(file),
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Play
                IconButton(
                  icon: const Icon(Icons.play_circle_outline,
                    color: AppTheme.accent, size: 26),
                  onPressed: () => _playRecording(file),
                  tooltip: AppLocalizations.of(context).gPlay,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                // Share
                IconButton(
                  icon: const Icon(Icons.share,
                    color: AppTheme.textSecondary, size: 22),
                  onPressed: () => _shareRecording(file),
                  tooltip: AppLocalizations.of(context).gShare,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor, size: 22),
                  onPressed: () => _deleteRecording(file),
                  tooltip: AppLocalizations.of(context).gDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen video player screen
// ─────────────────────────────────────────────────────────────────────────────
class _VideoPlayerScreen extends StatefulWidget {
  final File file;
  const _VideoPlayerScreen({required this.file});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      })
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _share() async {
    await Share.shareXFiles(
      [XFile(widget.file.path)],
      text: 'Screen recording from SecureShield AI — evidence capture',
      subject: 'SecureShield Recording',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos      = _ctrl.value.position;
    final dur      = _ctrl.value.duration;
    final isPlaying = _ctrl.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.file.path.split('/').last,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _share,
            tooltip: AppLocalizations.of(context).gShare,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Video ──────────────────────────────────────────────────
            _initialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent)),

            // ── Controls overlay ───────────────────────────────────────
            if (_initialized && _showControls)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Seek bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(_fmt(pos),
                              style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                                  trackHeight: 3,
                                  activeTrackColor: AppTheme.accent,
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: AppTheme.accent,
                                  overlayColor: AppTheme.accent
                                      .withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: dur.inMilliseconds > 0
                                      ? pos.inMilliseconds /
                                          dur.inMilliseconds
                                      : 0.0,
                                  onChanged: (v) {
                                    _ctrl.seekTo(Duration(
                                      milliseconds:
                                          (v * dur.inMilliseconds).toInt()));
                                  },
                                ),
                              ),
                            ),
                            Text(_fmt(dur),
                              style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),

                      // Play / pause / rewind / forward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Rewind 10s
                          IconButton(
                            icon: const Icon(Icons.replay_10,
                              color: Colors.white, size: 32),
                            onPressed: () => _ctrl.seekTo(
                              Duration(seconds:
                                (pos.inSeconds - 10).clamp(0, dur.inSeconds))),
                          ),
                          const SizedBox(width: 8),
                          // Play / pause
                          GestureDetector(
                            onTap: isPlaying ? _ctrl.pause : _ctrl.play,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Forward 10s
                          IconButton(
                            icon: const Icon(Icons.forward_10,
                              color: Colors.white, size: 32),
                            onPressed: () => _ctrl.seekTo(
                              Duration(seconds:
                                (pos.inSeconds + 10).clamp(0, dur.inSeconds))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Share row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _shareChip(Icons.chat, 'WhatsApp', _share),
                            const SizedBox(width: 12),
                            _shareChip(Icons.share, 'Share', _share),
                            const SizedBox(width: 12),
                            _shareChip(Icons.more_horiz, 'More', _share),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shareChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(label,
              style: const TextStyle(
                color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'services/recording_service.dart';
import 'services/recording_storage_service.dart';

// ── Recording status enum ─────────────────────────────────────────────────────

enum RecordingStatus { idle, recording, paused, stopped, saving, error }

// ── State ─────────────────────────────────────────────────────────────────────

class RecordingState {
  final RecordingStatus status;
  final Duration elapsed;
  final double amplitude; // 0.0–1.0 normalised
  final String? tempPath; // raw (unencrypted) temp file after stop
  final RecordingMeta? savedMeta; // after saveEncrypted()
  final String? errorMessage;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.elapsed = Duration.zero,
    this.amplitude = 0.0,
    this.tempPath,
    this.savedMeta,
    this.errorMessage,
  });

  bool get isActive =>
      status == RecordingStatus.recording || status == RecordingStatus.paused;

  RecordingState copyWith({
    RecordingStatus? status,
    Duration? elapsed,
    double? amplitude,
    String? tempPath,
    RecordingMeta? savedMeta,
    String? errorMessage,
  }) =>
      RecordingState(
        status: status ?? this.status,
        elapsed: elapsed ?? this.elapsed,
        amplitude: amplitude ?? this.amplitude,
        tempPath: tempPath ?? this.tempPath,
        savedMeta: savedMeta ?? this.savedMeta,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CallRecordingNotifier extends StateNotifier<RecordingState> {
  CallRecordingNotifier() : super(const RecordingState());

  Timer? _timer;
  StreamSubscription<Amplitude>? _ampSub;

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<void> startRecording() async {
    try {
      await RecordingService.startRecording();

      state = state.copyWith(
        status: RecordingStatus.recording,
        elapsed: Duration.zero,
        amplitude: 0.0,
        tempPath: null,
        savedMeta: null,
        errorMessage: null,
      );

      _startTimer();
      _startAmplitudeStream();
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  Future<void> pauseRecording() async {
    await RecordingService.pauseRecording();
    _timer?.cancel();
    state = state.copyWith(status: RecordingStatus.paused, amplitude: 0.0);
  }

  Future<void> resumeRecording() async {
    await RecordingService.resumeRecording();
    state = state.copyWith(status: RecordingStatus.recording);
    _startTimer();
  }

  // ── Stop ───────────────────────────────────────────────────────────────────

  Future<void> stopRecording() async {
    _timer?.cancel();
    await _ampSub?.cancel();

    final path = await RecordingService.stopRecording();
    state = state.copyWith(
      status: RecordingStatus.stopped,
      tempPath: path,
      amplitude: 0.0,
    );
  }

  // ── Save encrypted ─────────────────────────────────────────────────────────

  Future<RecordingMeta?> saveEncrypted({
    required String title,
  }) async {
    final tempPath = state.tempPath;
    if (tempPath == null) return null;

    state = state.copyWith(status: RecordingStatus.saving);

    try {
      final meta = await RecordingStorageService.saveEncrypted(
        tempPath: tempPath,
        title: title,
        durationSeconds: state.elapsed.inSeconds,
      );
      // Clean up the unencrypted temp file
      await RecordingService.deleteTempFile(tempPath);

      state = state.copyWith(status: RecordingStatus.idle, savedMeta: meta);
      return meta;
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Save failed: $e',
      );
      return null;
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset() {
    _timer?.cancel();
    _ampSub?.cancel();
    state = const RecordingState();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == RecordingStatus.recording) {
        state = state.copyWith(
          elapsed: state.elapsed + const Duration(seconds: 1),
        );
      }
    });
  }

  void _startAmplitudeStream() {
    _ampSub?.cancel();
    _ampSub = RecordingService.amplitudeStream().listen((amp) {
      if (!mounted) return;
      // Normalise from dB range (-160 to 0) to 0.0–1.0
      final normalised = ((amp.current + 160) / 160).clamp(0.0, 1.0);
      state = state.copyWith(amplitude: normalised);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final callRecordingProvider =
    StateNotifierProvider<CallRecordingNotifier, RecordingState>(
  (ref) => CallRecordingNotifier(),
);

/// List of all saved recordings on device.
final savedRecordingsProvider =
    FutureProvider<List<RecordingMeta>>((ref) async {
  return RecordingStorageService.listRecordings();
});

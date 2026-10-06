import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Outcome of a start attempt. [microphone] is false when the recording has no audio (permission denied).
class RecordingStartResult {
  const RecordingStartResult(
      {required this.started, this.microphone = false, this.error});
  final bool started;
  final bool microphone;
  final String? error;
}

class ScreenRecorderService {
  static const _channel = MethodChannel('secureshield/screen_record');

  /// Asks for the microphone permission (non-fatal if refused), then for screen capture. Returns whether the user
  /// granted screen capture; use [startRecordingChecked] to also learn whether it really started.
  Future<bool> startRecording() async {
    try {
      return await _channel.invokeMethod<bool>('startRecording') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> recordingStatus() async {
    try {
      final m =
          await _channel.invokeMapMethod<String, dynamic>('recordingStatus');
      return m ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// Full start flow. The microphone permission is optional: when it is refused the screen is still recorded,
  /// without audio, and the result says so. A native failure is reported in [RecordingStartResult.error]
  /// instead of leaving the UI believing a recording is running.
  Future<RecordingStartResult> startRecordingChecked({
    Duration settle = const Duration(milliseconds: 1500),
  }) async {
    try {
      await Permission.microphone.request();
    } catch (_) {/* treated as denied; native side re-checks */}
    final granted = await startRecording();
    if (!granted) {
      return const RecordingStartResult(
          started: false, error: 'Screen capture permission was not granted');
    }
    await Future<void>.delayed(settle);
    final st = await recordingStatus();
    if (st['recording'] == true) {
      return RecordingStartResult(
          started: true, microphone: st['microphone'] == true);
    }
    return RecordingStartResult(
        started: false,
        error: (st['error'] as String?) ?? 'Screen recording could not start');
  }

  Future<bool> stopRecording() async {
    try {
      return await _channel.invokeMethod<bool>('stopRecording') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isRecording() async {
    try {
      return await _channel.invokeMethod<bool>('isRecording') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Recordings directory ───────────────────────────────────────────────────
  // Native saves to:  getExternalFilesDir(null)/ScreenRecordings/
  // Dart equivalent:  getExternalStorageDirectory()/ScreenRecordings/

  Future<Directory?> getRecordingsDir() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return null;
      final dir = Directory('${extDir.path}/ScreenRecordings');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> listRecordings() async {
    final dir = await getRecordingsDir();
    if (dir == null || !dir.existsSync()) return [];
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.mp4'))
          .toList();
      // Newest first
      files
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final screenRecorderServiceProvider =
    Provider<ScreenRecorderService>((ref) => ScreenRecorderService());

// Recording state (true = currently recording)
class ScreenRecorderNotifier extends StateNotifier<bool> {
  final ScreenRecorderService _service;
  ScreenRecorderNotifier(this._service) : super(false);

  /// Result of the last [startRecording] (for the screen to explain: no microphone / failure).
  RecordingStartResult? lastStart;

  Future<bool> startRecording() async {
    final r = await _service.startRecordingChecked();
    lastStart = r;
    state = r.started;
    return r.started;
  }

  Future<void> stopRecording() async {
    await _service.stopRecording();
    state = false;
  }

  Future<void> checkState() async {
    state = await _service.isRecording();
  }
}

final screenRecorderProvider =
    StateNotifierProvider<ScreenRecorderNotifier, bool>((ref) {
  return ScreenRecorderNotifier(ref.watch(screenRecorderServiceProvider));
});

// Recordings list
class RecordingsNotifier extends StateNotifier<List<File>> {
  final ScreenRecorderService _service;
  RecordingsNotifier(this._service) : super([]);

  Future<void> load() async {
    state = await _service.listRecordings();
  }

  Future<void> delete(File file) async {
    await _service.deleteRecording(file.path);
    state = state.where((f) => f.path != file.path).toList();
  }
}

final recordingsProvider =
    StateNotifierProvider<RecordingsNotifier, List<File>>((ref) {
  return RecordingsNotifier(ref.watch(screenRecorderServiceProvider));
});

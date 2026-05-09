import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Wraps the `record` package for in-app microphone recording.
///
/// Android 9+ blocks tap into the telephony audio stream for third-party apps,
/// so this service records the microphone channel only.  Users must consent
/// before recording starts (enforced by the UI layer).
class RecordingService {
  RecordingService._();

  static final AudioRecorder _recorder = AudioRecorder();

  static const _callStateChannel = MethodChannel('secureshield/call_state');

  // ── Permission ──────────────────────────────────────────────────────────────

  /// Returns true if microphone permission is granted.
  static Future<bool> hasMicPermission() async {
    return _recorder.hasPermission();
  }

  /// Requests microphone permission.  Returns true if granted.
  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Call state ──────────────────────────────────────────────────────────────

  /// Returns true when the device is in an active call (OFFHOOK = state 2).
  static Future<bool> isInActiveCall() async {
    try {
      final state = await _callStateChannel.invokeMethod<int>('getCallState');
      return state == 2; // TelephonyManager.CALL_STATE_OFFHOOK
    } on MissingPluginException {
      return false; // not on Android
    } catch (e) {
      debugPrint('[RecordingService] callState error: $e');
      return false;
    }
  }

  // ── Recording lifecycle ────────────────────────────────────────────────────

  /// Starts a new recording and returns the output file path.
  ///
  /// The file is written to the app's temporary directory; the
  /// [RecordingStorageService] should be used to move/encrypt it afterward.
  static Future<String> startRecording() async {
    if (!await hasMicPermission()) {
      final granted = await requestMicPermission();
      if (!granted) throw Exception('Microphone permission denied');
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.aac';
    final filePath = '${dir.path}/$fileName';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: filePath,
    );

    debugPrint('[RecordingService] Started → $filePath');
    return filePath;
  }

  /// Pauses an in-progress recording.
  static Future<void> pauseRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.pause();
    }
  }

  /// Resumes a paused recording.
  static Future<void> resumeRecording() async {
    if (await _recorder.isPaused()) {
      await _recorder.resume();
    }
  }

  /// Stops recording and returns the saved file path (may be null if never started).
  static Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    debugPrint('[RecordingService] Stopped → $path');
    return path;
  }

  /// Returns true while recording is active (not paused).
  static Future<bool> isRecording() => _recorder.isRecording();

  /// Returns true while recording is paused.
  static Future<bool> isPaused() => _recorder.isPaused();

  /// Amplitude stream — emits every [interval] for waveform visualisation.
  static Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 100),
  }) =>
      _recorder.onAmplitudeChanged(interval);

  /// Release native resources.  Call when the feature is unmounted.
  static Future<void> dispose() async {
    await _recorder.dispose();
  }

  // ── File helpers ───────────────────────────────────────────────────────────

  /// Deletes a temporary recording file from disk.
  static Future<void> deleteTempFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[RecordingService] deleteTempFile error: $e');
    }
  }
}

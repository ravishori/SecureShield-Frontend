import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tells the app whether *its own screens* are currently being captured by a screen recording.
///
/// Only Android 15+ (API 35) offers a supported API for this (`Activity.registerScreenRecordingCallback`);
/// on older versions [isSupported] is false and [states] never emits - the UI must say so rather than guess.
class ScreenRecordingDetectorService {
  ScreenRecordingDetectorService({
    MethodChannel? method,
    EventChannel? events,
  })  : _method = method ?? const MethodChannel('secureshield/screen_recording_detector'),
        _events = events ?? const EventChannel('secureshield/screen_recording_events');

  final MethodChannel _method;
  final EventChannel _events;

  /// True when this device runs Android 15 or newer. Any error (including a missing plugin) means "not supported".
  Future<bool> isSupported() async {
    try {
      return await _method.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      debugPrint('[ScreenRecordingDetector] isSupported failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> isRecording() async {
    try {
      return await _method.invokeMethod<bool>('isRecording') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// `true` = the app's content is being recorded, `false` = it stopped. Errors end the stream silently.
  Stream<bool> get states => _events
      .receiveBroadcastStream()
      .map((e) => e == true)
      .handleError((Object e) => debugPrint('[ScreenRecordingDetector] stream error: ${e.runtimeType}'));
}

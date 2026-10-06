import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/screen_recorder/screen_recorder_service.dart';

const _rec = MethodChannel('secureshield/screen_record');
const _perm = MethodChannel('flutter.baseflow.com/permissions/methods');

/// Fake native side of the recorder + the permission plugin (microphone granted = 1, denied = 0).
void _install({
  required bool micGranted,
  bool captureGranted = true,
  Map<String, dynamic>? status,
}) {
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(_perm, (call) async {
    switch (call.method) {
      case 'requestPermissions':
        return {
          for (final p in (call.arguments as List)) p as int: micGranted ? 1 : 0
        };
      case 'checkPermissionStatus':
        return micGranted ? 1 : 0;
    }
    return null;
  });
  m.setMockMethodCallHandler(_rec, (call) async {
    switch (call.method) {
      case 'startRecording':
        return captureGranted;
      case 'recordingStatus':
        return status ??
            {'recording': true, 'microphone': micGranted, 'error': null};
    }
    throw MissingPluginException();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const settle = Duration.zero;

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_rec, null);
    m.setMockMethodCallHandler(_perm, null);
  });

  test('microphone granted: started with audio', () async {
    _install(micGranted: true);
    final r =
        await ScreenRecorderService().startRecordingChecked(settle: settle);
    expect(r.started, isTrue);
    expect(r.microphone, isTrue);
    expect(r.error, isNull);
  });

  test('microphone denied: still records the screen, flagged as no audio',
      () async {
    _install(micGranted: false);
    final r =
        await ScreenRecorderService().startRecordingChecked(settle: settle);
    expect(r.started, isTrue);
    expect(r.microphone, isFalse);
  });

  test('native failure is reported, never claimed as recording', () async {
    _install(micGranted: false, status: {
      'recording': false,
      'microphone': false,
      'error': 'Screen recording could not start (IllegalStateException)'
    });
    final r =
        await ScreenRecorderService().startRecordingChecked(settle: settle);
    expect(r.started, isFalse);
    expect(r.error, contains('could not start'));
  });

  test('screen-capture permission refused: not started, explained', () async {
    _install(micGranted: true, captureGranted: false);
    final r =
        await ScreenRecorderService().startRecordingChecked(settle: settle);
    expect(r.started, isFalse);
    expect(r.error, isNotEmpty);
  });

  test('a failing platform channel never throws and never reports recording',
      () async {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
        _perm, (call) async => throw PlatformException(code: 'x'));
    m.setMockMethodCallHandler(
        _rec, (call) async => throw PlatformException(code: 'boom'));
    final r =
        await ScreenRecorderService().startRecordingChecked(settle: settle);
    expect(r.started, isFalse);
  });

  test('notifier state follows the checked result', () async {
    _install(micGranted: false, status: {'recording': false, 'error': 'x'});
    final n = ScreenRecorderNotifier(ScreenRecorderService());
    expect(await n.startRecording(), isFalse);
    expect(n.state, isFalse);
    expect(n.lastStart?.error, 'x');
  });
}

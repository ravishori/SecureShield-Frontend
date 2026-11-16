import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/screen_recorder/screen_recording_detector_service.dart';
import 'package:secureshield_app/features/screen_recorder/screens/screen_recording_detector_screen.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

const _method = MethodChannel('secureshield/screen_recording_detector');
const _events = EventChannel('secureshield/screen_recording_events');

/// Fake native side: [supported]/[recording] answer the method channel, [emit] pushes events.
class FakeNative {
  FakeNative({this.supported = true, this.recording = false});
  bool supported;
  bool recording;
  StreamController<bool>? _ctl;
  bool listening = false;

  void install() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_method, (call) async {
      switch (call.method) {
        case 'isSupported':
          return supported;
        case 'isRecording':
          return recording;
      }
      throw MissingPluginException();
    });
    m.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          listening = true;
          _ctl = StreamController<bool>();
          _ctl!.stream.listen(sink.success);
        },
        onCancel: (args) {
          listening = false;
          _ctl?.close();
        },
      ),
    );
  }

  void emit(bool v) => _ctl!.add(v);

  void uninstall() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_method, null);
    m.setMockStreamHandler(_events, null);
  }
}

Widget app(Widget home, {String locale = 'en'}) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('service', () {
    test('reports support and state from the native side', () async {
      final n = FakeNative(supported: true, recording: true)..install();
      addTearDown(n.uninstall);
      final s = ScreenRecordingDetectorService();
      expect(await s.isSupported(), isTrue);
      expect(await s.isRecording(), isTrue);
    });

    test(
        'a missing/failing native side means "not supported", never an exception',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              _method, (c) async => throw PlatformException(code: 'boom'));
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_method, null));
      final s = ScreenRecordingDetectorService();
      expect(await s.isSupported(), isFalse);
      expect(await s.isRecording(), isFalse);
    });

    test('streams state changes', () async {
      final n = FakeNative()..install();
      addTearDown(n.uninstall);
      final got = <bool>[];
      final sub = ScreenRecordingDetectorService().states.listen(got.add);
      await Future<void>.delayed(Duration.zero);
      n.emit(true);
      n.emit(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(got, [true, false]);
      await sub.cancel();
    });
  });

  group('screen', () {
    testWidgets(
        'says plainly that detection is not possible below Android 15 and starts no listener',
        (tester) async {
      final n = FakeNative(supported: false)..install();
      addTearDown(n.uninstall);
      await tester.pumpWidget(app(const ScreenRecordingDetectorScreen()));
      await tester.pumpAndSettle();
      expect(
          find.text('Not supported on this Android version'), findsOneWidget);
      expect(find.byKey(const Key('srdStatus')), findsNothing);
      expect(n.listening, isFalse);
    });

    testWidgets(
        'shows idle, flips to RECORDING on an event, logs it and flips back',
        (tester) async {
      final n = FakeNative(supported: true)..install();
      addTearDown(n.uninstall);
      await tester.pumpWidget(app(const ScreenRecordingDetectorScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Not being recorded'), findsOneWidget);
      expect(find.text('No recording detected so far.'), findsOneWidget);

      n.emit(true);
      await tester.pumpAndSettle();
      expect(find.text('SCREEN IS BEING RECORDED'), findsOneWidget);
      expect(find.text('Recording started'), findsOneWidget);

      n.emit(false);
      await tester.pumpAndSettle();
      expect(find.text('Not being recorded'), findsOneWidget);
      expect(find.text('Recording stopped'), findsOneWidget);
      expect(find.text('Recording started'),
          findsOneWidget); // history is kept, newest first
    });

    testWidgets(
        'starts in the RECORDING state when a recording is already running',
        (tester) async {
      final n = FakeNative(supported: true, recording: true)..install();
      addTearDown(n.uninstall);
      await tester.pumpWidget(app(const ScreenRecordingDetectorScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SCREEN IS BEING RECORDED'), findsOneWidget);
    });

    testWidgets('stops listening when the screen is closed', (tester) async {
      final n = FakeNative(supported: true)..install();
      addTearDown(n.uninstall);
      await tester.pumpWidget(app(const ScreenRecordingDetectorScreen()));
      await tester.pumpAndSettle();
      expect(n.listening, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(n.listening, isFalse);
    });

    testWidgets('renders from the Hindi translation and states its limit',
        (tester) async {
      final n = FakeNative(supported: true)..install();
      addTearDown(n.uninstall);
      await tester
          .pumpWidget(app(const ScreenRecordingDetectorScreen(), locale: 'hi'));
      await tester.pumpAndSettle();
      expect(find.text('स्क्रीन रिकॉर्डिंग डिटेक्टर'), findsOneWidget);
      expect(
          find.textContaining('SecureShield की अपनी स्क्रीन'), findsOneWidget);
    });
  });
}

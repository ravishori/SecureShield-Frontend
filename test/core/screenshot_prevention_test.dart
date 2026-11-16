// Mocked-channel tests of the FLAG_SECURE lifecycle plus a contract test against the Kotlin source.
// They do NOT prove the flag reaches the window: that needs an Android device/emulator (see docs/audit).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/security/screenshot_prevention.dart';

const _channel = MethodChannel('secureshield/window_flags');

/// The platform override must be undone before the framework checks its invariants, so it is scoped to the body.
void androidWidgets(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body(t);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  Object? failWith;

  setUp(() {
    calls.clear();
    failWith = null;
    ScreenshotPrevention.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      if (failWith != null) throw failWith!;
      if (call.method == 'isSecure') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 10));
  }

  test('Dart method names match the Kotlin MainActivity handler', () {
    final kotlin = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/MainActivity.kt').readAsStringSync();
    expect(kotlin, contains('"secureshield/window_flags"'));
    for (final m in ['enableSecure', 'disableSecure', 'isSecure']) {
      expect(kotlin, contains('"$m"'), reason: 'Kotlin must handle $m');
    }
    final dart = File('lib/core/security/screenshot_prevention.dart').readAsStringSync();
    expect(dart, isNot(contains("'addFlags'")), reason: 'the old, unhandled method names must not return');
    expect(dart, isNot(contains("'clearFlags'")));
  });

  androidWidgets('a protected screen sets the flag once and clears it when removed', (t) async {
    await t.pumpWidget(MaterialApp(home: ScreenshotPrevention.protect(child: const Text('secret'))));
    await settle(t);
    expect(calls, ['enableSecure']);
    expect(ScreenshotPrevention.holders, 1);

    await t.pumpWidget(const MaterialApp(home: Text('plain')));
    await settle(t);
    expect(calls, ['enableSecure', 'disableSecure']);
    expect(ScreenshotPrevention.holders, 0);
  });

  androidWidgets('stacked protected screens keep the flag until the last one is gone', (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: ScreenshotPrevention.protect(child: const Text('a'))));
    await settle(t);
    nav.currentState!.push(MaterialPageRoute(builder: (_) => ScreenshotPrevention.protect(child: const Text('b'))));
    await t.pumpAndSettle();
    expect(ScreenshotPrevention.holders, 2);
    expect(calls, ['enableSecure'], reason: 'second holder must not toggle the flag');

    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(ScreenshotPrevention.holders, 1);
    expect(calls, ['enableSecure'], reason: 'flag must stay on while the first screen is still mounted');

    await t.pumpWidget(const MaterialApp(home: Text('plain')));
    await settle(t);
    expect(calls, ['enableSecure', 'disableSecure']);
  });

  androidWidgets('an unprotected screen pushed on top does not clear the flag', (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: ScreenshotPrevention.protect(child: const Text('a'))));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Text('plain')));
    await t.pumpAndSettle();
    expect(calls, ['enableSecure']);
    expect(ScreenshotPrevention.holders, 1);
  });

  androidWidgets('returning to the foreground re-applies the flag while protected', (t) async {
    await t.pumpWidget(MaterialApp(home: ScreenshotPrevention.protect(child: const Text('secret'))));
    await settle(t);
    calls.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(calls, ['enableSecure']);

    await t.pumpWidget(const MaterialApp(home: Text('plain')));
    await settle(t);
    calls.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(calls, isEmpty, reason: 'nothing protected, nothing to re-apply');
  });

  androidWidgets('a failing platform call never throws and the count stays correct', (t) async {
    failWith = PlatformException(code: 'boom');
    await t.pumpWidget(MaterialApp(home: ScreenshotPrevention.protect(child: const Text('secret'))));
    await settle(t);
    expect(ScreenshotPrevention.holders, 1);
    await t.pumpWidget(const MaterialApp(home: Text('plain')));
    await settle(t);
    expect(ScreenshotPrevention.holders, 0);
    expect(calls, ['enableSecure', 'disableSecure']);
  });

  test('disable without a holder is a no-op and never goes negative', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await ScreenshotPrevention.disable();
    expect(ScreenshotPrevention.holders, 0);
    expect(calls, isEmpty);
  });

  test('does nothing on non-Android platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await ScreenshotPrevention.enable();
    await ScreenshotPrevention.disable();
    expect(calls, isEmpty);
    expect(await ScreenshotPrevention.isSecure(), isNull);
  });

  test('isSecure reads the native state', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(await ScreenshotPrevention.isSecure(), isTrue);
    expect(calls, ['isSecure']);
  });

  test('every sensitive route in the router is wrapped', () {
    final router = File('lib/core/router.dart').readAsStringSync();
    for (final cls in [
      'EvidenceScreen', 'FamilyScreen', 'OtpVaultScreen', 'RecordingPreviewScreen', 'EmergencyShareScreen',
      'BankOtpScreen', 'ComplaintEmailScreen', 'ProfileScreen', 'ProfileDetailsScreen', 'FirDraftScreen',
      'AiCoachScreen', 'OtpScreen',
    ]) {
      expect(router, contains('_secure(${cls == 'OtpScreen' ? 'OtpScreen(' : 'const $cls('}'),
          reason: '$cls must be protected');
    }
  });
}

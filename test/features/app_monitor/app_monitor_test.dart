import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/features/app_monitor/app_monitor_service.dart';
import 'package:secureshield_app/features/app_monitor/monitor_sync_coordinator.dart';
import 'package:secureshield_app/features/app_monitor/screens/app_monitor_screen.dart';

import '../auth/fake_http.dart';
import 'flaky_prefs.dart';

String _session() => fakeJwt({'sub': 'user-1', 'identifier': 'a@example.com', 'exp': 4102444800});

const _channel = MethodChannel('secureshield/app_monitor');
const _events = MethodChannel('secureshield/install_analysis');

/// A scripted native side: records calls and answers from the fields below.
class _Native {
  final List<String> calls = [];
  final List<String> storeCalls = [];
  bool running = false;
  bool enabled = false; // the persisted "monitoring is on" preference
  bool notificationsVisible = true; // app notifications on AND the monitor channel not disabled
  int enforceCalls = 0;
  int preferenceWrites = 0;
  Object? startError; // PlatformException to throw, or null
  Completer<void>? startGate; // hold the start open
  bool stopSucceeds = true;
  Map<String, Object?> stats = {'available': true, 'hasOwner': true};
  List<Object?> pending = const []; // what drainEvents returns

  Future<Object?> handle(MethodCall call) async {
    // Stage 2B store calls are the coordinator's, tested in monitor_sync_coordinator_test.dart; kept apart from the monitor calls.
    if (const {'setOwner', 'drainEvents', 'markResults', 'stats', 'purge'}.contains(call.method)) {
      storeCalls.add(call.method);
    } else {
      calls.add(call.method);
    }
    switch (call.method) {
      case 'isRunning':
        return running;
      case 'isEnabled':
        return enabled;
      case 'enforceVisibility':
        enforceCalls++;
        if (enabled && !notificationsVisible) {
          // native contract: clear the preference once, stop the service, report "paused"
          enabled = false;
          running = false;
          preferenceWrites++;
          return true;
        }
        return false;
      case 'startMonitor':
        if (startGate != null) await startGate!.future;
        if (!notificationsVisible) throw PlatformException(code: 'NOTIFICATIONS_DISABLED');
        if (startError != null) throw startError!;
        running = true;
        enabled = true; // native persists the preference only after the service confirmed
        return true;
      case 'setOwner':
        return true;
      case 'drainEvents':
        return pending;
      case 'markResults':
        return {'updated': 0, 'ignored': 0};
      case 'stats':
        return stats;
      case 'stopMonitor':
        enabled = false; // an explicit stop always turns the preference off
        if (stopSucceeds) running = false;
        return stopSucceeds;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Native native;

  setUp(() {
    native = _Native();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'access_token': _session()});
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_channel, native.handle);
    m.setMockMethodCallHandler(_events, (_) async => null); // listen / cancel of the install-analysis stream
    DioClient().dio.httpClientAdapter = FakeAdapter((_) => jsonBody(404, {'detail': 'x'}));
  });

  tearDown(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_channel, null);
    m.setMockMethodCallHandler(_events, null);
  });

  AppMonitorService svc({bool notifications = true}) => AppMonitorService(
        requestNotificationPermission: () async => notifications,
        openAppSettingsHook: () async => true,
      );

  group('platform channel (AppMonitorService)', () {
    test('a confirmed start is reported as running', () async {
      final r = await svc().start();
      expect(r.running, isTrue);
      expect(r.failure, isNull);
      expect(native.calls, ['startMonitor']);
    });

    test('denied notification permission means the native service is never started', () async {
      final r = await svc(notifications: false).start();
      expect(r.running, isFalse);
      expect(r.failure, MonitorStartFailure.notificationPermissionDenied);
      expect(r.message, contains('Allow notifications'));
      expect(native.calls, isEmpty);
    });

    test('native NOTIFICATION_PERMISSION_DENIED (permission revoked after the check) is reported the same way', () async {
      native.startError = PlatformException(code: 'NOTIFICATION_PERMISSION_DENIED');
      final r = await svc().start();
      expect(r.running, isFalse);
      expect(r.failure, MonitorStartFailure.notificationPermissionDenied);
    });

    test('START_TIMEOUT and START_FAILED are distinct, plain failures and never "running"', () async {
      native.startError = PlatformException(code: 'START_TIMEOUT');
      var r = await svc().start();
      expect((r.running, r.failure), (false, MonitorStartFailure.timeout));
      native.startError = PlatformException(code: 'START_FAILED', message: 'SecurityException');
      r = await svc().start();
      expect((r.running, r.failure), (false, MonitorStartFailure.startFailed));
      expect(r.message!.contains('SecurityException'), isFalse); // no raw platform detail shown to the user
    });

    test('no native side (not Android, or a test host) is "unsupported", not a crash', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
      final r = await svc().start();
      expect((r.running, r.failure), (false, MonitorStartFailure.unsupported));
    });

    test('startMonitor (compat) is true only when confirmed', () async {
      expect(await svc().startMonitor(), isTrue);
      native.startError = PlatformException(code: 'START_FAILED');
      native.running = false;
      expect(await svc().startMonitor(), isFalse);
    });

    test('enforceVisibility: true only when monitoring was on and has just been paused; errors mean not paused', () async {
      native.enabled = true;
      native.notificationsVisible = false;
      expect(await svc().enforceVisibility(), isTrue);
      expect(await svc().enforceVisibility(), isFalse); // already off: nothing to do the second time
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
      expect(await svc().enforceVisibility(), isFalse);
    });

    test('NOTIFICATIONS_DISABLED from the native side is its own typed failure', () async {
      native.notificationsVisible = false;
      final r = await svc().start();
      expect((r.running, r.failure), (false, MonitorStartFailure.notificationsDisabled));
      expect(r.message, contains('App Install Monitor channel'));
    });

    test('isEnabled reports the native preference; unknown or unreadable is off', () async {
      native.enabled = true;
      expect(await svc().isEnabled(), isTrue);
      native.enabled = false;
      expect(await svc().isEnabled(), isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
      expect(await svc().isEnabled(), isFalse);
    });

    test('a confirmed start persists the preference and a stop clears it (native contract)', () async {
      await svc().start();
      expect(native.enabled, isTrue);
      await svc().stopMonitor();
      expect(native.enabled, isFalse);
    });

    test('stop and isRunning report exactly what the native side says; errors mean "not confirmed"', () async {
      native.running = true;
      expect(await svc().isRunning(), isTrue);
      expect(await svc().stopMonitor(), isTrue);
      expect(await svc().isRunning(), isFalse);
      native.stopSucceeds = false;
      expect(await svc().stopMonitor(), isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
      expect(await svc().isRunning(), isFalse); // unknown is never reported as running
    });

    test('starting twice is safe: both ask the native side, which owns the single-instance rule', () async {
      await svc().start();
      final second = await svc().start();
      expect(second.running, isTrue);
      expect(native.calls.where((c) => c == 'startMonitor').length, 2);
    });
  });

  group('screen: the UI only claims what the native service confirmed', () {
    Future<void> pump(WidgetTester t, {bool notifications = true, List<Override> overrides = const []}) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [appMonitorServiceProvider.overrideWithValue(svc(notifications: notifications)), ...overrides],
        child: const MaterialApp(home: AppMonitorScreen()),
      ));
      // As in the app: the session is restored and the native owner set before the screen is used.
      final c = ProviderScope.containerOf(t.element(find.byType(AppMonitorScreen)));
      c.read(monitorSyncProvider);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await t.pumpAndSettle();
    }

    testWidgets('failed, rejected and removed events are shown, with their reason codes', (t) async {
      native.stats = {
        'available': true,
        'historyFailed': 2,
        'historyRejected': 1,
        'lostFailed': 1,
        'lostRejected': 0,
        'lostUnsent': 3,
        'errorCodes': {'http_422': 2, 'bad_timestamp': 1},
      };
      await pump(t);
      expect(find.byKey(const Key('monitorProblems')), findsOneWidget);
      expect(find.textContaining('2 could not be synced'), findsOneWidget);
      expect(find.textContaining('1 were rejected'), findsOneWidget);
      expect(find.textContaining('4 were removed from this device'), findsOneWidget);
      expect(find.textContaining('http_422'), findsOneWidget);
    });

    testWidgets('a permanent endpoint problem (HTTP 404) is shown with its diagnostic code and the events stay queued', (t) async {
      native.pending = [
        {'client_event_id': 'e1', 'occurred_at': 1000, 'package_name': 'com.x', 'app_name': 'X', 'event_type': 'installed'},
      ];
      await pump(t); // DioClient is wired to answer 404 in setUp
      await t.tap(find.byIcon(Icons.sync));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('monitorEndpointProblem')), findsOneWidget);
      expect(find.textContaining('HTTP 404'), findsWidgets);
      expect(find.textContaining('Diagnostic code: http_404'), findsOneWidget);
      expect(find.textContaining('saved on this device'), findsWidgets);
    });

    testWidgets('an endpoint problem recorded before a restart is shown on launch, with no sync needed', (t) async {
      SharedPreferences.setMockInitialValues({
        restrictionKey: restrictionBlob('http_404', DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch),
      });
      await pump(t);
      expect(find.byKey(const Key('monitorEndpointProblem')), findsOneWidget);
      expect(find.textContaining('Diagnostic code: http_404'), findsOneWidget);
    });

    testWidgets('unreadable saved sync settings: a clear diagnostic is shown while sync stays paused', (t) async {
      final failing = MonitorSyncCoordinator(preferences: () async => throw PlatformException(code: 'prefs_read_failed'));
      await pump(t, overrides: [monitorSyncProvider.overrideWithValue(failing)]);
      expect(find.byKey(const Key('monitorStorageProblem')), findsOneWidget);
      expect(find.textContaining('Sync is paused'), findsOneWidget);
      expect(find.textContaining('Diagnostic code: prefs_unreadable'), findsOneWidget);
      expect(find.textContaining('nothing was discarded'), findsOneWidget);
    });

    testWidgets('no storage diagnostic is shown when the settings read fine', (t) async {
      await pump(t);
      expect(find.byKey(const Key('monitorStorageProblem')), findsNothing);
    });

    testWidgets('a restriction that could not be SAVED shows a clear diagnostic and keeps sync paused', (t) async {
      native.pending = [
        {'client_event_id': 'e1', 'occurred_at': 1000, 'package_name': 'com.x', 'app_name': 'X', 'event_type': 'installed'},
      ];
      final prefs = await t.runAsync(() async => FlakyPrefs(await SharedPreferences.getInstance()));
      prefs!.refuseWrites = true;
      final coordinator = MonitorSyncCoordinator(
        dio: () => dioWith(FakeAdapter((_) => jsonBody(404, {'detail': 'x'}))),
        preferences: () async => prefs,
      );
      await t.runAsync(() => coordinator.setOwner('user-1'));
      await pump(t, overrides: [monitorSyncProvider.overrideWithValue(coordinator)]);
      await t.tap(find.byIcon(Icons.sync));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('monitorWriteProblem')), findsOneWidget);
      expect(find.textContaining('Diagnostic code: prefs_write_failed'), findsOneWidget);
      expect(find.textContaining('could not save a sync restriction'), findsWidgets); // the card, and the message after Sync
      // saving works again: the next trigger saves it and the write diagnostic goes away
      prefs.refuseWrites = false;
      await t.tap(find.byIcon(Icons.sync));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('monitorWriteProblem')), findsNothing);
      expect(find.byKey(const Key('monitorEndpointProblem')), findsOneWidget);
    });

    testWidgets('a damaged-and-reset event database is reported', (t) async {
      native.stats = {'available': true, 'dbRecoveries': 2};
      await pump(t);
      expect(find.textContaining('reset 2 time(s)'), findsOneWidget);
    });

    testWidgets('nothing about problems is shown when there are none', (t) async {
      native.stats = {'available': true, 'historyFailed': 0, 'historyRejected': 0, 'lostFailed': 0, 'lostRejected': 0, 'lostUnsent': 0};
      await pump(t);
      expect(find.byKey(const Key('monitorProblems')), findsNothing);
    });

    testWidgets('shows OFF and the disclosure before anything is started', (t) async {
      await pump(t);
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(find.byKey(const Key('monitorDisclosure')), findsOneWidget);
      expect(find.textContaining('uploaded to your SecureShield account'), findsOneWidget);
      expect(find.textContaining('notification stays visible'), findsOneWidget);
      expect(native.calls, ['enforceVisibility', 'isRunning', 'isEnabled']);
    });

    testWidgets('already running natively on open: shows Active (state is read, not assumed)', (t) async {
      native.running = true;
      await pump(t);
      expect(find.text('Monitor Active'), findsOneWidget);
    });

    testWidgets('left ON but the process was killed: the service is restored on open, and shown Active only once it runs', (t) async {
      native.enabled = true;
      native.running = false;
      await pump(t);
      expect(native.calls, containsAllInOrder(['enforceVisibility', 'isRunning', 'isEnabled', 'startMonitor']));
      expect(find.text('Monitor Active'), findsOneWidget);
    });

    testWidgets('left ON but the restore is impossible (notifications off): preference is turned OFF and the screen says Off', (t) async {
      native.enabled = true;
      native.running = false;
      await pump(t, notifications: false);
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(native.enabled, isFalse); // fail to off, never "on but invisible"
      expect(native.calls.contains('startMonitor'), isFalse);
      expect(native.calls, contains('stopMonitor'));
      expect(find.byKey(const Key('monitorError')), findsOneWidget);
    });

    testWidgets('revoked while monitoring was ON: opening the app shows PAUSED, Off, and starts nothing', (t) async {
      native.enabled = true;
      native.running = true;
      native.notificationsVisible = false; // permission revoked or the monitor channel disabled
      await pump(t);
      expect(find.byKey(const Key('monitorPaused')), findsOneWidget);
      expect(find.textContaining('Nothing is being monitored'), findsOneWidget);
      expect(find.byKey(const Key('monitorPausedOpenSettings')), findsOneWidget);
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(native.enabled, isFalse);
      expect(native.calls.contains('startMonitor'), isFalse); // no restore attempt after a pause
      expect(native.preferenceWrites, 1);
    });

    testWidgets('resume after the user revoked notifications in Settings pauses the monitor', (t) async {
      native.enabled = true;
      native.running = true;
      await pump(t);
      expect(find.text('Monitor Active'), findsOneWidget);
      native.notificationsVisible = false; // the user went to Settings and turned notifications off
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(find.byKey(const Key('monitorPaused')), findsOneWidget);
    });

    testWidgets('repeated resumes after a pause do not repeat the stop or the preference write', (t) async {
      native.enabled = true;
      native.running = true;
      native.notificationsVisible = false;
      await pump(t);
      for (var i = 0; i < 3; i++) {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
      }
      expect(native.preferenceWrites, 1); // only the first check changed anything
    });

    testWidgets('notifications restored: the user starts the monitor again and the pause message clears', (t) async {
      native.enabled = true;
      native.running = true;
      native.notificationsVisible = false;
      await pump(t);
      expect(find.byKey(const Key('monitorPaused')), findsOneWidget);
      native.notificationsVisible = true;
      await t.tap(find.text('Start Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Active'), findsOneWidget);
      expect(find.byKey(const Key('monitorPaused')), findsNothing);
    });

    testWidgets('monitor channel disabled at start: the service refuses, the screen says why and stays Off', (t) async {
      await pump(t);
      native.notificationsVisible = false;
      await t.tap(find.text('Start Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(find.textContaining('App Install Monitor channel'), findsOneWidget);
      expect(find.byKey(const Key('monitorOpenSettings')), findsOneWidget);
    });

    testWidgets('preference off and service off: nothing is started on open', (t) async {
      await pump(t);
      expect(native.calls.contains('startMonitor'), isFalse);
      expect(find.text('Monitor Off'), findsOneWidget);
    });

    testWidgets('while the start is pending nothing says Active; Active appears only after confirmation', (t) async {
      await pump(t);
      native.startGate = Completer<void>();
      await t.tap(find.text('Start Monitor'));
      await t.pump();
      expect(find.text('Monitor Active'), findsNothing);
      expect(find.text('Monitor Off'), findsOneWidget);
      native.startGate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Monitor Active'), findsOneWidget);
    });

    testWidgets('notification permission denied: stays Off, explains why, offers settings, starts nothing', (t) async {
      await pump(t, notifications: false);
      await t.tap(find.text('Start Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(find.byKey(const Key('monitorError')), findsOneWidget);
      expect(find.textContaining('Allow notifications'), findsOneWidget);
      expect(find.byKey(const Key('monitorOpenSettings')), findsOneWidget);
      expect(native.calls.contains('startMonitor'), isFalse);
    });

    testWidgets('a platform failure leaves it Off with a plain message', (t) async {
      await pump(t);
      native.startError = PlatformException(code: 'START_FAILED');
      await t.tap(find.text('Start Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Off'), findsOneWidget);
      expect(find.textContaining('Android refused to start the monitor'), findsOneWidget);
      expect(find.byKey(const Key('monitorOpenSettings')), findsNothing);
    });

    testWidgets('stop: the screen shows what the native side reports afterwards', (t) async {
      native.running = true;
      await pump(t);
      await t.tap(find.text('Stop Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Off'), findsOneWidget);
    });

    testWidgets('if the native side did not stop, the screen keeps saying Active', (t) async {
      native.running = true;
      native.stopSucceeds = false;
      await pump(t);
      await t.tap(find.text('Stop Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Active'), findsOneWidget);
    });

    testWidgets('stopped from the notification while in the background: resuming the app corrects the screen', (t) async {
      native.running = true;
      await pump(t);
      expect(find.text('Monitor Active'), findsOneWidget);
      native.running = false; // the user tapped Stop on the notification, or the process was killed
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('Monitor Off'), findsOneWidget);
    });

    testWidgets('works offline: starting needs no network, a failed sync does not change the state', (t) async {
      await pump(t);
      await t.tap(find.text('Start Monitor'));
      await t.pumpAndSettle();
      expect(find.text('Monitor Active'), findsOneWidget); // the fake server answers 404 to every sync call
    });
  });
}

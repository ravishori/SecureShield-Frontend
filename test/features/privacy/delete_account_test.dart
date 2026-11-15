import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/features/app_monitor/monitor_sync_coordinator.dart';
import 'package:secureshield_app/features/auth/auth_provider.dart';
import 'package:secureshield_app/features/auth/identity_api.dart';
import 'package:secureshield_app/features/privacy/privacy_api.dart';
import 'package:secureshield_app/features/privacy/screens/delete_account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/fake_http.dart';

class _FakePrivacy implements PrivacyApi {
  final List<String> calls = [];
  Object? startError;
  Completer<void>? deleteGate; // lets a test hold the request open
  final List<Object?> deleteOutcomes = []; // null = success, otherwise thrown
  @override
  Future<DeletionStart> startDeletion() async {
    calls.add('start');
    if (startError != null) throw startError!;
    return const DeletionStart('sent', 'r***@example.com');
  }

  @override
  Future<void> deleteAccount(String code) async {
    calls.add('delete:$code');
    if (deleteGate != null) await deleteGate!.future;
    final outcome = deleteOutcomes.isEmpty ? null : deleteOutcomes.removeAt(0);
    if (outcome != null) throw outcome;
  }

  @override
  Future<ConsentSnapshot> getConsents() => throw UnimplementedError();
  @override
  Future<ConsentSnapshot> putConsent(String p, bool g, String v) => throw UnimplementedError();
}

class _FakeAuth extends AuthNotifier {
  int cleared = 0;
  final List<String> order;
  _FakeAuth(this.order);
  @override
  Future<void> clearAllLocalData() async {
    cleared++;
    order.add('cleared');
  }
}

class _FakeSync extends MonitorSyncCoordinator {
  final List<String> order;
  _FakeSync(this.order);
  @override
  Future<bool> purgeAll() async {
    order.add('purged');
    return purgeOk;
  }

  bool purgeOk = true;
}

void main() {
  late _FakePrivacy api;
  late _FakeAuth auth;
  late List<String> order;
  late _FakeSync sync;

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 2200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    order = [];
    sync = _FakeSync(order);
    api = _FakePrivacy();
    auth = _FakeAuth(order);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const DeleteAccountScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const Scaffold(body: Text('WELCOME'))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        privacyApiProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => auth),
        monitorSyncProvider.overrideWithValue(sync),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
  }

  Future<void> toCodeStep(WidgetTester t) async {
    await t.ensureVisible(find.byKey(const Key('understoodCheckbox')));
    await t.tap(find.byKey(const Key('understoodCheckbox')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('sendDeletionCode')));
    await t.tap(find.byKey(const Key('sendDeletionCode')));
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, {String code = '123456', String typed = 'DELETE'}) async {
    await t.enterText(find.byKey(const Key('deletionCodeField')), code);
    await t.enterText(find.byKey(const Key('typeDeleteField')), typed);
    await t.pump();
  }

  bool confirmEnabled(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const Key('confirmDeletion'))).onPressed != null;

  testWidgets('explains what is deleted and what is kept, and nothing can be sent before "I understand"', (t) async {
    await pump(t);
    expect(find.byKey(const Key('deletedList')), findsOneWidget);
    expect(find.byKey(const Key('keptList')), findsOneWidget);
    expect(find.textContaining('audit trail'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('sendDeletionCode'))).onPressed, isNull);
    expect(api.calls, isEmpty);
  });

  testWidgets('step 1 sends a code and states that nothing has been deleted yet', (t) async {
    await pump(t);
    await toCodeStep(t);
    expect(api.calls, ['start']);
    expect(find.byKey(const Key('codeSentNote')), findsOneWidget);
    expect(find.textContaining('Nothing has been deleted yet'), findsOneWidget);
    expect(find.textContaining('r***@example.com'), findsOneWidget);
  });

  testWidgets('deletion needs the code AND the exact word DELETE (prevents accidental deletion)', (t) async {
    await pump(t);
    await toCodeStep(t);
    expect(confirmEnabled(t), isFalse);
    await fill(t, code: '123456', typed: 'delete');
    expect(confirmEnabled(t), isFalse); // wrong case
    await fill(t, code: '123456', typed: 'DELETE ');
    expect(confirmEnabled(t), isFalse); // trailing space
    await fill(t, code: '12', typed: 'DELETE');
    expect(confirmEnabled(t), isFalse); // code too short
    await fill(t);
    expect(confirmEnabled(t), isTrue);
    expect(api.calls, ['start']); // still nothing deleted
  });

  testWidgets('success is shown and local data cleared ONLY after the server confirms', (t) async {
    await pump(t);
    api.deleteGate = Completer<void>();
    await toCodeStep(t);
    await fill(t);
    await t.ensureVisible(find.byKey(const Key('confirmDeletion')));
    await t.tap(find.byKey(const Key('confirmDeletion')));
    await t.pump();
    // request in flight: no success message, nothing cleared, button busy
    expect(find.text('Your account has been deleted.'), findsNothing);
    expect(auth.cleared, 0);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(confirmEnabled(t), isFalse); // cannot be double-submitted
    api.deleteGate!.complete();
    await t.pumpAndSettle();
    expect(api.calls.where((c) => c.startsWith('delete:')).length, 1);
    expect(auth.cleared, 1);
    expect(order, ['purged', 'cleared']); // the native monitor events go first, only after the server confirmed
    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  testWidgets('if the device data could NOT be purged the person is told, never "deleted" alone', (t) async {
    await pump(t);
    sync.purgeOk = false;
    await toCodeStep(t);
    await fill(t);
    await t.ensureVisible(find.byKey(const Key('confirmDeletion')));
    await t.tap(find.byKey(const Key('confirmDeletion')));
    await t.pumpAndSettle();
    expect(find.textContaining('could not be removed from this device'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsNothing);
    expect(order, ['purged', 'cleared']); // the session is still wiped
  });

  testWidgets('a server failure keeps the account, shows the error, clears nothing, and can be retried', (t) async {
    await pump(t);
    api.deleteOutcomes.add(const IdentityFailure(IdentityErrorKind.unavailable, 'We could not complete that right now.'));
    await toCodeStep(t);
    await fill(t);
    await t.ensureVisible(find.byKey(const Key('confirmDeletion')));
    await t.tap(find.byKey(const Key('confirmDeletion')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('deleteError')), findsOneWidget);
    expect(auth.cleared, 0);
    expect(find.text('WELCOME'), findsNothing);
    expect(find.text('Your account has been deleted.'), findsNothing);
    expect(confirmEnabled(t), isTrue); // retry is possible with the same code
    await t.tap(find.byKey(const Key('confirmDeletion')));
    await t.pumpAndSettle();
    expect(auth.cleared, 1);
    expect(find.text('WELCOME'), findsOneWidget);
  });

  testWidgets('a wrong or expired code is reported and the field is cleared for a new attempt', (t) async {
    await pump(t);
    api.deleteOutcomes.add(const IdentityFailure(IdentityErrorKind.invalidCode, 'That code is invalid or has expired.'));
    await toCodeStep(t);
    await fill(t);
    await t.ensureVisible(find.byKey(const Key('confirmDeletion')));
    await t.tap(find.byKey(const Key('confirmDeletion')));
    await t.pumpAndSettle();
    expect(find.text('That code is invalid or has expired.'), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const Key('deletionCodeField'))).controller!.text, '');
    expect(auth.cleared, 0);
    await t.ensureVisible(find.byKey(const Key('resendDeletionCode')));
    await t.tap(find.byKey(const Key('resendDeletionCode')));
    await t.pumpAndSettle();
    expect(api.calls.where((c) => c == 'start').length, 2);
  });

  testWidgets('offline when asking for the code: error shown, stays on step 1', (t) async {
    await pump(t);
    await t.ensureVisible(find.byKey(const Key('understoodCheckbox')));
    await t.tap(find.byKey(const Key('understoodCheckbox')));
    await t.pump();
    api.startError = const IdentityFailure(IdentityErrorKind.offline, 'No connection. Check your internet and try again.');
    await t.ensureVisible(find.byKey(const Key('sendDeletionCode')));
    await t.tap(find.byKey(const Key('sendDeletionCode')));
    await t.pumpAndSettle();
    expect(find.textContaining('No connection'), findsOneWidget);
    expect(find.byKey(const Key('deletionCodeField')), findsNothing);
    expect(auth.cleared, 0);
  });

  testWidgets('an account with no verified contact is told what to do (409 message from the server)', (t) async {
    await pump(t);
    await t.ensureVisible(find.byKey(const Key('understoodCheckbox')));
    await t.tap(find.byKey(const Key('understoodCheckbox')));
    await t.pump();
    api.startError = const IdentityFailure(
        IdentityErrorKind.claimed, 'Verify your email address or phone number before deleting your account.');
    await t.ensureVisible(find.byKey(const Key('sendDeletionCode')));
    await t.tap(find.byKey(const Key('sendDeletionCode')));
    await t.pumpAndSettle();
    expect(find.textContaining('Verify your email address'), findsOneWidget);
  });

  testWidgets('cancel leaves everything as it was', (t) async {
    await pump(t);
    await t.ensureVisible(find.byKey(const Key('cancelDeletion')));
    await t.tap(find.byKey(const Key('cancelDeletion')));
    await t.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(auth.cleared, 0);
  });

  group('PrivacyApi (real client against a recorded fake server)', () {
    PrivacyApi apiFor(FakeAdapter a) => PrivacyApi(dio: dioWith(a));

    test('start posts nothing sensitive; delete sends the literal confirmation and the code', () async {
      final a = FakeAdapter((o) => o.method == 'DELETE'
          ? jsonBody(200, {'message': 'ok', 'user_id': 'u', 'scrubbed_at': '2026-11-14T00:00:00', 'retained': []})
          : jsonBody(200, {'message': 'sent', 'identifier': 'r***@example.com'}));
      final p = apiFor(a);
      final s = await p.startDeletion();
      expect(s.maskedIdentifier, 'r***@example.com');
      await p.deleteAccount('123456');
      expect(a.requests[0].method, 'POST');
      expect(a.requests[0].path, '/auth/me/delete/start');
      expect(a.requests[1].method, 'DELETE');
      expect(a.requests[1].path, '/auth/me');
      expect(a.requests[1].data, {'confirm': 'DELETE', 'code': '123456'});
    });

    Future<IdentityFailure> failure(int status) async {
      try {
        await apiFor(FakeAdapter((_) => jsonBody(status, {'detail': 'x'}))).deleteAccount('123456');
      } on IdentityFailure catch (f) {
        return f;
      }
      fail('expected a failure');
    }

    test('every non-200 outcome is a failure, never a silent success', () async {
      expect((await failure(400)).kind, IdentityErrorKind.invalidCode);
      expect((await failure(401)).kind, IdentityErrorKind.sessionExpired);
      expect((await failure(403)).kind, isNot(isNull));
      expect((await failure(409)).kind, IdentityErrorKind.claimed);
      expect((await failure(429)).kind, IdentityErrorKind.rateLimited);
      expect((await failure(500)).kind, IdentityErrorKind.unavailable);
    });
  });

  group('local session cleanup', () {
    test('after a confirmed deletion tokens, secure storage and preferences are wiped', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({
        'access_token': fakeJwt({'sub': 'u1', 'identifier': 'a@b.com', 'exp': 4102444800}),
        'refresh_token': 'refresh-value',
        'pending_registration_email': 'a@b.com',
        'otp_vault_key': 'vault-secret',
      });
      SharedPreferences.setMockInitialValues({'locale': 'hi', 'senior_mode': true});
      DioClient().dio.httpClientAdapter = FakeAdapter((_) => jsonBody(404, {}));
      final n = AuthNotifier(googleSignIn: () async => null, googleSignOut: () async {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(n.state.isAuthenticated, isTrue);
      await n.clearAllLocalData();
      const s = FlutterSecureStorage();
      expect(await s.readAll(), isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(n.state.isAuthenticated, isFalse);
    });
  });
}

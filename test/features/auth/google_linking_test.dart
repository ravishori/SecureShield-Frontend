import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/constants.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/core/security/google_auth_service.dart';
import 'package:secureshield_app/features/auth/auth_provider.dart';
import 'package:secureshield_app/features/privacy/consent_choices.dart';

import 'fake_http.dart';

// Unit-level coverage of the client side of Google sign-in / account linking. The real Google SDK and the real
// provider are NOT exercised here (they need a device, an OAuth client and a Google account): the Google result is
// injected and the backend is replaced by a recorded fake. The backend rules themselves are tested server-side.
const _idToken = 'google-id-token-SECRET-VALUE';
const _accessJwtClaims = {'sub': 'user-9', 'identifier': 'rae@example.com'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter adapter;
  ResponseBody Function(RequestOptions)? googleRoute;
  const storage = FlutterSecureStorage();
  var signOuts = 0;
  var chooserCalls = 0;
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  GoogleSignInResult google({String? email = 'rae@example.com'}) =>
      GoogleSignInResult(idToken: _idToken, email: email, displayName: 'Rae', photoUrl: 'http://p/x.png');

  Future<AuthNotifier> notifier({GoogleSignInResult? result, bool cancelled = false}) async {
    final n = AuthNotifier(
      googleSignIn: () async {
        chooserCalls++;
        return cancelled ? null : (result ?? google());
      },
      googleSignOut: () async => signOuts++,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return n;
  }

  Map<String, dynamic> tokens({bool phoneVerified = false}) => {
        'access_token': fakeJwt(_accessJwtClaims),
        'refresh_token': 'refresh-token-value',
        'email_verified': true,
        'phone_verified': phoneVerified,
      };

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    signOuts = 0;
    chooserCalls = 0;
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
    googleRoute = null;
    adapter = FakeAdapter((o) {
      if (o.path == '/auth/google' && googleRoute != null) return googleRoute!(o);
      return jsonBody(404, {'detail': 'no route'});
    });
    DioClient().dio.httpClientAdapter = adapter;
  });

  tearDown(() => debugPrint = originalDebugPrint);

  test('links to a verified existing account: only the ID token is sent, the server decides the state', () async {
    googleRoute = (_) => jsonBody(200, tokens(phoneVerified: true));
    final n = await notifier();
    expect(await n.signInWithGoogle(), isTrue);
    final sent = adapter.requests.single.data as Map;
    expect(sent['id_token'], _idToken);
    // the client does not send (and so cannot assert) an e-mail, a user id or any ownership claim
    expect(sent.keys.where((k) => k != 'id_token' && !k.toString().startsWith('device')), isEmpty);
    expect(n.state.isAuthenticated, isTrue);
    expect(n.state.emailVerified, isTrue);
    expect(n.state.phoneVerified, isTrue); // taken from the response, not inferred
    expect(n.state.identifier, 'rae@example.com');
    expect(await storage.read(key: AppConstants.accessTokenKey), isNotNull);
  });

  test('the identity comes from the server token, never from the Google e-mail the client holds', () async {
    googleRoute = (_) => jsonBody(200, tokens());
    final n = await notifier(result: google(email: 'attacker-claim@example.com'));
    await n.signInWithGoogle();
    expect(n.state.identifier, 'rae@example.com');
    expect(n.state.identifier, isNot('attacker-claim@example.com'));
  });

  test('an unverified Google e-mail is rejected by the server (401): no session, Google signed out', () async {
    googleRoute = (_) => jsonBody(401, {'detail': 'Google sign-in could not be verified.'});
    final n = await notifier();
    expect(await n.signInWithGoogle(), isFalse);
    expect(n.state.isAuthenticated, isFalse);
    expect(n.state.isLoading, isFalse);
    expect(n.state.error, isNotNull);
    expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
    expect(signOuts, 1);
  });

  test('a conflicting Google subject (409) shows the server message and starts no session', () async {
    googleRoute = (_) =>
        jsonBody(409, {'detail': 'This account is already linked to a different Google account.'});
    final n = await notifier();
    expect(await n.signInWithGoogle(), isFalse);
    expect(n.state.error, contains('different Google account'));
    expect(n.state.isAuthenticated, isFalse);
    expect(signOuts, 1);
  });

  test('a legacy account with an unverified identifier (409) is refused and not linked', () async {
    googleRoute = (_) => jsonBody(409, {
          'detail': 'This identifier is on an existing account but has not been verified.',
        });
    final n = await notifier();
    expect(await n.signInWithGoogle(), isFalse);
    expect(n.state.error, contains('not been verified'));
    expect(await storage.read(key: AppConstants.refreshTokenKey), isNull);
  });

  test('an expired session or token during linking (401) leaves the user signed out', () async {
    googleRoute = (_) => jsonBody(401, {'detail': 'expired'});
    final n = await notifier();
    expect(await n.signInWithGoogle(), isFalse);
    expect(n.state.isAuthenticated, isFalse);
    expect(n.state.error, contains('Session expired'));
  });

  test('a network failure is reported and nothing is stored', () async {
    googleRoute = (o) => throw DioException(requestOptions: o, type: DioExceptionType.badCertificate);
    final n = await notifier();
    expect(await n.signInWithGoogle(), isFalse);
    expect(n.state.isAuthenticated, isFalse);
    expect(n.state.isLoading, isFalse);
    expect(n.state.error, isNotNull);
    expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
  });

  test('a server error (500) never leaks its detail to the user', () async {
    googleRoute = (_) => jsonBody(500, {'detail': 'secret stack trace'});
    final n = await notifier();
    expect(await n.signInWithGoogle(), isFalse);
    expect((n.state.error ?? '').contains('secret'), isFalse);
  });

  test('cancelling the Google chooser makes no request and changes nothing', () async {
    final n = await notifier(cancelled: true);
    expect(await n.signInWithGoogle(), isFalse);
    expect(adapter.requests, isEmpty);
    expect(n.state.isAuthenticated, isFalse);
    expect(n.state.error, isNull);
  });

  test('an existing signed-in session is preserved when a later Google attempt fails', () async {
    await storage.write(key: AppConstants.accessTokenKey, value: fakeJwt({..._accessJwtClaims, 'exp': 4102444800}));
    final n = await notifier();
    expect(n.state.isAuthenticated, isTrue);
    googleRoute = (_) => jsonBody(409, {'detail': 'conflict'});
    expect(await n.signInWithGoogle(), isFalse);
    expect(await storage.read(key: AppConstants.accessTokenKey), isNotNull); // tokens are not wiped by a failed link
  });

  test('no token, ID token or e-mail is written to the logs, on success or failure', () async {
    googleRoute = (_) => jsonBody(200, tokens());
    var n = await notifier();
    await n.signInWithGoogle();
    googleRoute = (_) => jsonBody(409, {'detail': 'conflict'});
    n = await notifier();
    await n.signInWithGoogle();
    final all = logs.join('\n');
    expect(all.contains(_idToken), isFalse);
    expect(all.contains('refresh-token-value'), isFalse);
    expect(all.contains('rae@example.com'), isFalse);
  });

  group('creating an account through Google needs consent', () {
    const choices = ConsentChoices(termsVersion: '2026-11-14', privacyVersion: '2026-11-14', aiProcessing: false);

    ResponseBody Function(RequestOptions) needsConsent() => (o) {
          final c = (o.data as Map)['consent'];
          if (c == null) {
            return ResponseBody.fromString(
              '{"detail":"consent required"}',
              422,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'x-consent-error': ['consent_required'],
              },
            );
          }
          return jsonBody(200, tokens());
        };

    test('without consent the server refuses; the app asks for it and does not sign out of Google', () async {
      googleRoute = needsConsent();
      final n = await notifier();
      expect(await n.signInWithGoogle(), isFalse);
      expect(n.state.consentRequired, isTrue);
      expect(n.state.isAuthenticated, isFalse);
      expect(n.state.error, isNull); // a prompt, not an error
      expect(signOuts, 0);
      expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
    });

    test('the retry sends the choices and reuses the Google result (the chooser does not reopen)', () async {
      googleRoute = needsConsent();
      final n = await notifier();
      await n.signInWithGoogle();
      expect(await n.signInWithGoogle(consent: choices), isTrue);
      expect(chooserCalls, 1);
      expect(adapter.requests.length, 2);
      final second = adapter.requests.last.data as Map;
      expect(second['id_token'], _idToken);
      expect(second['consent'], choices.toJson());
      expect(n.state.isAuthenticated, isTrue);
      expect(n.state.consentRequired, isFalse);
    });

    test('declining the consent screen leaves the user signed out and nothing is stored', () async {
      googleRoute = needsConsent();
      final n = await notifier();
      await n.signInWithGoogle();
      expect(n.state.isAuthenticated, isFalse);
      expect(await storage.read(key: AppConstants.refreshTokenKey), isNull);
    });

    test('a different failure on the retry (409 conflict) is shown as an error and ends the attempt', () async {
      var first = true;
      googleRoute = (o) {
        if (first) {
          first = false;
          return needsConsent()(o);
        }
        return jsonBody(409, {'detail': 'This account is already linked to a different Google account.'});
      };
      final n = await notifier();
      await n.signInWithGoogle();
      expect(await n.signInWithGoogle(consent: choices), isFalse);
      expect(n.state.error, contains('different Google account'));
      expect(n.state.consentRequired, isFalse);
      expect(signOuts, 1);
    });
  });
}

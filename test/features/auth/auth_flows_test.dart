import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/constants.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/features/auth/auth_provider.dart';
import 'package:secureshield_app/features/privacy/consent_choices.dart';

import 'fake_http.dart';

const _consent = ConsentChoices(termsVersion: '2026-11-14', privacyVersion: '2026-11-14', aiProcessing: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter adapter;
  late Map<String, ResponseBody Function(RequestOptions)> routes;
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    routes = {};
    adapter = FakeAdapter((o) {
      final h = routes['${o.method} ${o.path}'];
      if (h == null) return jsonBody(404, {'detail': 'no route ${o.path}'});
      return h(o);
    });
    DioClient().dio.httpClientAdapter = adapter;
  });

  Future<AuthNotifier> notifier() async {
    final n = AuthNotifier();
    await Future<void>.delayed(const Duration(milliseconds: 20)); // startup auth check
    return n;
  }

  Map<String, dynamic> tokens({bool phoneVerified = false, String? nextStep}) => {
        'access_token': fakeJwt({'sub': 'user-1', 'identifier': 'rae@example.com'}),
        'refresh_token': 'refresh-token-value',
        'email_verified': true,
        'phone_verified': phoneVerified,
        if (nextStep != null) 'next_step': nextStep,
      };

  test('registering creates no session, keeps the e-mail pending, and shows the e-mail step', () async {
    routes['POST /auth/register'] = (_) => jsonBody(200, {
          'message': 'We sent a verification code to your email.',
          'identifier': 'r*e@example.com',
          'masked_email': 'r*e@example.com',
          'masked_phone': '+91*****210',
          'next_step': 'verify_email',
        });
    final n = await notifier();
    final r = await n.register(consent: _consent, firstName: 'Rae', email: 'rae@example.com', phone: '+919800000010');
    expect(r.nextStep, 'verify_email');
    expect(n.state.isAuthenticated, false);
    expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
    expect(await n.pendingRegistrationEmail(), 'rae@example.com'); // resumable
    expect(adapter.requests.single.data['email'], 'rae@example.com');
    // the consent the person gave travels with the registration (versions + the separate optional choice)
    expect(adapter.requests.single.data['consent'], {
      'terms_version': '2026-11-14',
      'privacy_version': '2026-11-14',
      'ai_processing': false,
    });
  });

  test('registration is impossible without consent: nothing is sent', () async {
    final n = await notifier();
    await expectLater(
      n.register(consent: null, firstName: 'Rae', email: 'rae@example.com', phone: '+919800000010'),
      throwsA(isA<StateError>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('a pending registration can be resumed: the resend goes to the e-mail only', () async {
    routes['POST /auth/send-otp'] =
        (_) => jsonBody(200, {'message': 'OTP sent successfully', 'identifier': 'r*e@example.com', 'method': 'auto'});
    final n = await notifier();
    await storage.write(key: AppConstants.pendingRegistrationEmailKey, value: 'rae@example.com');
    expect(await n.pendingRegistrationEmail(), 'rae@example.com');
    await n.sendOtp('rae@example.com');
    expect(adapter.requests.single.data, {'identifier': 'rae@example.com'});
  });

  test('verifying the registration code calls /register/verify and applies the server-driven state', () async {
    routes['POST /auth/register/verify'] = (_) => jsonBody(200, tokens(nextStep: 'verify_phone'));
    final n = await notifier();
    await storage.write(key: AppConstants.pendingRegistrationEmailKey, value: 'rae@example.com');
    await n.verifyOtp('rae@example.com', '123456', registration: true);
    expect(adapter.requests.single.path, '/auth/register/verify');
    expect(n.state.isAuthenticated, true);
    expect(n.state.emailVerified, true);
    expect(n.state.phoneVerified, false);
    expect(n.state.nextStep, 'verify_phone');
    expect(await n.pendingRegistrationEmail(), isNull); // cleared once the account exists
    expect(await storage.read(key: AppConstants.accessTokenKey), isNotNull);
  });

  test('a normal login code goes to /verify-otp, not /register/verify', () async {
    routes['POST /auth/verify-otp'] = (_) => jsonBody(200, tokens(phoneVerified: true));
    final n = await notifier();
    await n.verifyOtp('rae@example.com', '123456');
    expect(adapter.requests.single.path, '/auth/verify-otp');
    expect(n.state.isAuthenticated, true);
    expect(n.state.phoneVerified, true);
    expect(n.state.nextStep, isNull);
  });

  test('a wrong or expired code leaves the user signed out and shows the server message', () async {
    routes['POST /auth/verify-otp'] =
        (_) => jsonBody(400, {'detail': 'Invalid or expired OTP. Please request a new one.'});
    final n = await notifier();
    await expectLater(n.verifyOtp('rae@example.com', '000000'), throwsA(isA<DioException>()));
    expect(n.state.isAuthenticated, false);
    expect(n.state.error, contains('Invalid or expired OTP'));
  });

  test('signing in with an unverified phone on a legacy account is refused (409) and no session starts', () async {
    routes['POST /auth/verify-otp'] =
        (_) => jsonBody(409, {'detail': 'This phone number is not verified on the account it is attached to.'});
    final n = await notifier();
    await expectLater(n.verifyOtp('+919800000010', '123456'), throwsA(isA<DioException>()));
    expect(n.state.isAuthenticated, false);
    expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
    expect(n.state.error, isNotNull);
  });

  test('registering an address that already has an account surfaces the 409 message', () async {
    routes['POST /auth/register'] =
        (_) => jsonBody(409, {'detail': 'An account with this email already exists. Please login instead.'});
    final n = await notifier();
    await expectLater(
      n.register(consent: _consent, firstName: 'Rae', email: 'rae@example.com', phone: '+919800000010'),
      throwsA(isA<DioException>()),
    );
    expect(n.state.error, contains('already exists'));
    expect(await n.pendingRegistrationEmail(), isNull);
  });

  test('a transport failure during registration is reported and stores nothing', () async {
    routes['POST /auth/register'] =
        (o) => throw DioException(requestOptions: o, type: DioExceptionType.badCertificate);
    final n = await notifier();
    await expectLater(
      n.register(consent: _consent, firstName: 'Rae', email: 'rae@example.com', phone: '+919800000010'),
      throwsA(isA<DioException>()),
    );
    expect(n.state.isAuthenticated, false);
    expect(n.state.error, isNotNull);
    expect(await n.pendingRegistrationEmail(), isNull);
  });

  test('refreshVerification takes the flags from the server and drops the verify-phone prompt', () async {
    routes['POST /auth/register/verify'] = (_) => jsonBody(200, tokens(nextStep: 'verify_phone'));
    routes['GET /auth/me'] = (_) => jsonBody(200, {'email_verified': true, 'phone_verified': true});
    final n = await notifier();
    await n.verifyOtp('rae@example.com', '123456', registration: true);
    expect(n.state.phoneVerified, false);
    await n.refreshVerification();
    expect(n.state.phoneVerified, true);
    expect(n.state.nextStep, isNull);
  });

  test('if the server cannot be reached the verification state is not invented', () async {
    routes['POST /auth/register/verify'] = (_) => jsonBody(200, tokens(nextStep: 'verify_phone'));
    routes['GET /auth/me'] = (o) => throw DioException(requestOptions: o, type: DioExceptionType.badCertificate);
    final n = await notifier();
    await n.verifyOtp('rae@example.com', '123456', registration: true);
    await n.refreshVerification();
    expect(n.state.phoneVerified, false);
    expect(n.state.nextStep, 'verify_phone');
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/auth/identity_api.dart';

import 'fake_http.dart';

void main() {
  IdentityApi api(FakeAdapter a) => IdentityApi(dio: dioWith(a));

  test('phone start posts only the phone and returns the server-reported state', () async {
    final a = FakeAdapter((_) => jsonBody(200, {
          'message': 'Verification code sent.',
          'identifier': '+91*****210',
          'email_verified': true,
          'phone_verified': false,
        }));
    final r = await api(a).startPhoneVerification('+919800000010');
    expect(a.requests.single.path, '/auth/phone/add/start');
    expect(a.requests.single.data, {'phone': '+919800000010'});
    expect(r.phoneVerified, false);
    expect(r.emailVerified, true);
    expect(r.maskedIdentifier, '+91*****210');
  });

  test('phone confirm and e-mail change use their own endpoints and bodies', () async {
    final a = FakeAdapter((_) => jsonBody(200, {'message': 'ok', 'phone_verified': true}));
    final c = api(a);
    await c.confirmPhone('+919800000010', '123456');
    await c.startEmailChange('new@example.com');
    await c.confirmEmailChange('new@example.com', '654321');
    expect(a.requests.map((r) => r.path), [
      '/auth/phone/add/confirm',
      '/auth/email/change/start',
      '/auth/email/change/confirm',
    ]);
    expect(a.requests[0].data, {'phone': '+919800000010', 'code': '123456'});
    expect(a.requests[1].data, {'new_email': 'new@example.com'});
    expect(a.requests[2].data, {'new_email': 'new@example.com', 'code': '654321'});
  });

  Future<IdentityFailure> failureFor(ResponseBody Function(RequestOptions) h) async {
    try {
      await api(FakeAdapter(h)).confirmPhone('+919800000010', '123456');
    } on IdentityFailure catch (f) {
      return f;
    }
    fail('expected an IdentityFailure');
  }

  test('400 is an invalid/expired code and shows the server message', () async {
    final f = await failureFor((_) => jsonBody(400, {'detail': 'Invalid or expired OTP. Please request a new one.'}));
    expect(f.kind, IdentityErrorKind.invalidCode);
    expect(f.message, 'Invalid or expired OTP. Please request a new one.');
  });

  test('409 means another account holds it', () async {
    final f = await failureFor((_) => jsonBody(409, {'detail': 'This email address belongs to another account.'}));
    expect(f.kind, IdentityErrorKind.claimed);
    expect(f.message, contains('another account'));
  });

  test('429, 401, 422 and 5xx map to distinct kinds', () async {
    expect((await failureFor((_) => jsonBody(429, {'detail': 'x'}))).kind, IdentityErrorKind.rateLimited);
    expect((await failureFor((_) => jsonBody(401, {'detail': 'x'}))).kind, IdentityErrorKind.sessionExpired);
    expect((await failureFor((_) => jsonBody(422, {'detail': 'Enter a valid phone number'}))).kind, IdentityErrorKind.validation);
    expect((await failureFor((_) => jsonBody(503, {'detail': 'smtp down'}))).kind, IdentityErrorKind.unavailable);
  });

  test('a server detail on a 5xx is never shown to the user', () async {
    final f = await failureFor((_) => jsonBody(500, {'detail': 'stack trace secret'}));
    expect(f.message.contains('secret'), false);
  });

  test('no connection is reported as offline', () async {
    final f = await failureFor((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError));
    expect(f.kind, IdentityErrorKind.offline);
  });
}

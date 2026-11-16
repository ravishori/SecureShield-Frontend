import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/security/google_auth_service.dart';

void main() {
  test('without GOOGLE_WEB_CLIENT_ID the feature is off and nothing is attempted', () async {
    expect(kGoogleAuthEnabled, isFalse);
    expect(await GoogleAuthService.signIn(), isNull);
    await GoogleAuthService.signOut(); // must not throw
  });
}

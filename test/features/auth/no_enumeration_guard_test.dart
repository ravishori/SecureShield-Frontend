import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// F1-C03 guard: the login screen must not ask the server whether an account exists (that would re-create the
// enumeration oracle). Sign-in relies on /auth/send-otp, which answers the same for every identifier.
void main() {
  test('login screen and provider do not call the account-existence endpoint', () {
    final screen = File('lib/features/auth/screens/phone_screen.dart').readAsStringSync();
    final provider = File('lib/features/auth/auth_provider.dart').readAsStringSync();
    expect(screen.contains('checkUserExists'), isFalse);
    expect(provider.contains('checkUserExists'), isFalse);
    expect(provider.contains('AppConstants.checkUser'), isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:secureshield_app/features/auth/auth_provider.dart';
import 'package:secureshield_app/features/auth/identity_api.dart';
import 'package:secureshield_app/features/auth/screens/phone_verify_screen.dart';

class _FakeAuth extends AuthNotifier {
  int refreshed = 0;
  @override
  Future<void> refreshVerification() async => refreshed++;
}

class _FakeIdentity implements IdentityApi {
  final List<String> calls = [];
  Object? startError;
  Object? confirmError;

  @override
  Future<IdentityState> startPhoneVerification(String phone) async {
    calls.add('start:$phone');
    if (startError != null) throw startError!;
    return const IdentityState(maskedIdentifier: '+91*****210', message: 'sent');
  }

  @override
  Future<IdentityState> confirmPhone(String phone, String code) async {
    calls.add('confirm:$phone:$code');
    if (confirmError != null) throw confirmError!;
    return const IdentityState(phoneVerified: true);
  }

  @override
  Future<IdentityState> startEmailChange(String newEmail) => throw UnimplementedError();
  @override
  Future<IdentityState> confirmEmailChange(String newEmail, String code) => throw UnimplementedError();
}

void main() {
  late _FakeIdentity api;
  late _FakeAuth auth;

  Future<void> pump(WidgetTester t) async {
    api = _FakeIdentity();
    auth = _FakeAuth();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const PhoneVerifyScreen()),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        identityApiProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
  }

  Future<void> sendCode(WidgetTester t) async {
    await t.enterText(find.byKey(const Key('phoneField')), '91 98000 00010');
    await t.tap(find.byKey(const Key('sendCodeButton')));
    await t.pumpAndSettle();
  }

  testWidgets('says the phone cannot be used to sign in until verified', (t) async {
    await pump(t);
    expect(find.byKey(const Key('phoneVerifyIntro')), findsOneWidget);
    expect(find.textContaining('cannot be used to log in'), findsOneWidget);
    expect(find.byKey(const Key('codeField')), findsNothing);
  });

  testWidgets('rejects an obviously invalid number without calling the server', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const Key('phoneField')), '12');
    await t.tap(find.byKey(const Key('sendCodeButton')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('phoneVerifyError')), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('sends the code to the normalised number, verifies, and re-reads state from the server', (t) async {
    await pump(t);
    await sendCode(t);
    expect(api.calls, ['start:+919800000010']);
    expect(find.byKey(const Key('codeSentTo')), findsOneWidget);
    await t.enterText(find.byKey(const Key('codeField')), '123456');
    await t.tap(find.byKey(const Key('confirmCodeButton')));
    await t.pumpAndSettle();
    expect(api.calls.last, 'confirm:+919800000010:123456');
    expect(auth.refreshed, 1); // server-driven: the screen asks the server instead of assuming
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a wrong or expired code shows the error and clears the field', (t) async {
    await pump(t);
    await sendCode(t);
    api.confirmError = const IdentityFailure(IdentityErrorKind.invalidCode, 'That code is invalid or has expired.');
    await t.enterText(find.byKey(const Key('codeField')), '000000');
    await t.tap(find.byKey(const Key('confirmCodeButton')));
    await t.pumpAndSettle();
    expect(find.text('That code is invalid or has expired.'), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const Key('codeField'))).controller!.text, '');
    expect(find.text('HOME'), findsNothing);
    expect(auth.refreshed, 0);
  });

  testWidgets('a number that belongs to another account returns to number entry', (t) async {
    await pump(t);
    api.startError = const IdentityFailure(IdentityErrorKind.claimed, 'This phone number belongs to another account.');
    await sendCode(t);
    expect(find.text('This phone number belongs to another account.'), findsOneWidget);
    expect(find.byKey(const Key('codeField')), findsNothing);
    expect(find.byKey(const Key('sendCodeButton')), findsOneWidget);
  });

  testWidgets('offline: shows the connection message and stays on the screen', (t) async {
    await pump(t);
    api.startError =
        const IdentityFailure(IdentityErrorKind.offline, 'No connection. Check your internet and try again.');
    await sendCode(t);
    expect(find.textContaining('No connection'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('resend is blocked during the cooldown, and verification can be skipped for later', (t) async {
    await pump(t);
    await sendCode(t);
    expect(t.widget<TextButton>(find.byKey(const Key('resendButton'))).onPressed, isNull);
    expect(find.textContaining('Resend code in'), findsOneWidget);
    await t.pump(const Duration(seconds: 31));
    expect(t.widget<TextButton>(find.byKey(const Key('resendButton'))).onPressed, isNotNull);
    await t.tap(find.byKey(const Key('skipButton')));
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/auth/identity_api.dart';
import 'package:secureshield_app/features/auth/screens/phone_verify_screen.dart' show identityApiProvider;
import 'package:secureshield_app/features/profile/widgets/email_change_dialog.dart';

class _FakeIdentity implements IdentityApi {
  final List<String> calls = [];
  Object? startError;
  Object? confirmError;

  @override
  Future<IdentityState> startEmailChange(String newEmail) async {
    calls.add('start:$newEmail');
    if (startError != null) throw startError!;
    return const IdentityState(message: 'sent');
  }

  @override
  Future<IdentityState> confirmEmailChange(String newEmail, String code) async {
    calls.add('confirm:$newEmail:$code');
    if (confirmError != null) throw confirmError!;
    return const IdentityState(emailVerified: true);
  }

  @override
  Future<IdentityState> startPhoneVerification(String phone) => throw UnimplementedError();
  @override
  Future<IdentityState> confirmPhone(String phone, String code) => throw UnimplementedError();
}

void main() {
  late _FakeIdentity api;
  bool? result;

  Future<void> open(WidgetTester t) async {
    api = _FakeIdentity();
    result = null;
    await t.pumpWidget(ProviderScope(
      overrides: [identityApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () async => result = await showEmailChangeDialog(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.byKey(const Key('open')));
    await t.pumpAndSettle();
  }

  testWidgets('step 1 asks for the new address and says the old one stays active', (t) async {
    await open(t);
    expect(find.textContaining('current email stays active'), findsOneWidget);
    expect(find.byKey(const Key('emailCodeField')), findsNothing);
  });

  testWidgets('an invalid address is rejected locally', (t) async {
    await open(t);
    await t.enterText(find.byKey(const Key('newEmailField')), 'not-an-email');
    await t.tap(find.byKey(const Key('emailChangeSend')));
    await t.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('an address claimed by another account is refused and no code step appears', (t) async {
    await open(t);
    api.startError =
        const IdentityFailure(IdentityErrorKind.claimed, 'This email address belongs to another account.');
    await t.enterText(find.byKey(const Key('newEmailField')), 'taken@example.com');
    await t.tap(find.byKey(const Key('emailChangeSend')));
    await t.pumpAndSettle();
    expect(find.text('This email address belongs to another account.'), findsOneWidget);
    expect(find.byKey(const Key('emailCodeField')), findsNothing);
  });

  testWidgets('wrong code keeps the dialog open; the right code confirms and returns true', (t) async {
    await open(t);
    await t.enterText(find.byKey(const Key('newEmailField')), 'New@Example.com');
    await t.tap(find.byKey(const Key('emailChangeSend')));
    await t.pumpAndSettle();
    expect(api.calls, ['start:new@example.com']);
    expect(find.byKey(const Key('emailCodeField')), findsOneWidget);

    api.confirmError = const IdentityFailure(IdentityErrorKind.invalidCode, 'That code is invalid or has expired.');
    await t.enterText(find.byKey(const Key('emailCodeField')), '000000');
    await t.tap(find.byKey(const Key('emailChangeConfirm')));
    await t.pumpAndSettle();
    expect(find.text('That code is invalid or has expired.'), findsOneWidget);
    expect(result, isNull); // still open

    api.confirmError = null;
    await t.enterText(find.byKey(const Key('emailCodeField')), '123456');
    await t.tap(find.byKey(const Key('emailChangeConfirm')));
    await t.pumpAndSettle();
    expect(api.calls.last, 'confirm:new@example.com:123456');
    expect(result, true);
  });

  testWidgets('cancelling changes nothing', (t) async {
    await open(t);
    await t.tap(find.byKey(const Key('emailChangeCancel')));
    await t.pumpAndSettle();
    expect(result, false);
    expect(api.calls, isEmpty);
  });
}

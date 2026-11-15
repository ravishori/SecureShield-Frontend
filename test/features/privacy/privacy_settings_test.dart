import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:secureshield_app/features/auth/identity_api.dart';
import 'package:secureshield_app/features/privacy/privacy_api.dart';
import 'package:secureshield_app/features/privacy/privacy_content.dart';
import 'package:secureshield_app/features/privacy/screens/privacy_settings_screen.dart';

ConsentSnapshot _snap({bool? ai}) => ConsentSnapshot([
      const ConsentItem(purpose: kPurposeTerms, required: true, version: kTermsVersion, granted: true, upToDate: true),
      const ConsentItem(purpose: kPurposePrivacy, required: true, version: kPrivacyVersion, granted: true, upToDate: true),
      ConsentItem(purpose: kPurposeAi, required: false, version: kAiProcessingVersion, granted: ai, upToDate: ai != null),
    ], true);

class _Api implements PrivacyApi {
  bool? ai;
  Object? getError;
  Object? putError;
  final List<String> puts = [];
  @override
  Future<ConsentSnapshot> getConsents() async {
    if (getError != null) throw getError!;
    return _snap(ai: ai);
  }

  @override
  Future<ConsentSnapshot> putConsent(String purpose, bool granted, String version) async {
    puts.add('$purpose:$granted');
    if (putError != null) throw putError!;
    ai = granted;
    return _snap(ai: ai);
  }

  @override
  Future<DeletionStart> startDeletion() => throw UnimplementedError();
  @override
  Future<void> deleteAccount(String code) => throw UnimplementedError();
}

void main() {
  late _Api api;

  Future<void> pump(WidgetTester t) async {
    api = _Api();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const PrivacySettingsScreen()),
      GoRoute(path: '/delete-account', builder: (_, __) => const Scaffold(body: Text('DELETE SCREEN'))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [privacyApiProvider.overrideWithValue(api)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
  }

  bool aiOn(WidgetTester t) => t.widget<SwitchListTile>(find.byKey(const Key('aiConsentSwitch'))).value;

  testWidgets('shows the server state: AI processing is off until the user turns it on', (t) async {
    await pump(t);
    expect(aiOn(t), isFalse);
  });

  testWidgets('granting and withdrawing the optional consent goes through the server', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('aiConsentSwitch')));
    await t.pumpAndSettle();
    expect(aiOn(t), isTrue);
    await t.tap(find.byKey(const Key('aiConsentSwitch')));
    await t.pumpAndSettle();
    expect(aiOn(t), isFalse);
    expect(api.puts, ['$kPurposeAi:true', '$kPurposeAi:false']);
  });

  testWidgets('a failed save leaves the switch where the server last had it and says so', (t) async {
    await pump(t);
    api.putError = const IdentityFailure(IdentityErrorKind.offline, 'No connection. Check your internet and try again.');
    await t.tap(find.byKey(const Key('aiConsentSwitch')));
    await t.pumpAndSettle();
    expect(aiOn(t), isFalse);
    expect(find.byKey(const Key('privacySettingsError')), findsOneWidget);
  });

  testWidgets('if the choices cannot be loaded there is a retry, not a guess', (t) async {
    api = _Api()..getError = const IdentityFailure(IdentityErrorKind.offline, 'No connection.');
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const PrivacySettingsScreen())]);
    await t.pumpWidget(ProviderScope(
      overrides: [privacyApiProvider.overrideWithValue(api)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('aiConsentSwitch')), findsNothing);
    api.getError = null;
    await t.tap(find.byKey(const Key('retryConsent')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('aiConsentSwitch')), findsOneWidget);
  });

  testWidgets('opens the notice and the delete-account flow', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('openNotice')));
    await t.pumpAndSettle();
    expect(find.text(kNoticeTitle), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('openDelete')));
    await t.pumpAndSettle();
    expect(find.text('DELETE SCREEN'), findsOneWidget);
  });
}

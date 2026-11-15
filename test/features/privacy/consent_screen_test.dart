import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/auth/identity_api.dart';
import 'package:secureshield_app/features/privacy/privacy_api.dart';
import 'package:secureshield_app/features/privacy/privacy_content.dart';
import 'package:secureshield_app/features/privacy/screens/consent_screen.dart';
import 'package:secureshield_app/features/privacy/screens/privacy_notice_screen.dart';

class _FakePrivacy implements PrivacyApi {
  final List<String> calls = [];
  Object? putError;
  @override
  Future<ConsentSnapshot> putConsent(String purpose, bool granted, String version) async {
    calls.add('$purpose:$granted:$version');
    if (putError != null) throw putError!;
    return const ConsentSnapshot([], true);
  }

  @override
  Future<ConsentSnapshot> getConsents() async => const ConsentSnapshot([], false);
  @override
  Future<DeletionStart> startDeletion() => throw UnimplementedError();
  @override
  Future<void> deleteAccount(String code) => throw UnimplementedError();
}

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: home));

Finder _box(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(Checkbox));

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  ConsentChoices? accepted;

  Future<void> pumpConsent(WidgetTester t) async {
    _tall(t);
    accepted = null;
    await t.pumpWidget(_app(ConsentScreen(onAccepted: (c) => accepted = c)));
  }

  bool continueEnabled(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const Key('consentContinue'))).onPressed != null;

  testWidgets('continue is disabled until BOTH mandatory acknowledgements are ticked, each on its own', (t) async {
    await pumpConsent(t);
    expect(continueEnabled(t), isFalse);
    expect(find.byKey(const Key('consentHint')), findsOneWidget);
    await t.tap(_box('termsCheckbox'));
    await t.pump();
    expect(continueEnabled(t), isFalse); // terms alone is not enough
    await t.tap(_box('termsCheckbox'));
    await t.tap(_box('privacyCheckbox'));
    await t.pump();
    expect(continueEnabled(t), isFalse); // privacy alone is not enough
    await t.tap(_box('termsCheckbox'));
    await t.pump();
    expect(continueEnabled(t), isTrue);
  });

  testWidgets('the optional AI choice is separate, off by default, and never required', (t) async {
    await pumpConsent(t);
    expect(t.widget<SwitchListTile>(find.byKey(const Key('aiSwitch'))).value, isFalse);
    await t.tap(_box('termsCheckbox'));
    await t.tap(_box('privacyCheckbox'));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('consentContinue')));
    await t.tap(find.byKey(const Key('consentContinue')));
    expect(accepted, isNotNull);
    expect(accepted!.aiProcessing, isFalse); // continuing without the optional choice is allowed
    expect(accepted!.termsVersion, kTermsVersion);
    expect(accepted!.privacyVersion, kPrivacyVersion);
  });

  testWidgets('turning the optional choice on is carried through, independent of the mandatory items', (t) async {
    await pumpConsent(t);
    await t.ensureVisible(find.byKey(const Key('aiSwitch')));
    await t.tap(find.byKey(const Key('aiSwitch')));
    await t.pump();
    expect(continueEnabled(t), isFalse); // the optional switch does NOT satisfy the mandatory items
    await t.tap(_box('termsCheckbox'));
    await t.tap(_box('privacyCheckbox'));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('consentContinue')));
    await t.tap(find.byKey(const Key('consentContinue')));
    expect(accepted!.aiProcessing, isTrue);
    expect(accepted!.toJson(), {
      'terms_version': kTermsVersion,
      'privacy_version': kPrivacyVersion,
      'ai_processing': true,
    });
  });

  testWidgets('Android permissions are not bundled into this consent', (t) async {
    await pumpConsent(t);
    await t.ensureVisible(find.byKey(const Key('permissionsNote')));
    expect(find.byKey(const Key('permissionsNote')), findsOneWidget);
    expect(find.textContaining('separately'), findsWidgets);
    for (final word in ['Camera', 'Location', 'Microphone', 'SMS', 'Contacts']) {
      expect(find.widgetWithText(CheckboxListTile, word), findsNothing);
      expect(find.widgetWithText(SwitchListTile, word), findsNothing);
    }
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });

  testWidgets('accessibility: headings are marked, controls are labelled and large enough', (t) async {
    final handle = t.ensureSemantics();
    await pumpConsent(t);
    final headers = <String>[];
    void walk(SemanticsNode n) {
      if (n.flagsCollection.isHeader) headers.add(n.label);
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(t.getSemantics(find.byType(Scaffold).first));
    expect(headers, containsAll(['Required to create an account', 'Optional']));
    final termsNode = t.getSemantics(find.byKey(const Key('termsCheckbox')));
    expect(termsNode.label, contains('I agree to the Terms of Service'));
    // the tick boxes are real, enabled Checkbox controls (they carry the platform checked-state semantics)
    expect(t.widget<Checkbox>(_box('termsCheckbox')).onChanged, isNotNull);
    expect(t.widget<Checkbox>(_box('privacyCheckbox')).onChanged, isNotNull);
    expect(t.getSize(find.byKey(const Key('termsCheckbox'))).height, greaterThanOrEqualTo(48));
    expect(t.getSize(find.byKey(const Key('privacyCheckbox'))).height, greaterThanOrEqualTo(48));
    expect(t.getSize(find.byKey(const Key('consentContinue'))).height, greaterThanOrEqualTo(40));
    handle.dispose();
  });

  testWidgets('the notice opens from the consent screen and returns to it', (t) async {
    await pumpConsent(t);
    await t.ensureVisible(find.byKey(const Key('readNoticeButton')));
    await t.tap(find.byKey(const Key('readNoticeButton')));
    await t.pumpAndSettle();
    expect(find.text(kNoticeTitle), findsOneWidget);
    expect(find.byKey(const Key('noticeStatus')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('termsCheckbox')), findsOneWidget);
  });

  testWidgets('the terms summary opens in a dialog', (t) async {
    await pumpConsent(t);
    await t.tap(find.byKey(const Key('readTermsButton')));
    await t.pumpAndSettle();
    expect(find.text('Terms of service'), findsOneWidget);
    expect(find.textContaining('not a guarantee'), findsOneWidget);
  });

  testWidgets('ConsentGate shows the consent screen first and the wrapped screen after acceptance', (t) async {
    _tall(t);
    await t.pumpWidget(_app(const ConsentGate(child: Scaffold(body: Text('REGISTER FORM')))));
    expect(find.text('REGISTER FORM'), findsNothing);
    await t.tap(_box('termsCheckbox'));
    await t.tap(_box('privacyCheckbox'));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('consentContinue')));
    await t.tap(find.byKey(const Key('consentContinue')));
    await t.pumpAndSettle();
    expect(find.text('REGISTER FORM'), findsOneWidget);
  });

  group('privacy notice content reflects real behaviour', () {
    String all() => [
          for (final s in kPrivacyNotice) ...[s.heading, ...s.paragraphs, ...s.bullets]
        ].join('\n').toLowerCase();

    test('names the providers that really receive data, and does not claim data is never shared', () {
      final text = all();
      for (final p in ['resend', 'railway', 'google', 'anthropic', 'jitsi', 'urlhaus']) {
        expect(text.contains(p), isTrue, reason: 'notice must mention $p');
      }
      expect(text.contains('never shared'), isFalse);
      expect(text.contains('never share'), isFalse);
      expect(text.contains('compliant'), isFalse);
      expect(text.contains('gdpr'), isFalse);
    });

    test('covers retention, deletion, withdrawal, and is honest about unfinished items', () {
      final text = all();
      expect(text.contains('delete'), isTrue);
      expect(text.contains('withdraw'), isTrue);
      expect(text.contains('to be completed'), isTrue); // contact and retention periods are not invented
      expect(kNoticeStatus.toLowerCase().contains('not yet reviewed'), isTrue);
    });

    test('does not promise consent-protected AI: it states external AI is currently disabled', () {
      final text = all();
      expect(text.contains('currently disabled'), isTrue);
      expect(text.contains('only when ai processing is enabled and you have agreed'), isFalse);
      expect(text.contains('it is off unless you turn it on'), isFalse);
    });

    test('says SMS and call log are not read', () {
      expect(all().contains('does not read your sms inbox'), isTrue);
    });
  });

  testWidgets('the notice screen has a heading per section and is scrollable on a small screen', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const PrivacyNoticeScreen()));
    expect(find.text(kPrivacyNotice.first.heading), findsOneWidget);
    await t.scrollUntilVisible(find.text(kPrivacyNotice.last.heading), 300);
    expect(find.text(kPrivacyNotice.last.heading), findsOneWidget);
  });

  group('consent update for an existing account', () {
    testWidgets('records both acknowledgements through the server and reports failures', (t) async {
      _tall(t);
      final api = _FakePrivacy();
      await t.pumpWidget(_app(const ConsentUpdateScreen(), overrides: [privacyApiProvider.overrideWithValue(api)]));
      await t.tap(_box('termsCheckbox'));
      await t.tap(_box('privacyCheckbox'));
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('consentContinue')));
      await t.tap(find.byKey(const Key('consentContinue')));
      await t.pumpAndSettle();
      expect(api.calls, [
        '$kPurposeTerms:true:$kTermsVersion',
        '$kPurposePrivacy:true:$kPrivacyVersion',
      ]); // no optional consent is recorded unless it was chosen
    });

    testWidgets('a failure is shown and nothing is assumed accepted', (t) async {
      _tall(t);
      final api = _FakePrivacy()
        ..putError = const IdentityFailure(IdentityErrorKind.offline, 'No connection. Check your internet and try again.');
      await t.pumpWidget(_app(const ConsentUpdateScreen(), overrides: [privacyApiProvider.overrideWithValue(api)]));
      await t.tap(_box('termsCheckbox'));
      await t.tap(_box('privacyCheckbox'));
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('consentContinue')));
      await t.tap(find.byKey(const Key('consentContinue')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('consentUpdateError')), findsOneWidget);
      expect(find.textContaining('No connection'), findsOneWidget);
    });
  });
}

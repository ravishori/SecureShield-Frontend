import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/core/verdict/scam_verdict.dart';
import 'package:secureshield_app/core/verdict/verdict_response.dart';
import 'package:secureshield_app/features/scam_hub/hub_input.dart';
import 'package:secureshield_app/features/scam_hub/hub_result.dart';
import 'package:secureshield_app/features/scam_hub/scam_hub_provider.dart';
import 'package:secureshield_app/features/scam_hub/screens/scam_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/verdict/server_verdict_fixtures.dart';
import '../auth/fake_http.dart';

Map<String, dynamic> fx(String name) => jsonDecode(serverVerdictFixtures[name]!) as Map<String, dynamic>;

/// Records every call the hub makes; the only way to reach the network from the hub.
class FakeGateway implements HubGateway {
  final List<(String, String)> calls = []; // (route, exact payload)
  Object? Function() next = () => VerdictResponse({}, ScamVerdict.fromJson(fx('urlMedium')));

  VerdictResponse _answer() {
    final r = next();
    if (r is VerdictResponse) return r;
    throw r!;
  }

  @override
  Future<VerdictResponse> analyzeMessage(String text) async {
    calls.add(('message', text));
    return _answer();
  }

  @override
  Future<VerdictResponse> scanUrl(String url) async {
    calls.add(('url', url));
    return _answer();
  }
}

VerdictResponse vr(String fixture) => VerdictResponse({}, ScamVerdict.fromJson(fx(fixture)));

(ProviderContainer, FakeGateway) make() {
  final g = FakeGateway();
  final c = ProviderContainer(overrides: [hubGatewayProvider.overrideWithValue(g)]);
  addTearDown(c.dispose);
  return (c, g);
}

ScamHubNotifier notifier(ProviderContainer c) => c.read(scamHubProvider.notifier);
HubState st(ProviderContainer c) => c.read(scamHubProvider);

DioException dioErr(DioExceptionType t, {int? status}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: t,
      response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
    );

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('routing and confirmation (notifier)', () {
    test('a pasted URL goes straight to the URL scanner, only after confirmation, exactly as entered', () async {
      final (c, g) = make();
      notifier(c).submitPasted('  example.com/login  ');
      expect(st(c).phase, HubPhase.confirming);
      expect(st(c).route, HubRoute.url);
      expect(g.calls, isEmpty, reason: 'nothing is sent before confirmation');
      await notifier(c).confirmSend(useMasked: false);
      expect(g.calls, [('url', 'example.com/login')]); // bare host, no prefix added
    });

    test('a pasted message goes to the message analyser after confirmation', () async {
      final (c, g) = make();
      g.next = () => vr('messageHigh');
      notifier(c).submitPasted('URGENT your KYC expired, click now');
      expect(g.calls, isEmpty);
      await notifier(c).confirmSend(useMasked: false);
      expect(g.calls, [('message', 'URGENT your KYC expired, click now')]);
      expect((st(c).outcome as HubVerdict).verdict.riskLevel, RiskLevel.high);
    });

    test('a pasted QR-style payload is analysed locally and never sent', () {
      final (c, g) = make();
      notifier(c).submitPasted('upi://pay?pa=shop@paytm-pay&am=999');
      expect(st(c).phase, HubPhase.result);
      expect((st(c).outcome as HubVerdict).local, isTrue);
      expect(g.calls, isEmpty);
    });

    test('camera QR: local analysis first; a URL makes ZERO calls until an explicit tap AND confirmation', () async {
      final (c, g) = make();
      notifier(c).submitCamera('https://example.com/pay');
      final o = st(c).outcome as HubVerdict;
      expect(o.local, isTrue);
      expect(o.checkableUrl, 'https://example.com/pay');
      expect(g.calls, isEmpty);
      notifier(c).requestReputationCheck(); // the explicit user action
      expect(st(c).phase, HubPhase.confirming);
      expect(g.calls, isEmpty, reason: 'the tap only opens the confirmation');
      await notifier(c).confirmSend(useMasked: false);
      expect(g.calls, [('url', 'https://example.com/pay')]);
    });

    test('camera QR that is not a URL can never be sent', () {
      final (c, g) = make();
      for (final p in ['upi://pay?pa=a@oksbi', 'tel:+911234567890', 'WIFI:S:x;T:WPA;P:y;;', 'plain text']) {
        notifier(c).submitCamera(p);
        expect((st(c).outcome as HubVerdict).checkableUrl, isNull, reason: p);
        notifier(c).requestReputationCheck();
        expect(st(c).phase, HubPhase.result, reason: p);
      }
      expect(g.calls, isEmpty);
    });

    test('camera QR is never auto-submitted, however long it sits', () {
      final (c, g) = make();
      notifier(c).submitCamera('https://example.com');
      // no further action: nothing may be pending
      expect(g.calls, isEmpty);
      expect(st(c).phase, HubPhase.result);
    });

    test('Edit/Cancel sends nothing; a camera lookup returns to its local result; paste returns to input', () {
      final (c, g) = make();
      notifier(c).submitCamera('https://example.com');
      notifier(c).requestReputationCheck();
      notifier(c).cancelConfirm();
      expect(st(c).phase, HubPhase.result);
      expect((st(c).outcome as HubVerdict).local, isTrue);
      notifier(c).submitPasted('hello there');
      notifier(c).cancelConfirm();
      expect(st(c).phase, HubPhase.idle);
      expect(g.calls, isEmpty);
    });

    test('an over-long camera payload is rejected locally and nothing is sent', () {
      final (c, g) = make();
      notifier(c).submitCamera('a' * 5001);
      expect(st(c).error, isNotNull);
      expect(st(c).phase, HubPhase.idle);
      expect(g.calls, isEmpty);
    });

    test('a double tap on Send submits once, and no copy of the text is kept in state afterwards', () async {
      final (c, g) = make();
      notifier(c).submitPasted('hello there friend');
      final a = notifier(c).confirmSend(useMasked: false);
      final b = notifier(c).confirmSend(useMasked: false);
      await Future.wait([a, b]);
      expect(g.calls.length, 1);
      expect(st(c).original, isEmpty);
      expect(st(c).masked, isEmpty);
    });

    test('the type can be corrected by the user without the text changing', () async {
      final (c, g) = make();
      notifier(c).submitPasted('example.com', override: HubRoute.message);
      await notifier(c).confirmSend(useMasked: false);
      expect(g.calls, [('message', 'example.com')]);
    });
  });

  group('sensitive content: masking shows and sends exactly the same text', () {
    const text = 'Your OTP is 482913, do not share';

    test('the masked text in state is what is sent when masked is chosen; the original never goes', () async {
      final (c, g) = make();
      notifier(c).submitPasted(text);
      expect(st(c).hasSensitive, isTrue);
      final shown = st(c).masked;
      expect(shown, 'Your OTP is ****, do not share');
      await notifier(c).confirmSend(useMasked: true);
      expect(g.calls.single.$2, shown);
      expect(g.calls.single.$2.contains('482913'), isFalse);
    });

    test('"Send anyway" sends the original, unmodified', () async {
      final (c, g) = make();
      notifier(c).submitPasted(text);
      await notifier(c).confirmSend(useMasked: false);
      expect(g.calls.single.$2, text);
    });

    test('masking is only ever applied on request: the entered text is untouched in state', () {
      final (c, _) = make();
      notifier(c).submitPasted(text);
      expect(st(c).original, text);
    });

    test('with nothing sensitive, "masked" and "original" are the same exact text', () async {
      final (c, g) = make();
      notifier(c).submitPasted('hello there');
      expect(st(c).hasSensitive, isFalse);
      await notifier(c).confirmSend(useMasked: true);
      expect(g.calls.single.$2, 'hello there');
    });
  });

  group('outcomes: UNKNOWN and COULD NOT CHECK stay distinct and are never LOW or SAFE', () {
    test('total provider outage: UNKNOWN preserved with the outage notice', () async {
      final (c, g) = make();
      g.next = () => vr('urlOutage');
      notifier(c).submitPasted('https://example.com');
      await notifier(c).confirmSend(useMasked: false);
      final o = st(c).outcome as HubVerdict;
      expect(o.verdict.riskLevel, RiskLevel.unknown);
      final k = explainCompleteness(o).map((n) => n.kind);
      expect(k, [NoticeKind.providerOutage]);
      expect(explainCompleteness(o).single.text, contains('Legitimacy could not be established'));
    });

    test('outage plus an adverse heuristic keeps its level and the outage notice, not an unknown notice', () async {
      final (c, g) = make();
      g.next = () => vr('urlOutageAdverse');
      notifier(c).submitPasted('http://192.168.4.4/login/verify');
      await notifier(c).confirmSend(useMasked: false);
      final o = st(c).outcome as HubVerdict;
      expect(o.verdict.riskLevel, RiskLevel.medium);
      expect(explainCompleteness(o).map((n) => n.kind), [NoticeKind.providerOutage]);
    });

    test('unknown evidence without an outage gets the unknown-evidence notice', () async {
      final (c, g) = make();
      g.next = () => vr('urlUnknown');
      notifier(c).submitPasted('https://example.com');
      await notifier(c).confirmSend(useMasked: false);
      expect(explainCompleteness(st(c).outcome!).map((n) => n.kind), [NoticeKind.unknownEvidence]);
    });

    test('a missing or malformed server verdict becomes a synthesised UNKNOWN, never SAFE or LOW', () async {
      for (final body in <Map<String, dynamic>>[
        {'risk_score': 0.0},
        {'verdict': 'safe'},
        {'verdict': {...fx('messageLow'), 'risk_level': 'safe'}},
      ]) {
        final (c, g) = make();
        g.next = () => VerdictResponse.from(body);
        notifier(c).submitPasted('hello there');
        await notifier(c).confirmSend(useMasked: false);
        final o = st(c).outcome as HubVerdict;
        expect(o.synthesized, isTrue);
        expect(o.verdict.riskLevel, RiskLevel.unknown, reason: '$body');
        expect(o.verdict.isSafeClaim, isFalse);
        expect(explainCompleteness(o).single.kind, NoticeKind.unknownEvidence);
      }
    });

    test('request failures are not verdicts, for every failure class', () async {
      final cases = <DioException, FailureKind>{
        dioErr(DioExceptionType.connectionTimeout): FailureKind.timeout,
        dioErr(DioExceptionType.receiveTimeout): FailureKind.timeout,
        dioErr(DioExceptionType.connectionError): FailureKind.network,
        dioErr(DioExceptionType.badResponse, status: 401): FailureKind.auth,
        dioErr(DioExceptionType.badResponse, status: 429): FailureKind.rateLimited,
        dioErr(DioExceptionType.badResponse, status: 500): FailureKind.server,
        dioErr(DioExceptionType.cancel): FailureKind.cancelled,
      };
      for (final e in cases.entries) {
        final (c, g) = make();
        g.next = () => e.key;
        notifier(c).submitPasted('hello there');
        await notifier(c).confirmSend(useMasked: false);
        final o = st(c).outcome;
        expect(o, isA<HubRequestFailed>(), reason: '${e.key.type}');
        expect((o as HubRequestFailed).kind, e.value);
        expect(explainCompleteness(o).single.kind, NoticeKind.requestFailure);
      }
    });

    test('local QR analysis carries the local-only notice and never reaches SAFE', () {
      final (c, _) = make();
      for (final p in ['https://example.com', 'upi://pay?pa=a@oksbi', 'plain text', 'tel:+911234567890']) {
        notifier(c).submitCamera(p);
        final o = st(c).outcome as HubVerdict;
        expect(explainCompleteness(o).map((n) => n.kind), contains(NoticeKind.localOnlyQr), reason: p);
        expect(o.verdict.isSafeClaim, isFalse, reason: p);
      }
    });
  });

  group('screen', () {
    Widget app(FakeGateway g, {Future<String?> Function(BuildContext)? capture}) => ProviderScope(
          overrides: [hubGatewayProvider.overrideWithValue(g)],
          child: MaterialApp(home: ScamHubScreen(captureQr: capture)),
        );

    Future<void> setSize(WidgetTester t) async {
      t.view.physicalSize = const Size(900, 3000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
    }

    testWidgets('URL: confirmation shows the exact link, the storage and AI-off disclosure; nothing sent until Send', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'https://example.com/a');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      expect(g.calls, isEmpty);
      expect(find.text('Send this link for checking?'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('preview_original')), matching: find.text('https://example.com/a')), findsOneWidget);
      final storage = (t.widget(find.byKey(const Key('storage_disclosure'))) as Text).data!;
      expect(storage, contains('Google Safe Browsing and URLhaus'));
      expect(storage, contains('full link'));
      expect(storage, contains('first 200 characters'));
      expect((t.widget(find.byKey(const Key('ai_disclosure'))) as Text).data!, contains('External AI analysis is switched off'));
      await t.tap(find.byKey(const Key('send_button')));
      await t.pumpAndSettle();
      expect(g.calls, [('url', 'https://example.com/a')]);
      expect(find.byKey(const Key('hub_headline')), findsOneWidget);
    });

    testWidgets('message: disclosure states what is stored; there is no "don\'t show again"', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'hello there my friend');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      final storage = (t.widget(find.byKey(const Key('storage_disclosure'))) as Text).data!;
      expect(storage, contains('first 100 characters'));
      expect(storage, contains('not risky is not saved'));
      expect(find.textContaining("n't show"), findsNothing);
      expect(find.textContaining('again'), findsNothing);
    });

    testWidgets('sensitive content: Edit is the primary action; masked and original are both shown exactly; masked is what is sent', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'Your OTP is 482913, do not share');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sensitive_warning')), findsOneWidget);
      expect(find.byKey(const Key('edit_button')), findsOneWidget);
      expect(find.byKey(const Key('send_button')), findsNothing, reason: 'Edit replaces the primary send action when a warning fires');
      expect(find.byKey(const Key('send_anyway_button')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('preview_masked')), matching: find.text('Your OTP is ****, do not share')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('preview_original')), matching: find.text('Your OTP is 482913, do not share')), findsOneWidget);
      await t.tap(find.byKey(const Key('send_masked_button')));
      await t.pumpAndSettle();
      expect(g.calls.single.$2, 'Your OTP is ****, do not share');
    });

    testWidgets('sensitive content: Edit returns to the field with the text untouched and sends nothing', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'password: Hunter2!');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('edit_button')));
      await t.pumpAndSettle();
      expect((t.widget(find.byKey(const Key('hub_input'))) as TextField).controller!.text, 'password: Hunter2!');
      expect(g.calls, isEmpty);
    });

    testWidgets('sensitive content: Send anyway still sends the original once chosen', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'cvv 123 please');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('send_anyway_button')));
      await t.pumpAndSettle();
      expect(g.calls.single.$2, 'cvv 123 please');
    });

    testWidgets('request failure shows COULD NOT CHECK, not LOW RISK, SAFE or UNABLE TO VERIFY', (t) async {
      await setSize(t);
      final g = FakeGateway()..next = () => dioErr(DioExceptionType.connectionError);
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'hello there my friend');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('send_button')));
      await t.pumpAndSettle();
      expect((t.widget(find.byKey(const Key('hub_headline'))) as Text).data, 'COULD NOT CHECK');
      expect(find.byKey(const Key('notice_requestFailure')), findsOneWidget);
      for (final l in ['SAFE', 'LOW RISK', 'UNABLE TO VERIFY']) {
        expect(find.text(l), findsNothing);
      }
    });

    testWidgets('outage UNKNOWN shows UNABLE TO VERIFY, a different outcome from COULD NOT CHECK', (t) async {
      await setSize(t);
      final g = FakeGateway()..next = () => vr('urlOutage');
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'https://example.com');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('send_button')));
      await t.pumpAndSettle();
      expect((t.widget(find.byKey(const Key('hub_headline'))) as Text).data, 'UNABLE TO VERIFY');
      expect(find.byKey(const Key('notice_providerOutage')), findsOneWidget);
    });

    testWidgets('camera QR with a link: local result first, zero requests until the explicit tap and confirmation', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g, capture: (_) async => 'https://example.com/pay'));
      await t.tap(find.byKey(const Key('scan_button')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('notice_localOnlyQr')), findsOneWidget);
      expect(find.byKey(const Key('check_reputation_button')), findsOneWidget);
      expect(g.calls, isEmpty);
      await t.tap(find.byKey(const Key('check_reputation_button')));
      await t.pumpAndSettle();
      expect(find.text('Send this link for checking?'), findsOneWidget);
      expect(g.calls, isEmpty);
      await t.tap(find.byKey(const Key('send_button')));
      await t.pumpAndSettle();
      expect(g.calls, [('url', 'https://example.com/pay')]);
    });

    testWidgets('camera QR that is not a link offers no reputation check', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g, capture: (_) async => 'upi://pay?pa=shop@paytm-pay'));
      await t.tap(find.byKey(const Key('scan_button')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('check_reputation_button')), findsNothing);
      expect(g.calls, isEmpty);
    });

    testWidgets('the hub writes nothing to local storage during a full flow', (t) async {
      await setSize(t);
      final g = FakeGateway();
      await t.pumpWidget(app(g));
      await t.enterText(find.byKey(const Key('hub_input')), 'Your OTP is 482913');
      await t.tap(find.byKey(const Key('analyze_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('send_masked_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('again_button')));
      await t.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      expect((t.widget(find.byKey(const Key('hub_input'))) as TextField).controller!.text, isEmpty, reason: 'a finished check leaves no text behind');
    });
  });

  group('privacy and safety guarantees (static and wire)', () {
    test('the hub sources never launch URLs, open WebViews, or persist anything', () {
      final files = Directory('lib/features/scam_hub').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final s = f.readAsStringSync();
        for (final banned in ['launchUrl', 'url_launcher', 'WebView', 'SharedPreferences', 'FlutterSecureStorage', 'writeAsString', 'openApp', 'Intent(']) {
          expect(s.contains(banned), isFalse, reason: '${f.path} contains $banned');
        }
      }
    });

    test('the real gateway asks for NO external AI and sends only the text / only the url', () async {
      final a = FakeAdapter((o) => jsonBody(200, {'is_safe': true}));
      DioClient().dio.httpClientAdapter = a;
      await ApiHubGateway().analyzeMessage('hello there');
      await ApiHubGateway().scanUrl('example.com');
      final msg = a.requests[0], link = a.requests[1];
      expect(msg.path, '/message/analyze');
      expect(msg.data, {'message_text': 'hello there', 'use_ai': false});
      expect(link.path, '/link-scanner/scan');
      expect(link.data, {'url': 'example.com'});
    });
  });
}

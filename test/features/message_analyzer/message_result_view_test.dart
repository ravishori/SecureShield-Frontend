// Stage 1.6D-4: widget tests for the SMS analysis result. Synthetic data only.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/message_analyzer/widgets/message_result_view.dart';

import '../../core/verdict/server_verdict_fixtures.dart';

Map<String, dynamic> fx(String name) => jsonDecode(serverVerdictFixtures[name]!) as Map<String, dynamic>;

Map<String, dynamic> verdictJson({
  String level = 'low',
  int score = 0,
  List<Map<String, dynamic>> evidence = const [],
  List<String> limitations = const ['Pattern matching only: it cannot understand context or intent.'],
  List<Map<String, String>> reasons = const [
    {'code': 'no_signals_found', 'text': 'No risk signals were found by the built-in checks.'},
  ],
}) =>
    {
      'schema_version': 1,
      'risk_level': level,
      'risk_score': score,
      'reasons': reasons,
      'evidence': evidence,
      'source_type': 'message',
      'confidence': null,
      'limitations': limitations,
      'recommended_actions': [
        {'code': 'verify_independently', 'text': 'If you did not expect this, check it another way before acting.'},
        {'code': 'do_not_share_otp', 'text': 'Do not share OTPs or PINs with anyone.'},
      ],
      'engine_version': 'message-patterns/1',
    };

Map<String, dynamic> sender(String verdict, {String? lookup = 'ok', String id = 'VM-SBIBNK-S', String? entity, String? suffix}) => {
      'is_registered': verdict == 'REGISTERED' ? true : (verdict == 'UNREGISTERED' ? false : null),
      'verdict': verdict,
      'verdict_detail': 'detail',
      'header': 'SBIBNK',
      'sender_id': id,
      'principal_entity_name': entity,
      'all_entity_names': <String>[],
      'tsp_code': null,
      'tsp_name': null,
      'lsa_code': null,
      'lsa_name': null,
      'sender_suffix': suffix,
      'lookup_status': lookup,
    };

Map<String, dynamic> response({Map<String, dynamic>? verdict, Map<String, dynamic>? sv, bool? isSafe, String level = 'suspicious_message'}) => {
      if (isSafe != null) 'is_safe': isSafe,
      'risk_level': level,
      'risk_score': 60.0,
      'scam_type': 'none',
      'explanation': 'Pattern analysis',
      'action': 'Be careful.',
      'red_flags': <String>['malicious_link_in_message'],
      'detected_patterns': <String>[],
      'sender_validation': sv,
      'analyzed_at': '2026-11-14T10:00:00',
      if (verdict != null) 'verdict': verdict,
    };

Future<void> show(WidgetTester t, Map<String, dynamic> result) async {
  t.view.physicalSize = const Size(900, 3200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: MessageResultView(result: result)))));
}

String text(WidgetTester t, String key) => (t.widget(find.byKey(Key(key))) as Text).data!;

void main() {
  group('headline', () {
    testWidgets('a low pattern score is "LOW RISK", never "safe"', (t) async {
      await show(t, response(verdict: verdictJson(), isSafe: true));
      expect(text(t, 'message_headline'), 'LOW RISK');
      expect(find.textContaining('Appears Safe'), findsNothing);
      expect(find.textContaining('SAFE'), findsNothing);
    });

    testWidgets('a legacy response says "No warning signs found", and a missing is_safe is suspicious', (t) async {
      await show(t, response(isSafe: true, level: 'safe'));
      expect(text(t, 'message_headline'), 'No warning signs found');
      await show(t, response());
      expect(text(t, 'message_headline'), 'Suspicious Message!');
    });

    testWidgets('a high verdict shows HIGH RISK with the score, reasons and actions', (t) async {
      await show(t, response(verdict: fx('messageHigh'), isSafe: false));
      expect(text(t, 'message_headline'), 'HIGH RISK');
      expect(text(t, 'message_risk_score'), 'Risk score: 60 / 100');
      expect(find.text('• The message pressures you to act immediately.'), findsOneWidget);
      expect(find.text('→ Do not open the link.'), findsOneWidget);
      expect(find.byKey(const Key('message_evidence')), findsOneWidget);
    });
  });

  group('confidence and limitations', () {
    testWidgets('confidence is "not rated" (the contract carries none) and limitations are always shown', (t) async {
      await show(t, response(verdict: fx('messageLow'), isSafe: true));
      expect(text(t, 'message_confidence'), contains('not rated'));
      expect(find.byKey(const Key('message_limitations')), findsOneWidget);
      expect(find.text('No adverse signal does not mean the message is trustworthy.'), findsOneWidget);
    });

    testWidgets('a legacy response still shows a limitation and next actions', (t) async {
      await show(t, response(isSafe: false));
      expect(find.byKey(const Key('message_limitations')), findsOneWidget);
      expect(find.textContaining('Do not share OTPs'), findsWidgets);
      expect(find.text('→ Be careful.'), findsOneWidget);
    });
  });

  group('sender verdicts', () {
    testWidgets('REGISTERED: positive about the name, with the "does not prove" caveat', (t) async {
      final v = verdictJson(
        evidence: [
          {'kind': 'registry_match', 'polarity': 'positive', 'code': 'sender_registered', 'source': 'registry:trai_sender', 'weight': null, 'count': null},
        ],
        limitations: ['Pattern matching only: it cannot understand context or intent.', 'A registered sender name does not prove that this message is genuine.'],
      );
      await show(t, response(verdict: v, sv: sender('REGISTERED', entity: 'STATE BANK OF INDIA', suffix: 'S'), isSafe: true));
      expect(text(t, 'sender_status'), 'Registered sender name');
      expect(text(t, 'sender_caveat'), contains('does not prove this message is genuine'));
      expect(find.text('Registered to: STATE BANK OF INDIA'), findsOneWidget);
      expect(find.textContaining('category -S'), findsOneWidget);
      expect(find.textContaining('✓ Sender name found in the registry'), findsOneWidget);
      expect(text(t, 'message_headline'), 'LOW RISK');
    });

    testWidgets('UNREGISTERED: a warning sign, not proof of fraud', (t) async {
      await show(t, response(sv: sender('UNREGISTERED', id: 'VM-NOSUCH-S'), isSafe: false));
      expect(text(t, 'sender_status'), 'Not found in the TRAI registry');
      expect(text(t, 'sender_caveat'), allOf(contains('warning sign'), contains('not proof of fraud')));
    });

    testWidgets('UNKNOWN because the registry is unavailable is a different state from UNREGISTERED', (t) async {
      await show(t, response(sv: sender('UNKNOWN', lookup: 'unavailable'), isSafe: false));
      expect(text(t, 'sender_status'), 'Sender check unavailable');
      expect(text(t, 'sender_caveat'), contains('says nothing about whether it is genuine or fake'));
      expect(find.text('Not found in the TRAI registry'), findsNothing);
    });

    testWidgets('UNKNOWN with no lookup is "not verified", and a phone number has its own wording', (t) async {
      await show(t, response(sv: sender('UNKNOWN', lookup: 'not_applicable'), isSafe: false));
      expect(text(t, 'sender_status'), 'Sender not verified');
      await show(t, response(sv: sender('PHONE_NUMBER', lookup: 'not_applicable', id: '[PHONE ...10]'), isSafe: false));
      expect(text(t, 'sender_status'), 'Sent from a personal phone number');
    });

    testWidgets('no sender at all shows no sender card', (t) async {
      await show(t, response(isSafe: false));
      expect(find.byKey(const Key('sender_card')), findsNothing);
    });
  });

  group('senderStatus (pure)', () {
    test('the states have distinct labels', () {
      final labels = {
        senderStatus(sender('REGISTERED')).label,
        senderStatus(sender('UNREGISTERED')).label,
        senderStatus(sender('UNKNOWN', lookup: 'unavailable')).label,
        senderStatus(sender('UNKNOWN', lookup: 'ok')).label,
        senderStatus(sender('PHONE_NUMBER')).label,
      };
      expect(labels.length, 5);
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/core/verdict/scam_verdict.dart';
import 'package:secureshield_app/core/verdict/verdict_response.dart';
import 'package:secureshield_app/features/dashboard/dashboard_api.dart';
import 'package:secureshield_app/features/link_scanner/link_scanner_api.dart';
import 'package:secureshield_app/features/message_analyzer/message_analyzer_api.dart';

import '../../features/auth/fake_http.dart';
import 'server_verdict_fixtures.dart';

Map<String, dynamic> fx(String name) => jsonDecode(serverVerdictFixtures[name]!) as Map<String, dynamic>;

const linkLegacy = {
  'id': '11111111-1111-1111-1111-111111111111',
  'user_id': '22222222-2222-2222-2222-222222222222',
  'url': 'http://192.168.4.4/login/verify',
  'is_phishing': true,
  'is_malicious': false,
  'risk_score': 55.0,
  'threat_category': 'ip_based_url',
  'scan_provider': 'internal_fallback',
  'gsb_threats': null,
  'scanned_at': '2026-11-14T10:00:00',
};
const messageLegacy = {
  'is_safe': false,
  'risk_level': 'suspicious_message',
  'risk_score': 60.0,
  'scam_type': 'none',
  'explanation': 'Pattern analysis: suspicious_message',
  'action': 'Be cautious with this message.',
  'red_flags': ['malicious_link_in_message'],
  'detected_patterns': ['malicious_link_in_message'],
  'sender_validation': null,
  'analyzed_at': '2026-11-14T10:00:00',
};
const jobLegacy = {
  'is_fake': true,
  'confidence': 85.0,
  'risk_score': 85.0,
  'red_flags': ['Legitimate jobs never ask for payment upfront'],
  'explanation': 'Risk score: 85/100',
  'action': 'Verify the company through official channels before applying.',
  'analyzed_at': '2026-11-14T10:00:00',
};
const dailyLegacy = {
  'id': '33333333-3333-3333-3333-333333333333',
  'user_id': '22222222-2222-2222-2222-222222222222',
  'report_date': '2026-11-14',
  'threats_detected': 1,
  'apps_scanned': 4,
  'links_scanned': 30,
  'calls_analyzed': 0,
  'overall_risk_score': 64.0,
  'top_threats': [],
  'recommendations': [],
  'created_at': '2026-11-14T10:00:00',
  'security_score': 36,
  'risk_level': 'high',
};

late FakeAdapter adapter;
late Object? Function(RequestOptions) reply;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({}); // the Dio client reads the token from secure storage
    reply = (_) => <String, dynamic>{};
    adapter = FakeAdapter((o) => jsonBody(200, reply(o)!));
    DioClient().dio.httpClientAdapter = adapter;
  });

  group('link scanner accessors', () {
    test('a response with a verdict: the legacy body is unchanged and the verdict is typed', () async {
      reply = (_) => {...linkLegacy, 'verdict': fx('urlMedium')};
      final r = await LinkScannerApi().scanLinkWithVerdict('http://192.168.4.4/login/verify');
      for (final e in linkLegacy.entries) {
        expect(r.body[e.key], e.value, reason: e.key);
      }
      expect(r.verdict!.riskLevel, RiskLevel.medium);
      expect(adapter.requests.single.path, '/link-scanner/scan');
      expect((adapter.requests.single.data as Map)['url'], 'http://192.168.4.4/login/verify');
    });

    test('an older server (no verdict key) gives a null verdict and the same body', () async {
      reply = (_) => linkLegacy;
      final r = await LinkScannerApi().scanLinkWithVerdict('http://x.example');
      expect(r.verdict, isNull);
      expect(r.body['risk_score'], 55.0);
    });

    test('an outage scan carries an UNKNOWN verdict (not safe, not low)', () async {
      reply = (_) => {...linkLegacy, 'risk_score': 0.0, 'is_phishing': false, 'threat_category': null, 'verdict': fx('urlOutage')};
      final r = await LinkScannerApi().scanLinkWithVerdict('https://example.com');
      expect(r.verdict!.isSafeClaim, isFalse);
      expect((r.verdict!.riskLevel, r.verdict!.riskScore), (RiskLevel.unknown, null));
      expect(r.verdict!.reasons.map((x) => x.code), ['reputation_unavailable']);
    });

    test('history: each item keeps its legacy fields and gets its own verdict; a bad item does not affect the others', () async {
      reply = (_) => [
            {...linkLegacy, 'verdict': fx('urlCritical')},
            {...linkLegacy, 'verdict': {'risk_level': 'SAFE'}}, // malformed
            linkLegacy, // legacy
            'junk',
          ];
      final h = await LinkScannerApi().getHistoryWithVerdicts();
      expect(h.length, 4);
      expect(h[0].verdict!.riskLevel, RiskLevel.critical);
      expect(h[1].verdict, isNull);
      expect(h[2].verdict, isNull);
      expect((h[1].body['url'], h[2].body['url']), (linkLegacy['url'], linkLegacy['url']));
      expect(h[3].body, isEmpty);
    });
  });

  group('message analyser accessors', () {
    test('message: legacy fields untouched, verdict typed, request unchanged', () async {
      reply = (_) => {...messageLegacy, 'verdict': fx('messageHigh')};
      final r = await MessageAnalyzerApi().analyzeMessageWithVerdict(messageText: 'hello', sender: '9876543210', useAi: false);
      expect(r.body['risk_level'], 'suspicious_message');
      expect(r.body['is_safe'], false);
      expect(r.verdict!.riskLevel, RiskLevel.high);
      expect(adapter.requests.single.path, '/message/analyze');
      expect(adapter.requests.single.data, {'message_text': 'hello', 'sender': '9876543210', 'use_ai': false});
    });

    test('job offer', () async {
      reply = (_) => {...jobLegacy, 'verdict': fx('jobHigh')};
      final r = await MessageAnalyzerApi().checkJobOfferWithVerdict(jobText: 'x', useAi: false);
      expect(r.body['is_fake'], true);
      expect(r.verdict!.riskLevel, RiskLevel.high);
      expect(r.verdict!.confidence, isNull); // the legacy "confidence" field stays; the verdict makes no such claim
    });

    test('missing and malformed verdicts fall back to null, never to safe', () async {
      for (final body in <Object>[
        messageLegacy,
        {...messageLegacy, 'verdict': 'safe'},
        {...messageLegacy, 'verdict': {...fx('messageLow'), 'risk_level': 'safe'}},
        {...messageLegacy, 'verdict': {...fx('messageLow'), 'schema_version': 9}},
      ]) {
        reply = (_) => body;
        final r = await MessageAnalyzerApi().analyzeMessageWithVerdict(messageText: 'x', useAi: false);
        expect(r.verdict, isNull, reason: '$body');
        expect(r.body['is_safe'], false);
      }
    });
  });

  group('dashboard accessor (API only)', () {
    test('the daily report keeps its legacy fields and exposes the aggregate verdict', () async {
      reply = (_) => {...dailyLegacy, 'verdict': fx('aggLow')};
      final r = await DashboardApi().getDailyReportWithVerdict();
      expect((r.body['security_score'], r.body['overall_risk_score']), (36, 64.0)); // the dashboard's own semantics are untouched
      expect(r.verdict!.sourceType, SourceType.dailyAggregate);
      expect(r.verdict!.riskScore, 10);
      expect(r.verdict!.limitations.join(' '), contains('F05-1'));
    });

    test('a day with no activity is an unknown verdict, not a safe one', () async {
      reply = (_) => {...dailyLegacy, 'threats_detected': 0, 'apps_scanned': 0, 'links_scanned': 0, 'overall_risk_score': 0.0, 'security_score': 100, 'verdict': fx('aggUnknown')};
      final r = await DashboardApi().getDailyReportWithVerdict();
      expect(r.verdict!.isUnknown, isTrue);
      expect(r.verdict!.isSafeClaim, isFalse);
      expect(r.body['security_score'], 100); // legacy semantics preserved (the misleading wording is outstanding F05-1 work)
    });
  });

  group('VerdictResponse', () {
    test('non-object bodies give an empty body and no verdict instead of throwing', () {
      for (final b in <Object?>[null, 'x', 5, <Object?>[]]) {
        final r = VerdictResponse.from(b);
        expect(r.body, isEmpty);
        expect(r.verdict, isNull);
      }
      expect(VerdictResponse.listFrom('x'), isEmpty);
    });

    test('server errors still surface exactly as before (the accessor adds no error handling)', () async {
      adapter = FakeAdapter((o) => jsonBody(500, {'detail': 'down'}));
      DioClient().dio.httpClientAdapter = adapter;
      expect(() => LinkScannerApi().scanLinkWithVerdict('https://example.com'), throwsA(isA<DioException>()));
    });
  });
}

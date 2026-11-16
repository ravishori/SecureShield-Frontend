import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/dashboard/security_assessment.dart';

Map<String, dynamic> _report({int t = 0, int a = 0, int l = 0, int c = 0, Object? score = 100, Object? risk = 0.0}) => {
      'threats_detected': t,
      'apps_scanned': a,
      'links_scanned': l,
      'calls_analyzed': c,
      'security_score': score,
      'overall_risk_score': risk,
    };

void main() {
  group('F-DEV-1: no data is NOT ASSESSED, never 100/100', () {
    test('new account: server reports 100 with zero activity', () {
      final r = SecurityAssessment.fromReport(_report());
      expect(r.isAssessed, isFalse);
      expect(r.score, isNull);
      expect(r.reason, SecurityAssessment.noActivityReason);
    });
    test('report not loaded (offline, expired token)', () {
      final r = SecurityAssessment.fromReport(null);
      expect(r.isAssessed, isFalse);
      expect(r.score, isNull);
      expect(r.reason, SecurityAssessment.noReportReason);
    });
    test('malformed counts are not assessed', () {
      expect(SecurityAssessment.fromReport({'threats_detected': 'x'}).isAssessed, isFalse);
      expect(SecurityAssessment.fromReport(_report()..['apps_scanned'] = -1).isAssessed, isFalse);
      expect(SecurityAssessment.fromReport(<String, dynamic>{}).isAssessed, isFalse);
    });
    test('activity but no usable score is not assessed', () {
      expect(SecurityAssessment.fromReport(_report(a: 3, score: null, risk: null)).isAssessed, isFalse);
    });
  });

  group('verified scores are unchanged', () {
    test('scans ran with no alert keeps the server score', () {
      final r = SecurityAssessment.fromReport(_report(a: 12, score: 94, risk: 6.0));
      expect(r.isAssessed, isTrue);
      expect(r.score, 94);
    });
    test('alerts lower the score', () {
      expect(SecurityAssessment.fromReport(_report(t: 3, score: 70, risk: 30.0)).score, 70);
    });
    test('falls back to the inverse of the risk score', () {
      expect(SecurityAssessment.fromReport(_report(l: 2, score: null, risk: 40.0)).score, 60);
    });
    test('a genuine low score stays low and is clamped to 0..100', () {
      expect(SecurityAssessment.fromReport(_report(t: 9, score: 5, risk: 95.0)).score, 5);
      expect(SecurityAssessment.fromReport(_report(t: 9, score: -4, risk: 104.0)).score, 0);
      expect(SecurityAssessment.fromReport(_report(a: 1, score: 140, risk: 0.0)).score, 100);
    });
  });
}

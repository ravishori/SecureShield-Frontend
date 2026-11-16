import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/security/fraud_keyword_engine.dart';
import 'package:secureshield_app/core/services/fraud_alert_policy.dart';
import 'package:secureshield_app/core/verdict/scam_verdict.dart';
import 'package:secureshield_app/core/verdict/verdict_response.dart';

import '../verdict/server_verdict_fixtures.dart';

/// A server response for a message at [level]/[score], derived from the real server fixture.
Map<String, dynamic> _response(String level, int? score) {
  final v = jsonDecode(serverVerdictFixtures['messageHigh']!) as Map<String, dynamic>;
  v['risk_level'] = level;
  v['risk_score'] = score;
  return {'risk_score': score, 'verdict': v};
}

FraudAlertDecision _fromResponse(Map<String, dynamic> r) =>
    decideFromServer(verdict: VerdictResponse.from(r).verdict, legacyRiskScore: r['risk_score']);

void main() {
  group('server verdict drives the notification (F-DEV-2)', () {
    test('70/100 high-risk scenario notifies', () {
      final d = _fromResponse(_response('high', 70));
      expect(d.notify, isTrue);
      expect(d.source, FraudAlertSource.verdict);
    });
    test('critical notifies', () => expect(_fromResponse(_response('critical', 95)).notify, isTrue));
    test('medium (suspicious) does not interrupt', () => expect(_fromResponse(_response('medium', 45)).notify, isFalse));
    test('low does not notify', () => expect(_fromResponse(_response('low', 25)).notify, isFalse));
    test('safe does not notify', () => expect(_fromResponse(_response('safe', 0)).notify, isFalse));
    test('unknown does not notify', () => expect(_fromResponse(_response('unknown', null)).notify, isFalse));
    test('the verdict wins over a stale legacy score', () {
      final r = _response('low', 10)..['risk_score'] = 90;
      expect(_fromResponse(r).notify, isFalse);
    });
  });

  group('legacy server without a verdict', () {
    test('70 notifies', () => expect(decideFromServer(legacyRiskScore: 70).notify, isTrue));
    test('69 does not', () => expect(decideFromServer(legacyRiskScore: 69).notify, isFalse));
    test('missing or malformed does not', () {
      expect(decideFromServer().notify, isFalse);
      expect(decideFromServer(legacyRiskScore: 'high').notify, isFalse);
    });
    test('a malformed verdict is ignored, not trusted', () {
      final r = {'risk_score': 20, 'verdict': {'risk_level': 'high'}};
      expect(_fromResponse(r).notify, isFalse);
    });
  });

  group('offline fallback (server unreachable)', () {
    test('3 or more keyword hits notifies', () => expect(decideOffline(matchedKeywordCount: 3).notify, isTrue));
    test('fewer does not', () {
      expect(decideOffline(matchedKeywordCount: 2).notify, isFalse);
      expect(decideOffline(matchedKeywordCount: 0).notify, isFalse);
    });
  });

  group('root cause of the missed alert', () {
    test('old ratio rule is unreachable for a realistic message; the verdict path is not', () {
      final a = FraudKeywordEngine.analyze('Your KYC is expired. Update KYC now or your account will be blocked. Click the link.');
      expect(a.suspicionScore, lessThanOrEqualTo(0.5), reason: 'a realistic scam message never exceeds half of a category list');
      expect(_fromResponse(_response('high', 70)).notify, isTrue);
    });
    test('RiskLevel enum names used by the policy exist', () {
      expect(RiskLevel.values.map((e) => e.name), containsAll(['high', 'critical']));
    });
  });
}

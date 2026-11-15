import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/verdict/scam_verdict.dart';

import 'server_verdict_fixtures.dart';

Map<String, dynamic> fx(String name) => jsonDecode(serverVerdictFixtures[name]!) as Map<String, dynamic>;

Map<String, dynamic> valid() => fx('urlMedium');

void main() {
  group('parses what the real server adapters send', () {
    for (final name in serverVerdictFixtures.keys) {
      test(name, () {
        final v = ScamVerdict.fromJson(fx(name));
        expect(v.schemaVersion, 1);
        expect(v.confidence, isNull);
        expect(v.limitations, isNotEmpty);
        // lossless round trip
        expect(ScamVerdict.fromJson(jsonDecode(jsonEncode(v.toJson()))).toJson(), v.toJson());
        expect(v.toJson()..remove('x'), fx(name));
      });
    }

    test('levels, scores and evidence come through as sent', () {
      final crit = ScamVerdict.fromJson(fx('urlCritical'));
      expect((crit.riskLevel, crit.riskScore), (RiskLevel.critical, 95));
      expect(crit.evidence.map((e) => e.code), containsAll(['listed_malicious', 'threat_phishing', 'not_listed']));
      final outage = ScamVerdict.fromJson(fx('urlOutage'));
      expect((outage.riskLevel, outage.riskScore, outage.isUnknown), (RiskLevel.unknown, null, true));
      expect(outage.reasons.map((r) => r.code), ['reputation_unavailable']);
      expect(outage.limitations.join(' '), contains('legitimacy could not be established'));
      final adverse = ScamVerdict.fromJson(fx('urlOutageAdverse'));
      expect(adverse.riskLevel, RiskLevel.medium);
      expect(adverse.reasons.map((r) => r.code), containsAll(['reputation_unavailable', 'ip_based_url']));
      expect(adverse.reasons.map((r) => r.code), isNot(contains('no_signals_found')));
      expect(outage.evidence.every((e) => e.polarity == Polarity.neutral), isTrue);
      final agg = ScamVerdict.fromJson(fx('aggUnknown'));
      expect((agg.riskLevel, agg.riskScore, agg.isUnknown, agg.isSafeClaim), (RiskLevel.unknown, null, true, false));
    });
  });

  group('risk level and score', () {
    test('level names parse and nothing else does (never repaired into safe)', () {
      for (final l in RiskLevel.values) {
        expect(RiskLevel.parse(l.name), l);
      }
      for (final bad in ['SAFE', 'safe ', 'ok', '', null, 3, 'severe', 'none']) {
        expect(() => RiskLevel.parse(bad), throwsFormatException, reason: '$bad');
      }
    });

    test('score boundaries: 0 and 100 are accepted, -1 and 101 are not', () {
      for (final s in [0, 1, 50, 99, 100]) {
        final d = valid()..['risk_score'] = s;
        expect(ScamVerdict.fromJson(d).riskScore, s);
      }
      for (final s in [-1, 101, 1000, 5.5, '55', true]) {
        final d = valid()..['risk_score'] = s;
        expect(() => ScamVerdict.fromJson(d), throwsFormatException, reason: '$s');
      }
    });

    test('unknown must have a null score; a server verdict may not have a null score otherwise', () {
      final u = fx('aggUnknown');
      expect(u['risk_score'], isNull);
      expect(() => ScamVerdict.fromJson({...u, 'risk_score': 0}), throwsFormatException);
      expect(() => ScamVerdict.fromJson({...valid(), 'risk_score': null}), throwsFormatException);
    });

    test('rule-based on-device detectors may report no score, and only those', () {
      final d = valid()
        ..['source_type'] = 'qr'
        ..['risk_score'] = null
        ..['engine_version'] = 'qr-rules/1';
      expect(ScamVerdict.fromJson(d).riskScore, isNull);
    });
  });

  group('missing evidence and unknown', () {
    test('medium, high and critical need adverse evidence and a reason', () {
      for (final level in ['medium', 'high', 'critical']) {
        expect(() => ScamVerdict.fromJson({...valid(), 'risk_level': level, 'evidence': []}), throwsFormatException);
        expect(() => ScamVerdict.fromJson({...valid(), 'risk_level': level, 'reasons': []}), throwsFormatException);
      }
    });

    test('low without adverse evidence needs the no_signals_found reason', () {
      final v = fx('messageLow');
      expect(ScamVerdict.fromJson(v).riskLevel, RiskLevel.low);
      expect(() => ScamVerdict.fromJson({...v, 'reasons': []}), throwsFormatException);
    });

    test('safe needs positive evidence and no adverse evidence', () {
      final base = fx('messageLow')..['risk_level'] = 'safe';
      expect(() => ScamVerdict.fromJson(base), throwsFormatException); // nothing found is not safe
      final positive = {
        'kind': 'registry_match',
        'polarity': 'positive',
        'code': 'registry_header_match',
        'source': 'registry:sms_header',
        'weight': null,
        'count': null,
      };
      expect(ScamVerdict.fromJson({...base, 'reasons': [], 'evidence': [positive]}).isSafeClaim, isTrue);
      final adverse = (valid()['evidence'] as List).first;
      expect(() => ScamVerdict.fromJson({...base, 'reasons': [], 'evidence': [positive, adverse]}), throwsFormatException);
    });

    test('a provider can never supply positive evidence and an outage is neutral', () {
      final v = fx('urlNotListed');
      final ev = List<Map<String, dynamic>>.from((v['evidence'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      ev[0]['polarity'] = 'positive';
      expect(() => ScamVerdict.fromJson({...v, 'evidence': ev}), throwsFormatException);
      final o = fx('urlOutage');
      final oe = List<Map<String, dynamic>>.from((o['evidence'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      oe[0]['polarity'] = 'adverse';
      expect(() => ScamVerdict.fromJson({...o, 'evidence': oe}), throwsFormatException);
    });

    test('the unknown factory never claims safety or a score', () {
      final v = ScamVerdict.unknown(sourceType: SourceType.qr, engineVersion: 'qr-rules/1');
      expect((v.riskLevel, v.riskScore, v.isSafeClaim), (RiskLevel.unknown, null, false));
      expect(v.limitations, isNotEmpty);
    });
  });

  group('malformed responses', () {
    final broken = <String, Object?>{
      'not an object': 'verdict',
      'a list': <Object?>[],
      'an empty object': <String, dynamic>{},
      'wrong schema version': {...valid(), 'schema_version': 2},
      'missing schema version': (valid()..remove('schema_version')),
      'non-null confidence': {...valid(), 'confidence': 0.9},
      'extra field': {...valid(), 'surprise': 1},
      'unknown level': {...valid(), 'risk_level': 'severe'},
      'null level': {...valid(), 'risk_level': null},
      'unknown source type': {...valid(), 'source_type': 'telepathy'},
      'empty limitations': {...valid(), 'limitations': <String>[]},
      'blank limitation': {...valid(), 'limitations': ['  ']},
      'limitation too long': {...valid(), 'limitations': ['x' * 201]},
      'limitations not a list': {...valid(), 'limitations': 'text'},
      'reasons not a list': {...valid(), 'reasons': 'x'},
      'reason without text': {...valid(), 'reasons': [{'code': 'insecure_http'}]},
      'reason with bad code': {...valid(), 'reasons': [{'code': 'Not A Code', 'text': 'x'}]},
      'too many reasons': {...valid(), 'reasons': List.generate(21, (i) => {'code': 'code_$i', 'text': 'x'})},
      'duplicate reasons': {...valid(), 'reasons': [{'code': 'insecure_http', 'text': 'x'}, {'code': 'insecure_http', 'text': 'y'}]},
      'evidence source free text': {...valid(), 'evidence': [{'kind': 'signal', 'polarity': 'adverse', 'code': 'insecure_http', 'source': 'http://evil.example', 'weight': 1, 'count': null}]},
      'evidence weight out of range': {...valid(), 'evidence': [{'kind': 'signal', 'polarity': 'adverse', 'code': 'insecure_http', 'source': 'heuristic:url', 'weight': 101, 'count': null}]},
      'engine version malformed': {...valid(), 'engine_version': 'url heuristics'},
      'engine version missing': (valid()..remove('engine_version')),
      'action list too long': {...valid(), 'recommended_actions': List.generate(11, (i) => {'code': 'action_$i', 'text': 'x'})},
    };

    for (final e in broken.entries) {
      test('${e.key}: fromJson throws, tryParse returns null (never a safe verdict)', () {
        expect(() => ScamVerdict.fromJson(e.value), throwsFormatException);
        expect(ScamVerdict.tryParse(e.value), isNull);
      });
    }

    test('tryParse of a missing verdict is null, of a valid one is the verdict', () {
      expect(ScamVerdict.tryParse(null), isNull);
      expect(ScamVerdict.tryParse(valid()), isNotNull);
    });
  });
}

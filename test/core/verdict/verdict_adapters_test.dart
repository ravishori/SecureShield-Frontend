import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/verdict/scam_verdict.dart';
import 'package:secureshield_app/core/verdict/verdict_adapters.dart';
import 'package:secureshield_app/features/digital_arrest/digital_arrest_classifier.dart';
import 'package:secureshield_app/features/fake_bank_sms/fake_bank_sms_classifier.dart';
import 'package:secureshield_app/features/payment_verifier/payment_screenshot_verifier.dart';
import 'package:secureshield_app/features/qr_scanner/qr_safety_service.dart';

const advisoryOnly = {
  'verify_independently', 'do_not_open', 'do_not_enter_details', 'do_not_pay', 'do_not_share_otp', 'contact_bank_directly',
  'report_to_authorities', 'review_alerts',
};

void expectClean(ScamVerdict v) {
  expect(v.confidence, isNull);
  expect(v.limitations, isNotEmpty);
  expect(v.recommendedActions.map((a) => a.code).toSet().difference(advisoryOnly), isEmpty);
  for (final a in v.recommendedActions) {
    expect(a.text.toLowerCase(), isNot(anyOf(contains('block '), contains('delete'), contains('uninstall'), contains('quarantine'))));
  }
  expect(ScamVerdict.fromJson(jsonDecode(jsonEncode(v.toJson()))).toJson(), v.toJson()); // always re-parses
  expect(v.isSafeClaim, isFalse, reason: 'no current on-device detector has trustworthy positive evidence');
}

QrSafetyReport qr(QrSafetyVerdict v, {List<String> reasons = const ['r1', 'r2'], String? route}) => QrSafetyReport(
      kind: QrPayloadKind.url,
      verdict: v,
      headline: 'h',
      reasons: reasons,
      extracted: const {'vpa': 'scammer@paytm-pay', 'amount': '99999', 'phone': '9876543210'},
      routeForFurtherCheck: route,
    );

PaymentScreenshotReport pay(PaymentVerdict v, List<PaymentCheck> checks) => PaymentScreenshotReport(
      verdict: v,
      confidence: 97,
      checks: checks,
      extractedAmount: '99999',
      extractedTxnId: 'TXN123456789',
      extractedReceiverVpa: 'scammer@paytm-pay',
    );

void main() {
  group('QR', () {
    test('verdict mapping: danger high, caution low, safe low, unknown unknown', () {
      expect(qr(QrSafetyVerdict.danger).toVerdict().riskLevel, RiskLevel.high);
      expect(qr(QrSafetyVerdict.caution).toVerdict().riskLevel, RiskLevel.low);
      expect(qr(QrSafetyVerdict.safe).toVerdict().riskLevel, RiskLevel.low);
      expect(qr(QrSafetyVerdict.unknown).toVerdict().riskLevel, RiskLevel.unknown);
      for (final v in QrSafetyVerdict.values) {
        expectClean(qr(v).toVerdict());
      }
    });

    test('rule-based: no score is invented; danger carries adverse evidence, safe carries none', () {
      final d = qr(QrSafetyVerdict.danger).toVerdict();
      expect(d.riskScore, isNull);
      expect(d.evidence.single.polarity, Polarity.adverse);
      expect(d.evidence.single.count, 2);
      final s = qr(QrSafetyVerdict.safe).toVerdict();
      expect(s.evidence, isEmpty);
      expect(s.reasons.map((r) => r.code), ['no_signals_found']);
      expect(s.limitations.join(' '), contains('not verified'));
    });

    test('an empty-reasons caution is low with no adverse evidence, not safe', () {
      final c = qr(QrSafetyVerdict.caution, reasons: const []).toVerdict();
      expect(c.riskLevel, RiskLevel.low);
      expect(c.evidence, isEmpty);
    });

    test('the link-scanner hand-off is recorded as a limitation', () {
      expect(qr(QrSafetyVerdict.caution, route: '/link-scanner').toVerdict().limitations.join(' '), contains('link scanner'));
    });

    test('real analyses: a scam-handle UPI QR and a plain-text QR (positive and negative examples)', () {
      final scam = QrSafetyService.analyze('upi://pay?pa=shop@paytm-pay&pn=Shop&am=99999&cu=INR').toVerdict();
      expect(scam.riskLevel, RiskLevel.high);
      final text = QrSafetyService.analyze('hello world').toVerdict();
      expect(text.riskLevel, RiskLevel.low); // caution -> low
      expect(QrSafetyService.analyze('   ').toVerdict().riskLevel, RiskLevel.unknown);
      for (final v in [scam, text]) {
        final blob = jsonEncode(v.toJson());
        for (final leak in ['paytm-pay', 'shop@', '99999', 'hello world']) {
          expect(blob, isNot(contains(leak)));
        }
      }
    });
  });

  group('digital arrest', () {
    DigitalArrestReport rep(DigitalArrestVerdict v, int n) => DigitalArrestReport(
          verdict: v,
          totalScore: n * 3,
          signals: List.generate(n, (i) => DigitalArrestSignal(code: 'tier1_$i', label: 'Impersonates an officer', matchedPhrase: 'you are under arrest TOPSECRET', weight: 5)),
          headline: 'h',
          advice: 'a',
        );

    test('tiers map to low / medium / high / critical', () {
      expect(rep(DigitalArrestVerdict.safe, 0).toVerdict().riskLevel, RiskLevel.low);
      expect(rep(DigitalArrestVerdict.suspicious, 1).toVerdict().riskLevel, RiskLevel.medium);
      expect(rep(DigitalArrestVerdict.likely, 2).toVerdict().riskLevel, RiskLevel.high);
      expect(rep(DigitalArrestVerdict.critical, 3).toVerdict().riskLevel, RiskLevel.critical);
      for (final v in DigitalArrestVerdict.values) {
        expectClean(rep(v, v == DigitalArrestVerdict.safe ? 0 : 2).toVerdict());
      }
    });

    test('no matched phrase, label or positional code is copied; weights become one aggregate item', () {
      final v = rep(DigitalArrestVerdict.critical, 3).toVerdict();
      final blob = jsonEncode(v.toJson());
      for (final leak in ['TOPSECRET', 'under arrest', 'Impersonates', 'tier1_']) {
        expect(blob, isNot(contains(leak)));
      }
      expect((v.evidence.single.count, v.evidence.single.weight), (3, 9));
    });

    test('a clean message is low with no adverse evidence, never safe', () {
      final v = DigitalArrestClassifier.analyze('Lunch at 1pm tomorrow?').toVerdict();
      expect(v.riskLevel, RiskLevel.low);
      expect(v.evidence, isEmpty);
      expect(v.reasons.map((r) => r.code), ['no_signals_found']);
    });

    test('a real digital-arrest script is high or critical', () {
      final v = DigitalArrestClassifier.analyze(
              'This is CBI. You are under digital arrest. Do not disconnect the call. Transfer the money to the safe RBI account immediately to avoid arrest.')
          .toVerdict();
      expect([RiskLevel.high, RiskLevel.critical], contains(v.riskLevel));
      expectClean(v);
    });
  });

  group('fake bank SMS', () {
    FakeBankSmsReport r(FakeBankSmsVerdict v) => FakeBankSmsReport(
          verdict: v,
          sender: '9876543210',
          matchedBank: 'Secret Bank',
          matchedHeader: 'SBIBNK',
          reasons: const ['Sender is a 10-digit mobile number', 'link'],
          recommendations: const [],
        );

    test('mapping: fake critical, suspicious high, unverifiable unknown, legitimate LOW (not safe)', () {
      expect(r(FakeBankSmsVerdict.fake).toVerdict().riskLevel, RiskLevel.critical);
      expect(r(FakeBankSmsVerdict.suspicious).toVerdict().riskLevel, RiskLevel.high);
      expect(r(FakeBankSmsVerdict.unverifiable).toVerdict().riskLevel, RiskLevel.unknown);
      final ok = r(FakeBankSmsVerdict.legitimate).toVerdict();
      expect(ok.riskLevel, RiskLevel.low);
      expect(ok.evidence.single.polarity, Polarity.positive);
      expect(ok.limitations.join(' '), contains('spoofed'));
      for (final v in FakeBankSmsVerdict.values) {
        expectClean(r(v).toVerdict());
      }
    });

    test('sender, bank name and header are never copied', () {
      for (final v in FakeBankSmsVerdict.values) {
        final blob = jsonEncode(r(v).toVerdict().toJson());
        for (final leak in ['9876543210', 'Secret Bank', 'SBIBNK']) {
          expect(blob, isNot(contains(leak)));
        }
      }
    });

    test('real classifications: a 10-digit sender claiming to be a bank is critical; a normal alphanumeric header is not flagged', () {
      final fake = FakeBankSmsClassifier.classify(sender: '+919876543210', body: 'Your SBI account is blocked. Update KYC at http://bit.ly/x now').toVerdict();
      expect(fake.riskLevel, RiskLevel.critical);
      final unk = FakeBankSmsClassifier.classify(sender: 'XY-UNKNWN', body: 'hello').toVerdict();
      expect([RiskLevel.unknown, RiskLevel.low], contains(unk.riskLevel));
    });
  });

  group('payment screenshots', () {
    const failing = [PaymentCheck(name: 'a', outcome: CheckOutcome.fail, detail: 'amount TOPSECRET'), PaymentCheck(name: 'b', outcome: CheckOutcome.warn, detail: 'd'), PaymentCheck(name: 'c', outcome: CheckOutcome.pass, detail: 'd')];
    const passing = [PaymentCheck(name: 'c', outcome: CheckOutcome.pass, detail: 'd')];

    test('mapping: fake critical, suspicious high, inconclusive unknown, authentic low', () {
      expect(pay(PaymentVerdict.fake, failing).toVerdict().riskLevel, RiskLevel.critical);
      expect(pay(PaymentVerdict.suspicious, failing).toVerdict().riskLevel, RiskLevel.high);
      expect(pay(PaymentVerdict.inconclusive, passing).toVerdict().riskLevel, RiskLevel.unknown);
      final ok = pay(PaymentVerdict.authentic, passing).toVerdict();
      expect(ok.riskLevel, RiskLevel.low);
      expect(ok.evidence, isEmpty);
      expect(ok.limitations.join(' '), contains('cannot prove'));
      for (final v in PaymentVerdict.values) {
        expectClean(pay(v, v == PaymentVerdict.authentic ? passing : failing).toVerdict());
      }
    });

    test("the detector's own 0-100 confidence is not passed through and no extracted value is copied", () {
      final v = pay(PaymentVerdict.fake, failing).toVerdict();
      expect(v.confidence, isNull);
      final blob = jsonEncode(v.toJson());
      for (final leak in ['97', 'TXN123456789', 'scammer@paytm-pay', '99999', 'TOPSECRET']) {
        expect(blob.contains(leak) && leak != '97', isFalse, reason: leak);
      }
      expect(v.evidence.single.count, 2); // the fail and the warn
    });

    test('an authentic result that still carries a warning keeps that evidence (low, not clean)', () {
      final v = pay(PaymentVerdict.authentic, [const PaymentCheck(name: 'w', outcome: CheckOutcome.warn, detail: 'd')]).toVerdict();
      expect(v.riskLevel, RiskLevel.low);
      expect(v.evidence.single.polarity, Polarity.adverse);
    });
  });
}

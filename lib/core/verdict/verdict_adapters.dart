/// Adapters from the on-device detectors' EXISTING reports to the shared `scam_verdict/1` contract.
///
/// Rules (see docs/development/X1_IMPLEMENTATION_PLAN.md): detector logic and thresholds are untouched; nothing is invented
/// (confidence is always null, and a score is never made up for rule-based detectors); nothing the user submitted (QR
/// payload, SMS text or sender, matched phrases, payment details) is copied into a verdict; and nothing here blocks anything.
/// No current detector qualifies for [RiskLevel.safe]: it needs trustworthy positive evidence, and these rule tables are not.
library;

import '../../features/digital_arrest/digital_arrest_classifier.dart';
import '../../features/fake_bank_sms/fake_bank_sms_classifier.dart';
import '../../features/payment_verifier/payment_screenshot_verifier.dart';
import '../../features/qr_scanner/qr_safety_service.dart';
import 'scam_verdict.dart';

const _noSignals = Reason(code: 'no_signals_found', text: 'No risk signals were found by the built-in checks.');
const _ruleMatches = Reason(code: 'rule_matches', text: "The detector's rules flagged this item.");

const _verifyIndependently = Reason(code: 'verify_independently', text: 'If you did not expect this, check it another way before acting.');
const _doNotOpen = Reason(code: 'do_not_open', text: 'Do not open the link.');
const _doNotEnter = Reason(code: 'do_not_enter_details', text: 'Do not enter passwords, OTPs or card details.');
const _doNotPay = Reason(code: 'do_not_pay', text: 'Do not make any payment.');
const _contactBank = Reason(code: 'contact_bank_directly', text: 'Contact your bank using the number printed on your card or on its official website.');
const _report = Reason(code: 'report_to_authorities', text: 'Consider reporting this to the national cyber-crime portal.');

Evidence _ruleEvidence(String detector, {int? count, int? weight}) => Evidence(
      kind: EvidenceKind.signal,
      polarity: Polarity.adverse,
      code: 'rule_matches',
      source: 'rule:$detector',
      count: (count != null && count > 0) ? count.clamp(1, 10000).toInt() : null,
      weight: weight?.clamp(0, 100).toInt(),
    );

/// QR payloads. `danger` -> high; `caution` -> low (advice to verify, not proof of risk); `safe` -> low (it only means no
/// rule fired; the payee or site is not verified); `unknown` -> unknown. The payload, `extracted` map and reason text are
/// never copied.
extension QrVerdictAdapter on QrSafetyReport {
  ScamVerdict toVerdict() {
    const engine = 'qr-rules/1';
    final limitations = <String>[
      'Rule-based checks of the QR content only; the destination or payee is not verified.',
      if (routeForFurtherCheck != null) 'Links inside QR codes should also be checked with the link scanner.',
    ];
    switch (verdict) {
      case QrSafetyVerdict.unknown:
        return ScamVerdict.unknown(sourceType: SourceType.qr, engineVersion: engine, limitation: 'The QR content could not be classified.');
      case QrSafetyVerdict.danger:
        return ScamVerdict.create(
          riskLevel: RiskLevel.high,
          reasons: const [_ruleMatches],
          evidence: [_ruleEvidence('qr', count: reasons.length)],
          sourceType: SourceType.qr,
          limitations: limitations,
          recommendedActions: const [_doNotOpen, _doNotPay, _doNotEnter],
          engineVersion: engine,
        );
      case QrSafetyVerdict.caution:
        return ScamVerdict.create(
          riskLevel: RiskLevel.low,
          reasons: reasons.isEmpty ? const [_noSignals] : const [_ruleMatches],
          evidence: reasons.isEmpty ? const [] : [_ruleEvidence('qr', count: reasons.length)],
          sourceType: SourceType.qr,
          limitations: [...limitations, 'The detector advises caution because the content cannot be verified automatically.'],
          recommendedActions: const [_verifyIndependently],
          engineVersion: engine,
        );
      case QrSafetyVerdict.safe:
        return ScamVerdict.create(
          riskLevel: RiskLevel.low,
          reasons: const [_noSignals],
          sourceType: SourceType.qr,
          limitations: [...limitations, 'No adverse signal does not mean the code is trustworthy.'],
          recommendedActions: const [_verifyIndependently],
          engineVersion: engine,
        );
    }
  }
}

/// Digital-arrest wording. safe -> low, suspicious -> medium, likely -> high, critical -> critical (the classifier's own
/// tiers). The matched phrases and signal labels are never copied; signal weights become one aggregate evidence item.
extension DigitalArrestVerdictAdapter on DigitalArrestReport {
  ScamVerdict toVerdict() {
    const engine = 'digital-arrest-signals/1';
    final limitations = ['Wording analysis only: it cannot know who is really calling or messaging.'];
    final level = switch (verdict) {
      DigitalArrestVerdict.safe => RiskLevel.low,
      DigitalArrestVerdict.suspicious => RiskLevel.medium,
      DigitalArrestVerdict.likely => RiskLevel.high,
      DigitalArrestVerdict.critical => RiskLevel.critical,
    };
    if (level == RiskLevel.low) {
      return ScamVerdict.create(
        riskLevel: level,
        reasons: signals.isEmpty ? const [_noSignals] : const [_ruleMatches],
        evidence: signals.isEmpty ? const [] : [_ruleEvidence('digital_arrest', count: signals.length, weight: totalScore)],
        sourceType: SourceType.digitalArrest,
        limitations: [...limitations, 'No adverse signal does not mean the contact is genuine.'],
        recommendedActions: const [_verifyIndependently],
        engineVersion: engine,
      );
    }
    return ScamVerdict.create(
      riskLevel: level,
      reasons: const [_ruleMatches],
      evidence: [_ruleEvidence('digital_arrest', count: signals.length, weight: totalScore)],
      sourceType: SourceType.digitalArrest,
      limitations: limitations,
      recommendedActions: const [_doNotPay, _verifyIndependently, _report],
      engineVersion: engine,
    );
  }
}

/// Bank-SMS sender check. fake -> critical, suspicious -> high, unverifiable -> unknown. `legitimate` (the sender code
/// matched a small built-in table) is recorded as positive evidence but stays LOW: the table is not the telecom registry and
/// headers can be spoofed, so it is not trustworthy enough for `safe`. Sender, bank name and message text are never copied.
extension FakeBankSmsVerdictAdapter on FakeBankSmsReport {
  ScamVerdict toVerdict() {
    const engine = 'fake-bank-sms-rules/1';
    switch (verdict) {
      case FakeBankSmsVerdict.unverifiable:
        return ScamVerdict.unknown(
          sourceType: SourceType.fakeBankSms,
          engineVersion: engine,
          limitation: 'The sender could not be matched to a known bank sender, so no judgement is made.',
        );
      case FakeBankSmsVerdict.legitimate:
        return ScamVerdict.create(
          riskLevel: RiskLevel.low,
          reasons: const [_noSignals],
          evidence: const [
            Evidence(kind: EvidenceKind.registryMatch, polarity: Polarity.positive, code: 'registry_header_match', source: 'registry:builtin_bank_headers'),
          ],
          sourceType: SourceType.fakeBankSms,
          limitations: const [
            'Matched against a small built-in table of bank sender codes, not the full telecom registry.',
            'Sender headers can be spoofed; a match does not prove the message is genuine.',
          ],
          recommendedActions: const [_verifyIndependently],
          engineVersion: engine,
        );
      case FakeBankSmsVerdict.suspicious:
      case FakeBankSmsVerdict.fake:
        return ScamVerdict.create(
          riskLevel: verdict == FakeBankSmsVerdict.fake ? RiskLevel.critical : RiskLevel.high,
          reasons: const [_ruleMatches],
          evidence: [_ruleEvidence('fake_bank_sms', count: reasons.length)],
          sourceType: SourceType.fakeBankSms,
          limitations: const ['Rule-based checks of the sender format and wording only.'],
          recommendedActions: const [_doNotOpen, _contactBank, _report],
          engineVersion: engine,
        );
    }
  }
}

/// Payment screenshots. fake -> critical, suspicious -> high, inconclusive -> unknown, authentic -> low. The detector's own
/// 0-100 `confidence` is a heuristic score, not a probability, so it is NOT passed through. Extracted amounts, IDs and VPAs are
/// never copied.
extension PaymentVerdictAdapter on PaymentScreenshotReport {
  ScamVerdict toVerdict() {
    const engine = 'payment-checks/1';
    const limitations = [
      'A screenshot cannot prove that a payment was made; check your bank app or statement.',
      'Only the image text and layout are checked.',
    ];
    final flagged = checks.where((c) => c.outcome == CheckOutcome.fail || c.outcome == CheckOutcome.warn).length;
    switch (verdict) {
      case PaymentVerdict.inconclusive:
        return ScamVerdict.unknown(sourceType: SourceType.paymentScreenshot, engineVersion: engine, limitation: limitations.first);
      case PaymentVerdict.authentic:
        return ScamVerdict.create(
          riskLevel: RiskLevel.low,
          reasons: flagged == 0 ? const [_noSignals] : const [_ruleMatches],
          evidence: flagged == 0 ? const [] : [_ruleEvidence('payment', count: flagged)],
          sourceType: SourceType.paymentScreenshot,
          limitations: [...limitations, 'No adverse signal does not mean the payment is real.'],
          recommendedActions: const [_verifyIndependently],
          engineVersion: engine,
        );
      case PaymentVerdict.suspicious:
      case PaymentVerdict.fake:
        return ScamVerdict.create(
          riskLevel: verdict == PaymentVerdict.fake ? RiskLevel.critical : RiskLevel.high,
          reasons: const [_ruleMatches],
          evidence: [_ruleEvidence('payment', count: flagged)],
          sourceType: SourceType.paymentScreenshot,
          limitations: limitations,
          recommendedActions: const [_doNotPay, _verifyIndependently, _report],
          engineVersion: engine,
        );
    }
  }
}

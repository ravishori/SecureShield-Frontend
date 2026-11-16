/// SMS analysis result (Stage 1.6D-4): an honest summary of what was checked and what that does and does not prove.
///
/// Rules this view follows:
///  * a low pattern score is never presented as "safe" (nothing here can prove a message is genuine);
///  * "registered sender" is positive evidence about the SENDER NAME only, with the caveat shown next to it;
///  * "not found in the registry" is a warning sign, not proof of fraud;
///  * "registry unavailable" is a different state from "not found" and says nothing about the sender;
///  * the shared verdict's score, reasons, evidence, confidence, limitations and actions are shown when the server sent one,
///    otherwise the legacy fields are shown with the same caveats.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/verdict/scam_verdict.dart';
import '../../../core/verdict/verdict_headline.dart';

/// Headline for a message result. Never "safe" from a low score alone.
String messageHeadline(Map<String, dynamic> result, ScamVerdict? verdict) {
  if (verdict != null) {
    return switch (verdict.riskLevel) {
      RiskLevel.safe => 'NO WARNING SIGNS FOUND',
      RiskLevel.low => 'LOW RISK',
      final other => verdictHeadlineLabel(other),
    };
  }
  // Legacy response (older server): is_safe true only means "the checks found nothing", and a missing value is never safe.
  return (result['is_safe'] as bool? ?? false) ? 'No warning signs found' : 'Suspicious Message!';
}

enum SenderTone { good, warning, bad, neutral }

class SenderStatus {
  final String label;
  final String caveat;
  final SenderTone tone;
  const SenderStatus(this.label, this.caveat, this.tone);
}

/// What to tell the user about the sender. REGISTERED, UNREGISTERED, PHONE_NUMBER and "registry unavailable" are four
/// different states, and each has its own caveat.
SenderStatus senderStatus(Map<String, dynamic> sv) {
  final verdict = sv['verdict'] as String? ?? 'UNKNOWN';
  final lookup = sv['lookup_status'] as String?;
  switch (verdict) {
    case 'REGISTERED':
      return const SenderStatus(
        'Registered sender name',
        'A registered sender name does not prove this message is genuine. Scammers can copy real names, so judge the message itself.',
        SenderTone.good,
      );
    case 'UNREGISTERED':
      return const SenderStatus(
        'Not found in the TRAI registry',
        'This is a warning sign, not proof of fraud: new, renamed or unusual sender IDs can also be missing from the list.',
        SenderTone.bad,
      );
    case 'PHONE_NUMBER':
      return const SenderStatus(
        'Sent from a personal phone number',
        'Banks and companies normally use registered sender names, so a personal number claiming to be one deserves extra care.',
        SenderTone.warning,
      );
    default:
      if (lookup == 'unavailable') {
        return const SenderStatus(
          'Sender check unavailable',
          'The sender registry could not be reached, so this sender was not checked. That says nothing about whether it is genuine or fake.',
          SenderTone.neutral,
        );
      }
      return const SenderStatus(
        'Sender not verified',
        'No sender was available to check, so the result is based on the message wording only.',
        SenderTone.neutral,
      );
  }
}

Color _toneColor(SenderTone t) => switch (t) {
      SenderTone.good => AppTheme.success,
      SenderTone.warning => AppTheme.warning,
      SenderTone.bad => AppTheme.errorColor,
      SenderTone.neutral => AppTheme.textSecondary,
    };

Color _riskColor(RiskLevel? level, bool legacySafe) => switch (level) {
      RiskLevel.critical || RiskLevel.high => AppTheme.errorColor,
      RiskLevel.medium => AppTheme.warning,
      RiskLevel.low || RiskLevel.safe => AppTheme.success,
      RiskLevel.unknown => AppTheme.textSecondary,
      null => legacySafe ? AppTheme.success : AppTheme.warning,
    };

class MessageResultView extends StatelessWidget {
  final Map<String, dynamic> result;
  const MessageResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final verdict = ScamVerdict.tryParse(result['verdict']);
    final legacySafe = result['is_safe'] as bool? ?? false;
    final sv = result['sender_validation'] is Map ? Map<String, dynamic>.from(result['sender_validation'] as Map) : null;
    final headline = messageHeadline(result, verdict);
    final color = _riskColor(verdict?.riskLevel, legacySafe);
    final score = verdict?.riskScore ?? (result['risk_score'] is num ? (result['risk_score'] as num).round() : null);
    final confidence = verdict?.confidence;
    final reasons = verdict != null
        ? [for (final r in verdict.reasons) r.text]
        : [for (final f in (result['red_flags'] as List? ?? const [])) f.toString()];
    final limitations = verdict != null && verdict.limitations.isNotEmpty
        ? verdict.limitations
        : const ['Pattern check only: it cannot understand context or confirm that a message is genuine.'];
    final actions = verdict != null && verdict.recommendedActions.isNotEmpty
        ? [for (final a in verdict.recommendedActions) a.text]
        : _fallbackActions(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, key: const Key('message_headline'), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                score == null ? 'Risk score: not available' : 'Risk score: $score / 100',
                key: const Key('message_risk_score'),
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                confidence == null ? 'Confidence: not rated (pattern matching only)' : 'Confidence: ${(confidence * 100).round()}%',
                key: const Key('message_confidence'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (sv != null) SenderStatusCard(data: sv),
        if (reasons.isNotEmpty)
          _Section(
            key: const Key('message_evidence'),
            title: 'Why this result',
            lines: [for (final r in reasons) '• $r'],
          ),
        if (verdict != null && verdict.evidence.any((e) => e.kind == EvidenceKind.registryMatch))
          _Section(
            key: const Key('message_registry_evidence'),
            title: 'Registry evidence',
            lines: [
              for (final e in verdict.evidence.where((e) => e.kind == EvidenceKind.registryMatch))
                e.polarity == Polarity.positive
                    ? '✓ Sender name found in the registry (does not prove the message is genuine)'
                    : '• Sender not found in the registry (a warning sign, not proof)',
            ],
          ),
        _Section(key: const Key('message_limitations'), title: 'What this check cannot tell you', lines: limitations, italic: true),
        _Section(key: const Key('message_actions'), title: 'What to do next', lines: [for (final a in actions) '→ $a']),
      ],
    );
  }

  static List<String> _fallbackActions(Map<String, dynamic> result) {
    final action = result['action'] as String?;
    return [
      if (action != null && action.trim().isNotEmpty) action.trim(),
      'Do not share OTPs or PINs, and do not tap links in the message.',
      'If it claims to be your bank, call the number printed on your card or the bank\'s official website.',
    ];
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> lines;
  final bool italic;
  const _Section({super.key, required this.title, required this.lines, this.italic = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(l, style: TextStyle(fontSize: 13, height: 1.4, fontStyle: italic ? FontStyle.italic : FontStyle.normal)),
              ),
          ],
        ),
      );
}

/// The sender block: the registry result with its caveat. Distinguishes registered, not found, phone number, unavailable.
class SenderStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const SenderStatusCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = senderStatus(data);
    final color = _toneColor(status.tone);
    final entity = data['principal_entity_name'] as String?;
    final suffix = data['sender_suffix'] as String?;
    final shown = data['sender_id'] as String? ?? data['header'] as String?;
    return Container(
      key: const Key('sender_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sender check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(status.label, key: const Key('sender_status'), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          if (shown != null && shown.isNotEmpty) Text('Sender: $shown${suffix == null ? '' : ' (category -$suffix)'}', style: const TextStyle(fontSize: 12)),
          if (entity != null) Text('Registered to: $entity', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(status.caveat, key: const Key('sender_caveat'), style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

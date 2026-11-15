import '../../core/verdict/scam_verdict.dart';
import 'hub_input.dart';

/// Why a request produced no verdict. A request failure is NOT a verdict: it is never LOW and never SAFE.
enum FailureKind { network, timeout, server, auth, rateLimited, cancelled }

sealed class HubOutcome {
  final HubRoute route;
  const HubOutcome(this.route);
}

/// A verdict was produced. [local] means it came from an on-device check with no network call (QR). [synthesized] means
/// the server answered but gave no usable verdict, so an UNKNOWN verdict was built here (never SAFE).
class HubVerdict extends HubOutcome {
  final ScamVerdict verdict;
  final bool local;
  final bool synthesized;
  final String? checkableUrl; // set only for a QR that carries a URL; the reputation lookup still needs an explicit tap
  const HubVerdict(super.route, this.verdict, {this.local = false, this.synthesized = false, this.checkableUrl});
}

class HubRequestFailed extends HubOutcome {
  final FailureKind kind;
  const HubRequestFailed(super.route, this.kind);
}

enum NoticeKind { providerOutage, unknownEvidence, localOnlyQr, requestFailure }

class HubNotice {
  final NoticeKind kind;
  final String text;
  const HubNotice(this.kind, this.text);
}

/// Incomplete-check explanations come from structured verdict codes, never from parsing free text.
List<HubNotice> explainCompleteness(HubOutcome o) {
  switch (o) {
    case HubRequestFailed(:final kind):
      final why = switch (kind) {
        FailureKind.network => 'There was no network connection.',
        FailureKind.timeout => 'The request timed out.',
        FailureKind.server => 'The server had a problem.',
        FailureKind.auth => 'You need to sign in again.',
        FailureKind.rateLimited => 'Too many requests. Wait a moment and try again.',
        FailureKind.cancelled => 'The request was cancelled.',
      };
      return [HubNotice(NoticeKind.requestFailure, 'The check did not complete. $why Nothing was learned about this input, so it is not safe or unsafe.')];
    case HubVerdict(:final verdict, :final local, :final synthesized, :final checkableUrl):
      final notices = <HubNotice>[];
      final outage = verdict.reasons.any((r) => r.code == 'reputation_unavailable') ||
          verdict.evidence.any((e) => e.kind == EvidenceKind.providerUnavailable);
      if (local) {
        notices.add(HubNotice(
            NoticeKind.localOnlyQr,
            checkableUrl != null
                ? "Checked on this device only. No reputation lookup was made. You can choose to check this link's reputation."
                : 'Checked on this device only. No reputation lookup was made.'));
      }
      if (outage) {
        notices.add(HubNotice(
            NoticeKind.providerOutage,
            verdict.isUnknown
                ? 'Reputation services could not be reached, so known-bad lists were not consulted. Legitimacy could not be established.'
                : 'Reputation services could not be reached, so known-bad lists were not consulted.'));
      } else if (verdict.isUnknown) {
        notices.add(HubNotice(
            NoticeKind.unknownEvidence,
            synthesized
                ? 'The server did not return a usable result, so this could not be judged.'
                : 'There was not enough information to judge this.'));
      }
      return notices;
  }
}

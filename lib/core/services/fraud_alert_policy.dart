/// Documented risk policy for the on-device "possible scam" notification (finding F-DEV-2).
///
/// Responsibilities:
///  * The BACKEND verdict is authoritative once it is available. Its levels use the server's own cut-offs
///    (message: >= 70 high, >= 40 medium, >= 20 low), so the app never re-derives a level from a score when a verdict exists.
///  * The on-device keyword engine is an OFFLINE FALLBACK only, used when no server result could be obtained.
///
/// Policy (a notification interrupts the user, so it is reserved for high risk):
///  | Source                       | Condition                         | Notification |
///  | verdict                      | high or critical                  | yes          |
///  | verdict                      | medium (suspicious)               | no, in-app result only |
///  | verdict                      | low, safe, unknown                | no           |
///  | legacy server (no verdict)   | risk_score >= 70                  | yes          |
///  | legacy server (no verdict)   | risk_score < 70 or missing        | no           |
///  | server unreachable           | >= 3 distinct keyword hits        | yes (offline fallback, PROVISIONAL) |
///  | server unreachable           | fewer hits                        | no           |
///
/// The old rule (`hits / categoryKeywordCount > 0.5`) required more than half of a category's whole keyword list to
/// appear in one message, which real messages never do, so it never fired.
library;

import '../verdict/scam_verdict.dart';

/// Minimum distinct keyword hits for the offline fallback.
///
/// PROVISIONAL: three is an engineering estimate, not a measured or approved threshold. It applies only when no server
/// answer exists, and must be reviewed against real false-positive data before release.
const int offlineFallbackMinKeywordHits = 3;

/// Legacy (no `verdict`) message score at which the server itself calls a message high risk.
const int legacyHighRiskScore = 70;

enum FraudAlertSource { verdict, legacyScore, offlineKeywords, none }

class FraudAlertDecision {
  final bool notify;
  final FraudAlertSource source;
  const FraudAlertDecision(this.notify, this.source);
}

/// Decision when the server answered. [verdict] is the parsed shared verdict (null if absent or malformed);
/// [legacyRiskScore] is the old `risk_score` field of an older server.
FraudAlertDecision decideFromServer({ScamVerdict? verdict, Object? legacyRiskScore}) {
  if (verdict != null) {
    final high = verdict.riskLevel == RiskLevel.high || verdict.riskLevel == RiskLevel.critical;
    return FraudAlertDecision(high, FraudAlertSource.verdict);
  }
  if (legacyRiskScore is num && legacyRiskScore >= legacyHighRiskScore) {
    return const FraudAlertDecision(true, FraudAlertSource.legacyScore);
  }
  return const FraudAlertDecision(false, FraudAlertSource.none);
}

/// Decision when no server result is available (offline, error). Never used when the server answered.
FraudAlertDecision decideOffline({required int matchedKeywordCount}) => matchedKeywordCount >= offlineFallbackMinKeywordHits
    ? const FraudAlertDecision(true, FraudAlertSource.offlineKeywords)
    : const FraudAlertDecision(false, FraudAlertSource.none);

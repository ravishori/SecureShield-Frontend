/// Whether the dashboard has enough evidence to show a protection score (finding F-DEV-1).
///
/// "Nothing was checked" is NOT "no risk": a missing report, malformed counts, or a day with no alerts and no scan
/// activity is NOT ASSESSED, never 100/100. This matches the backend daily-report verdict (`unknown` / `no_activity`).
/// A report with real activity keeps the server's own `security_score` unchanged.
library;

enum AssessmentState { assessed, notAssessed }

class SecurityAssessment {
  final AssessmentState state;
  final double? score; // 0..100, only when assessed
  final String reason; // shown to the user when not assessed

  const SecurityAssessment._(this.state, this.score, this.reason);

  bool get isAssessed => state == AssessmentState.assessed;

  static const String noReportReason = 'We could not load your security report yet. Check your connection and pull to refresh.';
  static const String noActivityReason =
      'No scans or alerts yet, so there is not enough evidence to rate your protection. Run a device scan to get a score.';

  factory SecurityAssessment.fromReport(Map<String, dynamic>? report) {
    if (report == null) return const SecurityAssessment._(AssessmentState.notAssessed, null, noReportReason);
    int? count(String key) {
      final v = report[key];
      return v is num && v >= 0 ? v.toInt() : null;
    }

    final threats = count('threats_detected');
    final apps = count('apps_scanned');
    final links = count('links_scanned');
    final calls = count('calls_analyzed');
    if (threats == null || apps == null || links == null || calls == null) {
      return const SecurityAssessment._(AssessmentState.notAssessed, null, noReportReason);
    }
    if (threats + apps + links + calls == 0) {
      return const SecurityAssessment._(AssessmentState.notAssessed, null, noActivityReason);
    }
    final server = report['security_score'];
    final risk = report['overall_risk_score'];
    final double raw;
    if (server is num) {
      raw = server.toDouble();
    } else if (risk is num) {
      raw = 100 - risk.toDouble();
    } else {
      return const SecurityAssessment._(AssessmentState.notAssessed, null, noReportReason);
    }
    return SecurityAssessment._(AssessmentState.assessed, raw.clamp(0.0, 100.0).toDouble(), '');
  }
}

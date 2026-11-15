import 'scam_verdict.dart';

/// The one place that turns a verdict level into its headline. SAFE only for a `safe` verdict; UNKNOWN is never softened.
String verdictHeadlineLabel(RiskLevel level) => switch (level) {
      RiskLevel.safe => 'SAFE',
      RiskLevel.low => 'LOW RISK',
      RiskLevel.medium => 'SUSPICIOUS',
      RiskLevel.high => 'HIGH RISK',
      RiskLevel.critical => 'CRITICAL RISK',
      RiskLevel.unknown => 'UNABLE TO VERIFY',
    };

/// Headline for a request that produced no verdict at all. A distinct, non-risk state: never LOW, never SAFE.
const String couldNotCheckLabel = 'COULD NOT CHECK';

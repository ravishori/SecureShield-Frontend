/// Fake/clone app detection engine.
///
/// Detects impersonators by:
///  1. Exact match against trusted catalog (known-good apps)
///  2. Similarity matching (Jaro-Winkler) against known brands
///  3. Package-name pattern analysis
///  4. Confusable-character detection
///
/// Works fully offline. Zero network calls.
library;

import 'similarity_metrics.dart';
import 'trusted_app_catalog.dart';

enum FakeAppRisk {
  notFake,        // Trusted or clearly legitimate
  suspected,      // Similar to a known brand (medium caution)
  likelyFake,     // Strong similarity + suspicious packaging
  probablyFake,   // Multiple red flags
}

extension FakeAppRiskExt on FakeAppRisk {
  String get label {
    switch (this) {
      case FakeAppRisk.notFake: return 'Not Fake';
      case FakeAppRisk.suspected: return 'Suspicious';
      case FakeAppRisk.likelyFake: return 'Likely Fake';
      case FakeAppRisk.probablyFake: return 'Probably Fake';
    }
  }

  bool get shouldWarn => index >= FakeAppRisk.suspected.index;
  String get emoji {
    switch (this) {
      case FakeAppRisk.notFake: return '✅';
      case FakeAppRisk.suspected: return '⚠️';
      case FakeAppRisk.likelyFake: return '🚨';
      case FakeAppRisk.probablyFake: return '🚫';
    }
  }
}

class FakeAppAnalysis {
  final String packageName;
  final String appLabel;
  final FakeAppRisk risk;
  final String? impersonatesApp; // e.g., "WhatsApp" if suspicious
  final List<String> reasons;

  const FakeAppAnalysis({
    required this.packageName,
    required this.appLabel,
    required this.risk,
    this.impersonatesApp,
    required this.reasons,
  });
}

class FakeAppDetector {
  FakeAppDetector._();

  // ── Similarity thresholds (tuned via real-world testing) ──────────────────
  static const double _jaroWinklerHigh = 0.92;   // Strong impersonation
  static const double _jaroWinklerMed = 0.88;    // Medium risk
  static const double _packageSimilarityThresh = 0.85;

  /// Analyze an app for fake/clone status.
  ///
  /// Input: [packageName] and [appLabel] from PackageManager.
  /// Returns: detailed analysis with risk level + reasons.
  static FakeAppAnalysis analyze(String packageName, String appLabel) {
    // Phase 1: Check against trusted catalog
    if (TrustedAppCatalog.lookup(packageName) != null) {
      return FakeAppAnalysis(
        packageName: packageName,
        appLabel: appLabel,
        risk: FakeAppRisk.notFake,
        reasons: ['Verified in trusted app catalog'],
      );
    }

    // Phase 2: Normalize inputs for comparison
    final normLabel = SimilarityMetrics.normalize(appLabel);
    final normPkgId = _packageIdSegments(packageName).join('');

    final reasons = <String>[];
    var maxRisk = FakeAppRisk.notFake;
    String? impersonates;

    // Phase 3: Check similarity against all known brands
    for (final trusted in TrustedAppCatalog.all) {
      final normTrustedLabel = SimilarityMetrics.normalize(trusted.label);
      final normTrustedPkg = _packageIdSegments(trusted.packageName).join('');

      // Jaro-Winkler on labels (catches WhaatsApp vs WhatsApp)
      final labelSim =
          SimilarityMetrics.jaroWinkler(normLabel, normTrustedLabel);

      // Also check confusable-folded version (catches SBl vs SBI)
      final foldedLabel = SimilarityMetrics.foldConfusables(normLabel);
      final foldedTrustedLabel =
          SimilarityMetrics.foldConfusables(normTrustedLabel);
      final foldedLabelSim = SimilarityMetrics.jaroWinkler(
          foldedLabel, foldedTrustedLabel);
      final bestLabelSim = labelSim > foldedLabelSim ? labelSim : foldedLabelSim;

      // Package ID similarity (catches "com.whatsap.app" vs "com.whatsapp")
      final pkgSim = SimilarityMetrics.jaroWinkler(normPkgId, normTrustedPkg);

      // Determine risk from label similarity
      if (bestLabelSim >= _jaroWinklerHigh) {
        final risk = FakeAppRisk.likelyFake;
        reasons.add(
            'App label very similar to ${trusted.label} (${(bestLabelSim * 100).toStringAsFixed(0)}%)');
        if (risk.index > maxRisk.index) {
          maxRisk = risk;
          impersonates = trusted.label;
        }
      } else if (bestLabelSim >= _jaroWinklerMed) {
        final risk = FakeAppRisk.suspected;
        reasons.add(
            'App label somewhat similar to ${trusted.label} (${(bestLabelSim * 100).toStringAsFixed(0)}%)');
        if (risk.index > maxRisk.index) {
          maxRisk = risk;
          impersonates = trusted.label;
        }
      }

      // Package-name red flag (rare but check it)
      if (pkgSim >= _packageSimilarityThresh && pkgSim > bestLabelSim) {
        reasons.add(
            'Package ID similar to ${trusted.label} (${(pkgSim * 100).toStringAsFixed(0)}%)');
      }
    }

    // Phase 4: Heuristic red flags
    if (maxRisk == FakeAppRisk.notFake) {
      // Check for generic/spammy label patterns
      if (_isSpammyLabel(appLabel)) {
        maxRisk = FakeAppRisk.suspected;
        reasons.add('App label has spammy/generic pattern');
      }

      // Check for randomized/suspicious package names
      if (_isSuspiciousPackageId(packageName)) {
        maxRisk = FakeAppRisk.suspected;
        reasons.add('Package ID has suspicious structure (random segments)');
      }
    }

    // If still no risk detected, mark as safe
    if (reasons.isEmpty) {
      reasons.add('No fake app indicators detected');
    }

    return FakeAppAnalysis(
      packageName: packageName,
      appLabel: appLabel,
      risk: maxRisk,
      impersonatesApp: impersonates,
      reasons: reasons,
    );
  }

  /// Extract segments from package name (e.g., "com.whatsapp.app" → ["com", "whatsapp", "app"])
  static List<String> _packageIdSegments(String pkg) {
    return pkg.split('.').where((s) => s.isNotEmpty).toList();
  }

  /// Heuristic: does the label look spammy/generic?
  /// Examples: "Free Game", "Fast Browser", "New App"
  static bool _isSpammyLabel(String label) {
    final lower = label.toLowerCase();
    final spammyKeywords = [
      'free ',
      ' game',
      ' app',
      ' browser',
      ' launcher',
      ' cleaner',
      ' booster',
      ' master',
      ' pro',
      ' lite',
      'new ',
      'fast ',
      'best ',
      'super ',
    ];
    return spammyKeywords.any((kw) => lower.contains(kw));
  }

  /// Heuristic: does the package ID look randomized or suspicious?
  /// Examples: "com.abc.xyz123", "app.random.stuff"
  static bool _isSuspiciousPackageId(String pkg) {
    final segments = _packageIdSegments(pkg);
    if (segments.length < 2) return true; // Too short (e.g., "myapp")

    // Check if any segment is mostly digits or looks random
    for (final seg in segments) {
      if (seg.length >= 3) {
        final digitCount = seg.split('').where((c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0).length;
        if (digitCount > seg.length * 0.5) {
          // More than 50% digits = suspicious (e.g., "abc123def456")
          return true;
        }
      }
    }

    return false;
  }
}

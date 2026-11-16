/// Fake / clone-app detection engine — v3.
///
/// Detects impersonators by:
///   1. Exact catalog match              → trusted, short-circuit
///   2. System-app gate                  → never a clone of itself
///   3. Trusted publisher prefix         → trusted, short-circuit
///   4. Publisher-token intersection     → same publisher → skip
///   5. Similarity matching against OTHER brands
///   6. Confusable-character detection   → e.g. "SBl" vs "SBI"
///   7. Spammy-label / suspicious-package heuristics
///
/// Works fully offline. Zero network calls.
///
/// v3 fixes (the notification-spam fix):
///   • Added `isSystem` parameter — system apps short-circuit immediately
///   • Trusted-publisher-prefix gate (mirrors AppRiskEngine's list)
///   • Phase 2 now uses **set intersection** of distinctive tokens, not
///     longest-token equality. So `com.icicidirect.idirectsuper` correctly
///     matches `com.icicidirect.app` (both share token "icicidirect") instead
///     of being flagged as a clone of itself.
///   • `com.android.*`, `com.miui.*`, `com.samsung.*` etc. treated as system
///     even without the isSystem flag.
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
  final String? impersonatesApp;
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
  static const double _jaroWinklerHigh = 0.93;
  static const double _jaroWinklerMed = 0.90;
  static const double _packageSimilarityThresh = 0.93;
  static const int _minLabelLen = 5;

  static const Set<String> _genericPkgSegments = {
    'com', 'co', 'org', 'net', 'io', 'in', 'us', 'me',
    'app', 'apps', 'android', 'mobile', 'global', 'lite',
    'pro', 'plus', 'free', 'beta', 'dev', 'test',
    'go', 'now', 'api', 'sdk', 'inc', 'ltd', 'pvt',
    'service', 'services', 'providers', 'provider',
  };

  /// Package-name prefixes that belong to OS / OEM system software. Apps in
  /// these namespaces are never user-visible clones — they ship with the
  /// device. Mirrors AppRiskEngine's prefix list, slightly narrower.
  static const List<String> _systemPrefixes = [
    'com.android.',
    'android.',
    'com.google.android.',
    'com.miui.',
    'com.xiaomi.',
    'com.mi.',
    'com.samsung.',
    'com.sec.',
    'com.oppo.',
    'com.coloros.',
    'com.heytap.',
    'com.realme.',
    'com.vivo.',
    'com.iqoo.',
    'com.huawei.',
    'com.hihonor.',
    'com.oneplus.',
  ];

  /// Trusted publisher prefixes (mirrors AppRiskEngine's list, abbreviated).
  /// An app whose package starts with one of these is auto-trusted regardless
  /// of label similarity.
  static const List<String> _trustedPublisherPrefixes = [
    'com.google.',
    'com.microsoft.',
    'com.facebook.',
    'com.instagram.',
    'com.whatsapp.',
    'com.amazon.',
    'in.amazon.',
    'com.adobe.',
    'org.mozilla.',
    'com.opera.',
    'com.brave.',
    'com.duckduckgo.',
    // Indian banks + fintech (full list mirrored from engine)
    'com.sbi.',         'com.sbilife.',    'com.sbicard.',
    'com.hdfcbank.',    'com.hdfcsec.',    'com.hdfclife.',
    'com.icicibank.',   'com.icicidirect.', 'com.idirect.',
    'com.icicilombard.','com.icicipruamc.', 'com.icicipruwm.',
    'com.iciciprulife.',
    'com.axisbank.',    'com.axis.',       'com.axisdirect.',
    'com.kotak.',       'com.kotaksecurities.',
    'com.bankofbaroda.','com.idbi.',       'com.idfcfirstbank.',
    'com.pnbindia.',    'com.canarabank.', 'com.fedmobile.',
    'com.fbl.',         'com.indusind.',   'com.unionbank.',
    'com.southindianbank.',
    'com.phonepe.',     'net.one97.paytm.','com.cred.',
    'com.razorpay.',    'com.zerodha.',    'com.upstox.',
    'com.groww.',       'com.angelbroking.','com.angelone.',
    'com.dhan.',        'in.fivepaisa.',   'com.fivepaisa.',
    'com.mstock.',
    'in.gov.',          'gov.in.',         'in.digilocker.',
    'in.org.npci.',     'com.umang.',      'in.uidai.',
    'com.uidai.',       'com.dot.app.sancharsaathi',
    'com.netflix.',     'in.startv.',      'com.spotify.',
    'com.linkedin.',    'com.twitter.',    'com.snapchat.',
    'com.pinterest.',   'com.reddit.',
    'com.makemytrip.',  'com.goibibo.',    'com.ubercab.',
    'com.olacabs.',     'com.swiggy.',     'com.zomato.',
    'com.bigbasket.',   'com.flipkart.',   'com.myntra.',
    'com.simplemobiletools.',
  ];

  /// Analyze an app for fake/clone status.
  ///
  /// [packageName] and [appLabel] are required. [isSystem] is optional but
  /// strongly recommended — pass `DeviceAppInfo.isSystem` so we never flag
  /// system apps as clones.
  static FakeAppAnalysis analyze(
    String packageName,
    String appLabel, {
    bool isSystem = false,
  }) {
    // ── Phase 1: Exact catalog match (case-insensitive backup) ─────────────
    final exact = TrustedAppCatalog.lookup(packageName);
    if (exact != null) {
      return FakeAppAnalysis(
        packageName: packageName,
        appLabel: appLabel,
        risk: FakeAppRisk.notFake,
        reasons: ['Verified publisher: '
            '${exact.publisher.isNotEmpty ? exact.publisher : exact.label}'],
      );
    }
    final lowerPkg = packageName.toLowerCase();
    if (lowerPkg != packageName) {
      for (final entry in TrustedAppCatalog.all) {
        if (entry.packageName.toLowerCase() == lowerPkg) {
          return FakeAppAnalysis(
            packageName: packageName,
            appLabel: appLabel,
            risk: FakeAppRisk.notFake,
            reasons: ['Verified publisher (case-insensitive match): ${entry.publisher}'],
          );
        }
      }
    }

    // ── Phase 1b: System-app gate ──────────────────────────────────────────
    // System apps cannot impersonate other apps — they're part of the OS.
    // We accept either the explicit `isSystem` flag from the caller OR a
    // package-prefix heuristic, so this works even when the flag isn't passed.
    if (isSystem || _matchesAnyPrefix(packageName, _systemPrefixes)) {
      return FakeAppAnalysis(
        packageName: packageName,
        appLabel: appLabel,
        risk: FakeAppRisk.notFake,
        reasons: const ['System app — part of Android/OEM bundle'],
      );
    }

    // ── Phase 1c: Trusted publisher prefix ─────────────────────────────────
    if (_matchesAnyPrefix(packageName, _trustedPublisherPrefixes)) {
      return FakeAppAnalysis(
        packageName: packageName,
        appLabel: appLabel,
        risk: FakeAppRisk.notFake,
        reasons: const ['Published in a verified vendor namespace'],
      );
    }

    // ── Phase 2: Same publisher as a trusted catalog entry? ────────────────
    // Uses SET INTERSECTION of distinctive tokens, not longest-token equality.
    //
    // Why: `com.icicidirect.idirectsuper` should match `com.icicidirect.app`
    // because they share the `icicidirect` token. The old "longest" logic
    // picked `idirectsuper` (12 chars) which didn't match anything.
    final candidateTokens = _extractPublisherTokens(packageName);
    if (candidateTokens.isNotEmpty) {
      for (final trusted in TrustedAppCatalog.all) {
        final trustedTokens = _extractPublisherTokens(trusted.packageName);
        final shared = candidateTokens.intersection(trustedTokens);
        if (shared.isNotEmpty) {
          return FakeAppAnalysis(
            packageName: packageName,
            appLabel: appLabel,
            risk: FakeAppRisk.notFake,
            reasons: [
              'Same publisher namespace as ${trusted.publisher} '
                  '(shared identifier: "${shared.first}")'
            ],
          );
        }
      }
    }

    // ── Phase 3: Similarity matching against OTHER brands ──────────────────
    final normLabel = SimilarityMetrics.normalize(appLabel);
    final normPkgId = _packageIdSegments(packageName).join('');
    final labelTooShort = normLabel.length < _minLabelLen;

    final bestByImpersonated = <String, _MatchScore>{};

    for (final trusted in TrustedAppCatalog.all) {
      if (trusted.packageName == packageName) continue;

      // Same-publisher guard via set intersection
      final tt = _extractPublisherTokens(trusted.packageName);
      if (candidateTokens.intersection(tt).isNotEmpty) continue;

      final normTrustedLabel = SimilarityMetrics.normalize(trusted.label);
      final normTrustedPkg = _packageIdSegments(trusted.packageName).join('');
      if (normTrustedLabel.length < _minLabelLen) continue;

      double bestLabelSim = 0.0;
      if (!labelTooShort) {
        final labelSim =
            SimilarityMetrics.jaroWinkler(normLabel, normTrustedLabel);
        final foldedLabel = SimilarityMetrics.foldConfusables(normLabel);
        final foldedTrustedLabel =
            SimilarityMetrics.foldConfusables(normTrustedLabel);
        final foldedSim = SimilarityMetrics.jaroWinkler(
            foldedLabel, foldedTrustedLabel);
        bestLabelSim = labelSim > foldedSim ? labelSim : foldedSim;
      }

      final pkgSim = SimilarityMetrics.jaroWinkler(normPkgId, normTrustedPkg);

      final existing = bestByImpersonated[trusted.label];
      final score = _MatchScore(
        labelSim: bestLabelSim,
        pkgSim:   pkgSim,
        trusted:  trusted,
      );
      if (existing == null || score.combined > existing.combined) {
        bestByImpersonated[trusted.label] = score;
      }
    }

    // ── Phase 4: Build risk + reasons from best matches ────────────────────
    final reasons = <String>[];
    var maxRisk = FakeAppRisk.notFake;
    String? impersonates;

    final ordered = bestByImpersonated.values.toList()
      ..sort((a, b) => b.combined.compareTo(a.combined));
    final topMatches = ordered.take(3).toList();

    for (final m in topMatches) {
      if (m.labelSim >= _jaroWinklerHigh) {
        if (FakeAppRisk.likelyFake.index > maxRisk.index) {
          maxRisk = FakeAppRisk.likelyFake;
          impersonates = m.trusted.label;
        }
        reasons.add(
            'App label very similar to ${m.trusted.label} '
            '(${(m.labelSim * 100).toStringAsFixed(0)}%)');
      } else if (m.labelSim >= _jaroWinklerMed) {
        if (FakeAppRisk.suspected.index > maxRisk.index) {
          maxRisk = FakeAppRisk.suspected;
          impersonates = m.trusted.label;
        }
        reasons.add(
            'App label somewhat similar to ${m.trusted.label} '
            '(${(m.labelSim * 100).toStringAsFixed(0)}%)');
      } else if (m.pkgSim >= _packageSimilarityThresh) {
        if (FakeAppRisk.suspected.index > maxRisk.index) {
          maxRisk = FakeAppRisk.suspected;
          impersonates = m.trusted.label;
        }
        reasons.add(
            'Package ID similar to ${m.trusted.label} '
            '(${(m.pkgSim * 100).toStringAsFixed(0)}%)');
      }
    }

    // ── Phase 5: Heuristic red flags ───────────────────────────────────────
    if (maxRisk == FakeAppRisk.notFake) {
      if (_isSpammyLabel(appLabel)) {
        maxRisk = FakeAppRisk.suspected;
        reasons.add('App label uses spammy/generic pattern');
      }
      if (_isSuspiciousPackageId(packageName)) {
        if (FakeAppRisk.suspected.index > maxRisk.index) {
          maxRisk = FakeAppRisk.suspected;
        }
        reasons.add('Package ID has suspicious structure (random segments)');
      }
    }

    // ── Phase 6: Escalate to "probablyFake" when several red flags align ──
    if (maxRisk == FakeAppRisk.likelyFake &&
        _isSuspiciousPackageId(packageName)) {
      maxRisk = FakeAppRisk.probablyFake;
    }

    if (reasons.isEmpty) {
      reasons.add('No fake-app indicators detected');
    }

    return FakeAppAnalysis(
      packageName: packageName,
      appLabel: appLabel,
      risk: maxRisk,
      impersonatesApp: impersonates,
      reasons: reasons,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _matchesAnyPrefix(String packageName, List<String> prefixes) {
    for (final p in prefixes) {
      if (packageName.startsWith(p)) return true;
    }
    return false;
  }

  /// Extract ALL distinctive publisher tokens from a package name.
  ///
  /// Strips generic segments (`com`, `app`, `android`, etc.) and returns the
  /// remaining tokens as a set. Used for cross-checking same-publisher apps:
  /// if two packages share ANY distinctive token, they're treated as same
  /// publisher.
  ///
  ///   `com.hdfcbank.app`              → {"hdfcbank"}
  ///   `com.hdfcbank.iMobile`          → {"hdfcbank", "imobile"}
  ///   `com.icicidirect.idirectsuper`  → {"icicidirect", "idirectsuper"}
  ///   `com.icicidirect.app`           → {"icicidirect"}
  ///   ↑ shared "icicidirect" → same publisher ✓
  static Set<String> _extractPublisherTokens(String packageName) {
    final segs = _packageIdSegments(packageName)
        .map((s) => s.toLowerCase())
        .where((s) => !_genericPkgSegments.contains(s))
        .where((s) => s.length >= 3) // skip 1-2 char tokens
        .toSet();
    return segs;
  }

  static List<String> _packageIdSegments(String pkg) =>
      pkg.split('.').where((s) => s.isNotEmpty).toList();

  static bool _isSpammyLabel(String label) {
    final lower = label.toLowerCase();
    const promoWords = ['free ', 'new ', 'best ', 'super ', 'fast ', 'top ', 'pro '];
    const genericApp = [
      ' game', ' browser', ' launcher', ' cleaner',
      ' booster', ' master', ' optimizer', ' speed',
    ];
    final hasPromo = promoWords.any(lower.contains);
    final hasGeneric = genericApp.any(lower.contains);
    return hasPromo && hasGeneric;
  }

  static bool _isSuspiciousPackageId(String pkg) {
    final segments = _packageIdSegments(pkg);
    if (segments.length < 2) return true;
    for (final seg in segments) {
      if (seg.length >= 3) {
        final digitCount = seg.split('')
            .where((c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0)
            .length;
        if (digitCount > seg.length * 0.5) return true;
      }
    }
    return false;
  }
}

class _MatchScore {
  final double labelSim;
  final double pkgSim;
  final TrustedApp trusted;
  const _MatchScore({
    required this.labelSim,
    required this.pkgSim,
    required this.trusted,
  });
  double get combined => labelSim * 0.7 + pkgSim * 0.3;
}

/// SecureShield Risk Engine v2 — multi-layer, false-positive resistant.
///
/// Replaces the v1 "any permission → HIGH" engine with a layered scoring
/// pipeline modelled on commercial AV products (Defender / Norton / BitDefender).
///
/// Layer order (first match wins for the trust layer):
///   1. Hard allowlist          — trusted publisher → SAFE
///   2. Combination matrix      — only score *patterns* of signals
///   3. Permission scorer       — category-aware, heavily capped
///   4. Behaviour scorer        — hidden launcher, brand impersonation, age
///   5. Reputation scorer       — installer, sideload, age
///   6. Confidence gating       — downgrade HIGH→MEDIUM when signals are weak
///
/// Single permissions never push an app to HIGH on their own. Only
/// **dangerous combinations** (e.g. Accessibility + Overlay + SMS) do.
library;

import 'device_scanner_service.dart';
import 'fake_app_detector.dart';
import 'trusted_app_catalog.dart';

// ────────────────────────────────────────────────────────────────────────────
// Risk levels (ordered low → high)
// ────────────────────────────────────────────────────────────────────────────
enum AppRiskLevel { safe, low, medium, high, critical }

extension AppRiskLevelExt on AppRiskLevel {
  String get label {
    switch (this) {
      case AppRiskLevel.safe:     return 'Safe';
      case AppRiskLevel.low:      return 'Low Risk';
      case AppRiskLevel.medium:   return 'Medium Risk';
      case AppRiskLevel.high:     return 'High Risk';
      case AppRiskLevel.critical: return 'Critical';
    }
  }

  bool get shouldWarn => index >= AppRiskLevel.medium.index;
  bool get isHighOrAbove => index >= AppRiskLevel.high.index;
}

AppRiskLevel _levelForScore(int score) {
  if (score >= 81) return AppRiskLevel.critical;
  if (score >= 61) return AppRiskLevel.high;
  if (score >= 41) return AppRiskLevel.medium;
  if (score >= 21) return AppRiskLevel.low;
  return AppRiskLevel.safe;
}

// ────────────────────────────────────────────────────────────────────────────
// Result of scoring a single app
// ────────────────────────────────────────────────────────────────────────────
class AppRiskResult {
  final DeviceAppInfo app;
  final AppRiskLevel level;
  final List<String> reasons;   // human-readable explanations
  final int score;              // 0-100
  final double confidence;      // 0.0-1.0
  final Set<String> riskTypes;  // banking|spyware|privacy|...

  const AppRiskResult({
    required this.app,
    required this.level,
    required this.reasons,
    this.score = 0,
    this.confidence = 1.0,
    this.riskTypes = const {},
  });

  bool get canUninstall => app.isUserApp;
}

// ────────────────────────────────────────────────────────────────────────────
// Overall device scan summary
// ────────────────────────────────────────────────────────────────────────────
class ScanSummary {
  final List<AppRiskResult> results;
  final int totalScanned;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int safeCount;

  const ScanSummary({
    required this.results,
    required this.totalScanned,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.safeCount,
  });

  int get warningCount => criticalCount + highCount + mediumCount;
  bool get hasHighRisk  => criticalCount > 0 || highCount > 0;

  /// All results that have warnings, sorted high → low
  List<AppRiskResult> get riskResults => results
      .where((r) => r.level.shouldWarn)
      .toList()
    ..sort((a, b) {
      final byLevel = b.level.index.compareTo(a.level.index);
      if (byLevel != 0) return byLevel;
      return b.score.compareTo(a.score);
    });
}

// ────────────────────────────────────────────────────────────────────────────
// Permission constants
// ────────────────────────────────────────────────────────────────────────────
const _smsPerms = {
  'android.permission.READ_SMS',
  'android.permission.SEND_SMS',
  'android.permission.RECEIVE_SMS',
  'android.permission.RECEIVE_MMS',
};

const _criticalPrivilegePerms = {
  'android.permission.BIND_ACCESSIBILITY_SERVICE',
  'android.permission.BIND_DEVICE_ADMIN',
  'android.permission.BIND_NOTIFICATION_LISTENER_SERVICE',
  'android.permission.SYSTEM_ALERT_WINDOW',
  'android.permission.REQUEST_INSTALL_PACKAGES',
};

const _sensitivePerms = {
  'android.permission.READ_CONTACTS',
  'android.permission.READ_CALL_LOG',
  'android.permission.READ_PHONE_STATE',
  'android.permission.RECORD_AUDIO',
  'android.permission.CAMERA',
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.READ_EXTERNAL_STORAGE',
  'android.permission.QUERY_ALL_PACKAGES',
  'android.permission.PACKAGE_USAGE_STATS',
};

// Installers that, when they appear, should NOT trigger sideload alerts.
const _trustedInstallers = {
  'com.android.vending',                       // Google Play
  'com.google.android.feedback',
  'com.sec.android.app.samsungapps',           // Samsung Galaxy Store
  'com.amazon.venezia',                        // Amazon Appstore
  'com.huawei.appmarket',
  'com.xiaomi.mipicks', 'com.xiaomi.market',
  'com.oppo.market', 'com.heytap.market',
  'com.vivo.appstore',
  'org.fdroid.fdroid',                         // F-Droid (debatable)
};

// Package-name prefixes that belong to well-known publishers. Apps in these
// namespaces installed from a trusted store are considered SAFE even without
// an exact catalog entry. Order matters — more specific prefixes first.
const _trustedPublisherPrefixes = [
  // Google / Android
  'com.google.',
  'com.android.',
  'android.',
  // Microsoft
  'com.microsoft.',
  // Samsung
  'com.samsung.',
  'com.sec.',
  // Xiaomi / MIUI
  'com.miui.',
  'com.xiaomi.',
  'com.mi.',
  // OPPO / OnePlus / Realme
  'com.oppo.',
  'com.oneplus.',
  'com.coloros.',
  'com.heytap.',
  'com.realme.',
  // Vivo / iQOO
  'com.vivo.',
  'com.iqoo.',
  // Huawei / Honor
  'com.huawei.',
  'com.hihonor.',
  // Meta
  'com.facebook.',
  'com.instagram.',
  'com.whatsapp.',
  // Amazon
  'com.amazon.',
  'in.amazon.',
  // Adobe / Mozilla / Opera / Brave / DuckDuckGo
  'com.adobe.',
  'org.mozilla.',
  'com.opera.',
  'com.brave.',
  'com.duckduckgo.',
  // Major Indian banks (multiple package roots)
  'com.sbi.',
  'com.hdfcbank.',
  'com.icicibank.',
  'com.icicidirect.',    // ICICI Securities (trading subsidiary)
  'com.idirect.',         // ICICI Direct legacy package root
  'com.icicilombard.',    // ICICI Lombard (insurance)
  'com.icicipruamc.',     // ICICI Prudential AMC
  'com.icicipruwm.',      // ICICI Prudential Wealth
  'com.iciciprulife.',    // ICICI Prudential Life
  'com.axisbank.',
  'com.axis.',
  'com.axisdirect.',      // Axis Securities
  'com.kotak.',
  'com.kotaksecurities.',
  'com.bankofbaroda.',
  'com.idbi.',
  'com.idfcfirstbank.',
  'com.pnbindia.',
  'com.canarabank.',
  'com.fedmobile.',
  'com.fbl.',
  'com.indusind.',
  'com.unionbank.',
  'com.southindianbank.',
  'com.hdfcsec.',         // HDFC Securities
  'com.hdfclife.',        // HDFC Life Insurance
  'com.sbilife.',         // SBI Life
  'com.sbicard.',         // SBI Card
  // UPI / fintech / stock brokers
  'com.phonepe.',
  'net.one97.paytm.',
  'com.cred.',
  'com.razorpay.',
  'com.zerodha.',         // Zerodha Kite
  'com.upstox.',          // Upstox
  'com.groww.',           // Groww
  'com.angelbroking.',    // Angel One
  'com.angelone.',
  'com.dhan.',            // Dhan
  'in.fivepaisa.',        // 5paisa
  'com.fivepaisa.',
  'com.mstock.',          // mStock (M-Stock)
  // Indian government
  'in.gov.',
  'gov.in.',
  'in.digilocker.',
  'in.org.npci.',
  'com.umang.',
  'in.uidai.',
  'com.uidai.',
  'com.dot.app.sancharsaathi',
  // Major OTT / consumer
  'com.netflix.',
  'in.startv.',
  'com.spotify.',
  'com.linkedin.',
  'com.twitter.',
  'com.snapchat.',
  'com.pinterest.',
  'com.reddit.',
  // Travel / ride-hailing / food
  'com.makemytrip.',
  'com.goibibo.',
  'com.ubercab.',
  'com.olacabs.',
  'com.swiggy.',
  'com.zomato.',
  'com.bigbasket.',
  'com.flipkart.',
  'com.myntra.',
  // Open-source dev favourites
  'com.simplemobiletools.',
];

bool _hasTrustedPublisherPrefix(String packageName) {
  for (final prefix in _trustedPublisherPrefixes) {
    if (packageName.startsWith(prefix)) return true;
  }
  return false;
}

/// Translate a known publisher prefix into a friendly publisher name.
/// Used to make SAFE-verdict reasons explain WHICH publisher we trusted.
String _publisherNameForPackage(String packageName) {
  const publisherNames = <String, String>{
    'com.google.':           'Google',
    'com.android.':          'Android system',
    'android.':              'Android system',
    'com.microsoft.':        'Microsoft',
    'com.samsung.':          'Samsung',
    'com.sec.':              'Samsung',
    'com.miui.':             'Xiaomi MIUI',
    'com.xiaomi.':           'Xiaomi',
    'com.mi.':               'Xiaomi',
    'com.oppo.':             'OPPO',
    'com.oneplus.':          'OnePlus',
    'com.coloros.':          'ColorOS',
    'com.heytap.':           'HeyTap',
    'com.realme.':           'realme',
    'com.vivo.':             'Vivo',
    'com.iqoo.':             'iQOO',
    'com.huawei.':           'Huawei',
    'com.hihonor.':          'Honor',
    'com.facebook.':         'Meta',
    'com.instagram.':        'Meta (Instagram)',
    'com.whatsapp.':         'WhatsApp / Meta',
    'com.amazon.':           'Amazon',
    'in.amazon.':            'Amazon India',
    'com.adobe.':            'Adobe',
    'org.mozilla.':          'Mozilla',
    'com.opera.':            'Opera',
    'com.brave.':            'Brave',
    'com.duckduckgo.':       'DuckDuckGo',
    'com.sbi.':              'State Bank of India',
    'com.sbilife.':          'SBI Life',
    'com.sbicard.':          'SBI Card',
    'com.hdfcbank.':         'HDFC Bank',
    'com.hdfcsec.':          'HDFC Securities',
    'com.hdfclife.':         'HDFC Life',
    'com.icicibank.':        'ICICI Bank',
    'com.icicidirect.':      'ICICI Securities (ICICI Direct)',
    'com.idirect.':          'ICICI Direct',
    'com.icicilombard.':     'ICICI Lombard',
    'com.icicipruamc.':      'ICICI Prudential',
    'com.icicipruwm.':       'ICICI Prudential',
    'com.iciciprulife.':     'ICICI Prudential Life',
    'com.axisbank.':         'Axis Bank',
    'com.axis.':             'Axis Bank',
    'com.axisdirect.':       'Axis Securities',
    'com.kotak.':            'Kotak Mahindra Bank',
    'com.kotaksecurities.':  'Kotak Securities',
    'com.bankofbaroda.':     'Bank of Baroda',
    'com.idbi.':             'IDBI Bank',
    'com.idfcfirstbank.':    'IDFC FIRST Bank',
    'com.pnbindia.':         'Punjab National Bank',
    'com.canarabank.':       'Canara Bank',
    'com.fedmobile.':        'Federal Bank',
    'com.fbl.':              'Federal Bank',
    'com.indusind.':         'IndusInd Bank',
    'com.unionbank.':        'Union Bank of India',
    'com.southindianbank.':  'South Indian Bank',
    'com.phonepe.':          'PhonePe',
    'net.one97.paytm.':      'Paytm',
    'com.cred.':             'CRED',
    'com.razorpay.':         'Razorpay',
    'com.zerodha.':          'Zerodha',
    'com.upstox.':           'Upstox',
    'com.groww.':            'Groww',
    'com.angelbroking.':     'Angel One',
    'com.angelone.':         'Angel One',
    'com.dhan.':             'Dhan',
    'in.fivepaisa.':         '5paisa',
    'com.fivepaisa.':        '5paisa',
    'com.mstock.':           'mStock',
    'in.gov.':               'Government of India',
    'gov.in.':               'Government of India',
    'in.digilocker.':        'DigiLocker (GoI)',
    'in.org.npci.':          'NPCI',
    'com.umang.':            'UMANG (GoI)',
    'in.uidai.':             'UIDAI (Aadhaar)',
    'com.uidai.':            'UIDAI (Aadhaar)',
    'com.dot.app.sancharsaathi': 'DoT Sanchar Saathi',
    'com.netflix.':          'Netflix',
    'in.startv.':            'Disney+ Hotstar',
    'com.spotify.':          'Spotify',
    'com.linkedin.':         'LinkedIn',
    'com.twitter.':          'X / Twitter',
    'com.snapchat.':         'Snap Inc.',
    'com.pinterest.':        'Pinterest',
    'com.reddit.':           'Reddit',
    'com.makemytrip.':       'MakeMyTrip',
    'com.goibibo.':          'Goibibo',
    'com.ubercab.':          'Uber',
    'com.olacabs.':          'Ola',
    'com.swiggy.':           'Swiggy',
    'com.zomato.':           'Zomato',
    'com.bigbasket.':        'BigBasket',
    'com.flipkart.':         'Flipkart',
    'com.myntra.':           'Myntra',
    'com.simplemobiletools.': 'Simple Mobile Tools',
  };
  // Longest prefix match wins (so com.icicidirect. beats com.icici if both existed)
  String? best;
  for (final entry in publisherNames.entries) {
    if (packageName.startsWith(entry.key)) {
      if (best == null || entry.key.length > best.length) {
        best = entry.key;
      }
    }
  }
  return best != null ? publisherNames[best]! : 'a known vendor';
}

// ────────────────────────────────────────────────────────────────────────────
// App category — informs how aggressive permission scoring should be
// ────────────────────────────────────────────────────────────────────────────
enum AppCategory {
  banking,
  upiPayments,
  social,
  messaging,
  productivity,
  shopping,
  launcher,
  accessibilityTool,
  passwordManager,
  browser,
  government,
  system,
  popular,
  unknown,
}

AppCategory _inferCategory(DeviceAppInfo app, TrustedApp? trusted) {
  if (trusted != null) {
    switch (trusted.category) {
      case 'banking':            return AppCategory.banking;
      case 'upi':
      case 'payments':           return AppCategory.upiPayments;
      case 'social':             return AppCategory.social;
      case 'messaging':          return AppCategory.messaging;
      case 'productivity':       return AppCategory.productivity;
      case 'shopping':           return AppCategory.shopping;
      case 'launcher':           return AppCategory.launcher;
      case 'a11y_tool':          return AppCategory.accessibilityTool;
      case 'password_manager':   return AppCategory.passwordManager;
      case 'browser':            return AppCategory.browser;
      case 'gov':                return AppCategory.government;
      case 'system':             return AppCategory.system;
      case 'popular':            return AppCategory.popular;
    }
  }
  if (app.isSystem) return AppCategory.system;
  return AppCategory.unknown;
}

// ────────────────────────────────────────────────────────────────────────────
// The combination matrix — the heart of the engine
// Each rule fires only when *multiple* signals align in a known-bad pattern.
// ────────────────────────────────────────────────────────────────────────────
class _ComboRule {
  final String code;
  final int weight;            // contribution to 0-100 score
  final AppRiskLevel hint;     // minimum level when this rule fires
  final Set<String> riskTypes;
  final String reason;
  final bool Function(_RuleCtx) when;

  const _ComboRule({
    required this.code,
    required this.weight,
    required this.hint,
    required this.riskTypes,
    required this.reason,
    required this.when,
  });
}

class _RuleCtx {
  final DeviceAppInfo app;
  final TrustedApp? trusted;
  final AppCategory category;
  final bool sideloaded;
  final bool hasSms;
  final bool hasOverlay;
  final bool usesAccessibility;
  final int sensitiveCount;
  final int ageDays;

  _RuleCtx({
    required this.app,
    required this.trusted,
    required this.category,
    required this.sideloaded,
    required this.hasSms,
    required this.hasOverlay,
    required this.usesAccessibility,
    required this.sensitiveCount,
    required this.ageDays,
  });
}

final List<_ComboRule> _combinationMatrix = [
  // ── CRITICAL: classic banking-trojan fingerprint ────────────────────────
  _ComboRule(
    code: 'A11Y_OVERLAY_SMS_SIDELOAD',
    weight: 75,
    hint: AppRiskLevel.critical,
    riskTypes: {'banking', 'remote_control', 'spyware'},
    reason: 'Accessibility + Overlay + SMS, installed outside the Play Store — '
            'classic banking-trojan footprint.',
    when: (c) => c.usesAccessibility && c.hasOverlay && c.hasSms && c.sideloaded,
  ),

  // ── HIGH: Accessibility + Overlay (no SMS, but still strong RAT signal) ─
  _ComboRule(
    code: 'A11Y_OVERLAY',
    weight: 55,
    hint: AppRiskLevel.high,
    riskTypes: {'remote_control', 'banking'},
    reason: 'Accessibility service is active together with screen-overlay. '
            'This combination is heavily abused by overlay-phishing kits.',
    when: (c) => c.usesAccessibility && c.hasOverlay &&
                 c.category != AppCategory.accessibilityTool &&
                 c.category != AppCategory.passwordManager &&
                 c.category != AppCategory.launcher,
  ),

  // ── HIGH: hidden app with high-privilege signals ────────────────────────
  _ComboRule(
    code: 'HIDDEN_HIGH_PRIV',
    weight: 55,
    hint: AppRiskLevel.high,
    riskTypes: {'spyware'},
    reason: 'App is installed but has no launcher icon and holds high-privilege '
            'permissions. Spyware/stalkerware fingerprint.',
    when: (c) => !c.app.hasLauncher && !c.app.isSystem &&
                 (c.usesAccessibility || c.hasOverlay || c.hasSms),
  ),

  // ── HIGH: SMS + sideloaded + multiple sensitive ─────────────────────────
  _ComboRule(
    code: 'SMS_PLUS_SIDELOAD_SENSITIVE',
    weight: 50,
    hint: AppRiskLevel.high,
    riskTypes: {'banking', 'spyware'},
    reason: 'Sideloaded app with SMS access and additional sensitive permissions '
            '— common OTP-stealer pattern.',
    when: (c) => c.hasSms && c.sideloaded && c.sensitiveCount >= 2,
  ),

  // ── HIGH: Sideloaded + Accessibility (not a known a11y tool) ────────────
  _ComboRule(
    code: 'A11Y_SIDELOAD',
    weight: 50,
    hint: AppRiskLevel.high,
    riskTypes: {'remote_control', 'spyware'},
    reason: 'Sideloaded app using Accessibility Service. Untrusted source for '
            'such a powerful capability.',
    when: (c) => c.usesAccessibility && c.sideloaded &&
                 c.category != AppCategory.accessibilityTool,
  ),

  // ── MEDIUM: brand impersonation by label (e.g. "SBI" with non-SBI signer)
  _ComboRule(
    code: 'BRAND_IMPERSONATION',
    weight: 35,
    hint: AppRiskLevel.medium,
    riskTypes: {'phishing', 'banking'},
    reason: 'Label resembles a banking/UPI brand but the publisher is unknown.',
    when: (c) {
      if (c.trusted != null) return false; // already verified
      final lbl = c.app.appName.toLowerCase();
      const brands = ['sbi', 'hdfc', 'icici', 'axis', 'kotak', 'yes bank',
        'bank of baroda', 'canara', 'pnb', 'union bank', 'idfc', 'federal',
        'indusind', 'paytm', 'phonepe', 'gpay', 'google pay', 'bhim', 'upi',
        'amazon pay', 'airtel payments', 'whatsapp'];
      return brands.any(lbl.contains);
    },
  ),

  // ── MEDIUM: sideloaded + very new + multiple sensitive perms ────────────
  _ComboRule(
    code: 'SIDELOAD_YOUNG_SENSITIVE',
    weight: 30,
    hint: AppRiskLevel.medium,
    riskTypes: {'scam', 'privacy'},
    reason: 'Recently sideloaded and requests several sensitive permissions.',
    when: (c) => c.sideloaded && c.ageDays < 7 && c.sensitiveCount >= 3,
  ),

  // ── MEDIUM: Overlay + sideloaded (overlay phishing risk) ────────────────
  _ComboRule(
    code: 'OVERLAY_SIDELOAD',
    weight: 30,
    hint: AppRiskLevel.medium,
    riskTypes: {'phishing'},
    reason: 'Sideloaded app can draw over other apps — overlay phishing risk.',
    when: (c) => c.hasOverlay && c.sideloaded &&
                 c.category != AppCategory.passwordManager,
  ),

  // ── LOW: sideloaded apps without other red flags ────────────────────────
  _ComboRule(
    code: 'SIDELOAD',
    weight: 15,
    hint: AppRiskLevel.low,
    riskTypes: {'privacy'},
    reason: 'Installed from outside an app store. Verify you trust the source.',
    when: (c) => c.sideloaded && c.app.isUserApp,
  ),
];

// ────────────────────────────────────────────────────────────────────────────
// Permission-only sub-score, heavily capped by category.
// Used only to slightly nudge the score; never the dominant signal.
// ────────────────────────────────────────────────────────────────────────────
int _permScore(_RuleCtx c) {
  final cap = switch (c.category) {
    AppCategory.banking ||
    AppCategory.upiPayments ||
    AppCategory.launcher ||
    AppCategory.accessibilityTool ||
    AppCategory.passwordManager ||
    AppCategory.government ||
    AppCategory.system          => 0,    // expected perms — no penalty
    AppCategory.messaging ||
    AppCategory.social ||
    AppCategory.browser ||
    AppCategory.popular         => 4,    // up to 4 pts total
    AppCategory.productivity ||
    AppCategory.shopping        => 8,
    AppCategory.unknown         => 20,
  };
  if (cap == 0) return 0;
  final hits = c.app.grantedDangerousPerms
      .where((p) => _sensitivePerms.contains(p) || _criticalPrivilegePerms.contains(p))
      .length;
  return (hits * 3).clamp(0, cap);
}

// ────────────────────────────────────────────────────────────────────────────
// Public engine API
// ────────────────────────────────────────────────────────────────────────────
class AppRiskEngine {
  /// Score all apps given the list of enabled accessibility service component names.
  static ScanSummary analyze(
    List<DeviceAppInfo> apps,
    List<String> accessibilityComponents,
  ) {
    // Build set of packages that have an accessibility service enabled
    final accessibilityPackages = accessibilityComponents
        .map((c) => c.split('/').first.trim())
        .where((p) => p.isNotEmpty)
        .toSet();

    // Mark accessibility flag on each app
    for (final app in apps) {
      app.usesAccessibility = accessibilityPackages.contains(app.packageName);
    }

    final results = apps.map(_score).toList();

    int critical = 0, high = 0, medium = 0, low = 0, safe = 0;
    for (final r in results) {
      switch (r.level) {
        case AppRiskLevel.critical: critical++; break;
        case AppRiskLevel.high:     high++;     break;
        case AppRiskLevel.medium:   medium++;   break;
        case AppRiskLevel.low:      low++;      break;
        case AppRiskLevel.safe:     safe++;     break;
      }
    }

    return ScanSummary(
      results:       results,
      totalScanned:  results.length,
      criticalCount: critical,
      highCount:     high,
      mediumCount:   medium,
      lowCount:      low,
      safeCount:     safe,
    );
  }

  /// Single-app scoring (public for tests / detail screens).
  static AppRiskResult scoreOne(DeviceAppInfo app) => _score(app);

  // ── private scoring pipeline ──────────────────────────────────────────────
  static AppRiskResult _score(DeviceAppInfo app) {
    final trusted = TrustedAppCatalog.lookup(app.packageName);

    // ─── Layer 1: hard allowlist short-circuit ────────────────────────────
    // Trusted-catalog membership is a STRONG signal. Until v3 ships
    // signature verification (SHA-256 of signing cert), the catalog IS our
    // hard allowlist — any known package name short-circuits to SAFE.
    //
    // Threat-model justification:
    //  • A malicious actor cannot install a package with a name that conflicts
    //    with an already-installed legitimate app (Android refuses).
    //  • If the legitimate app isn't installed, sideloading a fake with a
    //    trusted package name requires the user to enable "Install from
    //    unknown sources" AND ignore the developer-signature mismatch warning
    //    that Play Protect shows.
    //  • That residual risk is preferable to flagging every Play-Store-installed
    //    bank app as HIGH RISK because the OS dropped the installer field
    //    after a phone restore.
    if (trusted != null) {
      return AppRiskResult(
        app: app,
        level: AppRiskLevel.safe,
        score: 0,
        confidence: app.isFromKnownStore || app.isSystem ? 1.0 : 0.85,
        reasons: [
          'Verified publisher: '
              '${trusted.publisher.isNotEmpty ? trusted.publisher : trusted.label}.',
        ],
      );
    }

    // ─── Layer 1b: system apps ─────────────────────────────────────────────
    // OEM-bundled system apps almost never need to be flagged. This catches
    // Files (com.google.android.documentsui), Calendar (com.android.calendar),
    // OEM clocks, dialers, etc., even if not explicitly in the catalog.
    if (app.isSystem) {
      return AppRiskResult(
        app: app,
        level: AppRiskLevel.safe,
        score: 0,
        confidence: 0.95,
        reasons: const ['System app — bundled with the device.'],
      );
    }

    // ─── Layer 1c: trusted-publisher prefix ────────────────────────────────
    // Apps in well-known publisher namespaces installed from a trusted store
    // are treated as SAFE even if not explicitly in the catalog. This is the
    // catch-all for new Google/Microsoft/Samsung/etc. apps that haven't been
    // added yet.
    //
    // Conservative: requires BOTH a known publisher prefix AND a trusted
    // installer. A sideloaded app named `com.google.android.evil` won't be
    // auto-trusted.
    if ((app.isFromKnownStore ||
         _trustedInstallers.contains(app.installer)) &&
        _hasTrustedPublisherPrefix(app.packageName)) {
      final publisher = _publisherNameForPackage(app.packageName);
      return AppRiskResult(
        app: app,
        level: AppRiskLevel.safe,
        score: 0,
        confidence: 0.9,
        reasons: [
          'Published in the verified $publisher namespace',
          'Installed from a trusted app store',
          'No suspicious behaviour signals detected',
        ],
      );
    }

    final category = _inferCategory(app, trusted);
    final perms = app.grantedDangerousPerms.toSet();
    final hasSms = perms.any(_smsPerms.contains);
    final hasOverlay = app.hasOverlay;
    final usesA11y = app.usesAccessibility;

    // ─── Smarter "sideloaded" detection ──────────────────────────────────
    // An app is considered sideloaded ONLY if:
    //   • Installer is unknown / null / shell, AND
    //   • Not a system app or system-app update, AND
    //   • Installed less than 90 days ago (older installs are usually
    //     legitimate apps whose installer field was dropped during a
    //     backup/restore or Android upgrade)
    final ageDays = (DateTime.now().millisecondsSinceEpoch -
        app.firstInstallTime) ~/ (1000 * 60 * 60 * 24);
    final installerKnown = app.isFromKnownStore ||
                           _trustedInstallers.contains(app.installer);
    final sideloaded = !installerKnown &&
                       !app.isSystem &&
                       !app.isUpdatedSystem &&
                       ageDays < 90;
    final sensitiveCount =
        perms.where(_sensitivePerms.contains).length +
        perms.where(_criticalPrivilegePerms.contains).length;

    final ctx = _RuleCtx(
      app: app,
      trusted: trusted,
      category: category,
      sideloaded: sideloaded,
      hasSms: hasSms,
      hasOverlay: hasOverlay,
      usesAccessibility: usesA11y,
      sensitiveCount: sensitiveCount,
      ageDays: ageDays,
    );

    // ─── Layer 2: combination matrix ──────────────────────────────────────
    final reasons = <String>[];
    final riskTypes = <String>{};
    var comboScore = 0;
    var hint = AppRiskLevel.safe;

    for (final rule in _combinationMatrix) {
      if (rule.when(ctx)) {
        comboScore += rule.weight;
        reasons.add(rule.reason);
        riskTypes.addAll(rule.riskTypes);
        if (rule.hint.index > hint.index) hint = rule.hint;
      }
    }
    comboScore = comboScore.clamp(0, 100);

    // ─── Layer 3: permission-only sub-score (capped by category) ──────────
    final permScore = _permScore(ctx);

    // ─── Layer 4: fake-app detector (existing engine) ─────────────────────
    var fakeScore = 0;
    final fake = FakeAppDetector.analyze(
      app.packageName,
      app.appName,
      isSystem: app.isSystem,
    );
    if (fake.risk == FakeAppRisk.probablyFake) {
      fakeScore = 70;
      reasons.add('🚨 Likely impersonating ${fake.impersonatesApp}: '
                  '${fake.reasons.join(", ")}');
      riskTypes.add('phishing');
      riskTypes.add('banking');
      if (AppRiskLevel.critical.index > hint.index) hint = AppRiskLevel.critical;
    } else if (fake.risk == FakeAppRisk.likelyFake) {
      fakeScore = 45;
      reasons.add('⚠️ Possibly impersonating ${fake.impersonatesApp}');
      riskTypes.add('phishing');
      if (AppRiskLevel.high.index > hint.index) hint = AppRiskLevel.high;
    } else if (fake.risk == FakeAppRisk.suspected) {
      fakeScore = 25;
      reasons.add('🔍 Resembles ${fake.impersonatesApp}; manual verification recommended.');
      if (AppRiskLevel.medium.index > hint.index) hint = AppRiskLevel.medium;
    }

    // ─── Layer 5: reputation nudges ───────────────────────────────────────
    var repScore = 0;
    if (sideloaded && ageDays < 3 && hint == AppRiskLevel.safe) {
      repScore += 8;
      reasons.add('Installed less than 3 days ago.');
    }

    // ─── Final fusion ─────────────────────────────────────────────────────
    var raw = (comboScore * 0.55 +
               permScore  * 0.10 +
               fakeScore  * 0.30 +
               repScore   * 0.05)
        .round()
        .clamp(0, 100);

    // Allow per-rule "hint" to bump us up if the fusion under-scores.
    final hintFloor = switch (hint) {
      AppRiskLevel.critical => 81,
      AppRiskLevel.high     => 61,
      AppRiskLevel.medium   => 41,
      AppRiskLevel.low      => 21,
      AppRiskLevel.safe     => 0,
    };
    if (raw < hintFloor) raw = hintFloor;

    var level = _levelForScore(raw);

    // ─── Confidence-based downgrade ───────────────────────────────────────
    // Without a verified signature (we don't have native sig-check yet),
    // confidence on a 'high' verdict for an unknown app is moderate. Downgrade
    // HIGH→MEDIUM when (a) the only reason is sideload-related AND (b) no
    // combination-matrix rule fired.
    final onlyLowComboFired =
        _combinationMatrix
            .where((r) => r.when(ctx) && r.hint.index >= AppRiskLevel.high.index)
            .isEmpty;
    if (level == AppRiskLevel.high && onlyLowComboFired && fakeScore < 45) {
      level = AppRiskLevel.medium;
      raw = raw.clamp(41, 60);
    }

    if (reasons.isEmpty) {
      reasons.add('No risky behaviour detected.');
    }

    return AppRiskResult(
      app: app,
      level: level,
      reasons: reasons,
      score: raw,
      confidence: _confidence(app, trusted, hint),
      riskTypes: riskTypes,
    );
  }

  static double _confidence(DeviceAppInfo app, TrustedApp? trusted, AppRiskLevel hint) {
    double c = 0.5; // baseline
    if (trusted != null)              c += 0.20;
    if (app.isFromKnownStore)         c += 0.15;
    if (app.isSystem)                 c += 0.10;
    if (hint.index >= AppRiskLevel.high.index) c += 0.05;
    return c.clamp(0.0, 1.0);
  }
}

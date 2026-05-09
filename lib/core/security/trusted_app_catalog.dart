/// Offline catalog of trusted Indian banking, UPI, and popular apps.
///
/// This is the ground truth for fake-app detection. If an installed app's
/// package name is NOT in this list and its name is suspiciously similar
/// to a known brand (via Jaro-Winkler), it flags as a potential impersonator.
///
/// Database is purely local and updated via app upgrades (no network fetch).
/// To add new apps or update hashes, rebuild the app.
library;

/// A trusted app reference — package name + optional cert SHA-256 hashes.
/// (Hashes are for future APK tamper detection; currently just a stub.)
class TrustedApp {
  final String packageName;
  final String label;        // Human-readable name for UI
  final String? certHash;    // SHA-256 of signing cert (future use)
  final String category;     // 'banking', 'upi', 'payment', 'popular'
  final bool isSystemApp;    // System-bundled apps (pre-installed)

  const TrustedApp({
    required this.packageName,
    required this.label,
    required this.category,
    this.certHash,
    this.isSystemApp = false,
  });
}

class TrustedAppCatalog {
  TrustedAppCatalog._();

  // ── Major Indian Banks ──────────────────────────────────────────────────────
  static const _banks = [
    TrustedApp(
      packageName: 'com.sbi.sbimobile',
      label: 'SBI Mobile',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.sbi.upi',
      label: 'SBI UPI',
      category: 'upi',
    ),
    TrustedApp(
      packageName: 'com.hdfcbank.app',
      label: 'HDFC Bank',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.hdfcbank.iMobile',
      label: 'HDFC iMobile',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.icicibank.iMobile',
      label: 'ICICI iMobile',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.axisbank.finmobile',
      label: 'Axis Mobile',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.ybl',
      label: 'Google Pay',
      category: 'upi',
    ),
    TrustedApp(
      packageName: 'net.one97.paytm',
      label: 'Paytm',
      category: 'payment',
    ),
    TrustedApp(
      packageName: 'com.phonepe.app',
      label: 'PhonePe',
      category: 'upi',
    ),
    TrustedApp(
      packageName: 'com.amazon.mShop.android',
      label: 'Amazon Pay',
      category: 'payment',
    ),
    TrustedApp(
      packageName: 'in.org.npci.upiapp',
      label: 'BHIM',
      category: 'upi',
    ),
    TrustedApp(
      packageName: 'com.kotak.mobile',
      label: 'Kotak Mobile',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.bankofbaroda.mobilebanking',
      label: 'Bank of Baroda',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.barodampay',
      label: 'BarodaMPay',
      category: 'payment',
    ),
    TrustedApp(
      packageName: 'com.unionbank.mbanking',
      label: 'Union Bank',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.idbibank.m',
      label: 'IDBI Bank',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.pnbindia.pnbmobile',
      label: 'PNB Mobile',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.southindianbank.mobilebanking',
      label: 'South Indian Bank',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.indusind',
      label: 'IndusInd Bank',
      category: 'banking',
    ),
    TrustedApp(
      packageName: 'com.yodlee.mobile',
      label: 'Yodlee Mobile',
      category: 'payment',
    ),
  ];

  // ── Popular Indian & International Apps ─────────────────────────────────────
  static const _popular = [
    TrustedApp(
      packageName: 'com.whatsapp',
      label: 'WhatsApp',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.instagram.android',
      label: 'Instagram',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.facebook.katana',
      label: 'Facebook',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.telegram',
      label: 'Telegram',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.twitter.android',
      label: 'X (Twitter)',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.github.android',
      label: 'GitHub',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.google.android.gms',
      label: 'Google Play Services',
      category: 'popular',
      isSystemApp: true,
    ),
    TrustedApp(
      packageName: 'com.google.android.apps.maps',
      label: 'Google Maps',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.google.android.youtube',
      label: 'YouTube',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.google.android.apps.docs',
      label: 'Google Drive',
      category: 'popular',
    ),
  ];

  // ── Government & Civic Apps ──────────────────────────────────────────────────
  static const _government = [
    TrustedApp(
      packageName: 'com.nsdl.utiitsl',
      label: 'Aadhaar App',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.incometaxindiaefiling',
      label: 'Income Tax India',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.digilocker.android',
      label: 'DigiLocker',
      category: 'popular',
    ),
    TrustedApp(
      packageName: 'com.cibil.consumer',
      label: 'CIBIL Score',
      category: 'popular',
    ),
  ];

  // ── Combined catalog (all apps)
  static final _allApps = <String, TrustedApp>{
    for (final app in [..._banks, ..._popular, ..._government])
      app.packageName: app,
  };

  // ── Search & match API ──────────────────────────────────────────────────────

  /// Exact lookup by package name.
  static TrustedApp? lookup(String packageName) {
    return _allApps[packageName];
  }

  /// Return all banks (trusted reference for fake-bank detection).
  static List<TrustedApp> get banks => _banks;

  /// Return all UPI / payment apps.
  static List<TrustedApp> get paymentApps =>
      _allApps.values
          .where((a) => a.category == 'upi' || a.category == 'payment')
          .toList();

  /// Get all known package names as a set for O(1) lookup.
  static Set<String> get knownPackages => _allApps.keys.toSet();

  /// Get all known labels as a set (for normalized matching).
  static Set<String> get knownLabels => _allApps.values.map((a) => a.label).toSet();

  /// Returns all apps in a given category.
  static List<TrustedApp> byCategory(String category) =>
      _allApps.values.where((a) => a.category == category).toList();

  /// Returns all trusted apps (flattened list).
  static List<TrustedApp> get all => _allApps.values.toList();

  /// Total trusted apps in catalog.
  static int get count => _allApps.length;
}

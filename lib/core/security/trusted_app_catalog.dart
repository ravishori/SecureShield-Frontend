/// Offline catalog of trusted apps — banking, UPI, popular consumer & enterprise.
///
/// Used as the **hard allowlist** layer of the risk engine. Any app whose
/// package name appears here short-circuits to SAFE regardless of permissions.
///
/// Production guidance: in v3, pair every entry with a SHA-256 signing-cert
/// fingerprint (see [TrustedApp.certHashes]) and verify it at scan time via
/// the native APK signature method-channel. Until then we trust by package
/// name — adequate for false-positive reduction but not for active malware
/// defence.
library;

/// A trusted app reference — package name + optional cert SHA-256 hashes.
class TrustedApp {
  final String packageName;
  final String label;
  final String category;     // banking|upi|payments|popular|social|messaging|
                              // launcher|browser|a11y_tool|password_manager|
                              // remote_access|productivity|shopping|gov|system
  final String publisher;    // For UI explanations
  final List<String> certHashes; // SHA-256 of signing cert(s) — future use
  final bool isSystemApp;

  const TrustedApp({
    required this.packageName,
    required this.label,
    required this.category,
    this.publisher = '',
    this.certHashes = const [],
    this.isSystemApp = false,
  });
}

class TrustedAppCatalog {
  TrustedAppCatalog._();

  // ────────────────────────────────────────────────────────────────────────
  // Google / Android system apps (these legitimately use accessibility,
  // overlay, etc. — must never be flagged)
  // ────────────────────────────────────────────────────────────────────────
  static const _google = [
    TrustedApp(packageName: 'com.android.vending',                              label: 'Google Play Store',         category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.gms',                           label: 'Google Play Services',      category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.gsf',                           label: 'Google Services Framework', category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.googlequicksearchbox',          label: 'Google',                    category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.maps',                     label: 'Google Maps',               category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.docs',                     label: 'Google Drive',              category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.photos',                   label: 'Google Photos',             category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.docs.editors.docs',        label: 'Google Docs',               category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.docs.editors.sheets',      label: 'Google Sheets',             category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.docs.editors.slides',      label: 'Google Slides',             category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.gm',                            label: 'Gmail',                     category: 'messaging',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.calendar',                      label: 'Google Calendar',           category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.youtube',                       label: 'YouTube',                   category: 'popular',      publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.youtube.music',            label: 'YouTube Music',             category: 'popular',      publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.youtube.tv',                    label: 'YouTube TV',                category: 'popular',      publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.tachyon',                  label: 'Google Meet',               category: 'messaging',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.chrome',                   label: 'Chrome',                    category: 'browser',      publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.android.chrome',                               label: 'Chrome',                    category: 'browser',      publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.translate',                label: 'Google Translate',          category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.messaging',                label: 'Google Messages',           category: 'messaging',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.dialer',                        label: 'Google Phone',              category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.contacts',                      label: 'Google Contacts',           category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.calculator',                    label: 'Calculator',                category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.nbu.paisa.user',           label: 'Google Pay',                category: 'upi',          publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.keep',                          label: 'Google Keep',               category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.subscriptions.red',        label: 'Google One',                category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.fitness',                  label: 'Google Fit',                category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.accessibility.maui.selecttospeak', label: 'Select to Speak',  category: 'a11y_tool',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.marvin.talkback',               label: 'TalkBack',                  category: 'a11y_tool',    publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.accessibility.soundamplifier',  label: 'Sound Amplifier',           category: 'a11y_tool',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.accessibility.switchaccess',    label: 'Switch Access',             category: 'a11y_tool',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.accessibility.magnifier',  label: 'Magnification',             category: 'a11y_tool',    publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.inputmethod.latin',             label: 'Gboard',                    category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.googlecamera',                  label: 'Google Camera',             category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.wellbeing',                label: 'Digital Wellbeing',         category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.apps.walletnfcrel',             label: 'Google Wallet',             category: 'payments',     publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.authenticator2',           label: 'Google Authenticator',      category: 'password_manager', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.adm',                      label: 'Find My Device',            category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.ar.lens',                               label: 'Google Lens',               category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.cloudconsole',             label: 'Google Cloud',              category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.bard',                     label: 'Google Bard',               category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.apps.gemini',                   label: 'Google Gemini',             category: 'productivity', publisher: 'Google LLC'),
    // ── Files & document apps (very commonly false-flagged) ─────────────────
    TrustedApp(packageName: 'com.google.android.apps.nbu.files',                label: 'Files by Google',           category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.google.android.documentsui',                   label: 'Files',                     category: 'system',       publisher: 'Google LLC', isSystemApp: true),
    TrustedApp(packageName: 'com.android.documentsui',                          label: 'Files',                     category: 'system',       publisher: 'Android',    isSystemApp: true),
    // ── Common OEM calendar apps (commonly false-flagged for widget/overlay use) ──
    TrustedApp(packageName: 'com.google.android.calendar',                      label: 'Google Calendar',           category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.android.calendar',                             label: 'Calendar',                  category: 'system',       publisher: 'Android',    isSystemApp: true),
    TrustedApp(packageName: 'com.samsung.android.calendar',                     label: 'Samsung Calendar',          category: 'system',       publisher: 'Samsung',    isSystemApp: true),
    TrustedApp(packageName: 'com.android.deskclock',                            label: 'Clock',                     category: 'system',       publisher: 'Android',    isSystemApp: true),
    TrustedApp(packageName: 'com.google.android.deskclock',                     label: 'Google Clock',              category: 'productivity', publisher: 'Google LLC'),
    TrustedApp(packageName: 'com.android.gallery3d',                            label: 'Gallery',                   category: 'system',       publisher: 'Android',    isSystemApp: true),
    TrustedApp(packageName: 'com.miui.calculator',                              label: 'MIUI Calculator',           category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.miui.notes',                                   label: 'MIUI Notes',                category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.miui.calendar',                                label: 'MIUI Calendar',             category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.miui.weather2',                                label: 'MIUI Weather',              category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.miui.mediaeditor',                             label: 'MIUI Gallery Editor',       category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.miui.player',                                  label: 'MIUI Music',                category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.mi.android.globalFileexplorer',                label: 'Mi File Manager',           category: 'system',       publisher: 'Xiaomi',     isSystemApp: true),
    TrustedApp(packageName: 'com.android.camera',                               label: 'Camera',                    category: 'system',       publisher: 'Android',    isSystemApp: true),
    TrustedApp(packageName: 'com.android.fileexplorer',                         label: 'File Manager',              category: 'system',       publisher: 'Android',    isSystemApp: true),
    TrustedApp(packageName: 'com.simplemobiletools.calendar.pro',               label: 'Simple Calendar Pro',       category: 'productivity', publisher: 'Simple Mobile Tools'),
    TrustedApp(packageName: 'com.simplemobiletools.gallery.pro',                label: 'Simple Gallery Pro',        category: 'productivity', publisher: 'Simple Mobile Tools'),
    TrustedApp(packageName: 'com.simplemobiletools.contacts.pro',               label: 'Simple Contacts Pro',       category: 'productivity', publisher: 'Simple Mobile Tools'),
    TrustedApp(packageName: 'com.simplemobiletools.notes.pro',                  label: 'Simple Notes Pro',          category: 'productivity', publisher: 'Simple Mobile Tools'),
    TrustedApp(packageName: 'com.simplemobiletools.filemanager.pro',            label: 'Simple File Manager Pro',   category: 'productivity', publisher: 'Simple Mobile Tools'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // Indian banks
  // ────────────────────────────────────────────────────────────────────────
  static const _banks = [
    TrustedApp(packageName: 'com.sbi.SBIFreedomPlus',            label: 'YONO SBI',           category: 'banking', publisher: 'State Bank of India'),
    TrustedApp(packageName: 'com.sbi.sbimobile',                 label: 'SBI Mobile',         category: 'banking', publisher: 'State Bank of India'),
    TrustedApp(packageName: 'com.sbi.upi',                       label: 'SBI Pay',            category: 'upi',     publisher: 'State Bank of India'),
    TrustedApp(packageName: 'com.sbi.lotusintouch',              label: 'YONO Lite',          category: 'banking', publisher: 'State Bank of India'),
    TrustedApp(packageName: 'com.hdfcbank.app',                  label: 'HDFC Bank',          category: 'banking', publisher: 'HDFC Bank Ltd'),
    TrustedApp(packageName: 'com.hdfcbank.android',              label: 'HDFC Bank',          category: 'banking', publisher: 'HDFC Bank Ltd'),
    TrustedApp(packageName: 'com.hdfcbank.payzapp',              label: 'HDFC PayZapp',       category: 'payments',publisher: 'HDFC Bank Ltd'),
    TrustedApp(packageName: 'com.hdfcbank.netbanking',           label: 'HDFC NetBanking',    category: 'banking', publisher: 'HDFC Bank Ltd'),
    TrustedApp(packageName: 'com.hdfcbank.iMobile',              label: 'HDFC iMobile',       category: 'banking', publisher: 'HDFC Bank Ltd'),
    TrustedApp(packageName: 'com.snapwork.hdfc',                 label: 'HDFC Bank',          category: 'banking', publisher: 'HDFC Bank Ltd'),
    TrustedApp(packageName: 'com.csam.icici.bank.imobile',       label: 'iMobile Pay',        category: 'banking', publisher: 'ICICI Bank'),
    TrustedApp(packageName: 'com.icicibank.iMobile',             label: 'ICICI iMobile',      category: 'banking', publisher: 'ICICI Bank'),
    TrustedApp(packageName: 'com.icicibank.pockets',             label: 'ICICI Pockets',      category: 'payments', publisher: 'ICICI Bank'),
    TrustedApp(packageName: 'com.icicidirect.app',               label: 'ICICI Direct',       category: 'finance', publisher: 'ICICI Securities'),
    TrustedApp(packageName: 'com.icicidirect.imobile',           label: 'ICICI Direct',       category: 'finance', publisher: 'ICICI Securities'),
    TrustedApp(packageName: 'com.idirect.android',               label: 'ICICI Direct',       category: 'finance', publisher: 'ICICI Securities'),
    TrustedApp(packageName: 'com.axis.mobile',                   label: 'Axis Mobile',        category: 'banking', publisher: 'Axis Bank'),
    TrustedApp(packageName: 'com.axisbank.finmobile',            label: 'Axis Mobile',        category: 'banking', publisher: 'Axis Bank'),
    TrustedApp(packageName: 'com.kotak.mahindra.kotak_mobile',   label: 'Kotak Mobile',       category: 'banking', publisher: 'Kotak Mahindra Bank'),
    TrustedApp(packageName: 'com.kotak.mobile',                  label: 'Kotak Mobile',       category: 'banking', publisher: 'Kotak Mahindra Bank'),
    TrustedApp(packageName: 'com.kotak.mahindra.bank',           label: 'Kotak Mahindra',     category: 'banking', publisher: 'Kotak Mahindra Bank'),
    TrustedApp(packageName: 'com.bankofbaroda.mconnect',         label: 'Bob World',          category: 'banking', publisher: 'Bank of Baroda'),
    TrustedApp(packageName: 'com.bankofbaroda.mobilebanking',    label: 'Bank of Baroda',     category: 'banking', publisher: 'Bank of Baroda'),
    TrustedApp(packageName: 'com.barodampay',                    label: 'BarodaMPay',         category: 'upi',     publisher: 'Bank of Baroda'),
    TrustedApp(packageName: 'com.YesBank',                       label: 'Yes Bank',           category: 'banking', publisher: 'Yes Bank Ltd'),
    TrustedApp(packageName: 'com.unionbank.ecommerce.mobile.legacy',  label: 'Union Bank',    category: 'banking', publisher: 'Union Bank of India'),
    TrustedApp(packageName: 'com.unionbank.mbanking',            label: 'Union Bank',         category: 'banking', publisher: 'Union Bank of India'),
    TrustedApp(packageName: 'com.idbibank.m',                    label: 'IDBI Bank',          category: 'banking', publisher: 'IDBI Bank'),
    TrustedApp(packageName: 'com.idbi.mobile',                   label: 'IDBI Bank',          category: 'banking', publisher: 'IDBI Bank'),
    TrustedApp(packageName: 'com.pnbindia.pnbmobile',            label: 'PNB One',            category: 'banking', publisher: 'Punjab National Bank'),
    TrustedApp(packageName: 'com.pnbindia',                      label: 'PNB One',            category: 'banking', publisher: 'Punjab National Bank'),
    TrustedApp(packageName: 'com.southindianbank.mobilebanking', label: 'SIB Mirror+',        category: 'banking', publisher: 'South Indian Bank'),
    TrustedApp(packageName: 'com.indusind',                      label: 'IndusInd Mobile',    category: 'banking', publisher: 'IndusInd Bank'),
    TrustedApp(packageName: 'com.indusind.indusmobile',          label: 'IndusInd Mobile',    category: 'banking', publisher: 'IndusInd Bank'),
    TrustedApp(packageName: 'com.idfcfirstbank',                 label: 'IDFC First Bank',    category: 'banking', publisher: 'IDFC FIRST Bank'),
    TrustedApp(packageName: 'com.idfcbank.mobilebanking',        label: 'IDFC First Bank',    category: 'banking', publisher: 'IDFC FIRST Bank'),
    TrustedApp(packageName: 'com.canarabank.mobility',           label: 'Canara ai1',         category: 'banking', publisher: 'Canara Bank'),
    TrustedApp(packageName: 'com.fedmobile',                     label: 'Federal Mobile',     category: 'banking', publisher: 'Federal Bank'),
    TrustedApp(packageName: 'com.fbl.fedmobile',                 label: 'Federal Mobile',     category: 'banking', publisher: 'Federal Bank'),
    TrustedApp(packageName: 'com.rbl.banking',                   label: 'RBL Bank',           category: 'banking', publisher: 'RBL Bank'),
    TrustedApp(packageName: 'com.bobl.standardbank',             label: 'Standard Chartered', category: 'banking', publisher: 'Standard Chartered'),
    TrustedApp(packageName: 'com.dbs.in.digitalbank',            label: 'DBS digibank',       category: 'banking', publisher: 'DBS Bank'),
    TrustedApp(packageName: 'com.citibank.mobile.uk',            label: 'Citi Mobile',        category: 'banking', publisher: 'Citibank'),
    TrustedApp(packageName: 'com.hsbc.in.android',               label: 'HSBC India',         category: 'banking', publisher: 'HSBC'),
    TrustedApp(packageName: 'com.csam.imobile',                  label: 'iMobile',            category: 'banking', publisher: 'ICICI Bank'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // UPI / Payments / Fintech
  // ────────────────────────────────────────────────────────────────────────
  static const _payments = [
    TrustedApp(packageName: 'net.one97.paytm',                   label: 'Paytm',              category: 'payments', publisher: 'Paytm'),
    TrustedApp(packageName: 'com.phonepe.app',                   label: 'PhonePe',            category: 'upi',      publisher: 'PhonePe'),
    TrustedApp(packageName: 'com.ybl',                           label: 'Google Pay',         category: 'upi',      publisher: 'Google LLC'),
    TrustedApp(packageName: 'in.org.npci.upiapp',                label: 'BHIM',               category: 'upi',      publisher: 'NPCI'),
    TrustedApp(packageName: 'in.amazon.mShop.android.shopping',  label: 'Amazon Shopping',    category: 'shopping', publisher: 'Amazon'),
    TrustedApp(packageName: 'com.amazon.mShop.android.shopping', label: 'Amazon Shopping',    category: 'shopping', publisher: 'Amazon'),
    TrustedApp(packageName: 'com.amazon.mShop.android',          label: 'Amazon Pay',         category: 'payments', publisher: 'Amazon'),
    TrustedApp(packageName: 'com.amazon.avod.thirdpartyclient',  label: 'Amazon Prime Video', category: 'popular',  publisher: 'Amazon'),
    TrustedApp(packageName: 'in.amazon.payments.upi.android',    label: 'Amazon Pay',         category: 'upi',      publisher: 'Amazon'),
    TrustedApp(packageName: 'com.cred.club',                     label: 'CRED',               category: 'payments', publisher: 'CRED'),
    TrustedApp(packageName: 'com.dreamplug.androidapp',          label: 'CRED',               category: 'payments', publisher: 'CRED'),
    TrustedApp(packageName: 'com.razorpay.payments.app',         label: 'Razorpay',           category: 'payments', publisher: 'Razorpay'),
    TrustedApp(packageName: 'com.mobikwik_new',                  label: 'MobiKwik',           category: 'payments', publisher: 'MobiKwik'),
    TrustedApp(packageName: 'com.freecharge.android',            label: 'Freecharge',         category: 'payments', publisher: 'Freecharge'),
    TrustedApp(packageName: 'in.juspay.bankingbridge',           label: 'Juspay',             category: 'payments', publisher: 'Juspay'),
    TrustedApp(packageName: 'com.razorpay.upi',                  label: 'Razorpay UPI',       category: 'upi',      publisher: 'Razorpay'),
    TrustedApp(packageName: 'com.airtel.payments',               label: 'Airtel Payments',    category: 'payments', publisher: 'Airtel'),
    TrustedApp(packageName: 'com.myairtelapp',                   label: 'Airtel Thanks',      category: 'payments', publisher: 'Airtel'),
    TrustedApp(packageName: 'com.airtel.android.phone',          label: 'Airtel Thanks',      category: 'payments', publisher: 'Airtel'),
    TrustedApp(packageName: 'com.jio.myjio',                     label: 'MyJio',              category: 'payments', publisher: 'Jio'),
    TrustedApp(packageName: 'com.zerodha.kite3',                 label: 'Kite by Zerodha',    category: 'payments', publisher: 'Zerodha'),
    TrustedApp(packageName: 'com.upstox.stocks',                 label: 'Upstox',             category: 'payments', publisher: 'Upstox'),
    TrustedApp(packageName: 'com.groww.app',                     label: 'Groww',              category: 'payments', publisher: 'Groww'),
    TrustedApp(packageName: 'com.angelbroking.angelone',         label: 'Angel One',          category: 'payments', publisher: 'Angel One'),
    TrustedApp(packageName: 'com.fivepaisa.trade',               label: '5paisa',             category: 'payments', publisher: '5paisa'),
    TrustedApp(packageName: 'com.policybazaar',                  label: 'Policybazaar',       category: 'payments', publisher: 'Policybazaar'),
    TrustedApp(packageName: 'com.android.bankbazaar',            label: 'BankBazaar',         category: 'payments', publisher: 'BankBazaar'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // Social / Messaging / Popular consumer apps
  // ────────────────────────────────────────────────────────────────────────
  static const _social = [
    TrustedApp(packageName: 'com.whatsapp',                      label: 'WhatsApp',           category: 'messaging', publisher: 'WhatsApp LLC'),
    TrustedApp(packageName: 'com.whatsapp.w4b',                  label: 'WhatsApp Business',  category: 'messaging', publisher: 'WhatsApp LLC'),
    TrustedApp(packageName: 'org.telegram.messenger',            label: 'Telegram',           category: 'messaging', publisher: 'Telegram FZ-LLC'),
    TrustedApp(packageName: 'org.thunderdog.challegram',         label: 'Telegram X',         category: 'messaging', publisher: 'Telegram FZ-LLC'),
    TrustedApp(packageName: 'com.instagram.android',             label: 'Instagram',          category: 'social',    publisher: 'Meta Platforms'),
    TrustedApp(packageName: 'com.instagram.lite',                label: 'Instagram Lite',     category: 'social',    publisher: 'Meta Platforms'),
    TrustedApp(packageName: 'com.instagram.barcelona',           label: 'Threads',            category: 'social',    publisher: 'Meta Platforms'),
    TrustedApp(packageName: 'com.facebook.katana',               label: 'Facebook',           category: 'social',    publisher: 'Meta Platforms'),
    TrustedApp(packageName: 'com.facebook.lite',                 label: 'Facebook Lite',      category: 'social',    publisher: 'Meta Platforms'),
    TrustedApp(packageName: 'com.facebook.orca',                 label: 'Messenger',          category: 'messaging', publisher: 'Meta Platforms'),
    TrustedApp(packageName: 'com.twitter.android',               label: 'X (Twitter)',        category: 'social',    publisher: 'X Corp'),
    TrustedApp(packageName: 'com.zhiliaoapp.musically',          label: 'TikTok',             category: 'social',    publisher: 'ByteDance'),
    TrustedApp(packageName: 'com.snapchat.android',              label: 'Snapchat',           category: 'social',    publisher: 'Snap Inc'),
    TrustedApp(packageName: 'com.pinterest',                     label: 'Pinterest',          category: 'social',    publisher: 'Pinterest'),
    TrustedApp(packageName: 'com.linkedin.android',              label: 'LinkedIn',           category: 'social',    publisher: 'LinkedIn'),
    TrustedApp(packageName: 'com.reddit.frontpage',              label: 'Reddit',             category: 'social',    publisher: 'Reddit Inc'),
    TrustedApp(packageName: 'com.discord',                       label: 'Discord',            category: 'messaging', publisher: 'Discord Inc'),
    TrustedApp(packageName: 'org.thoughtcrime.securesms',        label: 'Signal',             category: 'messaging', publisher: 'Signal Foundation'),
    TrustedApp(packageName: 'org.signal.signal',                 label: 'Signal',             category: 'messaging', publisher: 'Signal Foundation'),
    TrustedApp(packageName: 'us.zoom.videomeetings',             label: 'Zoom',               category: 'messaging', publisher: 'Zoom Video'),
    TrustedApp(packageName: 'com.microsoft.teams',               label: 'Microsoft Teams',    category: 'messaging', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.skype.raider',                  label: 'Skype',              category: 'messaging', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.truecaller',                    label: 'Truecaller',         category: 'messaging', publisher: 'Truecaller'),
    TrustedApp(packageName: 'com.bsb.hike',                      label: 'Hike',               category: 'messaging', publisher: 'Hike'),
    TrustedApp(packageName: 'com.viber.voip',                    label: 'Viber',              category: 'messaging', publisher: 'Viber'),
    TrustedApp(packageName: 'com.tencent.mm',                    label: 'WeChat',             category: 'messaging', publisher: 'Tencent'),
    TrustedApp(packageName: 'com.imo.android.imoim',             label: 'imo',                category: 'messaging', publisher: 'imo.im'),
    TrustedApp(packageName: 'com.imo.android.imoimbeta',         label: 'imo beta',           category: 'messaging', publisher: 'imo.im'),
    TrustedApp(packageName: 'jp.naver.line.android',             label: 'LINE',               category: 'messaging', publisher: 'LINE'),
    TrustedApp(packageName: 'com.facebook.mlite',                label: 'Messenger Lite',     category: 'messaging', publisher: 'Meta Platforms'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // E-commerce / Travel / Lifestyle
  // ────────────────────────────────────────────────────────────────────────
  static const _commerce = [
    TrustedApp(packageName: 'com.flipkart.android',              label: 'Flipkart',           category: 'shopping',  publisher: 'Flipkart'),
    TrustedApp(packageName: 'com.myntra.android',                label: 'Myntra',             category: 'shopping',  publisher: 'Myntra'),
    TrustedApp(packageName: 'com.ajio.app',                      label: 'Ajio',               category: 'shopping',  publisher: 'Reliance Retail'),
    TrustedApp(packageName: 'com.tatacliq.tatacliq',             label: 'Tata CLiQ',          category: 'shopping',  publisher: 'Tata Group'),
    TrustedApp(packageName: 'com.snapdeal.main',                 label: 'Snapdeal',           category: 'shopping',  publisher: 'Snapdeal'),
    TrustedApp(packageName: 'com.meesho.supply',                 label: 'Meesho',             category: 'shopping',  publisher: 'Meesho'),
    TrustedApp(packageName: 'com.shopclues',                     label: 'Shopclues',          category: 'shopping',  publisher: 'Shopclues'),
    TrustedApp(packageName: 'com.makemytrip',                    label: 'MakeMyTrip',         category: 'productivity', publisher: 'MakeMyTrip'),
    TrustedApp(packageName: 'com.goibibo',                       label: 'Goibibo',            category: 'productivity', publisher: 'Goibibo'),
    TrustedApp(packageName: 'com.cleartrip.android',             label: 'Cleartrip',          category: 'productivity', publisher: 'Cleartrip'),
    TrustedApp(packageName: 'com.yatra.base',                    label: 'Yatra',              category: 'productivity', publisher: 'Yatra'),
    TrustedApp(packageName: 'com.irctc.rajdhani.prod',           label: 'IRCTC Rail Connect', category: 'gov',        publisher: 'IRCTC'),
    TrustedApp(packageName: 'cris.org.in.prs.ima',               label: 'IRCTC',              category: 'gov',        publisher: 'IRCTC'),
    TrustedApp(packageName: 'com.bookmyshow',                    label: 'BookMyShow',         category: 'popular',    publisher: 'BookMyShow'),
    TrustedApp(packageName: 'com.bookmyshow.app',                label: 'BookMyShow',         category: 'popular',    publisher: 'BookMyShow'),
    TrustedApp(packageName: 'com.swiggy.android',                label: 'Swiggy',             category: 'shopping',   publisher: 'Swiggy'),
    TrustedApp(packageName: 'com.application.zomato',            label: 'Zomato',             category: 'shopping',   publisher: 'Zomato'),
    TrustedApp(packageName: 'com.zomato.android',                label: 'Zomato',             category: 'shopping',   publisher: 'Zomato'),
    TrustedApp(packageName: 'com.dunzo.user',                    label: 'Dunzo',              category: 'shopping',   publisher: 'Dunzo'),
    TrustedApp(packageName: 'com.bigbasket.mobileapp',           label: 'BigBasket',          category: 'shopping',   publisher: 'BigBasket'),
    TrustedApp(packageName: 'com.grofers.customerapp',           label: 'Blinkit',            category: 'shopping',   publisher: 'Blinkit'),
    TrustedApp(packageName: 'com.zeptoconsumerapp',              label: 'Zepto',              category: 'shopping',   publisher: 'Zepto'),
    TrustedApp(packageName: 'com.olacabs.customer',              label: 'Ola',                category: 'productivity', publisher: 'Ola'),
    TrustedApp(packageName: 'com.ola.client',                    label: 'Ola',                category: 'productivity', publisher: 'Ola'),
    TrustedApp(packageName: 'com.ubercab',                       label: 'Uber',               category: 'productivity', publisher: 'Uber'),
    TrustedApp(packageName: 'com.rapido.passenger',              label: 'Rapido',             category: 'productivity', publisher: 'Rapido'),
    TrustedApp(packageName: 'com.netflix.mediaclient',           label: 'Netflix',            category: 'popular',    publisher: 'Netflix'),
    TrustedApp(packageName: 'in.startv.hotstar',                 label: 'Disney+ Hotstar',    category: 'popular',    publisher: 'Disney+ Hotstar'),
    TrustedApp(packageName: 'com.tv.v18.viola',                  label: 'JioCinema',          category: 'popular',    publisher: 'Viacom18'),
    TrustedApp(packageName: 'com.jio.media.jioxpressnews',       label: 'JioNews',            category: 'popular',    publisher: 'Jio'),
    TrustedApp(packageName: 'com.spotify.music',                 label: 'Spotify',            category: 'popular',    publisher: 'Spotify'),
    TrustedApp(packageName: 'com.gaana',                         label: 'Gaana',              category: 'popular',    publisher: 'Gaana'),
    TrustedApp(packageName: 'com.jiosaavn.media.global',         label: 'JioSaavn',           category: 'popular',    publisher: 'JioSaavn'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // Government / Civic / Utility
  // ────────────────────────────────────────────────────────────────────────
  static const _government = [
    TrustedApp(packageName: 'in.gov.uidai.mAadhaarPlus',         label: 'mAadhaar',           category: 'gov', publisher: 'UIDAI'),
    TrustedApp(packageName: 'in.digilocker.android',             label: 'DigiLocker',         category: 'gov', publisher: 'NeGD MeitY'),
    TrustedApp(packageName: 'com.digilocker.android',            label: 'DigiLocker',         category: 'gov', publisher: 'NeGD MeitY'),
    TrustedApp(packageName: 'com.umang.negd',                    label: 'UMANG',              category: 'gov', publisher: 'NeGD MeitY'),
    TrustedApp(packageName: 'in.gov.umang.negd.g2c',             label: 'UMANG',              category: 'gov', publisher: 'NeGD MeitY'),
    TrustedApp(packageName: 'com.nic.eahosp',                    label: 'eAushadhi',          category: 'gov', publisher: 'NIC'),
    TrustedApp(packageName: 'in.gov.scholarships.nsp',           label: 'NSP',                category: 'gov', publisher: 'GoI'),
    TrustedApp(packageName: 'com.cowinapp',                      label: 'CoWIN',              category: 'gov', publisher: 'MoHFW'),
    TrustedApp(packageName: 'in.gov.cowin.android',              label: 'CoWIN',              category: 'gov', publisher: 'MoHFW'),
    TrustedApp(packageName: 'com.passport.application.android',  label: 'mPassport',          category: 'gov', publisher: 'MEA'),
    TrustedApp(packageName: 'com.epfo.android',                  label: 'UMANG EPF',          category: 'gov', publisher: 'EPFO'),
    TrustedApp(packageName: 'com.incometaxindiaefiling',         label: 'Income Tax India',   category: 'gov', publisher: 'Govt of India'),
    TrustedApp(packageName: 'com.incometaxindia.ais',            label: 'IT Department',      category: 'gov', publisher: 'Govt of India'),
    TrustedApp(packageName: 'com.cibil.consumer',                label: 'CIBIL',              category: 'gov', publisher: 'CIBIL'),
    TrustedApp(packageName: 'com.uidai.faceauth',                label: 'Aadhaar FaceRD',     category: 'gov', publisher: 'UIDAI'),
    TrustedApp(packageName: 'in.gov.sancharsaathi',              label: 'Sanchar Saathi',     category: 'gov', publisher: 'DoT India'),
    TrustedApp(packageName: 'com.dot.app.sancharsaathi',         label: 'Sanchar Saathi',     category: 'gov', publisher: 'DoT India'),
    TrustedApp(packageName: 'in.gov.eshram',                     label: 'eShram',             category: 'gov', publisher: 'Govt of India'),
    TrustedApp(packageName: 'com.cdac.merchanthelp.bhim',        label: 'BHIM Aadhaar',       category: 'upi', publisher: 'NPCI'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // Microsoft / Enterprise / Productivity
  // ────────────────────────────────────────────────────────────────────────
  static const _enterprise = [
    TrustedApp(packageName: 'com.microsoft.office.outlook',      label: 'Outlook',            category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.office.word',         label: 'Word',               category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.office.excel',        label: 'Excel',              category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.office.powerpoint',   label: 'PowerPoint',         category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.office.onenote',      label: 'OneNote',            category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.skydrive',            label: 'OneDrive',           category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.todos',               label: 'Microsoft To Do',    category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.launcher',            label: 'Microsoft Launcher', category: 'launcher',     publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.windowsintune.companyportal', label: 'Intune',     category: 'productivity', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.microsoft.azure.authenticator', label: 'Microsoft Authenticator', category: 'password_manager', publisher: 'Microsoft'),
    TrustedApp(packageName: 'com.adobe.reader',                  label: 'Adobe Reader',       category: 'productivity', publisher: 'Adobe'),
    TrustedApp(packageName: 'com.adobe.creativesdk.aviary',      label: 'Adobe',              category: 'productivity', publisher: 'Adobe'),
    TrustedApp(packageName: 'com.dropbox.android',               label: 'Dropbox',            category: 'productivity', publisher: 'Dropbox'),
    TrustedApp(packageName: 'com.notion.id',                     label: 'Notion',             category: 'productivity', publisher: 'Notion Labs'),
    TrustedApp(packageName: 'com.evernote',                      label: 'Evernote',           category: 'productivity', publisher: 'Evernote'),
    TrustedApp(packageName: 'com.slack',                         label: 'Slack',              category: 'messaging',    publisher: 'Slack'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // Password managers / Security tools (need overlay + accessibility)
  // ────────────────────────────────────────────────────────────────────────
  static const _security = [
    TrustedApp(packageName: 'com.lastpass.lpandroid',            label: 'LastPass',           category: 'password_manager', publisher: 'LastPass'),
    TrustedApp(packageName: 'com.dashlane.android',              label: 'Dashlane',           category: 'password_manager', publisher: 'Dashlane'),
    TrustedApp(packageName: 'com.agilebits.onepassword',         label: '1Password',          category: 'password_manager', publisher: 'AgileBits'),
    TrustedApp(packageName: 'com.x8bit.bitwarden',               label: 'Bitwarden',          category: 'password_manager', publisher: 'Bitwarden'),
    TrustedApp(packageName: 'org.bromite.bromite',               label: 'Bromite',            category: 'browser',          publisher: 'Bromite'),
    TrustedApp(packageName: 'com.duckduckgo.mobile.android',     label: 'DuckDuckGo',         category: 'browser',          publisher: 'DuckDuckGo'),
    TrustedApp(packageName: 'org.mozilla.firefox',               label: 'Firefox',            category: 'browser',          publisher: 'Mozilla'),
    TrustedApp(packageName: 'org.mozilla.focus',                 label: 'Firefox Focus',      category: 'browser',          publisher: 'Mozilla'),
    TrustedApp(packageName: 'com.brave.browser',                 label: 'Brave',              category: 'browser',          publisher: 'Brave'),
    TrustedApp(packageName: 'com.opera.browser',                 label: 'Opera',              category: 'browser',          publisher: 'Opera'),
    TrustedApp(packageName: 'com.microsoft.emmx',                label: 'Edge',               category: 'browser',          publisher: 'Microsoft'),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // Samsung / Xiaomi / OEM system apps
  // ────────────────────────────────────────────────────────────────────────
  static const _oem = [
    TrustedApp(packageName: 'com.samsung.android.app.notes',     label: 'Samsung Notes',      category: 'system',  publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.samsung.android.calendar',      label: 'Samsung Calendar',   category: 'system',  publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.sec.android.app.launcher',      label: 'One UI Home',        category: 'launcher',publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.samsung.knox.keychain',         label: 'Samsung Knox',       category: 'system',  publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.samsung.android.spay',          label: 'Samsung Wallet',     category: 'payments',publisher: 'Samsung'),
    TrustedApp(packageName: 'com.samsung.android.app.accessibility', label: 'Samsung Accessibility', category: 'a11y_tool', publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.samsung.android.universalswitch', label: 'Universal Switch', category: 'a11y_tool', publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.samsung.accessibility',         label: 'Samsung Accessibility', category: 'a11y_tool', publisher: 'Samsung', isSystemApp: true),
    TrustedApp(packageName: 'com.miui.home',                     label: 'MIUI Home',          category: 'launcher',publisher: 'Xiaomi',  isSystemApp: true),
    TrustedApp(packageName: 'com.miui.securitycenter',           label: 'Mi Security',        category: 'system',  publisher: 'Xiaomi',  isSystemApp: true),
    TrustedApp(packageName: 'com.miui.gallery',                  label: 'Gallery',            category: 'system',  publisher: 'Xiaomi',  isSystemApp: true),
    TrustedApp(packageName: 'com.xiaomi.market',                 label: 'GetApps',            category: 'system',  publisher: 'Xiaomi',  isSystemApp: true),
    TrustedApp(packageName: 'com.android.systemui',              label: 'System UI',          category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.settings',              label: 'Settings',           category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.providers.contacts',    label: 'Contacts Provider',  category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.bluetooth',             label: 'Bluetooth',          category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.calendar',              label: 'Calendar',           category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.documentsui',           label: 'Files',              category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.dialer',                label: 'Phone',              category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.contacts',              label: 'Contacts',           category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.mms',                   label: 'Messages',           category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.calllogbackup',         label: 'Call Log',           category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.providers.media',       label: 'Media Provider',    category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.providers.downloads',   label: 'Downloads',          category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.keychain',              label: 'Keychain',           category: 'system',  publisher: 'Android', isSystemApp: true),
    TrustedApp(packageName: 'com.android.printspooler',          label: 'Print Spooler',      category: 'system',  publisher: 'Android', isSystemApp: true),
  ];

  // ── Combined catalog (all apps) ─────────────────────────────────────────
  static final Map<String, TrustedApp> _allApps = <String, TrustedApp>{
    for (final app in [
      ..._google, ..._banks, ..._payments, ..._social,
      ..._commerce, ..._government, ..._enterprise,
      ..._security, ..._oem,
    ])
      app.packageName: app,
  };

  // ── Search & match API ──────────────────────────────────────────────────

  /// Exact lookup by package name.
  static TrustedApp? lookup(String packageName) => _allApps[packageName];

  /// `true` if the package name is in the catalog.
  static bool isKnown(String packageName) => _allApps.containsKey(packageName);

  /// Return all banks (trusted reference for fake-bank detection).
  static List<TrustedApp> get banks => _banks;

  /// Return all UPI / payment apps.
  static List<TrustedApp> get paymentApps =>
      _allApps.values
          .where((a) => a.category == 'upi' || a.category == 'payments')
          .toList();

  /// Get all known package names as a set for O(1) lookup.
  static Set<String> get knownPackages => _allApps.keys.toSet();

  /// Get all known labels as a set (for normalized matching).
  static Set<String> get knownLabels =>
      _allApps.values.map((a) => a.label).toSet();

  /// Returns all apps in a given category.
  static List<TrustedApp> byCategory(String category) =>
      _allApps.values.where((a) => a.category == category).toList();

  /// Returns all trusted apps (flattened list).
  static List<TrustedApp> get all => _allApps.values.toList();

  /// Total trusted apps in catalog.
  static int get count => _allApps.length;
}

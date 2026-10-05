/// Fake Bank SMS Classifier
///
/// In India, registered enterprises send SMS through TRAI-allotted headers
/// in the format `<TT>-<ABCDEF>` where:
///   - `<TT>` is the access provider (VK = Vodafone, AX = Airtel, etc.)
///   - `<ABCDEF>` is the entity code (HDFCBK, SBIINB, ICICIB, etc.)
///
/// Legitimate banks NEVER message you from a 10-digit mobile number — that
/// would breach TRAI's TCCCPR 2018 regulations. A 10-digit sender claiming
/// to be a bank is therefore a near-certain scam.
///
/// This classifier inspects (sender, body) tuples and flags fakes.
library;

enum FakeBankSmsVerdict {
  legitimate,
  unverifiable,
  suspicious,
  fake,
}

class FakeBankSmsReport {
  final FakeBankSmsVerdict verdict;
  final String sender;
  final String? matchedBank;
  final String? matchedHeader;
  final List<String> reasons;
  final List<String> recommendations;

  const FakeBankSmsReport({
    required this.verdict,
    required this.sender,
    this.matchedBank,
    this.matchedHeader,
    required this.reasons,
    required this.recommendations,
  });
}

class FakeBankSmsClassifier {
  /// Approximate TRAI header pattern: AA-BBBBBB (with optional dash + suffix).
  /// Examples: VK-HDFCBK, JM-SBIINB, AX-AXISBK, VM-PAYTM, JD-ICICIB
  static final RegExp _traiHeader = RegExp(
    r'^[A-Z]{2}-[A-Z]{3,6}(?:-[A-Z0-9]{1,2})?$',
    caseSensitive: false,
  );

  /// Known legitimate bank/financial entity codes used in TRAI headers.
  static const _legitEntityCodes = {
    // Banks
    'HDFCBK': 'HDFC Bank',
    'HDFC': 'HDFC Bank',
    'SBIINB': 'State Bank of India',
    'SBI': 'State Bank of India',
    'SBIPSG': 'State Bank of India',
    'ICICIB': 'ICICI Bank',
    'ICICI': 'ICICI Bank',
    'AXISBK': 'Axis Bank',
    'AXIS': 'Axis Bank',
    'KOTAKB': 'Kotak Mahindra Bank',
    'KOTAK': 'Kotak Mahindra Bank',
    'YESBNK': 'YES Bank',
    'YESBK': 'YES Bank',
    'IDFCFB': 'IDFC FIRST Bank',
    'IDFC': 'IDFC FIRST Bank',
    'IDBI': 'IDBI Bank',
    'PNBSMS': 'Punjab National Bank',
    'PNB': 'Punjab National Bank',
    'BOBSMS': 'Bank of Baroda',
    'BOB': 'Bank of Baroda',
    'CANBNK': 'Canara Bank',
    'UNIONB': 'Union Bank',
    'INDUSB': 'IndusInd Bank',
    'INDIANB': 'Indian Bank',
    'CITIBANK': 'Citi Bank',
    'CITIBK': 'Citi Bank',
    'HSBCBK': 'HSBC',
    'STANCH': 'Standard Chartered',
    'BARCLY': 'Barclays',
    'DBSBNK': 'DBS Bank',
    'RBLBNK': 'RBL Bank',
    'FEDBNK': 'Federal Bank',
    'KARURB': 'Karur Vysya Bank',
    'KARNTK': 'Karnataka Bank',
    'BANDHN': 'Bandhan Bank',
    // Payment apps
    'PAYTM': 'Paytm',
    'PYTM': 'Paytm',
    'PHONPE': 'PhonePe',
    'PHONE': 'PhonePe',
    'GPAY': 'Google Pay',
    'GOOGLE': 'Google Pay',
    'AMAZONP': 'Amazon Pay',
    'AMAZON': 'Amazon Pay',
    'BHIM': 'BHIM',
    'BHIMUPI': 'BHIM',
    'MOBIKW': 'Mobikwik',
    'FREECH': 'Freecharge',
    // NBFCs / fintech
    'BAJAJFIN': 'Bajaj Finserv',
    'BAJAJ': 'Bajaj Finserv',
    'CASHEFB': 'CASHe',
    'LAZYPAY': 'LazyPay',
    'SLICEBNK': 'Slice',
    'RUPEEK': 'Rupeek',
    // Cards
    'AMEX': 'American Express',
    'AMERIC': 'American Express',
    'VISACD': 'Visa',
    'MSTRCD': 'Mastercard',
    'RUPAYCD': 'RuPay',
  };

  /// Bank-related keywords — used to decide if a message is "about" banking.
  static const _bankingKeywords = [
    'account', 'a/c', 'acct', 'a/c.',
    'debit', 'credit', 'balance', 'balance:',
    'transferred', 'transaction', 'txn', 'transfered',
    'upi', 'imps', 'neft', 'rtgs',
    'otp', 'cvv', 'pin', 'one time password', 'one-time-password',
    'kyc', 'aadhaar',
    'loan', 'emi',
    'card', 'debit card', 'credit card',
    'withdraw', 'deposit',
    'beneficiary', 'payee',
    'inr', 'rs.', 'rs ', '₹',
  ];

  /// Phrases strongly indicating fraud — even from a "legit" header could be
  /// a smishing attempt mimicking the header.
  static const _highRiskPhrases = [
    'click here', 'click below', 'tap here', 'tap link',
    'verify kyc', 'update kyc', 'kyc expired', 'kyc pending',
    'account will be blocked', 'a/c will be blocked',
    'account suspended', 'a/c suspended',
    'update your details', 'update bank details',
    'reactivate', 'reactivation',
    'win', 'won', 'lottery', 'prize',
    'verify identity', 'identity verification',
    'urgent', 'immediate', 'within 24 hours',
    'download.*app', 'install.*app',
  ];

  /// Free-text URL shorteners + suspicious TLDs that scammers love
  static final RegExp _shortenerPattern = RegExp(
    r'(bit\.ly|tinyurl|t\.co|goo\.gl|ow\.ly|is\.gd|buff\.ly|rebrand\.ly|cutt\.ly|shorturl|tiny\.cc|t2m\.io|rb\.gy)',
    caseSensitive: false,
  );

  static final RegExp _suspiciousTldPattern = RegExp(
    r'\.(xyz|tk|ml|ga|cf|top|click|link|info|review|loan|pw)\b',
    caseSensitive: false,
  );

  static final RegExp _tenDigitNumber = RegExp(r'^\+?91?[6-9]\d{9}$');

  static final RegExp _shortcode = RegExp(r'^\d{4,8}$');

  /// Main entry point.
  static FakeBankSmsReport classify({
    required String sender,
    required String body,
  }) {
    final senderClean = sender.trim();
    final bodyLower = body.toLowerCase();
    final reasons = <String>[];
    final recommendations = <String>[];

    final mentionsBanking = _bankingKeywords.any(bodyLower.contains);
    final hasUrl = RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(bodyLower);
    final hasShortener = _shortenerPattern.hasMatch(bodyLower);
    final hasSuspiciousTld = _suspiciousTldPattern.hasMatch(bodyLower);
    final highRiskHits = _highRiskPhrases.where((p) {
      try {
        return RegExp(p, caseSensitive: false).hasMatch(bodyLower);
      } catch (_) {
        return bodyLower.contains(p);
      }
    }).toList();

    // ── Path A: 10-digit number claiming banking content ──────────────────
    if (_tenDigitNumber.hasMatch(senderClean.replaceAll(RegExp(r'\s+'), ''))) {
      if (mentionsBanking) {
        reasons.add('Sender is a 10-digit mobile number, not a TRAI-registered header.');
        reasons.add('Banks NEVER send SMS from regular phone numbers.');
        if (hasUrl) {
          reasons.add('Message contains a link — banks rarely send actionable links over SMS.');
        }
        if (hasShortener) {
          reasons.add('Link uses a URL shortener — a classic smishing indicator.');
        }
        recommendations.addAll([
          'Do NOT click any link in this message.',
          'Do NOT call any phone number in this message.',
          'Call your bank using the number on the back of your card to verify.',
          'Report this number on the DoT Sanchaar Saathi portal (1909 SMS).',
        ]);
        return FakeBankSmsReport(
          verdict: FakeBankSmsVerdict.fake,
          sender: senderClean,
          reasons: reasons,
          recommendations: recommendations,
        );
      }
      return FakeBankSmsReport(
        verdict: FakeBankSmsVerdict.unverifiable,
        sender: senderClean,
        reasons: const [
          'Sender is a personal 10-digit number — context unclear.',
        ],
        recommendations: const [
          'Be cautious. If this is about banking or money, verify directly with your bank.',
        ],
      );
    }

    // ── Path B: TRAI-style header — check entity code ─────────────────────
    if (_traiHeader.hasMatch(senderClean)) {
      final parts = senderClean.toUpperCase().split('-');
      final entity = parts.length >= 2 ? parts[1] : '';
      final matchedBank = _legitEntityCodes[entity];

      // High-risk phrases (KYC, click link, verify, etc.) drastically raise risk
      // even from a legitimate-looking header — could be a TRAI-spoof attack.
      if (highRiskHits.isNotEmpty || hasShortener || hasSuspiciousTld) {
        reasons.add('Header looks TRAI-formatted (${matchedBank ?? entity}) BUT contains high-risk phrases.');
        for (final hit in highRiskHits.take(3)) {
          reasons.add('Suspicious phrase: "$hit"');
        }
        if (hasShortener) reasons.add('Contains a URL shortener.');
        if (hasSuspiciousTld) reasons.add('Contains a suspicious TLD (.xyz, .tk, etc.).');
        recommendations.addAll([
          'Even if the header looks correct, do not click links.',
          'Headers can be spoofed via SMSC tampering. Verify by calling your bank.',
          'Report to your bank\'s anti-fraud line.',
        ]);
        return FakeBankSmsReport(
          verdict: FakeBankSmsVerdict.suspicious,
          sender: senderClean,
          matchedBank: matchedBank,
          matchedHeader: entity,
          reasons: reasons,
          recommendations: recommendations,
        );
      }

      if (matchedBank != null) {
        return FakeBankSmsReport(
          verdict: FakeBankSmsVerdict.legitimate,
          sender: senderClean,
          matchedBank: matchedBank,
          matchedHeader: entity,
          reasons: ['Header matches the registered TRAI code for $matchedBank.'],
          recommendations: const [],
        );
      }

      // TRAI header but unknown entity — could be a small bank/fintech.
      return FakeBankSmsReport(
        verdict: FakeBankSmsVerdict.unverifiable,
        sender: senderClean,
        matchedHeader: entity,
        reasons: ['Header is TRAI-formatted but entity code "$entity" is not in our registry.'],
        recommendations: const [
          'Check whether this header belongs to a service you actually use.',
          'When in doubt, do not click links in the message.',
        ],
      );
    }

    // ── Path C: Short-code (e.g. 121, 567678, ICICI's 9215676766) ─────────
    if (_shortcode.hasMatch(senderClean)) {
      return FakeBankSmsReport(
        verdict: FakeBankSmsVerdict.unverifiable,
        sender: senderClean,
        reasons: const ['Sender is a short-code, often used by service providers.'],
        recommendations: const [
          'Short-codes are legitimate but can be leased by scammers.',
          'Cross-check by calling your bank directly.',
        ],
      );
    }

    // ── Path D: Anything else (alphanumeric with no dash, etc.) ───────────
    final upper = senderClean.toUpperCase();
    final knownMatch = _legitEntityCodes.keys.firstWhere(
      upper.contains,
      orElse: () => '',
    );
    if (knownMatch.isNotEmpty) {
      reasons.add(
        'Sender mentions "$knownMatch" but is not in TRAI header format.',
      );
      reasons.add('This is a classic header-spoofing pattern.');
      recommendations.addAll([
        'Do not click any link.',
        'Call your bank using the official number.',
      ]);
      return FakeBankSmsReport(
        verdict: FakeBankSmsVerdict.fake,
        sender: senderClean,
        matchedBank: _legitEntityCodes[knownMatch],
        reasons: reasons,
        recommendations: recommendations,
      );
    }

    return FakeBankSmsReport(
      verdict: FakeBankSmsVerdict.unverifiable,
      sender: senderClean,
      reasons: const ['Sender format is unrecognised.'],
      recommendations: mentionsBanking
          ? const ['Banking content from an unknown sender is suspicious. Verify with your bank.']
          : const [],
    );
  }
}

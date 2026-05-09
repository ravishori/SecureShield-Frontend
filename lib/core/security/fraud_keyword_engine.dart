/// Local fraud keyword detection engine.
///
/// Identifies scam-related keywords in SMS/messages without any network call.
/// Covers common Indian scams: KYC updates, digital arrests, customs parcels,
/// OTP verification, loan approvals, tax refunds, etc.
///
/// Supports English + Hindi (Devanagari) keywords.
library;

enum FraudCategory {
  kycUpdate,           // KYC/eKYC verification
  digitalArrest,       // Police/digital arrest scams
  customsParcel,       // Customs/parcel delivery scams
  otpVerification,     // OTP theft attempts
  loanApproval,        // Fake loan offers
  taxRefund,           // Income tax refund scams
  bankingAlert,        // Fake banking alerts
  inheritance,         // Nigerian prince / inheritance scams
  jobFraud,            // Fake job offers / data entry
  simSwap,             // SIM swap / phone theft alerts
  unknown,             // Unclassified
}

extension FraudCategoryExt on FraudCategory {
  String get label {
    switch (this) {
      case FraudCategory.kycUpdate: return 'KYC/eKYC Update';
      case FraudCategory.digitalArrest: return 'Digital Arrest';
      case FraudCategory.customsParcel: return 'Customs Parcel';
      case FraudCategory.otpVerification: return 'OTP Verification Scam';
      case FraudCategory.loanApproval: return 'Fake Loan Offer';
      case FraudCategory.taxRefund: return 'Tax Refund Scam';
      case FraudCategory.bankingAlert: return 'Fake Banking Alert';
      case FraudCategory.inheritance: return 'Inheritance/Prize Scam';
      case FraudCategory.jobFraud: return 'Job Fraud';
      case FraudCategory.simSwap: return 'SIM Swap Alert';
      case FraudCategory.unknown: return 'Suspicious Message';
    }
  }

  String get labelHi {
    switch (this) {
      case FraudCategory.kycUpdate: return 'केवाईसी/ईकेवाईसी अपडेट';
      case FraudCategory.digitalArrest: return 'डिजिटल गिरफ्तारी';
      case FraudCategory.customsParcel: return 'सीमा शुल्क पार्सल';
      case FraudCategory.otpVerification: return 'ओटीपी धोखाधड़ी';
      case FraudCategory.loanApproval: return 'नकली ऋण प्रस्ताव';
      case FraudCategory.taxRefund: return 'कर रिफंड घोटाला';
      case FraudCategory.bankingAlert: return 'नकली बैंकिंग सतर्कता';
      case FraudCategory.inheritance: return 'विरासत/पुरस्कार घोटाला';
      case FraudCategory.jobFraud: return 'नौकरी धोखाधड़ी';
      case FraudCategory.simSwap: return 'सिम स्वैप सतर्कता';
      case FraudCategory.unknown: return 'संदिग्ध संदेश';
    }
  }

  String get warningMessageEn {
    switch (this) {
      case FraudCategory.kycUpdate:
        return 'Banks never ask for OTP or passwords via SMS. Do not share these.';
      case FraudCategory.digitalArrest:
        return 'This is a common scam. Police never call about arrest via SMS. Ignore and report.';
      case FraudCategory.customsParcel:
        return 'Customs will not ask for payment via SMS. This is a scam.';
      case FraudCategory.otpVerification:
        return 'NEVER share your OTP with anyone. Banks/apps never ask for OTP.';
      case FraudCategory.loanApproval:
        return 'Unsolicited loan offers are scams. Do not click links or share details.';
      case FraudCategory.taxRefund:
        return 'Income tax refunds come via bank transfer, not SMS links. Be careful.';
      case FraudCategory.bankingAlert:
        return 'Verify alerts by calling your bank directly, not using numbers in SMS.';
      case FraudCategory.inheritance:
        return 'You cannot inherit money from strangers. This is always a scam.';
      case FraudCategory.jobFraud:
        return 'Fake job offers ask for personal info or upfront fees. Avoid these.';
      case FraudCategory.simSwap:
        return 'Never confirm SIM changes via SMS. Call your provider directly.';
      case FraudCategory.unknown:
        return 'Be cautious with unsolicited messages. Do not share sensitive info.';
    }
  }

  String get warningMessageHi {
    switch (this) {
      case FraudCategory.kycUpdate:
        return 'बैंक कभी एसएमएस के माध्यम से ओटीपी या पासवर्ड नहीं मांगते। इन्हें साझा न करें।';
      case FraudCategory.digitalArrest:
        return 'यह एक आम घोटाला है। पुलिस कभी एसएमएस के माध्यम से गिरफ्तारी के बारे में नहीं बोलती। अनदेखा करें और रिपोर्ट करें।';
      case FraudCategory.customsParcel:
        return 'सीमा शुल्क एसएमएस के माध्यम से भुगतान नहीं मांगेगा। यह एक घोटाला है।';
      case FraudCategory.otpVerification:
        return 'अपना ओटीपी किसी को साझा न करें। बैंक/ऐप्स कभी ओटीपी नहीं मांगते।';
      case FraudCategory.loanApproval:
        return 'बिना मांगे लिए गए ऋण प्रस्ताव घोटाले हैं। लिंक पर क्लिक न करें या विवरण साझा न करें।';
      case FraudCategory.taxRefund:
        return 'आयकर रिफंड बैंक हस्तांतरण के माध्यम से आता है, एसएमएस लिंक के माध्यम से नहीं।';
      case FraudCategory.bankingAlert:
        return 'सतर्कताओं को सीधे अपने बैंक को कॉल करके सत्यापित करें, एसएमएस में नंबरों का उपयोग न करें।';
      case FraudCategory.inheritance:
        return 'आप अजनबियों से पैसा विरासत में नहीं पा सकते। यह हमेशा एक घोटाला है।';
      case FraudCategory.jobFraud:
        return 'नकली नौकरी के प्रस्तावों में व्यक्तिगत जानकारी या अग्रिम शुल्क मांगा जाता है।';
      case FraudCategory.simSwap:
        return 'एसएमएस के माध्यम से सिम परिवर्तनों की पुष्टि न करें। सीधे अपने प्रदाता को कॉल करें।';
      case FraudCategory.unknown:
        return 'अनुरोधित संदेशों के साथ सावधान रहें। संवेदनशील जानकारी साझा न करें।';
    }
  }
}

class FraudAnalysis {
  final String messageText;
  final FraudCategory category;
  final double suspicionScore; // 0.0 to 1.0
  final List<String> matchedKeywords;

  const FraudAnalysis({
    required this.messageText,
    required this.category,
    required this.suspicionScore,
    required this.matchedKeywords,
  });

  bool get isSuspicious => suspicionScore >= 0.5;
}

class FraudKeywordEngine {
  FraudKeywordEngine._();

  // ── Keyword database (EN + HI) ─────────────────────────────────────────────

  static const Map<FraudCategory, List<String>> _keywordsEn = {
    FraudCategory.kycUpdate: [
      'kyc',
      'ekyc',
      'verification',
      'verify account',
      'update kyc',
      'aadhar',
      'pan card',
    ],
    FraudCategory.digitalArrest: [
      'digital arrest',
      'police',
      'arrest warrant',
      'complaint against you',
      'criminal case',
      'aadhaar blocked',
    ],
    FraudCategory.customsParcel: [
      'customs',
      'parcel',
      'delivery',
      'package held',
      'claim parcel',
      'customs clearance',
      'import duty',
    ],
    FraudCategory.otpVerification: [
      'verify otp',
      'confirm otp',
      'enter otp',
      'otp code',
      'otp expir',
      'verify code',
    ],
    FraudCategory.loanApproval: [
      'loan approv',
      'credit approv',
      'instant loan',
      'approve loan',
      'sanctioned loan',
      'get loan',
    ],
    FraudCategory.taxRefund: [
      'income tax',
      'tax refund',
      'itax refund',
      'refund pend',
      'claim refund',
      'tax return',
    ],
    FraudCategory.bankingAlert: [
      'bank alert',
      'suspicious transact',
      'unusual activity',
      'account compromis',
      'confirm transact',
    ],
    FraudCategory.inheritance: [
      'inherit',
      'unclaimed fund',
      'prize',
      'lottery',
      'claim reward',
      'relative died',
    ],
    FraudCategory.jobFraud: [
      'data entry',
      'work from home',
      'job offer',
      'recruitment',
      'hiring',
      'apply now',
    ],
    FraudCategory.simSwap: [
      'sim card',
      'sim swap',
      'new sim',
      'sim change',
      'number migrat',
      'port number',
    ],
  };

  static const Map<FraudCategory, List<String>> _keywordsHi = {
    FraudCategory.kycUpdate: [
      'केवाईसी',
      'ईकेवाईसी',
      'सत्यापन',
      'खाता अपडेट',
      'आधार',
      'पैन कार्ड',
      'जानकारी अपडेट',
    ],
    FraudCategory.digitalArrest: [
      'डिजिटल गिरफ्तारी',
      'पुलिस',
      'गिरफ्तारी पत्र',
      'आपके खिलाफ शिकायत',
      'अपराधिक मामला',
      'आधार ब्लॉक',
      'गिरफ्तार',
    ],
    FraudCategory.customsParcel: [
      'सीमा शुल्क',
      'पार्सल',
      'डिलीवरी',
      'पैकेज रोका',
      'पार्सल क्लेम',
      'सीमा शुल्क निकासी',
      'आयात शुल्क',
    ],
    FraudCategory.otpVerification: [
      'ओटीपी',
      'ओटीपी सत्यापन',
      'ओटीपी कोड',
      'ओटीपी साझा करें',
      'कोड डालें',
      'सत्यापन',
    ],
    FraudCategory.loanApproval: [
      'ऋण स्वीकृत',
      'ऋण मंजूरी',
      'तत्काल ऋण',
      'ऋण देना',
      'कर्ज',
      'साख मंजूरी',
    ],
    FraudCategory.taxRefund: [
      'आयकर',
      'टैक्स रिफंड',
      'रिफंड लंबित',
      'रिफंड क्लेम',
      'कर रिटर्न',
      'रिफंड राशि',
    ],
    FraudCategory.bankingAlert: [
      'बैंक सतर्कता',
      'संदिग्ध लेनदेन',
      'असामान्य गतिविधि',
      'खाता समझौता',
      'लेनदेन की पुष्टि करें',
    ],
    FraudCategory.inheritance: [
      'विरासत',
      'दावे की गई राशि',
      'पुरस्कार',
      'लॉटरी',
      'पारिश्रमिक दावा',
      'रिश्तेदार की मृत्यु',
    ],
    FraudCategory.jobFraud: [
      'डेटा प्रविष्टि',
      'घर से काम',
      'नौकरी का प्रस्ताव',
      'भर्ती',
      'नौकरी',
      'अभी आवेदन करें',
    ],
    FraudCategory.simSwap: [
      'सिम कार्ड',
      'सिम स्वैप',
      'नया सिम',
      'सिम बदलें',
      'नंबर माइग्रेट',
      'नंबर पोर्ट',
    ],
  };

  /// Analyze a message for fraud keywords.
  /// Returns analysis with category + suspicion score.
  static FraudAnalysis analyze(String messageText) {
    if (messageText.isEmpty) {
      return FraudAnalysis(
        messageText: messageText,
        category: FraudCategory.unknown,
        suspicionScore: 0.0,
        matchedKeywords: [],
      );
    }

    final lower = messageText.toLowerCase();

    // Calculate hits per category (both EN + HI)
    final scores = <FraudCategory, int>{};
    final allMatches = <String>{};

    for (final category in FraudCategory.values) {
      if (category == FraudCategory.unknown) continue;

      final enKeywords = _keywordsEn[category] ?? [];
      final hiKeywords = _keywordsHi[category] ?? [];
      int hits = 0;

      for (final kw in enKeywords) {
        if (lower.contains(kw)) {
          hits++;
          allMatches.add(kw);
        }
      }

      // HI keywords need broader space-aware matching (Devanagari)
      for (final kw in hiKeywords) {
        if (messageText.contains(kw)) {
          hits++;
          allMatches.add(kw);
        }
      }

      if (hits > 0) scores[category] = hits;
    }

    if (scores.isEmpty) {
      return FraudAnalysis(
        messageText: messageText,
        category: FraudCategory.unknown,
        suspicionScore: 0.0,
        matchedKeywords: [],
      );
    }

    // Highest-scoring category wins
    final winningCategory = scores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Suspicion score: normalized by category keyword count
    final categoryKeywordCount = ((_keywordsEn[winningCategory] ?? []).length +
            (_keywordsHi[winningCategory] ?? []).length)
        .toDouble();
    final hitCount = (scores[winningCategory] ?? 0).toDouble();
    final normalizedScore = hitCount / categoryKeywordCount;

    return FraudAnalysis(
      messageText: messageText,
      category: winningCategory,
      suspicionScore: normalizedScore.clamp(0.0, 1.0),
      matchedKeywords: allMatches.toList(),
    );
  }
}

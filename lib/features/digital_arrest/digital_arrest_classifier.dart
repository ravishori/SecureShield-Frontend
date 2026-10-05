/// Digital Arrest Scam Classifier
///
/// India's #1 scam by losses in 2024 (₹2,140 crore). Fraudsters impersonate
/// CBI/Police/Customs/Narcotics officers over Skype or WhatsApp video calls,
/// claim the victim is implicated in a serious crime (drug parcel, money
/// laundering, Aadhaar misuse) and pressure them not to disconnect — a
/// "digital arrest" — until they transfer money for "case closure".
///
/// This classifier inspects any text snippet (SMS, WhatsApp transcript,
/// pasted message, call subtitle) and returns a verdict.
///
/// Detection is multilingual (English + Hindi + Marathi + Tamil + Telugu +
/// Bengali keywords) and uses a weighted scoring model — single matches are
/// "suspicious", multi-vector matches are "likely scam".
library;

enum DigitalArrestVerdict {
  safe,
  suspicious,
  likely,
  critical,
}

class DigitalArrestSignal {
  final String code;
  final String label;
  final String matchedPhrase;
  final int weight;
  const DigitalArrestSignal({
    required this.code,
    required this.label,
    required this.matchedPhrase,
    required this.weight,
  });
}

class DigitalArrestReport {
  final DigitalArrestVerdict verdict;
  final int totalScore;
  final List<DigitalArrestSignal> signals;
  final String headline;
  final String advice;

  const DigitalArrestReport({
    required this.verdict,
    required this.totalScore,
    required this.signals,
    required this.headline,
    required this.advice,
  });

  bool get isAlertable => verdict != DigitalArrestVerdict.safe;
}

class DigitalArrestClassifier {
  // ── Tier-1 signals (very strong, weight 5 each) ─────────────────────────
  // These phrases are pathognomonic — almost exclusively used by scammers.
  static const Map<String, String> _tier1 = {
    'digital arrest': 'Direct use of the term "digital arrest"',
    'do not disconnect': 'Pressure to remain on the call',
    'don\'t disconnect': 'Pressure to remain on the call',
    'cannot disconnect': 'Pressure to remain on the call',
    'house arrest': 'Threat of house arrest by phone',
    'skype call.*cbi': 'CBI claims via Skype (CBI never uses Skype)',
    'whatsapp.*video call.*police': 'Police claims via WhatsApp (police never use WhatsApp)',
    'arrest warrant.*video': 'Arrest warrant served over video',
    'fedex parcel.*drugs': 'Fake FedEx drug-parcel allegation',
    'parcel.*narcotics': 'Fake narcotics-parcel allegation',
    'aadhaar.*money laundering': 'Fake Aadhaar/money-laundering link',
    // Hindi
    'डिजिटल अरेस्ट': 'Direct use of "digital arrest" (Hindi)',
    'डिजिटल गिरफ्तारी': 'Direct use of "digital arrest" (Hindi)',
    'फोन मत काटो': 'Pressure to remain on the call (Hindi)',
    'सीबीआई.*स्काइप': 'CBI claims via Skype (Hindi)',
    // Marathi
    'फोन ठेवू नका': 'Pressure to remain on the call (Marathi)',
    'सीबीआय.*स्काईप': 'CBI claims via Skype (Marathi)',
  };

  // ── Tier-2 signals (strong, weight 3 each) ──────────────────────────────
  static const Map<String, String> _tier2 = {
    'cbi inquiry': 'CBI inquiry claim',
    'cbi case': 'CBI case claim',
    'mumbai cyber police': 'Mumbai cyber police impersonation',
    'mumbai crime branch': 'Mumbai crime branch impersonation',
    'crime branch': 'Crime branch impersonation',
    'narcotics control bureau': 'NCB impersonation',
    'enforcement directorate': 'ED impersonation',
    'ed officer': 'ED impersonation',
    'customs department': 'Customs impersonation',
    'customs official': 'Customs impersonation',
    'fir against you': 'Fake FIR threat',
    'case registered against you': 'Fake case-registration claim',
    'arrest warrant': 'Arrest warrant threat',
    'non-bailable warrant': 'NBW threat',
    'money laundering case': 'Money-laundering allegation',
    'human trafficking': 'Human-trafficking allegation',
    // Hindi
    'सीबीआई जांच': 'CBI inquiry claim (Hindi)',
    'गिरफ्तारी वारंट': 'Arrest warrant threat (Hindi)',
    'मनी लॉन्ड्रिंग': 'Money-laundering allegation (Hindi)',
    'अरेस्ट वारंट': 'Arrest warrant threat (Hindi)',
    'जेल भेज देंगे': 'Threat of jail (Hindi)',
    'फर्जी एफआईआर': 'Fake FIR mention (Hindi)',
    // Marathi
    'अटक वॉरंट': 'Arrest warrant threat (Marathi)',
    // Bengali
    'সিবিআই তদন্ত': 'CBI inquiry claim (Bengali)',
    // Tamil
    'சிபிஐ விசாரணை': 'CBI inquiry claim (Tamil)',
    // Telugu
    'సిబిఐ విచారణ': 'CBI inquiry claim (Telugu)',
  };

  // ── Tier-3 signals (corroborating, weight 1 each) ───────────────────────
  static const Map<String, String> _tier3 = {
    'fedex': 'FedEx mention (common in parcel scams)',
    'dhl parcel': 'DHL mention (common in parcel scams)',
    'illegal goods': 'Illegal-goods allegation',
    'drugs were found': 'Drugs-found allegation',
    'your aadhaar': 'Aadhaar misuse claim',
    'your pan card': 'PAN misuse claim',
    'verification fee': 'Verification fee request',
    'refundable deposit': 'Refundable deposit request',
    'rti number': 'Fake RTI reference',
    'case number': 'Case number mention',
    'rbi guideline': 'Fake RBI guideline reference',
    'maharashtra police': 'State police impersonation',
    'delhi police': 'State police impersonation',
    'transfer.*rbi account': 'Transfer to fake RBI account',
    'transfer.*verification': 'Transfer for verification (always a scam)',
    'video call.*officer': 'Video call from "officer"',
    'badge number': 'Display of fake badge number',
    'inspector general': 'Senior officer impersonation',
    'commissioner of police': 'Senior officer impersonation',
    // Hindi
    'सत्यापन शुल्क': 'Verification fee request (Hindi)',
    'आधार दुरुपयोग': 'Aadhaar misuse claim (Hindi)',
    'पुलिस अधिकारी': 'Police officer mention (Hindi)',
    'दिल्ली पुलिस': 'Delhi police impersonation (Hindi)',
    // Marathi
    'मुंबई पोलीस': 'Mumbai police impersonation (Marathi)',
  };

  static DigitalArrestReport analyze(String text) {
    if (text.trim().isEmpty) {
      return const DigitalArrestReport(
        verdict: DigitalArrestVerdict.safe,
        totalScore: 0,
        signals: [],
        headline: '',
        advice: '',
      );
    }

    final lower = text.toLowerCase();
    final signals = <DigitalArrestSignal>[];
    var score = 0;

    void scan(Map<String, String> patterns, int weight, String tier) {
      for (final entry in patterns.entries) {
        final pat = entry.key;
        final label = entry.value;
        try {
          final regex = RegExp(pat, caseSensitive: false, multiLine: true);
          final match = regex.firstMatch(lower);
          if (match != null) {
            signals.add(DigitalArrestSignal(
              code: '${tier}_${signals.length}',
              label: label,
              matchedPhrase: match.group(0) ?? pat,
              weight: weight,
            ));
            score += weight;
          }
        } catch (_) {
          if (lower.contains(pat)) {
            signals.add(DigitalArrestSignal(
              code: '${tier}_${signals.length}',
              label: label,
              matchedPhrase: pat,
              weight: weight,
            ));
            score += weight;
          }
        }
      }
    }

    scan(_tier1, 5, 'T1');
    scan(_tier2, 3, 'T2');
    scan(_tier3, 1, 'T3');

    // Verdict bands
    final verdict = _classify(score, signals);
    return DigitalArrestReport(
      verdict: verdict,
      totalScore: score,
      signals: signals,
      headline: _headline(verdict),
      advice: _advice(verdict),
    );
  }

  static DigitalArrestVerdict _classify(int score, List<DigitalArrestSignal> sigs) {
    final tier1Hits = sigs.where((s) => s.weight == 5).length;
    if (tier1Hits >= 2 || score >= 10) return DigitalArrestVerdict.critical;
    if (tier1Hits >= 1 || score >= 6) return DigitalArrestVerdict.likely;
    if (score >= 3) return DigitalArrestVerdict.suspicious;
    return DigitalArrestVerdict.safe;
  }

  static String _headline(DigitalArrestVerdict v) {
    switch (v) {
      case DigitalArrestVerdict.critical:
        return 'DIGITAL ARREST SCAM — HANG UP NOW';
      case DigitalArrestVerdict.likely:
        return 'Highly likely digital-arrest scam';
      case DigitalArrestVerdict.suspicious:
        return 'Suspicious — possible digital-arrest scam';
      case DigitalArrestVerdict.safe:
        return 'No digital-arrest indicators found';
    }
  }

  static String _advice(DigitalArrestVerdict v) {
    switch (v) {
      case DigitalArrestVerdict.critical:
      case DigitalArrestVerdict.likely:
        return 'Disconnect immediately. The CBI, Police, Customs and ED NEVER call '
            'over WhatsApp, Skype or video. NEVER pay or transfer money to '
            '"prove your innocence". Report on 1930 (cyber-crime helpline) or '
            'cybercrime.gov.in. Do not share your screen, OTP, or bank details.';
      case DigitalArrestVerdict.suspicious:
        return 'Several red-flag phrases were detected. Verify the caller through '
            'an official channel BEFORE responding. Call 1930 to verify any '
            'claim of investigation against you. Real officers issue notices '
            'in person, never by video call.';
      case DigitalArrestVerdict.safe:
        return 'No clear scam indicators. Still, remember: no Indian government '
            'agency arrests people over a phone or video call.';
    }
  }
}

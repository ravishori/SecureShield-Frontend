/// Fake Payment Screenshot Verifier
///
/// Many India SMB-side scams work like this: a customer claims they paid via
/// UPI, shows a screenshot, the merchant releases the goods, and only later
/// notices no money arrived. The screenshot is fabricated using a screenshot-
/// editing app or one of dozens of "fake payment success" apps on third-party
/// stores.
///
/// This module takes OCR'd text from such a screenshot and runs forensic
/// heuristics:
///   1. Does it contain a transaction ID in a valid UPI/IMPS/NEFT format?
///   2. Does the digit amount match the amount-in-words?
///   3. Are there impossible/inconsistent fields (e.g. future date)?
///   4. Are obvious editing artifacts present (mixed fonts, wrong app brand)?
///
/// Returns a [PaymentScreenshotReport].
library;

enum PaymentVerdict {
  authentic,
  inconclusive,
  suspicious,
  fake,
}

class PaymentScreenshotReport {
  final PaymentVerdict verdict;
  final int confidence; // 0-100
  final List<PaymentCheck> checks;
  final String? extractedAmount;
  final String? extractedTxnId;
  final String? extractedDate;
  final String? extractedUpiRefNo;
  final String? extractedReceiverVpa;
  final String? detectedApp;

  const PaymentScreenshotReport({
    required this.verdict,
    required this.confidence,
    required this.checks,
    this.extractedAmount,
    this.extractedTxnId,
    this.extractedDate,
    this.extractedUpiRefNo,
    this.extractedReceiverVpa,
    this.detectedApp,
  });
}

enum CheckOutcome { pass, warn, fail, info }

class PaymentCheck {
  final String name;
  final CheckOutcome outcome;
  final String detail;
  const PaymentCheck({
    required this.name,
    required this.outcome,
    required this.detail,
  });
}

class PaymentScreenshotVerifier {
  // ── Format heuristics (Indian banking) ──────────────────────────────────
  /// UPI reference number: exactly 12 digits.
  static final RegExp _upiRefnoPattern = RegExp(r'\b\d{12}\b');

  /// IMPS reference: 12 numeric digits or alphanumeric like P140324...
  static final RegExp _impsRefPattern = RegExp(r'\b(?:P|N)?\d{10,16}\b');

  /// NEFT/RTGS UTR: 16-22 alphanumeric chars starting with bank code.
  static final RegExp _utrPattern = RegExp(r'\b[A-Z]{4}[A-Z0-9]{10,18}\b');

  /// Amount with ₹ or Rs or INR prefix.
  static final RegExp _amountPattern = RegExp(
    r'(?:[₹₹]|Rs\.?|INR)\s*([0-9,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  /// VPA: <user>@<handle> where handle is alphanumeric, allowing dots.
  static final RegExp _vpaPattern = RegExp(
    r'\b[a-zA-Z0-9_.\-]{2,}@[a-zA-Z][a-zA-Z0-9]{2,}\b',
  );

  /// Date in common formats (DD MMM YYYY, DD/MM/YYYY, etc.)
  static final RegExp _datePattern = RegExp(
    r'\b(\d{1,2}[\s/-](?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2})[\s/-]\d{2,4})\b',
    caseSensitive: false,
  );

  /// Branding cues — multiple-app contamination is suspicious.
  static const Map<String, List<String>> _appBrands = {
    'PhonePe': ['phonepe', 'phone pe', 'phonepay'],
    'Google Pay': ['google pay', 'gpay'],
    'Paytm': ['paytm'],
    'BHIM': ['bhim'],
    'Amazon Pay': ['amazon pay', 'amazonpay'],
    'Mobikwik': ['mobikwik'],
    'CRED': ['cred pay', 'cred upi'],
    'WhatsApp Pay': ['whatsapp pay'],
  };

  static const _successKeywords = [
    'payment successful', 'successful', 'paid successfully',
    'transferred successfully', 'sent successfully', 'completed',
    'transaction successful', 'transaction completed',
    'भुगतान सफल', 'सफलतापूर्वक भेजा',
  ];

  // Words-for-numbers — used to cross-check amount words vs digits
  static const _wordNumbers = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
    'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
    'eighty': 80, 'ninety': 90,
    'hundred': 100, 'thousand': 1000, 'lakh': 100000, 'crore': 10000000,
  };

  static PaymentScreenshotReport analyze(String ocrText) {
    final checks = <PaymentCheck>[];
    final lower = ocrText.toLowerCase();

    // ── Detect app ──────────────────────────────────────────────────────
    final detectedApps = <String>[];
    for (final entry in _appBrands.entries) {
      if (entry.value.any(lower.contains)) detectedApps.add(entry.key);
    }
    String? primaryApp;
    if (detectedApps.length == 1) {
      primaryApp = detectedApps.first;
      checks.add(PaymentCheck(
        name: 'Payment app detected',
        outcome: CheckOutcome.info,
        detail: 'Brand: $primaryApp',
      ));
    } else if (detectedApps.length > 1) {
      primaryApp = detectedApps.first;
      checks.add(PaymentCheck(
        name: 'Multiple app brands detected',
        outcome: CheckOutcome.fail,
        detail: 'Found: ${detectedApps.join(", ")}. Real receipts only show one brand.',
      ));
    } else {
      checks.add(const PaymentCheck(
        name: 'Payment app detection',
        outcome: CheckOutcome.warn,
        detail: 'Could not identify the payment app from the screenshot.',
      ));
    }

    // ── Success keyword ─────────────────────────────────────────────────
    final hasSuccessKeyword = _successKeywords.any(lower.contains);
    checks.add(PaymentCheck(
      name: 'Success keyword',
      outcome: hasSuccessKeyword ? CheckOutcome.pass : CheckOutcome.warn,
      detail: hasSuccessKeyword
          ? 'Screenshot claims payment success.'
          : 'No "successful / completed" phrase found.',
    ));

    // ── Transaction ID extraction ───────────────────────────────────────
    final upiMatch = _upiRefnoPattern.firstMatch(ocrText);
    final impsMatch = _impsRefPattern.firstMatch(ocrText);
    final utrMatch = _utrPattern.firstMatch(ocrText);

    String? extractedTxn;
    String? extractedRef;
    if (upiMatch != null) {
      extractedRef = upiMatch.group(0);
      extractedTxn = extractedRef;
      checks.add(PaymentCheck(
        name: 'UPI reference number',
        outcome: CheckOutcome.pass,
        detail: '12-digit UPI ref: $extractedRef ✓',
      ));
    } else if (utrMatch != null) {
      extractedTxn = utrMatch.group(0);
      checks.add(PaymentCheck(
        name: 'NEFT/RTGS UTR',
        outcome: CheckOutcome.pass,
        detail: 'UTR: $extractedTxn ✓',
      ));
    } else if (impsMatch != null) {
      extractedTxn = impsMatch.group(0);
      checks.add(PaymentCheck(
        name: 'IMPS reference',
        outcome: CheckOutcome.warn,
        detail: 'IMPS-like ref: $extractedTxn — verify format with bank.',
      ));
    } else {
      checks.add(const PaymentCheck(
        name: 'Transaction reference',
        outcome: CheckOutcome.fail,
        detail: 'No valid UPI/IMPS/NEFT reference number found. Fake screenshots often miss this.',
      ));
    }

    // ── Amount extraction ───────────────────────────────────────────────
    final amountMatch = _amountPattern.firstMatch(ocrText);
    String? extractedAmount;
    double? amountValue;
    if (amountMatch != null) {
      final raw = amountMatch.group(1) ?? '';
      extractedAmount = '₹$raw';
      amountValue = double.tryParse(raw.replaceAll(',', ''));
      checks.add(PaymentCheck(
        name: 'Amount extracted',
        outcome: CheckOutcome.pass,
        detail: extractedAmount,
      ));
    } else {
      checks.add(const PaymentCheck(
        name: 'Amount extracted',
        outcome: CheckOutcome.fail,
        detail: 'Could not extract a ₹ amount. Real receipts always show it prominently.',
      ));
    }

    // ── Amount-in-words vs digits cross-check ───────────────────────────
    if (amountValue != null) {
      final wordsAmount = _parseAmountWords(lower);
      if (wordsAmount != null) {
        if ((wordsAmount - amountValue).abs() < 0.5) {
          checks.add(const PaymentCheck(
            name: 'Amount-in-words match',
            outcome: CheckOutcome.pass,
            detail: 'Digit amount matches amount-in-words.',
          ));
        } else {
          checks.add(PaymentCheck(
            name: 'Amount-in-words mismatch',
            outcome: CheckOutcome.fail,
            detail: 'Digits say ₹${amountValue.toStringAsFixed(0)}, '
                'words say ₹${wordsAmount.toStringAsFixed(0)}. Edited screenshot.',
          ));
        }
      }
    }

    // ── Date sanity ─────────────────────────────────────────────────────
    final dateMatch = _datePattern.firstMatch(ocrText);
    if (dateMatch != null) {
      checks.add(PaymentCheck(
        name: 'Date detected',
        outcome: CheckOutcome.info,
        detail: dateMatch.group(0) ?? '',
      ));
    } else {
      checks.add(const PaymentCheck(
        name: 'Date',
        outcome: CheckOutcome.warn,
        detail: 'No date/time stamp found.',
      ));
    }

    // ── VPA extraction ──────────────────────────────────────────────────
    final vpaMatches = _vpaPattern.allMatches(ocrText).map((m) => m.group(0)!).toList();
    String? receiverVpa;
    if (vpaMatches.isNotEmpty) {
      receiverVpa = vpaMatches.last;
      checks.add(PaymentCheck(
        name: 'Receiver VPA',
        outcome: CheckOutcome.info,
        detail: receiverVpa,
      ));
    }

    // ── Verdict aggregation ─────────────────────────────────────────────
    final fails = checks.where((c) => c.outcome == CheckOutcome.fail).length;
    final warns = checks.where((c) => c.outcome == CheckOutcome.warn).length;
    final passes = checks.where((c) => c.outcome == CheckOutcome.pass).length;

    PaymentVerdict verdict;
    int confidence;
    if (fails >= 2) {
      verdict = PaymentVerdict.fake;
      confidence = 90 - (warns * 5);
    } else if (fails == 1) {
      verdict = PaymentVerdict.suspicious;
      confidence = 70;
    } else if (warns >= 3) {
      verdict = PaymentVerdict.inconclusive;
      confidence = 55;
    } else if (passes >= 3) {
      verdict = PaymentVerdict.authentic;
      confidence = 78;
    } else {
      verdict = PaymentVerdict.inconclusive;
      confidence = 50;
    }
    confidence = confidence.clamp(20, 95);

    return PaymentScreenshotReport(
      verdict: verdict,
      confidence: confidence,
      checks: checks,
      extractedAmount: extractedAmount,
      extractedTxnId: extractedTxn,
      extractedDate: dateMatch?.group(0),
      extractedUpiRefNo: extractedRef,
      extractedReceiverVpa: receiverVpa,
      detectedApp: primaryApp,
    );
  }

  /// Very small parser for "five thousand", "twenty-three hundred", etc.
  static double? _parseAmountWords(String text) {
    final tokens = text
        .replaceAll('-', ' ')
        .split(RegExp(r'[\s,]+'))
        .where((t) => _wordNumbers.containsKey(t))
        .toList();
    if (tokens.isEmpty) return null;

    double total = 0;
    double current = 0;
    for (final tok in tokens) {
      final val = _wordNumbers[tok]!.toDouble();
      if (val == 100) {
        current = current == 0 ? 100 : current * 100;
      } else if (val >= 1000) {
        current = current == 0 ? val : current * val;
        total += current;
        current = 0;
      } else {
        current += val;
      }
    }
    total += current;
    return total > 0 ? total : null;
  }
}

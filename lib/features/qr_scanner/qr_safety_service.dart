/// QR Safety Service
///
/// Classifies QR payloads and returns a verdict. Routes:
///   - UPI URIs   → VPA suffix check + amount sanity
///   - URLs       → caller should pipe into the existing Link Scanner
///   - Phone/SMS  → light heuristics
///   - Wi-Fi etc. → flagged as untrusted by default
library;

enum QrPayloadKind {
  upi,
  url,
  phone,
  sms,
  wifi,
  text,
  unknown,
}

enum QrSafetyVerdict {
  safe,
  caution,
  danger,
  unknown,
}

class QrSafetyReport {
  final QrPayloadKind kind;
  final QrSafetyVerdict verdict;
  final String headline;
  final List<String> reasons;
  final Map<String, String> extracted;
  final String? routeForFurtherCheck;

  const QrSafetyReport({
    required this.kind,
    required this.verdict,
    required this.headline,
    required this.reasons,
    required this.extracted,
    this.routeForFurtherCheck,
  });
}

class QrSafetyService {
  /// VPA suffixes belonging to NPCI-licensed banks/PSPs.
  /// A VPA `user@<suffix>` is legitimate only if <suffix> is in this set.
  static const _legitVpaSuffixes = {
    // Big banks
    'oksbi', 'okhdfcbank', 'okicici', 'okaxis', 'okkotak', 'okindianbank',
    'okfederalbank', 'okkbank', 'okyesbank', 'okidfcfirst',
    'hdfcbank', 'icici', 'icicibank', 'axisbank', 'kotak', 'kotakbank',
    'sbi', 'sbiup', 'sbigroup', 'pnb', 'unionbank', 'cnrb', 'canarabank',
    'idfcbank', 'idfcfirst', 'yesbank', 'yesg', 'federal', 'rbl',
    // PSPs
    'paytm', 'ybl', 'okhdfc', 'jio', 'ibl', 'apl', 'axl', 'upi',
    'pingpay', 'phonepe', 'gpay', 'amzpay', 'amazonpay', 'amazon',
    'mobikwik', 'freecharge', 'fbl',
    // Government / public
    'gov', 'gov.in', 'rbi', 'nic', 'rbihdfc', 'rbisbi',
  };

  /// Known phishing handles seen in the wild.
  static const _knownScamVpaSuffixes = {
    'paytm-pay', 'paytm-bank', 'okpaytm', 'phonepe-pay', 'gpay-pay',
  };

  static QrSafetyReport analyze(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      return const QrSafetyReport(
        kind: QrPayloadKind.unknown,
        verdict: QrSafetyVerdict.unknown,
        headline: 'Empty QR',
        reasons: ['QR contained no data.'],
        extracted: {},
      );
    }

    final lower = trimmed.toLowerCase();

    if (lower.startsWith('upi://')) return _analyzeUpi(trimmed);
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return _analyzeUrl(trimmed);
    }
    if (lower.startsWith('tel:')) return _analyzePhone(trimmed);
    if (lower.startsWith('sms:') || lower.startsWith('smsto:')) {
      return _analyzeSms(trimmed);
    }
    if (lower.startsWith('wifi:')) return _analyzeWifi(trimmed);

    // Plain text — often used to phish QR users
    return QrSafetyReport(
      kind: QrPayloadKind.text,
      verdict: QrSafetyVerdict.caution,
      headline: 'Plain text — verify before acting',
      reasons: const [
        'QR contains plain text — could be safe but cannot be auto-verified.',
      ],
      extracted: {'text': trimmed},
    );
  }

  static QrSafetyReport _analyzeUpi(String payload) {
    final reasons = <String>[];
    final extracted = <String, String>{};
    QrSafetyVerdict verdict = QrSafetyVerdict.safe;

    try {
      final uri = Uri.parse(payload);
      final params = uri.queryParameters;

      final vpa = params['pa'] ?? '';
      final payee = params['pn'] ?? '';
      final amount = params['am'] ?? '';
      final currency = params['cu'] ?? 'INR';

      extracted['vpa'] = vpa;
      if (payee.isNotEmpty) extracted['payee'] = Uri.decodeComponent(payee);
      if (amount.isNotEmpty) extracted['amount'] = '$currency $amount';

      if (vpa.isEmpty) {
        return const QrSafetyReport(
          kind: QrPayloadKind.upi,
          verdict: QrSafetyVerdict.danger,
          headline: 'Invalid UPI — no payee address',
          reasons: ['UPI URI has no `pa` (payee address). Do not pay.'],
          extracted: {},
        );
      }

      final suffix = vpa.contains('@') ? vpa.split('@').last.toLowerCase() : '';

      if (_knownScamVpaSuffixes.contains(suffix)) {
        return QrSafetyReport(
          kind: QrPayloadKind.upi,
          verdict: QrSafetyVerdict.danger,
          headline: 'Known scam VPA pattern',
          reasons: ['VPA suffix "$suffix" is a known impersonation pattern. Do not pay.'],
          extracted: extracted,
        );
      }

      if (!_legitVpaSuffixes.contains(suffix)) {
        reasons.add(
          'VPA suffix "$suffix" is not on our list of NPCI-registered handles. '
          'Verify with the merchant before paying.',
        );
        verdict = QrSafetyVerdict.caution;
      }

      // Amount sanity — > ₹1,00,000 in QR is unusual for personal transfers
      final amtVal = double.tryParse(amount);
      if (amtVal != null && amtVal >= 100000) {
        reasons.add('Pre-filled amount is ₹${amtVal.toStringAsFixed(0)} — large QR amounts are unusual.');
        if (verdict == QrSafetyVerdict.safe) verdict = QrSafetyVerdict.caution;
      }

      // Merchant-name mismatch with VPA (e.g. payee says "HDFC Bank" but VPA is @okpaytm)
      if (payee.isNotEmpty) {
        final payeeLower = Uri.decodeComponent(payee).toLowerCase();
        final suspiciousBrand = ['hdfc', 'sbi', 'icici', 'axis', 'rbi', 'income tax', 'gst'];
        for (final brand in suspiciousBrand) {
          if (payeeLower.contains(brand) && !suffix.contains(brand) && !suffix.startsWith('ok')) {
            reasons.add(
              'Payee name claims "$brand" but VPA suffix "@$suffix" doesn\'t match. '
              'Likely impersonation.',
            );
            verdict = QrSafetyVerdict.danger;
            break;
          }
        }
      }

      if (verdict == QrSafetyVerdict.safe) {
        reasons.add('VPA suffix is recognised. Always re-check the payee name before paying.');
      }

      return QrSafetyReport(
        kind: QrPayloadKind.upi,
        verdict: verdict,
        headline: _upiHeadline(verdict),
        reasons: reasons,
        extracted: extracted,
      );
    } catch (e) {
      return QrSafetyReport(
        kind: QrPayloadKind.upi,
        verdict: QrSafetyVerdict.danger,
        headline: 'Malformed UPI URI',
        reasons: ['Could not parse QR as a valid UPI URI: $e'],
        extracted: const {},
      );
    }
  }

  static QrSafetyReport _analyzeUrl(String payload) {
    final extracted = <String, String>{'url': payload};
    final lower = payload.toLowerCase();
    final reasons = <String>[];
    QrSafetyVerdict verdict = QrSafetyVerdict.caution;

    if (RegExp(r'(bit\.ly|tinyurl|t\.co|goo\.gl|cutt\.ly|rb\.gy)').hasMatch(lower)) {
      reasons.add('URL is a shortener — destination hidden.');
      verdict = QrSafetyVerdict.danger;
    }
    if (RegExp(r'\.(xyz|tk|ml|ga|cf|top|click|loan|review)\b').hasMatch(lower)) {
      reasons.add('Suspicious TLD detected.');
      verdict = QrSafetyVerdict.danger;
    }
    if (lower.startsWith('http://')) {
      reasons.add('URL uses HTTP, not HTTPS — traffic not encrypted.');
      if (verdict == QrSafetyVerdict.caution) verdict = QrSafetyVerdict.danger;
    }
    if (reasons.isEmpty) {
      reasons.add('Tap "Run full URL scan" to verify against Google Safe Browsing + URLhaus.');
    }

    return QrSafetyReport(
      kind: QrPayloadKind.url,
      verdict: verdict,
      headline: verdict == QrSafetyVerdict.danger ? 'Risky link' : 'Verify the link before opening',
      reasons: reasons,
      extracted: extracted,
      routeForFurtherCheck: '/link-scanner',
    );
  }

  static QrSafetyReport _analyzePhone(String payload) {
    final number = payload.replaceFirst('tel:', '').trim();
    return QrSafetyReport(
      kind: QrPayloadKind.phone,
      verdict: QrSafetyVerdict.caution,
      headline: 'Phone call QR',
      reasons: const [
        'QR will trigger a phone call. Verify the number before calling — scam QRs route to premium-rate or fraud numbers.',
      ],
      extracted: {'number': number},
    );
  }

  static QrSafetyReport _analyzeSms(String payload) {
    return QrSafetyReport(
      kind: QrPayloadKind.sms,
      verdict: QrSafetyVerdict.caution,
      headline: 'SMS QR',
      reasons: const [
        'QR will send an SMS. Scam QRs use this to trigger premium-rate texts. Verify before sending.',
      ],
      extracted: {'payload': payload},
    );
  }

  static QrSafetyReport _analyzeWifi(String payload) {
    return QrSafetyReport(
      kind: QrPayloadKind.wifi,
      verdict: QrSafetyVerdict.caution,
      headline: 'Wi-Fi join QR',
      reasons: const [
        'QR will join a Wi-Fi network. Public Wi-Fi can be used for MITM attacks.',
        'Do not join unless you trust the operator.',
      ],
      extracted: {'payload': payload},
    );
  }

  static String _upiHeadline(QrSafetyVerdict v) {
    switch (v) {
      case QrSafetyVerdict.safe:
        return 'UPI QR — recognised handle';
      case QrSafetyVerdict.caution:
        return 'UPI QR — verify before paying';
      case QrSafetyVerdict.danger:
        return 'UPI QR — high risk, do not pay';
      case QrSafetyVerdict.unknown:
        return 'UPI QR — unverifiable';
    }
  }
}

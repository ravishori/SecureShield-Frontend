/// Local, offline detection of likely secrets in text the user is about to send. Nothing here sends, stores or logs text.
///
/// Heuristic and incomplete by nature. It only flags a secret VALUE (a code, number or word after a cue); merely mentioning
/// "OTP" in a scam message is normal and is not flagged.
library;

enum SensitiveKind { otp, pin, password, cvv, card, aadhaar, account }

class SensitiveSpan {
  final int start;
  final int end; // exclusive
  final SensitiveKind kind;
  const SensitiveSpan(this.start, this.end, this.kind);
}

const maskToken = '****';

final _otp = RegExp(r'(?:otp|one[\s-]?time|verification\s*code|security\s*code|passcode)\D{0,25}?(\d{4,8})\b', caseSensitive: false);
final _otpAfter = RegExp(r'\b(\d{4,8})\b\D{0,12}?(?:is\s+(?:your|the)\s+)?(?:otp|one[\s-]?time|verification\s*code)', caseSensitive: false);
final _pin = RegExp(r'(?:upi\s*pin|m-?pin|atm\s*pin|\bpin\b)\W{0,12}?(?:is\W{0,6})?(\d{4,6})\b', caseSensitive: false);
final _password = RegExp(r'(?:password|passcode|pwd|pass\s*word)\s*(?:is|[:=])\s*(\S+)', caseSensitive: false);
final _cvv = RegExp(r'(?:cvv2?|cvc)\W{0,8}?(\d{3,4})\b', caseSensitive: false);
final _cardLike = RegExp(r'(?<![\d-])(?:\d[ -]?){12,18}\d(?![\d-])');
final _aadhaar = RegExp(r'(?<!\d)\d{4}[ -]\d{4}[ -]\d{4}(?!\d)|(?<!\d)\d{12}(?!\d)');
final _account = RegExp(r'(?:account|a/c|acct?\b)\D{0,15}?(\d{9,18})\b', caseSensitive: false);

bool _luhn(String digits) {
  if (digits.length < 13 || digits.length > 19) return false;
  var sum = 0;
  var alt = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var n = digits.codeUnitAt(i) - 48;
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}

/// All sensitive spans in [text], merged and sorted. Empty when nothing looks sensitive.
List<SensitiveSpan> findSensitiveSpans(String text) {
  final spans = <SensitiveSpan>[];
  void group(RegExp re, SensitiveKind k) {
    for (final m in re.allMatches(text)) {
      final g = m.groupCount >= 1 ? m.group(1) : m.group(0);
      if (g == null || g.isEmpty) continue;
      final start = m.start + m.group(0)!.lastIndexOf(g);
      spans.add(SensitiveSpan(start, start + g.length, k));
    }
  }

  group(_otp, SensitiveKind.otp);
  group(_otpAfter, SensitiveKind.otp);
  group(_pin, SensitiveKind.pin);
  group(_password, SensitiveKind.password);
  group(_cvv, SensitiveKind.cvv);
  group(_account, SensitiveKind.account);
  for (final m in _cardLike.allMatches(text)) {
    final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (_luhn(digits)) spans.add(SensitiveSpan(m.start, m.end, SensitiveKind.card));
  }
  for (final m in _aadhaar.allMatches(text)) {
    spans.add(SensitiveSpan(m.start, m.end, SensitiveKind.aadhaar));
  }
  spans.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  final merged = <SensitiveSpan>[];
  for (final s in spans) {
    if (merged.isNotEmpty && s.start < merged.last.end) {
      final last = merged.last;
      if (s.end > last.end) merged[merged.length - 1] = SensitiveSpan(last.start, s.end, last.kind);
    } else {
      merged.add(s);
    }
  }
  return merged;
}

Set<SensitiveKind> sensitiveKinds(String text) => findSensitiveSpans(text).map((s) => s.kind).toSet();

/// [text] with every sensitive span replaced by [maskToken]. The caller shows this exact string to the user before it is sent.
String maskSensitive(String text) {
  final spans = findSensitiveSpans(text);
  if (spans.isEmpty) return text;
  final b = StringBuffer();
  var i = 0;
  for (final s in spans) {
    b.write(text.substring(i, s.start));
    b.write(maskToken);
    i = s.end;
  }
  b.write(text.substring(i));
  return b.toString();
}

String sensitiveKindLabel(SensitiveKind k) => switch (k) {
      SensitiveKind.otp => 'an OTP or verification code',
      SensitiveKind.pin => 'a PIN',
      SensitiveKind.password => 'a password',
      SensitiveKind.cvv => 'a card CVV',
      SensitiveKind.card => 'a card number',
      SensitiveKind.aadhaar => 'an Aadhaar-like number',
      SensitiveKind.account => 'a bank account number',
    };

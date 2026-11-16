/// Privacy-safe text for local notifications (Stage 1.6D-3).
///
/// A notification can be read on the lock screen, in the notification shade, by a smartwatch, or by anyone holding the phone.
/// So it carries a SAFE SUMMARY (what kind of scam and what to do), never the message that was analysed: no preview, no
/// sender, no OTP, account number or phone number. The full result stays inside the app, behind its own lock.
library;

/// A run of 4 or more digits (OTP, account, card, phone) is never allowed into a notification.
final RegExp _digitRun = RegExp(r'\d[\d\s\-]{2,}\d');
final RegExp _control = RegExp(r'[\u0000-\u001F\u007F]+');

/// Bounded, single-line text with every long number removed. Never throws.
String safeNotificationText(String? value, {int max = 60}) {
  try {
    final cleaned = (value ?? '')
        .replaceAll(_control, ' ')
        .replaceAll(_digitRun, '•••')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length <= max ? cleaned : '${cleaned.substring(0, max - 1)}…';
  } catch (_) {
    return '';
  }
}

class FraudNotificationContent {
  final String title;
  final String body;
  final String expandedBody;
  const FraudNotificationContent(this.title, this.body, this.expandedBody);
}

/// Title, collapsed text and expanded text for a possible-scam notification. Inputs are a scam CATEGORY label and how many
/// scam phrases matched; the analysed message is deliberately not an input, so it cannot leak by mistake.
FraudNotificationContent buildFraudNotificationContent({
  required String fraudType,
  int matchedCount = 0,
}) {
  final type = safeNotificationText(fraudType, max: 40);
  final label = type.isEmpty ? 'Possible scam' : type;
  final strength = matchedCount >= 3
      ? 'Several warning signs found.'
      : matchedCount > 0
          ? 'A warning sign was found.'
          : 'This message looks suspicious.';
  return FraudNotificationContent(
    '⚠️ Possible scam: $label',
    'Open SecureShield to review. Do not share OTP, PIN or bank details.',
    '$strength Open SecureShield to see why. Never share your OTP, PIN, '
        'Aadhaar or bank details, and do not tap links in the message.',
  );
}

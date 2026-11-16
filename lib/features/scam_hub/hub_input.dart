/// Local classification of what the user typed or pasted. Pure and offline: nothing is sent anywhere here.
library;

enum HubRoute { message, url, qrPayload }

const int hubMaxChars = 5000; // the strictest backend limit (message_text)
const int hubMaxUrlChars = 2048; // backend url limit

sealed class HubClassification {
  const HubClassification();
}

class HubClassified extends HubClassification {
  final HubRoute route;
  final String text; // exactly as entered (only surrounding whitespace trimmed for classification; see [raw])
  const HubClassified(this.route, this.text);
}

class HubRejected extends HubClassification {
  final String reason;
  const HubRejected(this.reason);
}

final _bareHost = RegExp(r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?::\d{1,5})?(?:[/?#]\S*)?$', caseSensitive: false);
final _bareIp = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?(?:[/?#]\S*)?$');
const _qrSchemes = ['upi://', 'tel:', 'sms:', 'smsto:', 'wifi:'];

/// Classify pasted or typed input. The text is returned as entered: it is only trimmed at its ends, never rewritten.
HubClassification classifyScamInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const HubRejected('Enter or paste something to check.');
  if (text.length > hubMaxChars) return const HubRejected('That is too long. The limit is $hubMaxChars characters.');
  if (text.runes.any((r) => r < 32 && r != 10 && r != 9 && r != 13)) {
    return const HubRejected('That contains control characters. Remove them and try again.');
  }
  final lower = text.toLowerCase();
  if (_qrSchemes.any(lower.startsWith)) return HubClassified(HubRoute.qrPayload, text);
  final single = !text.contains(RegExp(r'\s'));
  if (single && (lower.startsWith('http://') || lower.startsWith('https://') || _bareHost.hasMatch(text) || _bareIp.hasMatch(text))) {
    if (text.length > hubMaxUrlChars) return const HubRejected('That link is too long. The limit is $hubMaxUrlChars characters.');
    return HubClassified(HubRoute.url, text);
  }
  return HubClassified(HubRoute.message, text);
}

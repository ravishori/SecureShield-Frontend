import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/scam_hub/hub_input.dart';

HubRoute? route(String s) {
  final c = classifyScamInput(s);
  return c is HubClassified ? c.route : null;
}

void main() {
  group('classification', () {
    test('messages', () {
      expect(route('Your KYC has expired, click now'), HubRoute.message);
      expect(route('hello'), HubRoute.message);
      expect(route('Visit http://bit.ly/x now to claim'), HubRoute.message); // a link inside a message stays a message
    });
    test('links, including bare hosts, are kept exactly as entered', () {
      for (final u in ['https://example.com/a?b=1', 'HTTP://Example.com', 'example.com/login', 'sub.example.co.in', '192.168.4.4/verify', 'example.com:8080/x']) {
        final c = classifyScamInput('  $u  ');
        expect(c, isA<HubClassified>(), reason: u);
        expect((c as HubClassified).route, HubRoute.url, reason: u);
        expect(c.text, u, reason: 'only surrounding whitespace is trimmed; nothing is added (no https:// prefix)');
      }
    });
    test('qr-style payloads', () {
      for (final p in ['upi://pay?pa=a@b', 'UPI://pay', 'tel:+911234567890', 'sms:123', 'smsto:123:hi', 'WIFI:S:x;T:WPA;P:y;;']) {
        expect(route(p), HubRoute.qrPayload, reason: p);
      }
    });
    test('an email address and a sentence are not links', () {
      expect(route('someone@example.com'), HubRoute.message);
      expect(route('go to example.com now'), HubRoute.message);
    });
    test('limits and control characters are rejected, never truncated', () {
      expect(classifyScamInput(''), isA<HubRejected>());
      expect(classifyScamInput('   \n '), isA<HubRejected>());
      expect(classifyScamInput('a' * 5000), isA<HubClassified>());
      expect(classifyScamInput('a' * 5001), isA<HubRejected>());
      expect(classifyScamInput('https://example.com/${'a' * 2040}'), isA<HubRejected>());
      expect(classifyScamInput('https://example.com/${'a' * 2020}'), isA<HubClassified>());
      expect(classifyScamInput('hi\x00there'), isA<HubRejected>());
      expect(classifyScamInput('line1\nline2\tx'), isA<HubClassified>());
    });
  });
}

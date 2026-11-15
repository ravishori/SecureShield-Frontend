// Stage 1.6D-3: local notifications carry a safe summary only. Synthetic data.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/services/notification_content.dart';

const _otp = '482913';
const _account = '123456789012';
const _phone = '9876543210';

void main() {
  group('buildFraudNotificationContent', () {
    test('is built from a category and a count, with nothing from the message', () {
      final c = buildFraudNotificationContent(fraudType: 'KYC Update', matchedCount: 4);
      expect(c.title, contains('KYC Update'));
      expect(c.body, contains('Open SecureShield'));
      expect(c.expandedBody, contains('Several warning signs'));
    });

    test('strength wording follows the count', () {
      expect(buildFraudNotificationContent(fraudType: 'x', matchedCount: 0).expandedBody, contains('looks suspicious'));
      expect(buildFraudNotificationContent(fraudType: 'x', matchedCount: 1).expandedBody, contains('A warning sign'));
    });

    test('a category label that somehow contains identifiers is cleaned', () {
      final c = buildFraudNotificationContent(fraudType: 'OTP $_otp acct $_account call $_phone');
      final all = '${c.title}|${c.body}|${c.expandedBody}';
      for (final raw in [_otp, _account, _phone]) {
        expect(all.contains(raw), isFalse, reason: raw);
      }
    });

    test('empty, huge and control-character labels are safe', () {
      expect(buildFraudNotificationContent(fraudType: '').title, contains('Possible scam'));
      final big = buildFraudNotificationContent(fraudType: 'A' * 500);
      expect(big.title.length, lessThan(80));
      expect(buildFraudNotificationContent(fraudType: '\u0000\u0001').title, contains('Possible scam'));
    });
  });

  group('safeNotificationText', () {
    test('removes long number runs but keeps ordinary text and short numbers', () {
      expect(safeNotificationText('Pay $_phone now'), 'Pay ••• now');
      expect(safeNotificationText('card 4111 1111 1111 1111'), 'card •••');
      expect(safeNotificationText('Top 5 scams in 99 cities'), 'Top 5 scams in 99 cities');
    });

    test('is bounded and never throws on null', () {
      expect(safeNotificationText(null), '');
      expect(safeNotificationText('x' * 200, max: 20).length, 20);
    });
  });

  group('source guard (no raw message can reach a notification)', () {
    final service = File('lib/core/services/notification_service.dart').readAsStringSync();
    final screen = File('lib/features/message_analyzer/screens/message_analyzer_screen.dart').readAsStringSync();

    test('showFraudAlert no longer accepts a message or keywords', () {
      final start = service.indexOf('static Future<void> showFraudAlert(');
      final signature = service.substring(start, service.indexOf(') async', start));
      expect(signature.contains('message'), isFalse);
      expect(signature.contains('matchedKeywords'), isFalse);
      expect(service.contains('message.substring'), isFalse);
    });

    test('the message analyzer passes no message text to the notification', () {
      final start = screen.indexOf('NotificationService.showFraudAlert(');
      final call = screen.substring(start, screen.indexOf(');', start));
      expect(call.contains('messageText'), isFalse);
      expect(call.contains('message:'), isFalse);
    });

    test('every Android notification hides its content on a secure lock screen', () {
      final android = 'AndroidNotificationDetails('.allMatches(service).length;
      final private = 'NotificationVisibility.private'.allMatches(service).length;
      expect(android, greaterThan(0));
      expect(private, android);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/scam_hub/sensitive_content.dart';

void main() {
  group('detects a secret VALUE', () {
    final positives = <String, SensitiveKind>{
      'Your OTP is 482913, do not share': SensitiveKind.otp,
      'verification code: 123456': SensitiveKind.otp,
      '482913 is your OTP for login': SensitiveKind.otp,
      'my upi pin is 4321': SensitiveKind.pin,
      'MPIN 123456': SensitiveKind.pin,
      'password: Hunter2!': SensitiveKind.password,
      'pwd = abc123': SensitiveKind.password,
      'cvv 123': SensitiveKind.cvv,
      'card 4111 1111 1111 1111 exp 12/29': SensitiveKind.card, // Luhn-valid test number
      'aadhaar 1234 5678 9012': SensitiveKind.aadhaar,
      'a/c no 123456789012': SensitiveKind.account,
    };
    positives.forEach((text, kind) {
      test(text, () => expect(sensitiveKinds(text), contains(kind)));
    });
  });

  group('does not flag ordinary text', () {
    for (final t in [
      'Share your OTP to claim the prize', // mentions OTP but holds no value
      'Your account is blocked. Click the link',
      'Pay Rs 5000 by 2026',
      'Call 9876543210 now',
      'Meeting at 10:30 on 12/11/2026',
      'Order 1234567890123 shipped', // 13 digits but not Luhn-valid
    ]) {
      test(t, () => expect(findSensitiveSpans(t), isEmpty));
    }
  });

  group('masking', () {
    test('replaces only the secret value and shows exactly the string that would be sent', () {
      const t = 'Your OTP is 482913, do not share';
      expect(maskSensitive(t), 'Your OTP is ****, do not share');
      expect(maskSensitive(t).contains('482913'), isFalse);
    });
    test('several spans, overlapping spans and no spans', () {
      expect(maskSensitive('cvv 123 and password: abc'), 'cvv **** and password: ****');
      expect(maskSensitive('nothing here'), 'nothing here');
      final m = maskSensitive('card 4111 1111 1111 1111 cvv 123');
      expect(m.contains('4111'), isFalse);
      expect(m.contains('123'), isFalse);
    });
  });
}

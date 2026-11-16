import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/security/encryption_service.dart';

Future<void> fresh([Map<String, String> initial = const {}]) async {
  FlutterSecureStorage.setMockInitialValues(Map.of(initial));
  EncryptionService.resetForTesting(storage: const FlutterSecureStorage());
  await EncryptionService.initialize();
}

Uint8List nonceOf(String sealed) =>
    Uint8List.fromList(base64.decode(sealed.substring(3)).sublist(0, 12));

void main() {
  group('round trip', () {
    test('encrypts and decrypts text, unicode and empty strings', () async {
      await fresh();
      for (final p in ['hello', '', 'नमस्ते 🔐 ' * 50, 'x' * 100000]) {
        final c = EncryptionService.encrypt(p);
        expect(c.startsWith('v2:'), isTrue);
        expect(c, isNot(contains(base64.encode(utf8.encode('hello')))));
        expect(EncryptionService.decrypt(c), p);
      }
    });

    test('maps round-trip', () async {
      await fresh();
      final m = {
        'a': 1,
        'b': ['x', 'y'],
        'c': {'d': true}
      };
      expect(EncryptionService.decryptMap(EncryptionService.encryptMap(m)), m);
    });

    test('the key persists: a second start decrypts what the first one wrote',
        () async {
      await fresh();
      final c = EncryptionService.encrypt('persisted');
      EncryptionService
          .resetForTesting(); // simulate a new process, same storage
      await EncryptionService.initialize();
      expect(EncryptionService.decrypt(c), 'persisted');
    });
  });

  group('nonce / IV', () {
    test(
        'every message gets a different random nonce and a different ciphertext',
        () async {
      await fresh();
      final seen = <String>{};
      final cts = <String>{};
      for (var i = 0; i < 500; i++) {
        final c = EncryptionService.encrypt('same plaintext');
        seen.add(base64.encode(nonceOf(c)));
        cts.add(c);
      }
      expect(seen.length, 500, reason: 'a nonce was reused');
      expect(cts.length, 500);
    });

    test('no IV is stored for new data and the nonce is 96 bits', () async {
      await fresh();
      expect(nonceOf(EncryptionService.encrypt('a')).length, 12);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'aes_iv'),
          isNull); // the fixed IV of the old design is gone
    });
  });

  group('failure handling: never plaintext', () {
    test(
        'using the service before initialization throws instead of returning plaintext',
        () {
      EncryptionService.resetForTesting();
      expect(() => EncryptionService.encrypt('secret'),
          throwsA(isA<EncryptionException>()));
      expect(() => EncryptionService.decrypt('v2:AAAA'),
          throwsA(isA<EncryptionException>()));
    });

    test('malformed, truncated and tampered values throw', () async {
      await fresh();
      final c = EncryptionService.encrypt('top secret');
      final raw = base64.decode(c.substring(3));
      final flipped = Uint8List.fromList(raw)..[raw.length - 1] ^= 1; // tag
      final flippedBody = Uint8List.fromList(raw)..[14] ^= 1; // ciphertext
      for (final bad in [
        'v2:${base64.encode(flipped)}',
        'v2:${base64.encode(flippedBody)}',
        'v2:${base64.encode(raw.sublist(0, raw.length - 3))}',
        'v2:${base64.encode(raw.sublist(0, 10))}',
        'v2:not-base64!!',
        'v2:',
        'plain text that is not ciphertext',
      ]) {
        expect(() => EncryptionService.decrypt(bad),
            throwsA(isA<EncryptionException>()),
            reason: bad);
      }
    });

    test('a different key cannot decrypt', () async {
      await fresh();
      final c = EncryptionService.encrypt('for the first key only');
      await fresh(); // brand-new random key
      expect(() => EncryptionService.decrypt(c),
          throwsA(isA<EncryptionException>()));
    });

    test('a corrupt stored key makes initialization fail loudly', () async {
      FlutterSecureStorage.setMockInitialValues({
        'aes_encryption_key': base64.encode([1, 2, 3])
      });
      EncryptionService.resetForTesting(storage: const FlutterSecureStorage());
      await expectLater(
          EncryptionService.initialize(), throwsA(isA<EncryptionException>()));
      expect(EncryptionService.isInitialized, isFalse);
      expect(() => EncryptionService.encrypt('x'),
          throwsA(isA<EncryptionException>()));
    });

    test('decryptMap rejects a value that is not a JSON object', () async {
      await fresh();
      expect(
          () => EncryptionService.decryptMap(
              EncryptionService.encrypt('[1,2,3]')),
          throwsA(isA<EncryptionException>()));
    });
  });

  group(
      'legacy data (old fixed-IV CBC) stays readable, nothing new is written that way',
      () {
    test('decrypts a value sealed by the old scheme', () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final iv = Uint8List.fromList(List<int>.generate(16, (i) => 100 + i));
      final legacy = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc))
          .encrypt('old recording', iv: enc.IV(iv))
          .base64;
      await fresh({
        'aes_encryption_key': base64.encode(key),
        'aes_iv': base64.encode(iv)
      });
      expect(EncryptionService.decrypt(legacy), 'old recording');
      final fresh1 = EncryptionService.encrypt('old recording');
      expect(fresh1.startsWith('v2:'), isTrue);
      expect(fresh1, isNot(legacy));
    });

    test('a legacy value without a legacy IV is an error, not garbage',
        () async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await fresh({'aes_encryption_key': base64.encode(key)});
      final legacy = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc))
          .encrypt('x', iv: enc.IV(Uint8List(16)))
          .base64;
      expect(() => EncryptionService.decrypt(legacy),
          throwsA(isA<EncryptionException>()));
    });
  });
}

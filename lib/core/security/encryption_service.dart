import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC encryption service for sensitive local data.
///
/// The key and IV are generated once, stored in the device Keystore
/// via [FlutterSecureStorage], and reloaded on subsequent runs.
///
/// Usage:
///   await EncryptionService.initialize();
///   final cipher = EncryptionService.encrypt('secret');
///   final plain  = EncryptionService.decrypt(cipher);
class EncryptionService {
  EncryptionService._();

  static late final enc.Encrypter _encrypter;
  static late final enc.IV _iv;
  static const _keyStorageKey = 'aes_encryption_key';
  static const _ivStorageKey = 'aes_iv';
  static const _storage = FlutterSecureStorage();
  static bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialization — call once at app startup
  // ---------------------------------------------------------------------------

  /// Load the AES key + IV from secure storage, or generate and store new ones.
  ///
  /// Must be awaited before any call to [encrypt] / [decrypt].
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final storedKey = await _storage.read(key: _keyStorageKey);
      final storedIv = await _storage.read(key: _ivStorageKey);

      Uint8List keyBytes;
      Uint8List ivBytes;

      if (storedKey != null && storedIv != null) {
        // Load existing key/IV
        keyBytes = base64.decode(storedKey);
        ivBytes = base64.decode(storedIv);
      } else {
        // Generate fresh 256-bit key and 128-bit IV
        final rng = Random.secure();
        keyBytes = Uint8List.fromList(
          List<int>.generate(32, (_) => rng.nextInt(256)),
        );
        ivBytes = Uint8List.fromList(
          List<int>.generate(16, (_) => rng.nextInt(256)),
        );

        // Persist to secure storage (Keystore on Android, Keychain on iOS)
        await _storage.write(key: _keyStorageKey, value: base64.encode(keyBytes));
        await _storage.write(key: _ivStorageKey, value: base64.encode(ivBytes));

        debugPrint('[EncryptionService] Generated and stored new AES-256 key.');
      }

      final aesKey = enc.Key(keyBytes);
      _iv = enc.IV(ivBytes);
      _encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
      _initialized = true;

      debugPrint('[EncryptionService] AES-256-CBC initialized.');
    } catch (e) {
      debugPrint('[EncryptionService] Initialization failed: $e');
      // Do not set _initialized — subsequent calls will return originals
    }
  }

  // ---------------------------------------------------------------------------
  // Encrypt / decrypt strings
  // ---------------------------------------------------------------------------

  /// Encrypt [plaintext] and return a base64-encoded ciphertext string.
  ///
  /// Returns [plaintext] unchanged if the service is not initialized (safe
  /// degradation instead of a hard crash).
  static String encrypt(String plaintext) {
    if (!_initialized) {
      debugPrint('[EncryptionService] WARNING: not initialized, returning plaintext.');
      return plaintext;
    }
    try {
      final encrypted = _encrypter.encrypt(plaintext, iv: _iv);
      return encrypted.base64;  // enc.Encrypted.base64
    } catch (e) {
      debugPrint('[EncryptionService] Encryption error: $e');
      return plaintext;
    }
  }

  /// Decrypt a base64-encoded [ciphertext] string.
  ///
  /// Returns [ciphertext] unchanged on any failure (safe degradation).
  static String decrypt(String ciphertext) {
    if (!_initialized) {
      debugPrint('[EncryptionService] WARNING: not initialized, returning ciphertext.');
      return ciphertext;
    }
    try {
      final encrypted = enc.Encrypted.fromBase64(ciphertext);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      debugPrint('[EncryptionService] Decryption error: $e');
      return ciphertext;
    }
  }

  // ---------------------------------------------------------------------------
  // Encrypt / decrypt Map objects (JSON round-trip)
  // ---------------------------------------------------------------------------

  /// JSON-encode [data], then AES-encrypt and return a base64 string.
  static String encryptMap(Map<String, dynamic> data) {
    try {
      final json = jsonEncode(data);
      return encrypt(json);
    } catch (e) {
      debugPrint('[EncryptionService] encryptMap error: $e');
      return jsonEncode(data);
    }
  }

  /// Decrypt [ciphertext] and JSON-decode the result back to a Map.
  ///
  /// Returns an empty Map on failure.
  static Map<String, dynamic> decryptMap(String ciphertext) {
    try {
      final json = decrypt(ciphertext);
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[EncryptionService] decryptMap error: $e');
      return {};
    }
  }
}

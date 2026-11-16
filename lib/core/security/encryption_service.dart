import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Raised when data cannot be encrypted or decrypted. Callers must treat it as a failure: the service
/// NEVER hands back the plaintext (or the ciphertext) in place of a result.
class EncryptionException implements Exception {
  const EncryptionException(this.message);
  final String message;

  @override
  String toString() => 'EncryptionException: $message';
}

/// Authenticated encryption (AES-256-GCM) for sensitive local data.
///
/// * The 256-bit key is generated once with a CSPRNG and kept in the Android Keystore-backed
///   [FlutterSecureStorage].
/// * **Every message gets a fresh random 96-bit nonce**; the nonce is stored with the ciphertext
///   (`v2:` + base64(nonce | ciphertext | 16-byte tag)). A nonce is never reused and there is no stored IV.
/// * Tampering, a wrong key or a truncated value fails the GCM tag check and throws.
/// * Any failure throws [EncryptionException]; there is no plaintext fallback anywhere.
///
/// Legacy data: earlier versions used AES-256-CBC with one fixed IV and returned plaintext on failure. Values that do
/// not start with `v2:` are decrypted with that legacy scheme (using the IV that was stored back then) so existing
/// recordings stay readable; nothing new is ever written in the legacy format.
class EncryptionService {
  EncryptionService._();

  static const _prefix = 'v2:';
  static const _nonceBytes = 12;
  static const _keyStorageKey = 'aes_encryption_key';
  static const _legacyIvStorageKey = 'aes_iv'; // read only, for legacy values
  static FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final Random _rng = Random.secure();

  static enc.Key? _key;
  static enc.IV? _legacyIv;

  static bool get isInitialized => _key != null;

  /// Test hook: forget the loaded key so [initialize] reads storage again.
  @visibleForTesting
  static void resetForTesting({FlutterSecureStorage? storage}) {
    _key = null;
    _legacyIv = null;
    if (storage != null) _storage = storage;
  }

  // ---------------------------------------------------------------------------
  // Initialization - call once at app startup
  // ---------------------------------------------------------------------------

  /// Loads the AES key from secure storage, or generates and stores a new one. Throws
  /// [EncryptionException] if neither is possible (the app then cannot save anything encrypted).
  static Future<void> initialize() async {
    if (_key != null) return;
    try {
      final storedKey = await _storage.read(key: _keyStorageKey);
      final storedIv = await _storage.read(key: _legacyIvStorageKey);

      Uint8List keyBytes;
      if (storedKey != null && storedKey.isNotEmpty) {
        keyBytes = base64.decode(storedKey);
        if (keyBytes.length != 32) {
          throw const EncryptionException('stored key has the wrong length');
        }
      } else {
        keyBytes = Uint8List.fromList(
            List<int>.generate(32, (_) => _rng.nextInt(256)));
        await _storage.write(
            key: _keyStorageKey, value: base64.encode(keyBytes));
        debugPrint(
            '[EncryptionService] Generated and stored a new AES-256 key.');
      }
      _key = enc.Key(keyBytes);
      if (storedIv != null && storedIv.isNotEmpty) {
        _legacyIv = enc.IV(base64.decode(storedIv));
      }
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException('initialization failed (${e.runtimeType})');
    }
  }

  // ---------------------------------------------------------------------------
  // Encrypt / decrypt strings
  // ---------------------------------------------------------------------------

  static enc.Key _requireKey() {
    final k = _key;
    if (k == null) {
      throw const EncryptionException(
          'not initialized - refusing to continue without encryption');
    }
    return k;
  }

  /// Encrypts [plaintext] and returns `v2:` + base64(nonce | ciphertext | tag). Throws on any failure.
  static String encrypt(String plaintext) {
    final key = _requireKey();
    try {
      final nonce = enc.IV(Uint8List.fromList(
          List<int>.generate(_nonceBytes, (_) => _rng.nextInt(256))));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final sealed = encrypter.encrypt(plaintext, iv: nonce).bytes;
      final out = Uint8List(_nonceBytes + sealed.length)
        ..setRange(0, _nonceBytes, nonce.bytes)
        ..setRange(_nonceBytes, _nonceBytes + sealed.length, sealed);
      return _prefix + base64.encode(out);
    } catch (e) {
      throw EncryptionException('encryption failed (${e.runtimeType})');
    }
  }

  /// Decrypts a value produced by [encrypt] (or by the legacy scheme). Throws on a wrong key, tampering,
  /// truncation or malformed input - never returns the input.
  static String decrypt(String ciphertext) {
    final key = _requireKey();
    try {
      if (ciphertext.startsWith(_prefix)) {
        final raw = base64.decode(ciphertext.substring(_prefix.length));
        if (raw.length < _nonceBytes + 16) {
          throw const EncryptionException('ciphertext is too short');
        }
        final nonce = enc.IV(Uint8List.fromList(raw.sublist(0, _nonceBytes)));
        final sealed =
            enc.Encrypted(Uint8List.fromList(raw.sublist(_nonceBytes)));
        return enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm))
            .decrypt(sealed, iv: nonce);
      }
      return _decryptLegacy(key, ciphertext);
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException('decryption failed (${e.runtimeType})');
    }
  }

  static String _decryptLegacy(enc.Key key, String ciphertext) {
    final iv = _legacyIv;
    if (iv == null) {
      throw const EncryptionException(
          'legacy value but no legacy IV is available');
    }
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
        .decrypt(enc.Encrypted.fromBase64(ciphertext), iv: iv);
  }

  // ---------------------------------------------------------------------------
  // Encrypt / decrypt Map objects (JSON round-trip)
  // ---------------------------------------------------------------------------

  static String encryptMap(Map<String, dynamic> data) =>
      encrypt(jsonEncode(data));

  /// Throws [EncryptionException] if the value cannot be decrypted or is not a JSON object.
  static Map<String, dynamic> decryptMap(String ciphertext) {
    final json = decrypt(ciphertext);
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const EncryptionException('decrypted value is not a JSON object');
    }
  }
}

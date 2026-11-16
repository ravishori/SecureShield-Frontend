import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/auth/auth_provider.dart';

/// Service for biometric (fingerprint / face) authentication.
///
/// Uses [local_auth] for the actual prompt and [FlutterSecureStorage]
/// to persist the user's opt-in preference.
class BiometricService {
  BiometricService._();

  static const _enabledKey = 'biometric_enabled';
  static const _storage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();

  // ---------------------------------------------------------------------------
  // Availability
  // ---------------------------------------------------------------------------

  /// Returns true if the device supports biometrics AND at least one biometric
  /// (fingerprint / face) is enrolled.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // User preference (stored in Keystore / Keychain via secure storage)
  // ---------------------------------------------------------------------------

  /// Returns true if the user has opted in to biometric login.
  static Future<bool> isEnabled() async {
    try {
      final value = await _storage.read(key: _enabledKey);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Persist the user's biometric login preference.
  static Future<void> setEnabled(bool value) async {
    try {
      await _storage.write(key: _enabledKey, value: value ? 'true' : 'false');
    } catch (_) {
      // Swallow storage errors — preference will default to false on next read
    }
  }

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Show the biometric / PIN prompt.
  ///
  /// Returns true on success, false on failure or cancellation.
  /// [reason] is displayed in the system prompt dialog.
  static Future<bool> authenticate({
    String reason = 'Confirm your identity to access SecureShield AI',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,  // allow device PIN as fallback
          stickyAuth: true,      // keep prompt alive if user switches apps
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // e.g. NotAvailable, NotEnrolled, LockedOut
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Biometric login shortcut
  // ---------------------------------------------------------------------------

  /// Authenticate with biometrics and, if successful, silently refresh the
  /// JWT tokens so the user is logged in without entering an OTP again.
  ///
  /// Returns true if both biometric auth AND token refresh succeed.
  static Future<bool> authenticateAndLogin(WidgetRef ref) async {
    final ok = await authenticate();
    if (!ok) return false;

    try {
      await ref.read(authProvider.notifier).refreshTokens();
      return true;
    } catch (_) {
      return false;
    }
  }
}

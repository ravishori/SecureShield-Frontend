/// Google Sign-In
/// ──────────────────────────────────────────────────────────────────────────
/// The app obtains a Google **ID token** and sends it to `POST /auth/google`; the BACKEND verifies the token
/// (signature, audience, issuer, expiry, verified e-mail) - the client is never trusted for identity.
///
/// Enabling (owner action, nothing here can be done from code):
///   1. Google Cloud Console -> Credentials: create an OAuth client of type **Web** (its client ID is the
///      `serverClientId`) and one of type **Android** (package `com.secureshield.secureshield_app` + the SHA-1 of
///      the signing key). Both IDs go into the backend variable `GOOGLE_CLIENT_IDS` (comma separated).
///   2. Build with `--dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>`.
/// Without the define the button stays disabled ("Setup required") and no Google code runs.
library;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const String kGoogleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// True only for builds made with a web client ID.
const bool kGoogleAuthEnabled = kGoogleWebClientId != '';

class GoogleSignInResult {
  final String idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const GoogleSignInResult({
    required this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}

abstract class GoogleAuthService {
  static GoogleSignIn? _client;

  static GoogleSignIn get _google => _client ??= GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: kGoogleWebClientId,
      );

  /// Opens the Google account chooser. Returns null when disabled, cancelled or failed (never throws).
  static Future<GoogleSignInResult?> signIn() async {
    if (!kGoogleAuthEnabled) return null;
    try {
      final account = await _google.signIn();
      if (account == null) return null; // user cancelled
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return null;
      return GoogleSignInResult(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      debugPrint('[GoogleAuth] sign-in failed: ${e.runtimeType}');
      return null;
    }
  }

  static Future<void> signOut() async {
    if (!kGoogleAuthEnabled) return;
    try {
      await _google.signOut();
    } catch (_) {}
  }
}

/// Google Sign-In Service
/// ──────────────────────────────────────────────────────────────────────────
/// SETUP REQUIRED before this feature is enabled:
///
/// 1. Create a Firebase project at https://console.firebase.google.com
/// 2. Add an Android app with package name: com.secureshield.secureshield_app
/// 3. Register your debug SHA-1:
///      cd android && ./gradlew signingReport
/// 4. Download google-services.json → place at android/app/google-services.json
/// 5. In android/build.gradle (project level), add:
///      classpath 'com.google.gms:google-services:4.4.2'
/// 6. In android/app/build.gradle, add at the top of plugins:
///      id 'com.google.gms.google-services'
/// 7. Add packages to pubspec.yaml:
///      google_sign_in: ^6.2.1
///      firebase_core: ^3.6.0
///      firebase_auth: ^5.3.1
/// 8. Set kGoogleAuthEnabled = true below
/// 9. Run: flutter pub get && flutter pub run flutterfire configure
///
/// ──────────────────────────────────────────────────────────────────────────
library;

/// Set to true ONLY after completing all Firebase setup steps above.
const bool kGoogleAuthEnabled = false;

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
  /// Triggers Google Sign-In and returns the result, or null if cancelled/failed.
  ///
  /// Returns null if [kGoogleAuthEnabled] is false (feature not yet set up).
  static Future<GoogleSignInResult?> signIn() async {
    if (!kGoogleAuthEnabled) {
      // Feature flag off — Firebase not yet configured
      return null;
    }
    // ── Real implementation (uncomment after Firebase setup) ──────────────
    // try {
    //   final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    //   final GoogleSignInAccount? account = await googleSignIn.signIn();
    //   if (account == null) return null; // User cancelled
    //
    //   final GoogleSignInAuthentication auth = await account.authentication;
    //   if (auth.idToken == null) return null;
    //
    //   return GoogleSignInResult(
    //     idToken:     auth.idToken!,
    //     email:       account.email,
    //     displayName: account.displayName,
    //     photoUrl:    account.photoUrl,
    //   );
    // } catch (e) {
    //   return null;
    // }
    return null;
  }

  static Future<void> signOut() async {
    if (!kGoogleAuthEnabled) return;
    // await GoogleSignIn().signOut();
  }
}

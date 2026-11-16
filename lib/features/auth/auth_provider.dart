import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/google_auth_service.dart';
import '../privacy/consent_choices.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/utils/jwt_decoder.dart';
import '../../core/network/dio_client.dart';

// ── AuthState ────────────────────────────────────────────────────────────────

class AuthState {
  final bool   isAuthenticated;
  final bool   isLoading;
  final bool   loginSuccess;   // true right after successful OTP login (shown as popup)
  final String? userId;
  final String? identifier;    // phone OR email — whatever the user logged in with
  final String? error;
  /// Verification state exactly as the server reported it (null = not reported yet). The client never infers it.
  final bool?   emailVerified;
  final bool?   phoneVerified;
  /// Server-driven next step after sign-in: `verify_phone` or null.
  final String? nextStep;
  /// True when a Google sign-in was refused only because it would create an account without consent: the UI shows the
  /// consent screen and calls [AuthNotifier.signInWithGoogle] again with the choices.
  final bool    consentRequired;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading       = true,
    this.loginSuccess    = false,
    this.userId,
    this.identifier,
    this.error,
    this.emailVerified,
    this.phoneVerified,
    this.nextStep,
    this.consentRequired = false,
  });

  AuthState copyWith({
    bool?   isAuthenticated,
    bool?   isLoading,
    bool?   loginSuccess,
    String? userId,
    String? identifier,
    String? error,
    bool?   emailVerified,
    bool?   phoneVerified,
    String? nextStep,
    bool    clearNextStep = false,
    bool?   consentRequired,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading:       isLoading       ?? this.isLoading,
      loginSuccess:    loginSuccess    ?? this.loginSuccess,
      userId:          userId          ?? this.userId,
      identifier:      identifier      ?? this.identifier,
      error:           error,          // intentionally NOT carried forward (null resets)
      emailVerified:   emailVerified   ?? this.emailVerified,
      phoneVerified:   phoneVerified   ?? this.phoneVerified,
      nextStep:        clearNextStep ? null : (nextStep ?? this.nextStep),
      consentRequired: consentRequired ?? this.consentRequired,
    );
  }
}

// ── RegisterResult ────────────────────────────────────────────────────────────

/// Returned by [AuthNotifier.register] so the caller knows which channels
/// received the OTP (to display on the OTP screen).
class RegisterResult {
  final String  identifier;    // masked email shown on OTP screen
  final String  maskedEmail;
  final String? maskedPhone;   // hint only: the phone is verified separately, after the account exists
  final String  nextStep;      // 'verify_email'

  const RegisterResult({
    required this.identifier,
    required this.maskedEmail,
    this.maskedPhone,
    this.nextStep = 'verify_email',
  });
}

// ── AuthNotifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage   = const FlutterSecureStorage();
  final _dioClient = DioClient();

  /// Seams for tests: the real Google SDK cannot run in a unit test. Production uses [GoogleAuthService].
  final Future<GoogleSignInResult?> Function() _googleSignIn;
  final Future<void> Function() _googleSignOut;
  GoogleSignInResult? _pendingGoogle; // in memory only

  AuthNotifier({
    Future<GoogleSignInResult?> Function()? googleSignIn,
    Future<void> Function()? googleSignOut,
  })  : _googleSignIn  = googleSignIn  ?? GoogleAuthService.signIn,
        _googleSignOut = googleSignOut ?? GoogleAuthService.signOut,
        super(const AuthState()) {
    _checkAuth();
  }

  // ── Startup auth check ───────────────────────────────────────────────────

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null && !JwtDecoder.isExpired(token)) {
      final userId     = JwtDecoder.getUserId(token);
      final identifier = JwtDecoder.getIdentifier(token);
      state = AuthState(
        isAuthenticated: true,
        isLoading:       false,
        userId:          userId,
        identifier:      identifier,
      );
    } else {
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  // ── Registration (full profile form → OTP) ───────────────────────────────

  /// Creates a new user account with complete profile data and sends OTP.
  /// Returns [RegisterResult] with masked channel info for the OTP screen.
  Future<RegisterResult> register({
    required ConsentChoices? consent,
    required String firstName,
    String?  lastName,
    required String email,
    String?  phone,
    String?  flatNo,
    String?  building,
    String?  street,
    String?  city,
    String?  state,
    String?  country,
    String?  pinCode,
  }) async {
    this.state = this.state.copyWith(isLoading: true, error: null);
    try {
      if (consent == null) {
        throw StateError('Consent is required before registration.');
      }
      final body = <String, dynamic>{
        'first_name': firstName,
        'email':      email,
        'country':    country ?? 'India',
        'consent':    consent.toJson(),
      };
      if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;
      if (phone    != null && phone.isNotEmpty)    body['phone']     = phone;
      if (flatNo   != null && flatNo.isNotEmpty)   body['flat_no']   = flatNo;
      if (building != null && building.isNotEmpty) body['building']  = building;
      if (street   != null && street.isNotEmpty)   body['street']    = street;
      if (city     != null && city.isNotEmpty)     body['city']      = city;
      if (state    != null && state.isNotEmpty)    body['state']     = state;
      if (pinCode  != null && pinCode.isNotEmpty)  body['pin_code']  = pinCode;

      final response = await _dioClient.dio.post(
        AppConstants.register,
        data: body,
      );

      this.state = this.state.copyWith(isLoading: false);
      // Remember the pending registration so the user can come back to the code screen (no secret is stored).
      await _storage.write(key: AppConstants.pendingRegistrationEmailKey, value: email);

      return RegisterResult(
        identifier:   response.data['identifier']   as String? ?? email,
        maskedEmail:  response.data['masked_email']  as String? ?? email,
        maskedPhone:  response.data['masked_phone']  as String?,
        nextStep:     response.data['next_step']     as String? ?? 'verify_email',
      );
    } on DioException catch (e) {
      this.state = this.state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      this.state = this.state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Send OTP (login) ─────────────────────────────────────────────────────

  /// [identifier] is a phone number or email address. The code goes to THAT identifier only. For a registration that
  /// is still waiting for its e-mail code the server re-issues the registration code (same reply either way).
  Future<void> sendOtp(String identifier) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dioClient.dio.post(
        AppConstants.sendOtp,
        data: {'identifier': identifier},
      );
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────

  /// [identifier] is the same phone or email used in sendOtp / register.
  /// [deviceInfo] optional device registration fields.
  ///
  /// [registration] true completes a pending registration (`/auth/register/verify`): only then is the account
  /// created. false is a normal login code (`/auth/verify-otp`).
  Future<void> verifyOtp(
    String identifier,
    String code, {
    Map<String, dynamic>? deviceInfo,
    bool registration = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{
        'identifier': identifier,
        'code':       code,
      };
      if (deviceInfo != null) body.addAll(deviceInfo);

      final response = await _dioClient.dio.post(
        registration ? AppConstants.registerVerify : AppConstants.verifyOtp,
        data: body,
      );
      final accessToken  = response.data['access_token']  as String;
      final refreshToken = response.data['refresh_token'] as String;

      await _storage.write(key: AppConstants.accessTokenKey,  value: accessToken);
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);

      final userId           = JwtDecoder.getUserId(accessToken);
      final resolvedIdentifier = JwtDecoder.getIdentifier(accessToken);

      state = AuthState(
        isAuthenticated: true,
        isLoading:       false,
        loginSuccess:    true,       // ← triggers the success popup on OTP screen
        userId:          userId,
        identifier:      resolvedIdentifier,
        emailVerified:   response.data['email_verified'] as bool?,
        phoneVerified:   response.data['phone_verified'] as bool?,
        nextStep:        response.data['next_step']      as String?,
      );
      if (registration) {
        await _storage.delete(key: AppConstants.pendingRegistrationEmailKey);
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Called after the login-success popup is dismissed so it does not re-show.
  void clearLoginSuccess() {
    state = state.copyWith(loginSuccess: false);
  }

  // ── Pending registration (resume) ───────────────────────────────────────

  /// The e-mail of a registration still waiting for its code, or null.
  Future<String?> pendingRegistrationEmail() =>
      _storage.read(key: AppConstants.pendingRegistrationEmailKey);

  Future<void> clearPendingRegistration() =>
      _storage.delete(key: AppConstants.pendingRegistrationEmailKey);

  // ── Server-driven verification state ────────────────────────────────────

  /// Re-reads `email_verified` / `phone_verified` from the server (after a phone or e-mail change).
  Future<void> refreshVerification() async {
    try {
      final res = await _dioClient.dio.get(AppConstants.getMe);
      state = state.copyWith(
        emailVerified: res.data['email_verified'] as bool?,
        phoneVerified: res.data['phone_verified'] as bool?,
        clearNextStep: res.data['phone_verified'] == true,
      );
    } catch (_) {
      // keep what the server last told us; the UI never invents a verified state
    }
  }

  // ── Refresh tokens (biometric login) ────────────────────────────────────

  Future<void> refreshTokens() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final storedRefreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (storedRefreshToken == null) {
        throw Exception('No refresh token stored. Please log in again.');
      }

      final response = await _dioClient.dio.post(
        AppConstants.refreshToken,
        data: {'refresh_token': storedRefreshToken},
      );

      final accessToken     = response.data['access_token']  as String;
      final newRefreshToken = response.data['refresh_token'] as String;

      await _storage.write(key: AppConstants.accessTokenKey,  value: accessToken);
      await _storage.write(key: AppConstants.refreshTokenKey, value: newRefreshToken);

      final userId     = JwtDecoder.getUserId(accessToken);
      final identifier = JwtDecoder.getIdentifier(accessToken);

      state = AuthState(
        isAuthenticated: true,
        isLoading:       false,
        userId:          userId,
        identifier:      identifier,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────

  /// Signs in with a Google ID token verified by the backend. The server links Google only to an account whose e-mail
  /// it has verified (409 otherwise) and never trusts an unverified e-mail claim. Returns false when Google Sign-In is
  /// not configured in this build, was cancelled, or the backend rejected the token; [AuthState.error] then carries
  /// the reason (for example: linked to a different Google account).
  /// A sign-in that would create an account needs [consent]; without it the server refuses (422 `consent_required`), this
  /// returns false with [AuthState.consentRequired] set, and the Google result is kept in memory (never logged or stored) so
  /// the retry with the person's choices does not reopen the account chooser.
  Future<bool> signInWithGoogle({Map<String, dynamic>? deviceInfo, ConsentChoices? consent}) async {
    final google = (consent != null ? _pendingGoogle : null) ?? await _googleSignIn();
    _pendingGoogle = null;
    if (google == null) return false;
    state = state.copyWith(isLoading: true, error: null, consentRequired: false);
    try {
      final body = <String, dynamic>{'id_token': google.idToken};
      if (consent != null) body['consent'] = consent.toJson();
      if (deviceInfo != null) body.addAll(deviceInfo);
      final response = await _dioClient.dio.post(AppConstants.googleAuth, data: body);
      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String;
      await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        loginSuccess: true,
        userId: JwtDecoder.getUserId(accessToken),
        identifier: JwtDecoder.getIdentifier(accessToken),
        emailVerified: response.data['email_verified'] as bool?,
        phoneVerified: response.data['phone_verified'] as bool?,
        nextStep: response.data['next_step'] as String?,
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422 && e.response?.headers.value('x-consent-error') == 'consent_required') {
        _pendingGoogle = google; // keep the Google result for the retry; do not sign out of Google yet
        state = state.copyWith(isLoading: false, consentRequired: true);
        return false;
      }
      await _googleSignOut();
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      return false;
    } catch (e) {
      await _googleSignOut();
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed. Please try again.');
      return false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  /// After a CONFIRMED account deletion: forget the session and everything stored on this device for this user
  /// (tokens, pending registration, local vault data and preferences).
  Future<void> clearAllLocalData() async {
    _pendingGoogle = null;
    try {
      await _googleSignOut();
    } catch (_) {}
    await _dioClient.clearTokens();
    try {
      await _storage.deleteAll();
    } catch (_) {}
    try {
      await (await SharedPreferences.getInstance()).clear();
    } catch (_) {}
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  Future<void> logout() async {
    await _dioClient.clearTokens();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

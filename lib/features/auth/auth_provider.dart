import '../../core/security/google_auth_service.dart';
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

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading       = true,
    this.loginSuccess    = false,
    this.userId,
    this.identifier,
    this.error,
  });

  AuthState copyWith({
    bool?   isAuthenticated,
    bool?   isLoading,
    bool?   loginSuccess,
    String? userId,
    String? identifier,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading:       isLoading       ?? this.isLoading,
      loginSuccess:    loginSuccess    ?? this.loginSuccess,
      userId:          userId          ?? this.userId,
      identifier:      identifier      ?? this.identifier,
      error:           error,          // intentionally NOT carried forward (null resets)
    );
  }
}

// ── RegisterResult ────────────────────────────────────────────────────────────

/// Returned by [AuthNotifier.register] so the caller knows which channels
/// received the OTP (to display on the OTP screen).
class RegisterResult {
  final String  identifier;    // masked email shown on OTP screen
  final String  maskedEmail;
  final String? maskedPhone;

  const RegisterResult({
    required this.identifier,
    required this.maskedEmail,
    this.maskedPhone,
  });
}

// ── AuthNotifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage   = const FlutterSecureStorage();
  final _dioClient = DioClient();

  AuthNotifier() : super(const AuthState()) {
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
      final body = <String, dynamic>{
        'first_name': firstName,
        'email':      email,
        'country':    country ?? 'India',
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

      return RegisterResult(
        identifier:   response.data['identifier']   as String? ?? email,
        maskedEmail:  response.data['masked_email']  as String? ?? email,
        maskedPhone:  response.data['masked_phone']  as String?,
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

  /// [identifier] is a phone number or email address.
  /// Backend will send to both email + phone if the user has both on file.
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
  Future<void> verifyOtp(
    String identifier,
    String code, {
    Map<String, dynamic>? deviceInfo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{
        'identifier': identifier,
        'code':       code,
      };
      if (deviceInfo != null) body.addAll(deviceInfo);

      final response = await _dioClient.dio.post(
        AppConstants.verifyOtp,
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
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Called after the login-success popup is dismissed so it doesn't re-show.
  void clearLoginSuccess() {
    state = state.copyWith(loginSuccess: false);
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

  // ── Smart auth check ─────────────────────────────────────────────────────

  Future<({bool exists, bool hasProfile})> checkUserExists(String identifier) async {
    try {
      final response = await _dioClient.dio.get(
        AppConstants.checkUser,
        queryParameters: {'identifier': identifier},
      );
      final exists     = response.data['exists']      as bool? ?? false;
      final hasProfile = response.data['has_profile'] as bool? ?? false;
      return (exists: exists, hasProfile: hasProfile);
    } catch (_) {
      return (exists: false, hasProfile: false);
    }
  }

  // ── Google Sign-In (stub) ────────────────────────────────────────────────

  /// Signs in with a Google ID token verified by the backend. Returns false when Google Sign-In is not
  /// configured in this build, was cancelled, or the backend rejected the token.
  Future<bool> signInWithGoogle({Map<String, dynamic>? deviceInfo}) async {
    final google = await GoogleAuthService.signIn();
    if (google == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{'id_token': google.idToken};
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
      );
      return true;
    } on DioException catch (e) {
      await GoogleAuthService.signOut();
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      return false;
    } catch (e) {
      await GoogleAuthService.signOut();
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed. Please try again.');
      return false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _dioClient.clearTokens();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

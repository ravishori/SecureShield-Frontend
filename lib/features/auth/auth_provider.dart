import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/utils/jwt_decoder.dart';
import '../../core/network/dio_client.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? identifier; // phone number OR email — whatever the user logged in with
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.userId,
    this.identifier,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? identifier,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      identifier: identifier ?? this.identifier,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();
  final _dioClient = DioClient();

  AuthNotifier() : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null && !JwtDecoder.isExpired(token)) {
      final userId = JwtDecoder.getUserId(token);
      final identifier = JwtDecoder.getIdentifier(token);
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        userId: userId,
        identifier: identifier,
      );
    } else {
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Send OTP
  // ---------------------------------------------------------------------------

  /// [identifier] is a phone number or email address
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

  // ---------------------------------------------------------------------------
  // Verify OTP
  // ---------------------------------------------------------------------------

  /// [identifier] is the same phone or email used in sendOtp.
  /// [deviceInfo] is an optional map containing device registration fields:
  ///   { device_token, device_name, platform, os_version, app_version }
  Future<void> verifyOtp(
    String identifier,
    String code, {
    Map<String, dynamic>? deviceInfo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{
        'identifier': identifier,
        'code': code,
      };

      // Merge optional device registration info
      if (deviceInfo != null) {
        body.addAll(deviceInfo);
      }

      final response = await _dioClient.dio.post(
        AppConstants.verifyOtp,
        data: body,
      );
      final accessToken = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];

      await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);

      final userId = JwtDecoder.getUserId(accessToken);
      final resolvedIdentifier = JwtDecoder.getIdentifier(accessToken);

      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        userId: userId,
        identifier: resolvedIdentifier,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh tokens (used by biometric login)
  // ---------------------------------------------------------------------------

  /// Use the stored refresh token to silently obtain a new access token.
  ///
  /// Called by [BiometricService.authenticateAndLogin] after a successful
  /// biometric prompt — no OTP required.
  ///
  /// Throws if the refresh token is missing, expired, or the API call fails.
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

      final accessToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];

      await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
      await _storage.write(key: AppConstants.refreshTokenKey, value: newRefreshToken);

      final userId = JwtDecoder.getUserId(accessToken);
      final identifier = JwtDecoder.getIdentifier(accessToken);

      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        userId: userId,
        identifier: identifier,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.friendlyMessage);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    await _dioClient.clearTokens();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

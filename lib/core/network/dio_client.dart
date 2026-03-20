import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../app_config.dart';

/// Central HTTP client for SecureShield AI.
///
/// Features:
///   • Dynamic base URL (emulator ↔ real device via AppConfig)
///   • JWT auth interceptor with automatic token refresh
///   • User-friendly error messages — no raw DioException shown to user
///   • Retry on connection error with updated base URL
class DioClient {
  static DioClient? _instance;

  factory DioClient() {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        // ── Attach JWT to every request ───────────────────────────────────
        onRequest: (options, handler) async {
          // Always use the latest resolved URL (handles runtime URL changes)
          options.baseUrl = AppConstants.baseUrl;

          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        // ── Auto-refresh JWT on 401 ───────────────────────────────────────
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshToken =
                await _storage.read(key: AppConstants.refreshTokenKey);
            if (refreshToken != null) {
              try {
                final response = await Dio().post(
                  '${AppConstants.baseUrl}${AppConstants.refreshToken}',
                  data: {'refresh_token': refreshToken},
                );
                final newToken = response.data['access_token'];
                await _storage.write(
                  key: AppConstants.accessTokenKey,
                  value: newToken,
                );
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';
                final retryResponse = await dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                await _storage.deleteAll();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Invalidate the singleton so it's recreated with a new base URL.
  /// Call this after AppConfig.setCustomUrl().
  static void reset() => _instance = null;

  Future<void> clearTokens() async => await _storage.deleteAll();
}

// ---------------------------------------------------------------------------
// Extension: map DioException → friendly user message
// ---------------------------------------------------------------------------
extension DioErrorMessage on DioException {
  /// Returns a short, user-friendly error string.
  String get friendlyMessage {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet and try again.';

      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Make sure you are connected to Wi-Fi '
            'and the server is running.';

      case DioExceptionType.badResponse:
        final status = response?.statusCode ?? 0;
        final serverMsg = _extractServerMessage(response?.data);
        switch (status) {
          case 400:
            return serverMsg ?? 'Invalid request. Please check your input.';
          case 401:
            return 'Session expired. Please log in again.';
          case 403:
            return 'Access denied.';
          case 404:
            return 'Resource not found.';
          case 409:
            return serverMsg ?? 'Conflict — resource already exists.';
          case 422:
            return serverMsg ?? 'Validation failed. Please check your input.';
          case 429:
            return 'Too many requests. Please wait a moment and try again.';
          case 500:
          case 502:
          case 503:
            return 'Server error. Please try again shortly.';
          default:
            return serverMsg ?? 'Something went wrong (HTTP $status).';
        }

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.badCertificate:
        return 'SSL certificate error. Please contact support.';

      case DioExceptionType.unknown:
      default:
        // Catch network-unreachable OS errors
        final msg = message ?? '';
        if (msg.contains('SocketException') ||
            msg.contains('Connection refused') ||
            msg.contains('Network is unreachable')) {
          return 'Cannot connect to server. Make sure you are on the same '
              'Wi-Fi as the server.';
        }
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Pull the "error" or "detail" field from the server JSON response body.
  String? _extractServerMessage(dynamic data) {
    if (data is Map) {
      return (data['error'] ?? data['detail'])?.toString();
    }
    return null;
  }
}

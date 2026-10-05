import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../app_config.dart';

/// True if the Dio error is a low-level network/connection failure that
/// could be cured by re-resolving the backend host (e.g. dev IP changed,
/// backend bound to wrong interface, phone moved Wi-Fi networks).
bool _isConnectionFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.sendTimeout:
      return true;
    case DioExceptionType.unknown:
      final msg = e.message ?? '';
      return msg.contains('SocketException') ||
             msg.contains('Connection refused') ||
             msg.contains('Network is unreachable') ||
             msg.contains('Failed host lookup') ||
             msg.contains('No route to host');
    default:
      return false;
  }
}

/// Prevent redetect+retry loops — only re-probe once per request.
bool _isRedetectRetry(RequestOptions opts) =>
    opts.extra['_redetectRetry'] == true;

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

        // ── Auto-refresh JWT on 401 + auto-redetect on connection failure
        onError: (error, handler) async {
          // ─ 1. Connection-level failures → re-probe backend, retry once ─
          if (_isConnectionFailure(error) && !_isRedetectRetry(error.requestOptions)) {
            try {
              final swapped = await AppConfig.redetect();
              if (swapped) {
                // Mark this request so we don't loop forever.
                final retryOpts = error.requestOptions
                  ..baseUrl = AppConstants.baseUrl
                  ..extra['_redetectRetry'] = true;
                final retryResp = await dio.fetch(retryOpts);
                return handler.resolve(retryResp);
              }
            } catch (_) {/* fall through to the original error */}
          }

          // ─ 2. JWT auto-refresh on 401 ──────────────────────────────────
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

  /// Pull a user-facing message from the server JSON response body.
  ///
  /// Priority: `detail` first (FastAPI convention + this app's custom error
  /// middleware puts the *specific* message here, e.g. "An account with this
  /// email already exists"), then `error` (the generic friendly version like
  /// "Conflict — the resource already exists"), then `message`.
  String? _extractServerMessage(dynamic data) {
    if (data is Map) {
      return (data['detail'] ?? data['error'] ?? data['message'])?.toString();
    }
    return null;
  }
}

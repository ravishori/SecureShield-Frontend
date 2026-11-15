import 'package:dio/dio.dart';

import '../../core/constants.dart';
import '../../core/network/dio_client.dart';

/// Why an identity call failed, in terms the UI can act on. The backend stays authoritative: the client never
/// decides that something is verified, it only shows what the server says.
enum IdentityErrorKind {
  invalidCode, // 400 - wrong, expired, replayed or wrong-purpose code (the server answers all of them identically)
  claimed, // 409 - the e-mail / phone belongs to another account
  rateLimited, // 429
  offline, // no connection / timeout
  unavailable, // 5xx, or 503 "could not send the code"
  validation, // 422
  sessionExpired, // 401
  unknown,
}

class IdentityFailure implements Exception {
  final IdentityErrorKind kind;
  final String message;
  const IdentityFailure(this.kind, this.message);

  @override
  String toString() => message;
}

/// Maps any error from an identity call to an [IdentityFailure] with a user-facing message.
IdentityFailure mapIdentityError(Object error) {
  if (error is IdentityFailure) return error;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const IdentityFailure(
          IdentityErrorKind.offline,
          'No connection. Check your internet and try again.',
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final detail = _detail(error.response?.data);
        switch (status) {
          case 400:
            return IdentityFailure(
              IdentityErrorKind.invalidCode,
              detail ?? 'That code is invalid or has expired. Request a new one.',
            );
          case 401:
            return const IdentityFailure(
              IdentityErrorKind.sessionExpired,
              'Your session expired. Please log in again.',
            );
          case 409:
            return IdentityFailure(
              IdentityErrorKind.claimed,
              detail ?? 'This detail already belongs to another account.',
            );
          case 422:
            return IdentityFailure(
              IdentityErrorKind.validation,
              detail ?? 'Please check what you entered.',
            );
          case 429:
            return const IdentityFailure(
              IdentityErrorKind.rateLimited,
              'Too many attempts. Please wait a while and try again.',
            );
          default:
            if (status >= 500) {
              return const IdentityFailure(
                IdentityErrorKind.unavailable,
                'We could not complete that right now. Please try again shortly.',
              );
            }
        }
        break;
      default:
        break;
    }
  }
  return const IdentityFailure(IdentityErrorKind.unknown, 'Something went wrong. Please try again.');
}

String? _detail(Object? data) {
  if (data is Map) {
    final d = data['detail'];
    if (d is String && d.isNotEmpty) return d;
  }
  return null;
}

/// Verification flags exactly as the server reports them.
class IdentityState {
  final bool? emailVerified;
  final bool? phoneVerified;
  final String message;
  final String? maskedIdentifier;
  const IdentityState({
    this.emailVerified,
    this.phoneVerified,
    this.message = '',
    this.maskedIdentifier,
  });

  factory IdentityState.fromJson(Map<String, dynamic> j) => IdentityState(
        emailVerified: j['email_verified'] as bool?,
        phoneVerified: j['phone_verified'] as bool?,
        message: j['message'] as String? ?? '',
        maskedIdentifier: j['identifier'] as String?,
      );
}

/// Phone verification and e-mail change. Every call is authenticated (the Dio client adds the bearer token).
class IdentityApi {
  final Dio _dio;
  IdentityApi({Dio? dio}) : _dio = dio ?? DioClient().dio;

  Future<IdentityState> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post(path, data: body);
      return IdentityState.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw mapIdentityError(e);
    }
  }

  Future<IdentityState> startPhoneVerification(String phone) =>
      _post(AppConstants.phoneAddStart, {'phone': phone});

  Future<IdentityState> confirmPhone(String phone, String code) =>
      _post(AppConstants.phoneAddConfirm, {'phone': phone, 'code': code});

  Future<IdentityState> startEmailChange(String newEmail) =>
      _post(AppConstants.emailChangeStart, {'new_email': newEmail});

  Future<IdentityState> confirmEmailChange(String newEmail, String code) =>
      _post(AppConstants.emailChangeConfirm, {'new_email': newEmail, 'code': code});
}

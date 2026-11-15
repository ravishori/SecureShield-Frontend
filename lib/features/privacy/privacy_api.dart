import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../auth/identity_api.dart' show IdentityFailure, mapIdentityError;

/// One purpose as the SERVER reports it. The client never decides whether a consent is current.
class ConsentItem {
  final String purpose;
  final bool required;
  final String version;
  final bool? granted;
  final bool upToDate;
  const ConsentItem({
    required this.purpose,
    required this.required,
    required this.version,
    required this.granted,
    required this.upToDate,
  });

  factory ConsentItem.fromJson(Map<String, dynamic> j) => ConsentItem(
        purpose: j['purpose'] as String,
        required: j['required'] as bool? ?? false,
        version: j['version'] as String? ?? '',
        granted: j['granted'] as bool?,
        upToDate: j['up_to_date'] as bool? ?? false,
      );
}

class ConsentSnapshot {
  final List<ConsentItem> items;
  final bool requiredUpToDate;
  const ConsentSnapshot(this.items, this.requiredUpToDate);

  ConsentItem? item(String purpose) {
    for (final i in items) {
      if (i.purpose == purpose) return i;
    }
    return null;
  }

  factory ConsentSnapshot.fromJson(Map<String, dynamic> j) => ConsentSnapshot(
        [for (final i in (j['items'] as List)) ConsentItem.fromJson(Map<String, dynamic>.from(i as Map))],
        j['required_up_to_date'] as bool? ?? false,
      );
}

class DeletionStart {
  final String message;
  final String? maskedIdentifier;
  const DeletionStart(this.message, this.maskedIdentifier);
}

/// Consent decisions and the re-authenticated account deletion. Failures are [IdentityFailure]s with user-facing text.
class PrivacyApi {
  final Dio _dio;
  PrivacyApi({Dio? dio}) : _dio = dio ?? DioClient().dio;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw mapIdentityError(e);
    }
  }

  Future<ConsentSnapshot> getConsents() => _guard(() async {
        final r = await _dio.get('/auth/consents');
        return ConsentSnapshot.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<ConsentSnapshot> putConsent(String purpose, bool granted, String version) => _guard(() async {
        final r = await _dio.put('/auth/consents', data: {'purpose': purpose, 'granted': granted, 'version': version});
        return ConsentSnapshot.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  /// Sends the confirmation code. Nothing is deleted by this call.
  Future<DeletionStart> startDeletion() => _guard(() async {
        final r = await _dio.post('/auth/me/delete/start');
        final m = Map<String, dynamic>.from(r.data as Map);
        return DeletionStart(m['message'] as String? ?? '', m['identifier'] as String?);
      });

  /// Deletes the account. Returns normally ONLY when the server answered 200; any other outcome throws.
  Future<void> deleteAccount(String code) => _guard(() async {
        final r = await _dio.delete('/auth/me', data: {'confirm': 'DELETE', 'code': code});
        if (r.statusCode != 200) {
          throw DioException(requestOptions: r.requestOptions, response: r, type: DioExceptionType.badResponse);
        }
      });
}

final privacyApiProvider = Provider<PrivacyApi>((ref) => PrivacyApi());

typedef PrivacyFailure = IdentityFailure;

/// Safe error text for the UI and for diagnostics (Stage 1.6D-4).
///
/// An exception's own text is written for developers: it can contain a full request URL with query parameters, a token, the
/// server's reply, a file path or a phone number. It must never be shown to the user or logged as is. The UI shows
/// [safeErrorMessage]; diagnostics log [safeErrorSummary]: the exception TYPE and, for HTTP, its status code. Nothing else.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A short, understandable message for [error]. Never contains the exception's own text.
///
/// [prefix] is the action that failed, for example `Check failed`; the result is `"Check failed. <reason>"`.
String safeErrorMessage(Object? error, {String? prefix}) {
  final reason = _reason(error);
  return prefix == null || prefix.trim().isEmpty ? reason : '${prefix.trim().replaceAll(RegExp(r'[.:]+$'), '')}. $reason';
}

String _reason(Object? error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'A secure connection could not be made. Please try again on a trusted network.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode ?? 0;
        if (code == 401) return 'Your session has ended. Please sign in again.';
        if (code == 403) return 'You do not have permission to do that.';
        if (code == 404) return 'That item could not be found.';
        if (code == 429) return 'Too many attempts. Please wait a minute and try again.';
        if (code >= 500) return 'The SecureShield server is having trouble. Please try again later.';
        return 'The request could not be completed. Please check it and try again.';
      case DioExceptionType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }
  if (error is FormatException || error is TypeError) {
    return 'The response could not be understood. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

/// Privacy-safe one-line description for logs: exception type, plus the HTTP status or Dio kind. No message, URL, body or stack.
String safeErrorSummary(Object? error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    return 'DioException(${error.type.name}${code == null ? '' : ', $code'})';
  }
  return error == null ? 'null' : error.runtimeType.toString();
}

/// Logs [safeErrorSummary] under [tag]. Debug builds only: a release build writes nothing.
void logSafeError(String tag, Object? error) {
  if (kDebugMode) debugPrint('[$tag] ${safeErrorSummary(error)}');
}

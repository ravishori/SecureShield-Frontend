// Stage 1.6D-4: errors shown to the user or logged never carry URLs, tokens or response text.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/utils/safe_error.dart';

const _token = 'SEKRET-TOKEN-99';

DioException dio(DioExceptionType type, {int? status, Object? data}) {
  final req = RequestOptions(path: 'https://api.example.test/v1/scan?token=$_token&phone=9876543210');
  return DioException(
    requestOptions: req,
    type: type,
    message: 'failed for https://api.example.test/v1/scan?token=$_token',
    response: status == null ? null : Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('safeErrorMessage', () {
    test('never contains the exception text, the URL, a token or a response body', () {
      final errors = <Object>[
        dio(DioExceptionType.connectionTimeout),
        dio(DioExceptionType.connectionError),
        dio(DioExceptionType.badResponse, status: 500, data: {'detail': 'otp 482913 for $_token'}),
        dio(DioExceptionType.badResponse, status: 422, data: 'phone 9876543210'),
        const FormatException('bad $_token'),
        Exception('boom $_token 9876543210'),
        StateError('x'),
      ];
      for (final e in errors) {
        final m = safeErrorMessage(e, prefix: 'Check failed');
        for (final raw in [_token, '9876543210', '482913', 'api.example.test', 'token=', 'Exception']) {
          expect(m.contains(raw), isFalse, reason: '$raw in "$m"');
        }
        expect(m.startsWith('Check failed.'), isTrue);
      }
    });

    test('maps the common failures to understandable text', () {
      expect(safeErrorMessage(dio(DioExceptionType.connectionError)), contains('No internet connection'));
      expect(safeErrorMessage(dio(DioExceptionType.receiveTimeout)), contains('taking too long'));
      expect(safeErrorMessage(dio(DioExceptionType.badResponse, status: 401)), contains('sign in again'));
      expect(safeErrorMessage(dio(DioExceptionType.badResponse, status: 429)), contains('Too many attempts'));
      expect(safeErrorMessage(dio(DioExceptionType.badResponse, status: 503)), contains('server is having trouble'));
      expect(safeErrorMessage(null), contains('Something went wrong'));
    });

    test('prefix punctuation is normalised', () {
      expect(safeErrorMessage(StateError('x'), prefix: 'Failed:'), startsWith('Failed. '));
      expect(safeErrorMessage(StateError('x'), prefix: '  '), startsWith('Something went wrong'));
    });
  });

  group('safeErrorSummary', () {
    test('keeps the type and status only', () {
      expect(safeErrorSummary(dio(DioExceptionType.badResponse, status: 500)), 'DioException(badResponse, 500)');
      expect(safeErrorSummary(dio(DioExceptionType.connectionError)), 'DioException(connectionError)');
      expect(safeErrorSummary(StateError('with $_token')), 'StateError');
      expect(safeErrorSummary(null), 'null');
      expect(safeErrorSummary(dio(DioExceptionType.unknown, status: 400)).contains(_token), isFalse);
    });
  });

  test('source guard: no UI string interpolates a caught exception', () {
    // Text(...) / SnackBar(...) / errorMessage: / _error = / _showSnack(...) built from $e, $err, $error or ${e...}
    // Only `$e`, `${e}`, `${e.toString()}` and `${e.message...}`: `${e.sender}` or `${e.key}` on a loop variable is not an exception.
    final ui = RegExp(
      r'(Text\(|SnackBar\(|errorMessage:|_error\s*=|_showSnack\()[^;\n]*'
      r'(\$(e|err|error|ex|exception)\b(?!\.)|\$\{(e|err|error|ex|exception)(\.toString\(\)|\.message[^}]*)?\})',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (ui.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

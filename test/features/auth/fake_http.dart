import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Records every request and answers from a handler - no network.
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final ResponseBody Function(RequestOptions) handler;
  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// An unsigned JWT-shaped string carrying the given claims (the app only decodes the payload).
String fakeJwt(Map<String, dynamic> claims) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.${seg(claims)}.sig';
}

Dio dioWith(FakeAdapter a) {
  final d = Dio(BaseOptions(baseUrl: 'http://test'));
  d.httpClientAdapter = a;
  return d;
}

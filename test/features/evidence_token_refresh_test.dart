// Real HTTP over loopback against a small in-test server, using the app's real DioClient (auth + 401 refresh
// interceptor) and the real EvidenceApi. Only the platform plugins are mocked (flutter_secure_storage and
// shared_preferences). This proves the expired-access-token path of a *download*; it does not exercise a real
// backend, a real device, or the Android share sheet.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/app_config.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/features/evidence/evidence_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = '3f2b8c1e-5a47-4d0e-9b61-0c7d2e8a1f44';
final _payload = List<int>.generate(70000, (i) => (i * 31 + 7) % 256);

class _Backend {
  late HttpServer server;
  int refreshCalls = 0;
  int downloadCalls = 0;
  final authHeaders = <String?>[];
  String validRefresh = 'refresh-ok';
  String validAccess = 'access-new';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      if (req.method == 'POST' && req.uri.path == '/api/v1/auth/refresh') {
        refreshCalls++;
        final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
        if (body['refresh_token'] == validRefresh) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({'access_token': validAccess, 'refresh_token': 'refresh-rotated'}));
        } else {
          res.statusCode = 401;
        }
      } else if (req.method == 'GET' && req.uri.path == '/api/v1/evidence/$_id/download') {
        downloadCalls++;
        authHeaders.add(req.headers.value('authorization'));
        if (req.headers.value('authorization') == 'Bearer $validAccess') {
          res.headers.set('content-disposition', 'attachment; filename="proof.bin"');
          res.headers.contentType = ContentType.binary;
          res.add(_payload);
        } else {
          res.statusCode = 401;
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({'detail': 'Not authenticated'}));
        }
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
  }

  String get baseUrl => 'http://127.0.0.1:${server.port}/api/v1';
  Future<void> stop() => server.close(force: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // flutter_test blocks real sockets by default

  late _Backend backend;
  late Directory root;

  setUp(() async {
    backend = _Backend();
    await backend.start();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-expired',
      'refresh_token': 'refresh-ok',
    });
    DioClient.reset();
    await AppConfig.setCustomUrl(backend.baseUrl);
    root = await Directory.systemTemp.createTemp('evidence_refresh_test');
  });

  tearDown(() async {
    await backend.stop();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('an expired access token is refreshed once and the download is retried with the new token', () async {
    final file = await EvidenceApi().downloadEvidence(
      id: _id,
      downloadsRoot: root,
      expectedBytes: _payload.length,
    );

    expect(await file.readAsBytes(), _payload);
    expect(backend.refreshCalls, 1);
    expect(backend.downloadCalls, 2);
    expect(backend.authHeaders, ['Bearer access-expired', 'Bearer access-new']);
    expect(Directory('${root.path}${Platform.pathSeparator}$_id').listSync().map((e) => e.path.split(Platform.pathSeparator).last),
        ['proof.bin']);
  });

  test('a rejected refresh token fails the download cleanly and leaves nothing on disk', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-expired',
      'refresh_token': 'refresh-revoked',
    });
    DioClient.reset();

    await expectLater(
      EvidenceApi().downloadEvidence(id: _id, downloadsRoot: root),
      throwsA(isA<EvidenceDownloadException>().having((e) => e.gone, 'gone', false)),
    );
    expect(backend.refreshCalls, 1);
    expect(backend.downloadCalls, 1);
    expect(Directory('${root.path}${Platform.pathSeparator}$_id').listSync(), isEmpty);
  });

  test('a valid access token needs no refresh', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'access-new', 'refresh_token': 'refresh-ok'});
    DioClient.reset();

    final file = await EvidenceApi().downloadEvidence(id: _id, downloadsRoot: root);
    expect(await file.readAsBytes(), _payload);
    expect(backend.refreshCalls, 0);
    expect(backend.downloadCalls, 1);
  });
}

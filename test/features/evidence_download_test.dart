import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/evidence/evidence_api.dart';

const _id = '3f2b8c1e-5a47-4d0e-9b61-0c7d2e8a1f44';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(List<int> bytes, {String? disposition}) => ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        if (disposition != null) 'content-disposition': [disposition],
        'content-length': ['${bytes.length}'],
      },
    );

ResponseBody _status(int code) =>
    ResponseBody.fromString(jsonEncode({'detail': 'x'}), code, headers: {
      'content-type': ['application/json'],
    });

EvidenceApi _api(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'))
    ..httpClientAdapter = adapter;
  return EvidenceApi(dio: dio);
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('evidence_dl_test');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('downloadEvidence', () {
    test('saves the exact bytes under the server-provided name', () async {
      final bytes = List<int>.generate(5000, (i) => (i * 7) % 256);
      final adapter = _FakeAdapter(
          (_) => _ok(bytes, disposition: 'attachment; filename="report.pdf"'));
      final file = await _api(adapter)
          .downloadEvidence(id: _id, downloadsRoot: root, expectedBytes: bytes.length);

      expect(await file.readAsBytes(), bytes);
      expect(file.path.endsWith('report.pdf'), isTrue);
      expect(file.parent.path, '${root.path}${Platform.pathSeparator}$_id');
      expect(adapter.requests.single.path, endsWith('/evidence/$_id/download'));
      expect(File('${file.parent.path}${Platform.pathSeparator}download.part').existsSync(), isFalse);
    });

    test('a 404 is reported as gone and leaves no file behind', () async {
      final adapter = _FakeAdapter((_) => _status(404));
      await expectLater(
        _api(adapter).downloadEvidence(id: _id, downloadsRoot: root),
        throwsA(isA<EvidenceDownloadException>().having((e) => e.gone, 'gone', true)),
      );
      expect(Directory('${root.path}${Platform.pathSeparator}$_id').listSync(), isEmpty);
    });

    test('401, 403 and 500 are failures but not "gone"', () async {
      for (final code in [401, 403, 500]) {
        final adapter = _FakeAdapter((_) => _status(code));
        await expectLater(
          _api(adapter).downloadEvidence(id: _id, downloadsRoot: root),
          throwsA(isA<EvidenceDownloadException>().having((e) => e.gone, 'gone', false)),
        );
        expect(Directory('${root.path}${Platform.pathSeparator}$_id').listSync(), isEmpty,
            reason: 'status $code');
      }
    });

    test('a transfer shorter than the recorded size is rejected and removed', () async {
      final adapter = _FakeAdapter((_) => _ok([1, 2, 3], disposition: 'attachment; filename="a.txt"'));
      await expectLater(
        _api(adapter).downloadEvidence(id: _id, downloadsRoot: root, expectedBytes: 10),
        throwsA(isA<EvidenceDownloadException>()),
      );
      expect(Directory('${root.path}${Platform.pathSeparator}$_id').listSync(), isEmpty);
    });

    test('an empty body is rejected', () async {
      final adapter = _FakeAdapter((_) => _ok(const []));
      await expectLater(
        _api(adapter).downloadEvidence(id: _id, downloadsRoot: root),
        throwsA(isA<EvidenceDownloadException>()),
      );
    });

    test('a non-UUID id is refused without any request', () async {
      final adapter = _FakeAdapter((_) => _ok([1]));
      for (final bad in ['../../etc/passwd', 'not-a-uuid', '', '$_id/../x']) {
        await expectLater(
          _api(adapter).downloadEvidence(id: bad, downloadsRoot: root),
          throwsA(isA<EvidenceDownloadException>()),
        );
      }
      expect(adapter.requests, isEmpty);
    });

    test('a hostile file name cannot escape the download directory', () async {
      final adapter = _FakeAdapter(
          (_) => _ok([9, 9], disposition: 'attachment; filename="../../../evil.sh"'));
      final file = await _api(adapter).downloadEvidence(id: _id, downloadsRoot: root);
      expect(file.parent.path, '${root.path}${Platform.pathSeparator}$_id');
      expect(file.path.endsWith('evil.sh'), isTrue);
    });

    test('a failure never leaves an earlier copy of the same item overwritten half-way', () async {
      final first = _FakeAdapter((_) => _ok([1, 2, 3, 4], disposition: 'attachment; filename="a.bin"'));
      final f = await _api(first).downloadEvidence(id: _id, downloadsRoot: root, expectedBytes: 4);
      final bad = _FakeAdapter((_) => _status(500));
      await expectLater(_api(bad).downloadEvidence(id: _id, downloadsRoot: root), throwsA(isA<EvidenceDownloadException>()));
      expect(await f.readAsBytes(), [1, 2, 3, 4]);
    });
  });

  group('safeEvidenceFileName', () {
    test('handles quoted, bare and RFC 5987 forms', () {
      expect(safeEvidenceFileName('attachment; filename="scan.png"'), 'scan.png');
      expect(safeEvidenceFileName('attachment; filename=scan.png'), 'scan.png');
      expect(safeEvidenceFileName("attachment; filename*=utf-8''r%C3%A9sum%C3%A9.pdf"), 'résumé.pdf');
    });

    test('strips directories, control and reserved characters, leading dots', () {
      expect(safeEvidenceFileName('attachment; filename="a/b\\c.txt"'), 'c.txt');
      expect(safeEvidenceFileName('attachment; filename="..\\..\\x.txt"'), 'x.txt');
      expect(safeEvidenceFileName('attachment; filename=".hidden"'), 'hidden');
      expect(safeEvidenceFileName('attachment; filename="a:b*c?.txt"'), 'a_b_c_.txt');
    });

    test('falls back to a fixed name and bounds the length', () {
      expect(safeEvidenceFileName(null), 'evidence');
      expect(safeEvidenceFileName(''), 'evidence');
      expect(safeEvidenceFileName('attachment; filename=".."'), 'evidence');
      final long = safeEvidenceFileName('attachment; filename="${'x' * 300}.pdf"');
      expect(long.length, 100);
      expect(long.endsWith('.pdf'), isTrue);
    });
  });

  test('purgeDownloads removes every downloaded copy and tolerates a missing folder', () async {
    final adapter = _FakeAdapter((_) => _ok([1, 2], disposition: 'attachment; filename="a.bin"'));
    final api = _api(adapter);
    await api.downloadEvidence(id: _id, downloadsRoot: root);
    await api.purgeDownloads(root);
    expect(root.existsSync(), isFalse);
    await api.purgeDownloads(root); // no throw
  });
}

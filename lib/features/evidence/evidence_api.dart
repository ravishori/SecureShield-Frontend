import 'dart:io';

import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

/// Raised when a stored evidence file cannot be retrieved.
/// [gone] is true when the server says the item or its file no longer exists (404).
class EvidenceDownloadException implements Exception {
  final bool gone;
  final String message;
  const EvidenceDownloadException(this.message, {this.gone = false});

  @override
  String toString() => 'EvidenceDownloadException($message)';
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// A file name that is safe to create on disk, taken from a Content-Disposition header.
/// Never contains a path separator, control character or reserved character; falls back to `evidence`.
String safeEvidenceFileName(String? contentDisposition) {
  var name = '';
  final header = contentDisposition ?? '';
  final star = RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)", caseSensitive: false)
      .firstMatch(header);
  if (star != null) {
    try {
      name = Uri.decodeComponent(star.group(1)!.trim());
    } catch (_) {
      name = '';
    }
  }
  if (name.isEmpty) {
    final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
        .firstMatch(header);
    name = plain?.group(1)?.trim() ?? '';
  }
  name = name.split(RegExp(r'[\\/]')).last;
  name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f:*?"<>|]'), '_').trim();
  name = name.replaceAll(RegExp(r'^[.\s]+'), '');
  if (name.length > 100) {
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 && name.length - dot <= 10 ? name.substring(dot) : '';
    name = name.substring(0, 100 - ext.length) + ext;
  }
  return name.isEmpty ? 'evidence' : name;
}

class EvidenceApi {
  EvidenceApi({Dio? dio}) : _injected = dio;

  final Dio? _injected;
  Dio get _dio => _injected ?? DioClient().dio;

  Future<List<dynamic>> getEvidence() async {
    final response = await _dio.get(AppConstants.evidence);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> uploadEvidence({
    required String title,
    String? description,
    String? caseId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      if (description != null) 'description': description,
      if (caseId != null) 'case_id': caseId,
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      AppConstants.evidenceUpload,
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _dio.delete('${AppConstants.evidence}/$id');
  }

  /// Downloads the caller's own evidence item into `<downloadsRoot>/<id>/<name>` and returns the file.
  ///
  /// The server enforces ownership (another user's id is a 404) and decrypts at-rest encryption itself.
  /// The file is written under a temporary name and only renamed once its length equals [expectedBytes]
  /// (when known), so a truncated transfer is never presented as the evidence. On any failure nothing is left behind.
  Future<File> downloadEvidence({
    required String id,
    required Directory downloadsRoot,
    int? expectedBytes,
  }) async {
    if (!_uuidPattern.hasMatch(id)) {
      throw const EvidenceDownloadException('Invalid evidence id', gone: true);
    }
    final dir = Directory('${downloadsRoot.path}${Platform.pathSeparator}$id');
    await dir.create(recursive: true);
    final part = File('${dir.path}${Platform.pathSeparator}download.part');
    try {
      final response = await _dio.download(
        '${AppConstants.evidence}/$id/download',
        part.path,
        deleteOnError: true,
      );
      final name = safeEvidenceFileName(
        response.headers.value('content-disposition'),
      );
      final length = await part.length();
      if (length == 0 || (expectedBytes != null && expectedBytes > 0 && length != expectedBytes)) {
        throw const EvidenceDownloadException('Incomplete download');
      }
      final target = File('${dir.path}${Platform.pathSeparator}$name');
      if (await target.exists()) await target.delete();
      return await part.rename(target.path);
    } on DioException catch (e) {
      final gone = e.response?.statusCode == 404;
      throw EvidenceDownloadException(
        gone ? 'Evidence not found' : 'Download failed',
        gone: gone,
      );
    } on EvidenceDownloadException {
      rethrow;
    } catch (_) {
      throw const EvidenceDownloadException('Download failed');
    } finally {
      if (await part.exists()) await part.delete();
    }
  }

  /// Removes downloaded copies (they are sensitive and only needed while being opened/shared).
  ///
  /// With [olderThan] only per-item folders not modified within that window are removed. The share sheet hands the
  /// receiving app a content URI that it may read long after the sheet (or this screen) is gone - e-mail attachments
  /// and cloud uploads are read when sent - so a copy must outlive the screen that created it by a grace period.
  /// Without [olderThan] everything is removed.
  Future<void> purgeDownloads(
    Directory downloadsRoot, {
    Duration? olderThan,
    DateTime? now, // test seam
  }) async {
    if (!await downloadsRoot.exists()) return;
    if (olderThan == null) {
      await downloadsRoot.delete(recursive: true);
      return;
    }
    final cutoff = (now ?? DateTime.now()).subtract(olderThan);
    await for (final entry in downloadsRoot.list()) {
      try {
        if ((await entry.stat()).modified.isBefore(cutoff)) {
          await entry.delete(recursive: true);
        }
      } catch (_) {/* best effort: a file still in use or already gone */}
    }
  }
}

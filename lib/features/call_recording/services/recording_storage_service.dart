import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/security/encryption_service.dart';

/// Metadata stored alongside each saved recording.
class RecordingMeta {
  final String id;
  final String title;
  final String filePath;     // path to the encrypted .enc file
  final int durationSeconds;
  final int fileSizeBytes;
  final DateTime createdAt;
  final bool isEncrypted;

  const RecordingMeta({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.isEncrypted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'durationSeconds': durationSeconds,
        'fileSizeBytes': fileSizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'isEncrypted': isEncrypted,
      };

  factory RecordingMeta.fromJson(Map<String, dynamic> j) => RecordingMeta(
        id: j['id'] as String,
        title: j['title'] as String,
        filePath: j['filePath'] as String,
        durationSeconds: j['durationSeconds'] as int? ?? 0,
        fileSizeBytes: j['fileSizeBytes'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        isEncrypted: j['isEncrypted'] as bool? ?? true,
      );
}

/// Handles encrypted persistence of audio recording files.
///
/// Files are stored in the app's support directory (private sandbox).
/// Each file is AES-256-CBC encrypted via [EncryptionService].
/// A metadata index is persisted to [SharedPreferences].
class RecordingStorageService {
  RecordingStorageService._();

  static const _prefKey = 'recording_meta_list';

  // ── Directories ─────────────────────────────────────────────────────────────

  static Future<Directory> _storageDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/secure_recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/rec_decrypt');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Save (encrypt + persist metadata) ─────────────────────────────────────

  /// Reads [tempPath], encrypts the file bytes, writes to the private storage
  /// directory, and persists metadata.  Returns the [RecordingMeta].
  static Future<RecordingMeta> saveEncrypted({
    required String tempPath,
    required String title,
    required int durationSeconds,
  }) async {
    final srcFile = File(tempPath);
    final bytes = await srcFile.readAsBytes();
    final base64Raw = base64.encode(bytes);

    // AES-256-CBC via EncryptionService (encrypts base64 string)
    final encrypted = EncryptionService.encrypt(base64Raw);

    final id = const Uuid().v4();
    final dir = await _storageDir();
    final destPath = '${dir.path}/$id.enc';
    await File(destPath).writeAsString(encrypted);

    final meta = RecordingMeta(
      id: id,
      title: title,
      filePath: destPath,
      durationSeconds: durationSeconds,
      fileSizeBytes: bytes.lengthInBytes,
      createdAt: DateTime.now(),
      isEncrypted: true,
    );

    await _appendMeta(meta);
    debugPrint('[RecordingStorage] Saved encrypted → $destPath');
    return meta;
  }

  // ── Decrypt for playback ───────────────────────────────────────────────────

  /// Decrypts the recording at [meta.filePath] and writes it to a temporary
  /// file for playback.  Returns the temp file path.
  ///
  /// Caller is responsible for deleting the temp file after use.
  static Future<String> decryptForPlayback(RecordingMeta meta) async {
    if (!meta.isEncrypted) return meta.filePath;

    final encrypted = await File(meta.filePath).readAsString();
    final base64Raw = EncryptionService.decrypt(encrypted);
    final bytes = Uint8List.fromList(base64.decode(base64Raw));

    final tempDir = await _tempDir();
    final tempPath = '${tempDir.path}/${meta.id}_play.aac';
    await File(tempPath).writeAsBytes(bytes);

    debugPrint('[RecordingStorage] Decrypted to temp → $tempPath');
    return tempPath;
  }

  /// Returns the raw decrypted bytes for a recording (use for upload/share).
  static Future<Uint8List> decryptToBytes(RecordingMeta meta) async {
    if (!meta.isEncrypted) return File(meta.filePath).readAsBytes();

    final encrypted = await File(meta.filePath).readAsString();
    final base64Raw = EncryptionService.decrypt(encrypted);
    return Uint8List.fromList(base64.decode(base64Raw));
  }

  // ── Metadata CRUD ──────────────────────────────────────────────────────────

  static Future<List<RecordingMeta>> listRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecordingMeta.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('[RecordingStorage] listRecordings parse error: $e');
      return [];
    }
  }

  static Future<void> deleteRecording(String id) async {
    final recordings = await listRecordings();
    final meta = recordings.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Recording not found'),
    );

    // Delete encrypted file
    final file = File(meta.filePath);
    if (await file.exists()) await file.delete();

    // Remove from metadata list
    final updated = recordings.where((r) => r.id != id).toList();
    await _saveMeta(updated);
    debugPrint('[RecordingStorage] Deleted recording $id');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<void> _appendMeta(RecordingMeta meta) async {
    final existing = await listRecordings();
    existing.insert(0, meta);
    await _saveMeta(existing);
  }

  static Future<void> _saveMeta(List<RecordingMeta> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(list.map((r) => r.toJson()).toList()));
  }
}

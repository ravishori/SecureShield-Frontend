import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One bank OTP the monitor intercepted and saved for the user.
class VaultEntry {
  VaultEntry({
    required this.id,
    required this.sender,
    required this.otp,
    required this.sourceApp,
    required this.receivedAt,
    this.isRead = false,
    this.isArchived = false,
  });

  final String id;
  final String sender;
  final String otp;
  final String sourceApp;
  final DateTime receivedAt;
  bool isRead;
  bool isArchived;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'otp': otp,
        'sourceApp': sourceApp,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
        'isArchived': isArchived,
      };

  static VaultEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return VaultEntry(
        id: raw['id'] as String,
        sender: raw['sender'] as String? ?? '',
        otp: raw['otp'] as String? ?? '',
        sourceApp: raw['sourceApp'] as String? ?? '',
        receivedAt: DateTime.parse(raw['receivedAt'] as String),
        isRead: raw['isRead'] as bool? ?? false,
        isArchived: raw['isArchived'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Device-local vault. Everything lives in the Android Keystore-backed secure storage (never the backend,
/// never plain preferences); reading it from the UI additionally requires the user to authenticate.
class OtpVaultStore {
  OtpVaultStore({FlutterSecureStorage? storage, this.maxEntries = 200})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'otp_vault_v1';
  final FlutterSecureStorage _storage;
  final int maxEntries;

  Future<List<VaultEntry>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.map(VaultEntry.fromJson).whereType<VaultEntry>().toList();
    } catch (e) {
      debugPrint('[OtpVault] load failed: ${e.runtimeType}');
      return [];
    }
  }

  Future<void> _save(List<VaultEntry> entries) async {
    await _storage.write(
      key: _key,
      value: json.encode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Adds an OTP unless the same code from the same sender arrived in the last two minutes (the listener can
  /// see the same notification twice).
  Future<bool> add({
    required String sender,
    required String otp,
    required String sourceApp,
    DateTime? now,
  }) async {
    if (otp.isEmpty) return false;
    final at = now ?? DateTime.now();
    final entries = await load();
    final duplicate = entries.any((e) =>
        e.otp == otp && e.sender == sender && at.difference(e.receivedAt).inSeconds.abs() < 120);
    if (duplicate) return false;
    entries.insert(
      0,
      VaultEntry(
        id: '${at.microsecondsSinceEpoch}',
        sender: sender,
        otp: otp,
        sourceApp: sourceApp,
        receivedAt: at,
      ),
    );
    if (entries.length > maxEntries) entries.removeRange(maxEntries, entries.length);
    await _save(entries);
    return true;
  }

  Future<void> markRead(String id) => _update(id, (e) => e.isRead = true);

  Future<void> setArchived(String id, bool archived) => _update(id, (e) => e.isArchived = archived);

  Future<void> delete(String id) async {
    final entries = await load();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  Future<void> clear() => _storage.delete(key: _key);

  Future<void> _update(String id, void Function(VaultEntry) change) async {
    final entries = await load();
    for (final e in entries.where((e) => e.id == id)) {
      change(e);
    }
    await _save(entries);
  }
}

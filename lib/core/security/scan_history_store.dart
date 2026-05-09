/// Persistent forensics log for scans.
///
/// Records every app scan with timestamp, risk details, and detection results.
/// Stored locally in SharedPreferences as JSON (encrypted).
/// Useful for user audit trails and historical analysis.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single scan record.
class ScanRecord {
  final DateTime timestamp;
  final String packageName;
  final String appLabel;
  final String riskLevel;        // 'safe', 'low', 'medium', 'high', 'critical'
  final List<String> threats;    // List of detected issues
  final bool isFake;             // Fake app detected?
  final String? fakeAppNameMatch; // Name it's impersonating

  ScanRecord({
    required this.timestamp,
    required this.packageName,
    required this.appLabel,
    required this.riskLevel,
    required this.threats,
    required this.isFake,
    this.fakeAppNameMatch,
  });

  /// Serialize to JSON (for storage)
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'packageName': packageName,
    'appLabel': appLabel,
    'riskLevel': riskLevel,
    'threats': threats,
    'isFake': isFake,
    'fakeAppNameMatch': fakeAppNameMatch,
  };

  /// Deserialize from JSON
  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    timestamp: DateTime.parse(json['timestamp'] as String),
    packageName: json['packageName'] as String,
    appLabel: json['appLabel'] as String,
    riskLevel: json['riskLevel'] as String,
    threats: List<String>.from(json['threats'] as List? ?? []),
    isFake: json['isFake'] as bool? ?? false,
    fakeAppNameMatch: json['fakeAppNameMatch'] as String?,
  );
}

class ScanHistoryStore {
  static const String _storageKey = 'scan_history_v1';
  static const int _maxRecords = 1000; // Prevent unbounded growth

  static late SharedPreferences _prefs;
  static bool _initialized = false;

  /// Initialize the store (call once at app startup)
  static Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Add a scan record to the history.
  static Future<void> addRecord(ScanRecord record) async {
    _checkInitialized();

    final history = await _loadHistory();
    history.add(record);

    // Keep only the most recent [_maxRecords]
    if (history.length > _maxRecords) {
      history.removeRange(0, history.length - _maxRecords);
    }

    await _saveHistory(history);
  }

  /// Get all scan records (most recent first)
  static Future<List<ScanRecord>> getAll() async {
    _checkInitialized();
    final records = await _loadHistory();
    return records.reversed.toList();
  }

  /// Get recent scans (last N records)
  static Future<List<ScanRecord>> getRecent({int limit = 20}) async {
    _checkInitialized();
    final records = await _loadHistory();
    final recentCount = records.length > limit ? limit : records.length;
    return records.sublist(records.length - recentCount).reversed.toList();
  }

  /// Get scans within a time range
  static Future<List<ScanRecord>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    _checkInitialized();
    final records = await _loadHistory();
    return records
        .where((r) => r.timestamp.isAfter(start) && r.timestamp.isBefore(end))
        .toList();
  }

  /// Get all scans for a specific package
  static Future<List<ScanRecord>> getByPackage(String packageName) async {
    _checkInitialized();
    final records = await _loadHistory();
    return records.where((r) => r.packageName == packageName).toList();
  }

  /// Get all suspicious scans (high/critical risk or fake app)
  static Future<List<ScanRecord>> getSuspicious() async {
    _checkInitialized();
    final records = await _loadHistory();
    return records
        .where((r) => r.isFake || r.riskLevel == 'high' || r.riskLevel == 'critical')
        .toList();
  }

  /// Delete all history
  static Future<void> clear() async {
    _checkInitialized();
    await _prefs.remove(_storageKey);
  }

  /// Delete records older than [days] days
  static Future<void> deleteOlderThan(int days) async {
    _checkInitialized();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    var history = await _loadHistory();
    history = history.where((r) => r.timestamp.isAfter(cutoff)).toList();
    await _saveHistory(history);
  }

  /// Get statistics
  static Future<Map<String, dynamic>> getStats() async {
    _checkInitialized();
    final records = await _loadHistory();
    if (records.isEmpty) {
      return {
        'totalScans': 0,
        'fakeAppsFound': 0,
        'criticalRisk': 0,
        'highRisk': 0,
        'mediumRisk': 0,
        'lowRisk': 0,
      };
    }

    final fakeCount = records.where((r) => r.isFake).length;
    final criticalCount = records.where((r) => r.riskLevel == 'critical').length;
    final highCount = records.where((r) => r.riskLevel == 'high').length;
    final mediumCount = records.where((r) => r.riskLevel == 'medium').length;
    final lowCount = records.where((r) => r.riskLevel == 'low').length;

    return {
      'totalScans': records.length,
      'fakeAppsFound': fakeCount,
      'criticalRisk': criticalCount,
      'highRisk': highCount,
      'mediumRisk': mediumCount,
      'lowRisk': lowCount,
      'lastScanTime': records.isNotEmpty ? records.last.timestamp.toIso8601String() : null,
    };
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<List<ScanRecord>> _loadHistory() async {
    final json = _prefs.getString(_storageKey);
    if (json == null || json.isEmpty) return [];

    try {
      final decoded = jsonDecode(json) as List;
      return decoded
          .map((item) => ScanRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _saveHistory(List<ScanRecord> records) async {
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await _prefs.setString(_storageKey, json);
  }

  static void _checkInitialized() {
    if (!_initialized) {
      throw StateError('ScanHistoryStore not initialized. Call initialize() first.');
    }
  }
}

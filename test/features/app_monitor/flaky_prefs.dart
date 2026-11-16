import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/app_monitor/monitor_sync_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The (mocked) SharedPreferences with writes that can be made to fail, the way a full or locked disk does.
/// Reads always work; use a throwing `preferences:` accessor to simulate unreadable storage instead.
class FlakyPrefs extends Fake implements SharedPreferences {
  FlakyPrefs(this.real);

  final SharedPreferences real;

  /// Writes answer `false` (refused) without storing anything.
  bool refuseWrites = false;

  /// Writes throw.
  bool throwOnWrite = false;

  /// Only integer writes are refused (the earlier two-value layout's deadline).
  bool refuseSetInt = false;

  /// Writes answer `true` but store nothing (a lying store): only a read-back can tell.
  bool dropSilently = false;

  /// Removals answer `false` without removing anything.
  bool refuseRemove = false;

  /// Removals of just these keys are refused.
  final Set<String> refuseRemoveKeys = {};

  @override
  Object? get(String key) => real.get(key);

  @override
  Future<bool> setString(String key, String value) async {
    if (throwOnWrite) throw StateError('write failed');
    if (refuseWrites) return false;
    if (dropSilently) return true;
    return real.setString(key, value);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (throwOnWrite) throw StateError('write failed');
    if (refuseWrites || refuseSetInt) return false;
    if (dropSilently) return true;
    return real.setInt(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (throwOnWrite) throw StateError('remove failed');
    if (refuseRemove || refuseRemoveKeys.contains(key)) return false;
    return real.remove(key);
  }
}

const restrictionKey = MonitorSyncCoordinator.endpointRestrictionKey;
const legacyCodeKey = MonitorSyncCoordinator.endpointProblemKey;
const legacyUntilKey = MonitorSyncCoordinator.endpointBlockedUntilKey;

/// The single saved value, as the coordinator writes it.
String restrictionBlob(String code, int untilMs) => jsonEncode({'v': 1, 'code': code, 'until': untilMs});

Map<String, dynamic>? storedRestriction(SharedPreferences p) {
  final v = p.getString(restrictionKey);
  return v == null ? null : jsonDecode(v) as Map<String, dynamic>;
}

String? storedCode(SharedPreferences p) => storedRestriction(p)?['code'] as String?;
int? storedUntil(SharedPreferences p) => storedRestriction(p)?['until'] as int?;

/// True if anything of either layout is saved.
bool anyStored(SharedPreferences p) => p.containsKey(restrictionKey) || p.containsKey(legacyCodeKey) || p.containsKey(legacyUntilKey);

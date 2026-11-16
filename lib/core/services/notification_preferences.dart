/// User control over which kinds of local notification may appear (Stage 1.6D-4).
///
/// Two categories are optional (scam-message and general security notices). Two are ESSENTIAL safety alerts (fake or
/// impersonating apps, and active banking threats) and cannot be switched off here: [NotificationCategory.essential].
/// Nothing in this file requests a permission; the system notification permission stays a separate, OS-level choice.
library;

import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory {
  scamMessages('notif_scam_messages', 'Scam message alerts', 'A short warning when a message you analyse looks like a scam.', false),
  securityWarnings('notif_security_warnings', 'General security notices', 'Risk notices about apps on this phone.', false),
  fakeApps('notif_fake_apps', 'Fake app alerts', 'Always on: warns about apps pretending to be banks or other trusted apps.', true),
  banking('notif_banking', 'Banking safety alerts', 'Always on: warns about active threats that could affect banking.', true);

  const NotificationCategory(this.key, this.title, this.description, this.essential);
  final String key;
  final String title;
  final String description;

  /// Essential categories are always delivered; the stored value is ignored.
  final bool essential;
}

abstract class NotificationPreferencesStore {
  /// Whether [category] may show a notification. Essential categories are always enabled. Defaults to enabled, and a storage
  /// failure also means enabled: failing quiet must never hide a safety warning.
  static Future<bool> isEnabled(NotificationCategory category) async {
    if (category.essential) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(category.key) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Stores the choice. Returns false (and stores nothing) for an essential category.
  static Future<bool> setEnabled(NotificationCategory category, bool enabled) async {
    if (category.essential) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // await: without it an asynchronous write failure escapes this try/catch instead of returning false
      return await prefs.setBool(category.key, enabled);
    } catch (_) {
      return false;
    }
  }
}

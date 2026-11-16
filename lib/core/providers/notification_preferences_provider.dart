import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_preferences.dart';

/// Riverpod state for the notification-category switches. Essential categories are always `true`.
class NotificationPreferencesNotifier extends StateNotifier<Map<NotificationCategory, bool>> {
  NotificationPreferencesNotifier()
      : super({for (final c in NotificationCategory.values) c: true}) {
    _load();
  }

  Future<void> _load() async {
    final loaded = {for (final c in NotificationCategory.values) c: await NotificationPreferencesStore.isEnabled(c)};
    if (mounted) state = loaded;
  }

  Future<void> setEnabled(NotificationCategory category, bool enabled) async {
    if (category.essential) return;
    state = {...state, category: enabled};
    await NotificationPreferencesStore.setEnabled(category, enabled);
  }
}

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, Map<NotificationCategory, bool>>(
  (ref) => NotificationPreferencesNotifier(),
);

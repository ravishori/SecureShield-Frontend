import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/notification_preferences_provider.dart';
import '../../../core/services/notification_preferences.dart';
import '../../../core/theme.dart';

/// Settings block for notification categories. Optional categories have a switch; essential safety alerts are listed as
/// always on. It requests no permission: notification permission is an Android setting.
class NotificationPreferencesSection extends ConsumerWidget {
  const NotificationPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const Key('notification_preferences'),
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Notifications show only a short warning, never the message itself. '
          'Turning on or off the Android notification permission is done in your phone settings.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final c in NotificationCategory.values)
          SwitchListTile(
            key: Key('notif_switch_${c.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(c.title),
            subtitle: Text(c.description, style: const TextStyle(fontSize: 12)),
            value: c.essential ? true : (prefs[c] ?? true),
            onChanged: c.essential ? null : (v) => notifier.setEnabled(c, v),
            activeThumbColor: AppTheme.accent,
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// Stage 1.6D-4: notification category preferences. Essential safety alerts cannot be disabled.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/providers/notification_preferences_provider.dart';
import 'package:secureshield_app/core/services/notification_preferences.dart';
import 'package:secureshield_app/features/settings/widgets/notification_preferences_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('store', () {
    test('everything is enabled by default', () async {
      for (final c in NotificationCategory.values) {
        expect(await NotificationPreferencesStore.isEnabled(c), isTrue, reason: c.name);
      }
    });

    test('optional categories can be disabled and re-enabled', () async {
      expect(await NotificationPreferencesStore.setEnabled(NotificationCategory.scamMessages, false), isTrue);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.scamMessages), isFalse);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.securityWarnings), isTrue);
      await NotificationPreferencesStore.setEnabled(NotificationCategory.scamMessages, true);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.scamMessages), isTrue);
    });

    test('essential safety categories cannot be disabled, even if a value is stored', () async {
      SharedPreferences.setMockInitialValues({'notif_banking': false, 'notif_fake_apps': false});
      expect(await NotificationPreferencesStore.setEnabled(NotificationCategory.banking, false), isFalse);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.banking), isTrue);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.fakeApps), isTrue);
    });

    test('exactly the intended categories are essential', () {
      expect(NotificationCategory.values.where((c) => c.essential).map((c) => c.name).toSet(), {'fakeApps', 'banking'});
    });
  });

  group('settings section', () {
    Future<ProviderContainer> pump(WidgetTester t) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      t.view.physicalSize = const Size(900, 2000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: NotificationPreferencesSection()))),
      ));
      await t.pumpAndSettle();
      return container;
    }

    testWidgets('lists every category, with switches only on the optional ones', (t) async {
      await pump(t);
      for (final c in NotificationCategory.values) {
        expect(find.byKey(Key('notif_switch_${c.name}')), findsOneWidget);
      }
      final scam = t.widget<SwitchListTile>(find.byKey(const Key('notif_switch_scamMessages')));
      final banking = t.widget<SwitchListTile>(find.byKey(const Key('notif_switch_banking')));
      expect(scam.onChanged, isNotNull);
      expect(banking.onChanged, isNull); // essential: cannot be toggled
      expect(banking.value, isTrue);
      expect(find.textContaining('never the message itself'), findsOneWidget);
    });

    testWidgets('switching an optional category off is persisted and used by the store', (t) async {
      final container = await pump(t);
      await t.tap(find.byKey(const Key('notif_switch_scamMessages')));
      await t.pumpAndSettle();
      expect(container.read(notificationPreferencesProvider)[NotificationCategory.scamMessages], isFalse);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.scamMessages), isFalse);
      expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.fakeApps), isTrue);
    });

    testWidgets('a saved choice is restored', (t) async {
      SharedPreferences.setMockInitialValues({'notif_security_warnings': false});
      final container = await pump(t);
      expect(container.read(notificationPreferencesProvider)[NotificationCategory.securityWarnings], isFalse);
      expect(t.widget<SwitchListTile>(find.byKey(const Key('notif_switch_securityWarnings'))).value, isFalse);
    });
  });

  test('source guard: the service honours only the optional categories and requests no permission', () {
    final service = File('lib/core/services/notification_service.dart').readAsStringSync();
    expect(service.contains('NotificationCategory.scamMessages'), isTrue);
    expect(service.contains('NotificationCategory.securityWarnings'), isTrue);
    expect(service.contains('NotificationCategory.banking'), isFalse); // essential alerts are not gated
    expect(service.contains('requestNotificationsPermission'), isFalse);
    expect(service.contains('requestPermissions'), isFalse);
    final prefs = File('lib/core/services/notification_preferences.dart').readAsStringSync();
    expect(prefs.contains('Permission.'), isFalse);
  });
}

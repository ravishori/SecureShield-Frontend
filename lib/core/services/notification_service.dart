/// Unified local notification service.
///
/// Wraps flutter_local_notifications with channels for:
/// - Fake app alerts
/// - Fraud/scam detection
/// - System security warnings
///
/// Initialize once in main() before runApp().
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'notification_content.dart';
import 'notification_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static late FlutterLocalNotificationsPlugin _plugin;
  static bool _initialized = false;

  // Notification channel IDs
  static const String _fakeAppChannelId = 'fake_app_alerts';
  static const String _fraudChannelId = 'fraud_alerts';
  static const String _securityChannelId = 'security_alerts';
  static const String _bankingChannelId = 'banking_alerts';

  /// Initialize the notification service (call once in main()).
  static Future<void> initialize() async {
    if (_initialized) return;

    _plugin = FlutterLocalNotificationsPlugin();

    // Android setup
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS setup
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels (Android 8.0+)
    if (Platform.isAndroid) {
      await _createChannels();
    }

    _initialized = true;
  }

  /// Create Android notification channels for categorized alerts.
  static Future<void> _createChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _fakeAppChannelId,
          'Fake App Alerts',
          description: 'Alerts when suspicious/fake apps are detected',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _fraudChannelId,
          'Fraud Alerts',
          description: 'Alerts for scam keywords (KYC, Digital Arrest, etc.)',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _bankingChannelId,
          'Banking Security',
          description: 'Banking app security warnings',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _securityChannelId,
          'Security Warnings',
          description: 'General security & privacy warnings',
          importance: Importance.defaultImportance,
          enableVibration: false,
          playSound: false,
        ),
      );
    }
  }

  /// Show a fake app detection notification.
  static Future<void> showFakeAppAlert({
    required String appName,
    required String impersonatesApp,
    required String packageName,
    String? reason,
  }) async {
    _checkInitialized();

    const title = '🚨 Fake App Detected';
    final body = '$appName is impersonating $impersonatesApp';
    final payload = 'fake_app:$packageName';

    if (Platform.isAndroid) {
      await _plugin.show(
        appName.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _fakeAppChannelId,
            'Fake App Alerts',
            channelDescription: 'Alerts when suspicious/fake apps are detected',
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            ticker: 'Fake App Detected',
            styleInformation: BigTextStyleInformation(
              '$body\n\nReason: ${reason ?? "Name impersonation"}\n\nPackage: $packageName',
            ),
            color: const Color.fromARGB(255, 255, 51, 51),
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } else {
      await _plugin.show(
        appName.hashCode,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        payload: payload,
      );
    }
  }

  /// Show a fraud/scam detection notification.
  ///
  /// Privacy (1.6D-3): shows a SAFE SUMMARY only (scam category + advice). The analysed message, its sender and any number in
  /// it never enter a notification, so nothing sensitive reaches the lock screen, the shade or a paired watch.
  static Future<void> showFraudAlert({
    required String fraudType, // e.g., "KYC Update", "Digital Arrest", "Customs Parcel"
    int matchedCount = 0,
  }) async {
    _checkInitialized();
    if (!await NotificationPreferencesStore.isEnabled(NotificationCategory.scamMessages)) return;

    final content = buildFraudNotificationContent(
      fraudType: fraudType,
      matchedCount: matchedCount,
    );
    final title = content.title;
    final body = content.body;
    final payload = 'fraud:${safeNotificationText(fraudType, max: 40)}';

    if (Platform.isAndroid) {
      await _plugin.show(
        fraudType.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _fraudChannelId,
            'Fraud Alerts',
            channelDescription:
                'Alerts for scam keywords (KYC, Digital Arrest, etc.)',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'Scam Detected',
            visibility: NotificationVisibility.private,
            styleInformation: BigTextStyleInformation(content.expandedBody),
            color: const Color.fromARGB(255, 255, 193, 7),
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } else {
      await _plugin.show(
        fraudType.hashCode,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        payload: payload,
      );
    }
  }

  /// Show a banking security alert.
  static Future<void> showBankingAlert({
    required String bankName,
    required String alertType, // "Fake App", "Compromised", "Update Available"
    String? details,
  }) async {
    _checkInitialized();

    final title = '🏦 $bankName Security Alert';
    final body = alertType;
    final payload = 'banking:$bankName:$alertType';

    if (Platform.isAndroid) {
      await _plugin.show(
        '$bankName:$alertType'.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _bankingChannelId,
            'Banking Security',
            channelDescription: 'Banking app security warnings',
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            ticker: 'Banking Alert',
            styleInformation: BigTextStyleInformation(
              '$body\n\n${details ?? "Check your banking app security settings."}',
            ),
            color: const Color.fromARGB(255, 76, 175, 80),
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } else {
      await _plugin.show(
        '$bankName:$alertType'.hashCode,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        payload: payload,
      );
    }
  }

  /// Show a general security warning.
  static Future<void> showSecurityWarning({
    required String title,
    required String message,
    String? action,
  }) async {
    _checkInitialized();
    if (!await NotificationPreferencesStore.isEnabled(NotificationCategory.securityWarnings)) return;

    if (Platform.isAndroid) {
      await _plugin.show(
        title.hashCode,
        title,
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _securityChannelId,
            'Security Warnings',
            channelDescription: 'General security & privacy warnings',
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(message),
            color: const Color.fromARGB(255, 33, 150, 243),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        payload: 'security_warning',
      );
    } else {
      await _plugin.show(
        title.hashCode,
        title,
        message,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        payload: 'security_warning',
      );
    }
  }

  /// Cancel a specific notification by ID.
  static Future<void> cancel(int id) async {
    _checkInitialized();
    await _plugin.cancel(id);
  }

  /// Cancel all notifications.
  static Future<void> cancelAll() async {
    _checkInitialized();
    await _plugin.cancelAll();
  }

  // Callback when notification is tapped
  static void _onNotificationTapped(
    NotificationResponse response,
  ) {
    // ignore: unused_local_variable
    final payload = response.payload ?? '';
    // Handle navigation based on payload
    // e.g., if (payload.startsWith('fake_app:')) { navigate to app detail }
    // This would be connected to your router
  }

  static void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'NotificationService not initialized. Call NotificationService.initialize() in main().',
      );
    }
  }
}

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

    final initSettings = InitializationSettings(
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
        AndroidNotificationChannel(
          _fakeAppChannelId,
          'Fake App Alerts',
          description: 'Alerts when suspicious/fake apps are detected',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _fraudChannelId,
          'Fraud Alerts',
          description: 'Alerts for scam keywords (KYC, Digital Arrest, etc.)',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _bankingChannelId,
          'Banking Security',
          description: 'Banking app security warnings',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
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

    final title = '🚨 Fake App Detected';
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
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
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
  static Future<void> showFraudAlert({
    required String fraudType, // e.g., "KYC Update", "Digital Arrest", "Customs Parcel"
    required String message,
    String? matchedKeywords,
  }) async {
    _checkInitialized();

    final title = '⚠️ Scam Alert: $fraudType';
    final body = message.length > 100
        ? '${message.substring(0, 97)}...'
        : message;
    final payload = 'fraud:$fraudType';

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
            styleInformation: BigTextStyleInformation(
              '$body\n\n${matchedKeywords ?? "Unknown scam type"}\n\n'
                  'Do not share OTP, Aadhaar, or bank details.',
            ),
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
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
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
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
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
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
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

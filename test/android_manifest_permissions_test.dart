import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase G permission review, as a regression test. A permission can only be added to the manifest by also adding it (with
/// the reason and the Play-policy status) to [approved] below, so every new permission is a deliberate, reviewed decision.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final declared = RegExp(r'<uses-permission\s+android:name="android\.permission\.([A-Z_]+)"')
      .allMatches(manifest)
      .map((m) => m.group(1)!)
      .toSet();

  // permission -> why it is needed (feature). Restricted ones are marked.
  const approved = <String, String>{
    'INTERNET': 'API calls',
    'ACCESS_NETWORK_STATE': 'offline detection',
    'DETECT_SCREEN_RECORDING': 'Android 15 screen-recorder detector',
    'CAMERA': 'evidence capture, QR scanning',
    'RECORD_AUDIO': 'call/screen recording evidence (user-started)',
    'ACCESS_FINE_LOCATION': 'panic button, Wi-Fi scan',
    'ACCESS_COARSE_LOCATION': 'panic button, Wi-Fi scan',
    'ACCESS_WIFI_STATE': 'Wi-Fi scanner',
    'CHANGE_WIFI_STATE': 'Wi-Fi scanner',
    'QUERY_ALL_PACKAGES': 'RESTRICTED (Play declaration): app risk scanner and clone detector',
    'PACKAGE_USAGE_STATS': 'special access the user grants manually; app monitor',
    'USE_BIOMETRIC': 'OTP vault and login',
    'USE_FINGERPRINT': 'legacy biometric API',
    'READ_PHONE_STATE': 'call-state detection for recording, SIM-change detection',
    'READ_PHONE_NUMBERS': 'SIM fingerprint',
    // Needed on Android 9+ for the two user-confirmed uninstall flows (MainActivity.uninstallApp, ElderlyProtectionManager
    // "REMOVE THIS APP"), both ACTION_DELETE. Owned in the source manifest; it used to arrive only via the unused
    // installed_apps plugin, which was removed.
    'REQUEST_DELETE_PACKAGES': 'user-confirmed uninstall dialogs (ACTION_DELETE) in MainActivity and ElderlyProtectionManager',
    'READ_EXTERNAL_STORAGE': 'evidence files (Android 12 and below)',
    'WRITE_EXTERNAL_STORAGE': 'evidence files (Android 9 and below)',
    'READ_MEDIA_IMAGES': 'evidence files (Android 13+)',
    'READ_MEDIA_VIDEO': 'evidence files (Android 13+)',
    'READ_MEDIA_AUDIO': 'evidence files (Android 13+)',
    'READ_MEDIA_VISUAL_USER_SELECTED': 'partial media access (Android 14+)',
    'FOREGROUND_SERVICE': 'monitoring services',
    'FOREGROUND_SERVICE_SYSTEM_EXEMPTED': 'VPN monitor service type (Play declaration)',
    'FOREGROUND_SERVICE_DATA_SYNC': 'VPN monitor service type',
    'FOREGROUND_SERVICE_SPECIAL_USE': 'VPN monitor service type (Play declaration)',
    'FOREGROUND_SERVICE_MEDIA_PROJECTION': 'screen recording (Play declaration)',
    'POST_NOTIFICATIONS': 'alerts',
    'RECEIVE_BOOT_COMPLETED': 'restart monitors after reboot',
    'VIBRATE': 'alerts',
    'BIND_NOTIFICATION_LISTENER_SERVICE': 'RESTRICTED (user-granted special access): bank-OTP fraud alerts',
    'WAKE_LOCK': 'background processing',
    'BIND_VPN_SERVICE': 'RESTRICTED (Play VpnService declaration): local VPN monitor',
  };

  test('the four permissions with no supported feature behind them are gone', () {
    for (final p in ['READ_SMS', 'RECEIVE_SMS', 'READ_CALL_LOG', 'PROCESS_OUTGOING_CALLS']) {
      expect(declared.contains(p), isFalse, reason: '$p must not be declared');
    }
  });

  test('no other SMS, call-log, contacts or calling permission is declared', () {
    for (final p in [
      'SEND_SMS', 'RECEIVE_MMS', 'RECEIVE_WAP_PUSH', 'WRITE_CALL_LOG', 'READ_CONTACTS', 'WRITE_CONTACTS',
      'CALL_PHONE', 'ANSWER_PHONE_CALLS', 'ACCESS_BACKGROUND_LOCATION', 'SYSTEM_ALERT_WINDOW',
      'BIND_ACCESSIBILITY_SERVICE', 'MANAGE_EXTERNAL_STORAGE', 'REQUEST_INSTALL_PACKAGES',
    ]) {
      expect(declared.contains(p), isFalse, reason: '$p must not be declared');
    }
  });

  test('every declared permission is one that was reviewed and has a stated reason', () {
    final unknown = declared.difference(approved.keys.toSet());
    expect(unknown, isEmpty, reason: 'add a reviewed entry (with its Play status) before declaring: $unknown');
  });

  test('every approved permission is still declared (the review list does not rot)', () {
    expect(approved.keys.toSet().difference(declared), isEmpty);
  });

  test('restricted capabilities stay explicitly marked so their Play declarations are not forgotten', () {
    final restricted = approved.entries.where((e) => e.value.contains('RESTRICTED')).map((e) => e.key).toSet();
    expect(restricted, {'QUERY_ALL_PACKAGES', 'BIND_NOTIFICATION_LISTENER_SERVICE', 'BIND_VPN_SERVICE'});
  });

  test('no component listens for incoming SMS or outgoing calls', () {
    expect(manifest.contains('SMS_RECEIVED'), isFalse);
    expect(manifest.contains('NEW_OUTGOING_CALL'), isFalse);
    expect(manifest.contains('android.provider.Telephony'), isFalse);
  });

  test('the app code never asks Android for the SMS or call-log runtime groups', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      if (RegExp(r'Permission\.(sms|callLog)\b').hasMatch(text)) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  test('the Kotlin code reads neither the SMS inbox nor the call log (the permission names there only classify OTHER apps)', () {
    final offenders = <String>[];
    final root = Directory('android/app/src/main/kotlin');
    for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.kt'))) {
      final text = f.readAsStringSync();
      if (RegExp(r'content://sms|Telephony\.Sms|CallLog\.Calls|SmsManager').hasMatch(text)) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  group('services', () {
    final serviceTags = RegExp(r'<service[^>]*>', multiLine: true).allMatches(manifest).map((m) => m.group(0)!).toList();

    String? attr(String tag, String name) => RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);

    test('AppMonitorService is declared: explicit class, not exported, specialUse foreground type', () {
      final tag = serviceTags.where((t) => attr(t, 'android:name') == '.AppMonitorService');
      expect(tag.length, 1, reason: 'len=${manifest.length} has=${manifest.contains("<service")} tags=${serviceTags.length} names=${serviceTags.map((t) => attr(t, "android:name")).toList()}');
      final t = tag.single;
      expect(attr(t, 'android:exported'), 'false');
      expect(attr(t, 'android:foregroundServiceType'), 'specialUse');
      expect(manifest.contains('PROPERTY_SPECIAL_USE_FGS_SUBTYPE'), isTrue);
    });

    test('no service is exported, and every foreground service declares a type', () {
      for (final t in serviceTags) {
        expect(attr(t, 'android:exported'), 'false', reason: t);
      }
      for (final name in ['.ScreenRecordService', '.SecureShieldVpnService', '.AppMonitorService']) {
        final t = serviceTags.singleWhere((t) => attr(t, 'android:name') == name);
        expect(attr(t, 'android:foregroundServiceType'), isNotNull, reason: name);
      }
    });

    test('every Service subclass in the Kotlin code is declared in the manifest (an undeclared service silently never starts)', () {
      final declared = serviceTags.map((t) => attr(t, 'android:name')!.replaceFirst('.', '')).toSet();
      final missing = <String>[];
      final root = Directory('android/app/src/main/kotlin');
      for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.kt'))) {
        for (final m in RegExp(r'class\s+(\w+)\s*(?:\([^)]*\))?\s*:\s*(?:android\.[\w.]*\.)?(Service|VpnService|NotificationListenerService)\b')
            .allMatches(f.readAsStringSync())) {
          if (!declared.contains(m.group(1))) missing.add(m.group(1)!);
        }
      }
      expect(missing, isEmpty);
    });

    test('the monitor uses only the two foreground-service permissions it needs', () {
      // specialUse type => FOREGROUND_SERVICE + FOREGROUND_SERVICE_SPECIAL_USE (both already approved above); nothing new
      expect(declared.contains('FOREGROUND_SERVICE'), isTrue);
      expect(declared.contains('FOREGROUND_SERVICE_SPECIAL_USE'), isTrue);
      expect(declared.contains('FOREGROUND_SERVICE_LOCATION'), isFalse);
      expect(declared.contains('FOREGROUND_SERVICE_CAMERA'), isFalse);
      expect(declared.contains('FOREGROUND_SERVICE_MICROPHONE'), isFalse);
    });
  });

  group('package install receiver and uninstall ownership (F19 stage 1)', () {
    final receiver = RegExp(r'<receiver[^>]*PackageInstallReceiver[^>]*>[\s\S]*?</receiver>').firstMatch(manifest)?.group(0);

    test('PackageInstallReceiver is declared, NOT exported, and handles only the protected PACKAGE_ADDED broadcast', () {
      expect(receiver, isNotNull);
      expect(RegExp('android:exported="false"').hasMatch(receiver!), isTrue);
      expect(receiver.contains('android:exported="true"'), isFalse);
      final actions = RegExp('<action android:name="([^"]+)"').allMatches(receiver).map((m) => m.group(1)).toList();
      expect(actions, ['android.intent.action.PACKAGE_ADDED']); // a protected system broadcast: only the system can send it
      expect(receiver.contains('<data android:scheme="package"'), isTrue);
    });

    test('the receiver is gated by the persisted monitoring preference and defers to the running service', () {
      final src = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/PackageInstallReceiver.kt').readAsStringSync();
      expect(src.contains('MonitorPreference.isEnabled(context)'), isTrue);
      expect(src.contains('NotificationVisibility.check(context)'), isTrue); // checked at the moment of every event
      expect(src.contains('PAUSE_NOTIFICATIONS_OFF'), isTrue);
      expect(src.contains('MonitorPause.pause(context)'), isTrue);
      expect(src.contains('AppMonitorService.isRunning'), isTrue);
      expect(src.contains('MonitorPolicy.Decision.HANDLE'), isTrue);
    });

    test('the service re-checks visibility on start and on every event, and never clears the preference from onDestroy', () {
      final svcSrc = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/AppMonitorService.kt').readAsStringSync();
      expect('NotificationVisibility.check'.allMatches(svcSrc).length, greaterThanOrEqualTo(3)); // start, event, mid-analysis
      expect(svcSrc.contains('stopMonitoring()'), isTrue);
      final destroy = RegExp(r'override fun onDestroy\(\) \{[\s\S]*?\n    \}').firstMatch(svcSrc)!.group(0)!;
      expect(destroy.contains('MonitorPreference.set'), isFalse, reason: 'a process death must not turn the preference off');
      // lifecycle is set only AFTER the visibility decision, so nothing can observe "running" for a refused start
      expect(svcSrc.indexOf('NotificationVisibility.check(this)') < svcSrc.indexOf('lifecycle.begin()'), isTrue);
    });

    test('MainActivity exposes enforceVisibility and distinguishes a disabled-notification refusal', () {
      final main = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/MainActivity.kt').readAsStringSync();
      expect(main.contains('"enforceVisibility"'), isTrue);
      expect(main.contains('NOTIFICATIONS_DISABLED'), isTrue);
    });

    test('there is a single monitoring preference (one key, one file), written only by MainActivity and the service', () {
      final dir = Directory('android/app/src/main/kotlin');
      final keys = <String>[];
      for (final f in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.kt'))) {
        final t = f.readAsStringSync();
        if (t.contains('monitoring_enabled')) keys.add(f.path);
        if (!f.path.endsWith('MonitorPolicy.kt')) {
          expect(RegExp(r'getSharedPreferences\([^)]*monitor', caseSensitive: false).hasMatch(t), isFalse, reason: f.path);
        }
      }
      expect(keys.length, 1);
      final main = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/MainActivity.kt').readAsStringSync();
      expect(main.contains('MonitorPreference.set(this, true)'), isTrue);
      expect(main.contains('MonitorPreference.set(this, false)'), isTrue);
    });

    test('both uninstall flows exist and the permission they need is declared in the SOURCE manifest', () {
      final main = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/MainActivity.kt').readAsStringSync();
      final elderly = File('android/app/src/main/kotlin/com/secureshield/secureshield_app/ElderlyProtectionManager.kt').readAsStringSync();
      expect(main.contains('Intent.ACTION_DELETE'), isTrue);
      expect(elderly.contains('Intent.ACTION_DELETE'), isTrue);
      expect(declared.contains('REQUEST_DELETE_PACKAGES'), isTrue);
    });

    test('the unused installed_apps plugin is gone and nothing imports it', () {
      expect(File('pubspec.yaml').readAsStringSync().contains('installed_apps'), isFalse);
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('package:installed_apps')) offenders.add(f.path);
      }
      expect(offenders, isEmpty);
    });

    test('no SMS or call-log permission was reintroduced and QUERY_ALL_PACKAGES is still declared', () {
      for (final p in ['READ_SMS', 'RECEIVE_SMS', 'READ_CALL_LOG', 'PROCESS_OUTGOING_CALLS']) {
        expect(declared.contains(p), isFalse, reason: p);
      }
      expect(declared.contains('QUERY_ALL_PACKAGES'), isTrue);
    });
  });
}

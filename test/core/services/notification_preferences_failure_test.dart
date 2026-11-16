// Regression: a storage failure must be CAUGHT and reported as `false`, not escape from setEnabled.
// `return prefs.setBool(...)` without `await` inside try/catch let an asynchronous failure bypass the catch.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/services/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('plugins.flutter.io/shared_preferences');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SharedPreferences.resetStatic);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  });

  void mockStore({required bool writesFail}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      if (writesFail) throw PlatformException(code: 'disk_full', message: 'simulated write failure');
      return true;
    });
  }

  test('an asynchronous write failure is caught and setEnabled returns false', () async {
    mockStore(writesFail: true);
    expect(await NotificationPreferencesStore.setEnabled(NotificationCategory.scamMessages, false), isFalse);
  });

  test('a successful write still returns true', () async {
    mockStore(writesFail: false);
    expect(await NotificationPreferencesStore.setEnabled(NotificationCategory.scamMessages, false), isTrue);
  });

  test('an essential category is never written, even when storage is healthy', () async {
    mockStore(writesFail: false);
    expect(await NotificationPreferencesStore.setEnabled(NotificationCategory.banking, false), isFalse);
  });

  test('reading while storage fails still fails open (enabled)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await NotificationPreferencesStore.isEnabled(NotificationCategory.scamMessages), isTrue);
  });
}

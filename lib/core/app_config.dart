import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the backend base URL at runtime depending on:
///   • Android Emulator  → 10.0.2.2  (special loopback to host machine)
///   • iOS Simulator     → localhost
///   • Real device       → your PC's LAN IP (set [deviceLanIp] below)
///
/// ⚙️  ONLY ONE LINE TO CHANGE when switching networks:
///     static const String deviceLanIp = '192.168.x.x';
///
/// The resolved URL is cached for the lifetime of the app.
/// Users can also override it at runtime via the Settings screen
/// (stored in SharedPreferences under key 'custom_server_url').
class AppConfig {
  // ─── Configure your PC's LAN IP here ────────────────────────────────────
  static const String deviceLanIp = '192.168.1.132'; // ← your PC's LAN IP
  static const int port = 8000;
  // ────────────────────────────────────────────────────────────────────────

  static const String _emulatorUrl    = 'http://10.0.2.2:$port/api/v1';
  static const String _iosSimUrl      = 'http://localhost:$port/api/v1';
  static const String _lanUrl         = 'http://$deviceLanIp:$port/api/v1';
  static const String _prefKey        = 'custom_server_url';

  static String _baseUrl = _emulatorUrl;
  static bool _initialized = false;

  /// Call once from main() before runApp().
  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. Check SharedPreferences for a user-saved custom URL
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
      _initialized = true;
      return;
    }

    // 2. Auto-detect emulator vs real device
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _baseUrl = info.isPhysicalDevice ? _lanUrl : _emulatorUrl;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        _baseUrl = info.isPhysicalDevice ? _lanUrl : _iosSimUrl;
      } else {
        // Desktop / web — use LAN
        _baseUrl = _lanUrl;
      }
    } catch (_) {
      // If device_info fails, default to emulator (safest dev default)
      _baseUrl = _emulatorUrl;
    }

    _initialized = true;
  }

  /// The resolved base URL for the current runtime environment.
  static String get baseUrl => _baseUrl;

  /// Allow the user to override the server URL at runtime
  /// (useful for QA / switching between environments).
  static Future<void> setCustomUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, url);
  }

  /// Clear the custom URL override and re-detect automatically.
  static Future<void> clearCustomUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _initialized = false;
    await initialize();
  }
}

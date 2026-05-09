import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteApp {
  final String packageName;
  final String appName;
  final bool isEnabled;
  const RemoteApp({required this.packageName, required this.appName, required this.isEnabled});
}

class RemoteThreatReport {
  final List<RemoteApp> remoteApps;
  final bool adbEnabled;
  final List<String> deviceAdminApps;

  const RemoteThreatReport({
    required this.remoteApps,
    required this.adbEnabled,
    required this.deviceAdminApps,
  });

  bool get hasThreat => remoteApps.isNotEmpty || adbEnabled || deviceAdminApps.isNotEmpty;
  int get threatCount => remoteApps.length + (adbEnabled ? 1 : 0);
}

class RemoteDetectorService {
  static const _channel = MethodChannel('secureshield/remote_detector');

  Future<RemoteThreatReport> scan() async {
    final apps    = await _getRemoteControlApps();
    final adb     = await _isAdbEnabled();
    final admins  = await _getDeviceAdminApps();
    return RemoteThreatReport(remoteApps: apps, adbEnabled: adb, deviceAdminApps: admins);
  }

  Future<List<RemoteApp>> _getRemoteControlApps() async {
    try {
      final list = await _channel.invokeListMethod<Map>('getRemoteControlApps') ?? [];
      return list.map((m) => RemoteApp(
        packageName: m['packageName'] as String? ?? '',
        appName:     m['appName']     as String? ?? '',
        isEnabled:   m['isEnabled']   as bool?   ?? false,
      )).toList();
    } catch (_) { return []; }
  }

  Future<bool> _isAdbEnabled() async {
    try { return await _channel.invokeMethod<bool>('isAdbEnabled') ?? false; }
    catch (_) { return false; }
  }

  Future<List<String>> _getDeviceAdminApps() async {
    try { return await _channel.invokeListMethod<String>('getDeviceAdminApps') ?? []; }
    catch (_) { return []; }
  }
}

final remoteDetectorServiceProvider =
    Provider<RemoteDetectorService>((ref) => RemoteDetectorService());

final remoteThreatProvider = FutureProvider<RemoteThreatReport>((ref) async {
  return ref.watch(remoteDetectorServiceProvider).scan();
});

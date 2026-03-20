import 'package:flutter/services.dart';

// ────────────────────────────────────────────────────────────────────────────
// Data model for a single installed app
// ────────────────────────────────────────────────────────────────────────────
class DeviceAppInfo {
  final String packageName;
  final String appName;
  final bool isSystem;
  final bool isUpdatedSystem;
  final String? installer;       // null = unknown / sideloaded
  final bool isFromKnownStore;
  final List<String> grantedDangerousPerms;
  final bool hasLauncher;        // visible in launcher
  final int firstInstallTime;    // epoch ms
  final int lastUpdateTime;      // epoch ms
  final int rxBytes;             // network received since boot
  final int txBytes;             // network sent since boot
  final bool hasOverlay;         // SYSTEM_ALERT_WINDOW granted
  final int uid;
  final String versionName;

  // Set by AppRiskEngine after scoring
  bool usesAccessibility = false;

  DeviceAppInfo({
    required this.packageName,
    required this.appName,
    required this.isSystem,
    required this.isUpdatedSystem,
    required this.installer,
    required this.isFromKnownStore,
    required this.grantedDangerousPerms,
    required this.hasLauncher,
    required this.firstInstallTime,
    required this.lastUpdateTime,
    required this.rxBytes,
    required this.txBytes,
    required this.hasOverlay,
    required this.uid,
    required this.versionName,
  });

  factory DeviceAppInfo.fromMap(Map<dynamic, dynamic> m) => DeviceAppInfo(
        packageName:           m['packageName'] as String,
        appName:               m['appName'] as String,
        isSystem:              m['isSystem'] as bool,
        isUpdatedSystem:       m['isUpdatedSystem'] as bool,
        installer:             m['installer'] as String?,
        isFromKnownStore:      m['isFromKnownStore'] as bool,
        grantedDangerousPerms: List<String>.from(m['grantedDangerousPerms'] as List),
        hasLauncher:           m['hasLauncher'] as bool,
        firstInstallTime:      (m['firstInstallTime'] as int),
        lastUpdateTime:        (m['lastUpdateTime'] as int),
        rxBytes:               (m['rxBytes'] as int),
        txBytes:               (m['txBytes'] as int),
        hasOverlay:            m['hasOverlay'] as bool,
        uid:                   m['uid'] as int,
        versionName:           m['versionName'] as String,
      );

  /// Total bytes transferred
  int get totalBytes => rxBytes + txBytes;

  /// MB received (for display)
  double get rxMb => rxBytes / (1024 * 1024);

  /// True for pure user-installed apps (not system at all)
  bool get isUserApp => !isSystem && !isUpdatedSystem;
}

// ────────────────────────────────────────────────────────────────────────────
// Platform channel wrapper — calls native Android methods
// ────────────────────────────────────────────────────────────────────────────
class DeviceScannerService {
  static const _channel = MethodChannel('secureshield/device_scanner');

  /// Returns all installed apps with security metadata.
  static Future<List<DeviceAppInfo>> getInstalledApps() async {
    final raw = await _channel.invokeMethod<List>('getInstalledApps') ?? [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map(DeviceAppInfo.fromMap)
        .toList();
  }

  /// Returns package names of apps currently using accessibility services.
  /// Format: "com.example.app/com.example.app.MyService"
  static Future<List<String>> getAccessibilityServices() async {
    final raw = await _channel.invokeMethod<List>('getAccessibilityServices') ?? [];
    return raw.cast<String>();
  }

  /// Launches the system uninstall dialog for [packageName].
  static Future<void> uninstallApp(String packageName) async {
    await _channel.invokeMethod('uninstallApp', {'packageName': packageName});
  }
}

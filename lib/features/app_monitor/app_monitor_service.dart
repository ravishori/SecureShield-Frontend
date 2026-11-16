import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/network/dio_client.dart';
import 'models/install_event.dart';
import 'monitor_sync_coordinator.dart';

// ── Platform channels ─────────────────────────────────────────────────────────
const _monitorChannel  = MethodChannel('secureshield/app_monitor');
const _analysisChannel = EventChannel('secureshield/install_analysis');

/// Why a start did not happen. The UI shows the reason and never shows "active" for any of these.
enum MonitorStartFailure { notificationPermissionDenied, notificationsDisabled, startFailed, timeout, unsupported }

/// Outcome of asking the native service to start. [running] is true ONLY when the native service itself confirmed it.
class MonitorStartResult {
  final bool running;
  final MonitorStartFailure? failure;
  final String? message;
  const MonitorStartResult.confirmed()
      : running = true,
        failure = null,
        message = null;
  const MonitorStartResult.failed(MonitorStartFailure this.failure, this.message) : running = false;
}

class AppMonitorService {
  final _client = DioClient();
  final Future<bool> Function() _requestNotifications;
  final Future<bool> Function() _openSettings;

  /// The hooks exist so tests never touch the real permission plugin.
  AppMonitorService({
    Future<bool> Function()? requestNotificationPermission,
    Future<bool> Function()? openAppSettingsHook,
  })  : _requestNotifications = requestNotificationPermission ?? _defaultRequestNotifications,
        _openSettings = openAppSettingsHook ?? openAppSettings;

  static Future<bool> _defaultRequestNotifications() async => (await Permission.notification.request()).isGranted;

  Future<bool> openSettings() => _openSettings();

  // -- Monitor lifecycle
  /// Starts the native service. Asks for the notification permission first (the persistent notice is the disclosure that
  /// monitoring is on), then waits for the native side to CONFIRM; every other outcome is a typed failure.
  Future<MonitorStartResult> start() async {
    if (!await _requestNotifications()) {
      return const MonitorStartResult.failed(
        MonitorStartFailure.notificationPermissionDenied,
        'Allow notifications so SecureShield can show that monitoring is on. Monitoring was not started.',
      );
    }
    try {
      final ok = await _monitorChannel.invokeMethod<bool>('startMonitor');
      if (ok == true) return const MonitorStartResult.confirmed();
      return const MonitorStartResult.failed(MonitorStartFailure.startFailed, 'The monitor could not be started.');
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NOTIFICATION_PERMISSION_DENIED':
          return const MonitorStartResult.failed(
            MonitorStartFailure.notificationPermissionDenied,
            'Allow notifications so SecureShield can show that monitoring is on. Monitoring was not started.',
          );
        case 'NOTIFICATIONS_DISABLED':
          return const MonitorStartResult.failed(
            MonitorStartFailure.notificationsDisabled,
            'Notifications for SecureShield (or the App Install Monitor channel) are off, so monitoring cannot be shown. '
            'Turn them on, then start the monitor again.',
          );
        case 'START_TIMEOUT':
          return const MonitorStartResult.failed(
              MonitorStartFailure.timeout, 'The monitor did not confirm that it started. It is not running.');
        default:
          return const MonitorStartResult.failed(
              MonitorStartFailure.startFailed, 'Android refused to start the monitor. It is not running.');
      }
    } on MissingPluginException {
      return const MonitorStartResult.failed(
          MonitorStartFailure.unsupported, 'App monitoring is only available on Android.');
    } catch (_) {
      return const MonitorStartResult.failed(MonitorStartFailure.startFailed, 'The monitor could not be started.');
    }
  }

  /// Compatibility wrapper: true only if the native service confirmed it is running.
  Future<bool> startMonitor() async => (await start()).running;

  /// True only if the native side confirmed the service is no longer running.
  Future<bool> stopMonitor() async {
    try { return await _monitorChannel.invokeMethod<bool>('stopMonitor') ?? false; }
    catch (_) { return false; }
  }

  /// Asks the native side to re-check that the user can still see the monitor. True = it WAS on and has just been
  /// paused because notifications (or the monitor channel) are off. Unknown or unreadable is reported as not paused: the
  /// native side is the only authority, and it has already failed closed on its own.
  Future<bool> enforceVisibility() async {
    try { return await _monitorChannel.invokeMethod<bool>('enforceVisibility') ?? false; }
    catch (_) { return false; }
  }

  /// The persisted "monitoring is on" preference (native side). Unknown or unreadable means off.
  Future<bool> isEnabled() async {
    try { return await _monitorChannel.invokeMethod<bool>('isEnabled') ?? false; }
    catch (_) { return false; }
  }

  Future<bool> isRunning() async {
    try { return await _monitorChannel.invokeMethod<bool>('isRunning') ?? false; }
    catch (_) { return false; }
  }

  /// On-demand analysis of any already-installed package
  Future<InstallEvent?> analyzePackage(String packageName) async {
    try {
      final map = await _monitorChannel.invokeMapMethod<dynamic, dynamic>(
        'analyzePackage', {'packageName': packageName});
      return map != null ? InstallEvent.fromMap(map) : null;
    } catch (_) { return null; }
  }

  // ── Live event stream ─────────────────────────────────────────────────────
  Stream<InstallEvent> get liveEventStream => _analysisChannel
      .receiveBroadcastStream()
      .map((e) => InstallEvent.fromMap(e as Map));

  // The old in-memory/SharedPreferences upload queue (enqueue / syncQueue) is retired: the native SQLite store is the
  // only queue and MonitorSyncCoordinator is the only uploader.

  // ── History from backend ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchHistory({int page = 1, String? riskLevel}) async {
    try {
      final resp = await _client.dio.get(
        '/app-monitor/history',
        queryParameters: {
          'page': page,
          if (riskLevel != null) 'risk_level': riskLevel,
        },
      );
      return resp.data as Map<String, dynamic>;
    } catch (_) { return {'events': [], 'total': 0}; }
  }

  Future<Map<String, dynamic>> fetchSummary() async {
    try {
      final resp = await _client.dio.get('/app-monitor/summary');
      return resp.data as Map<String, dynamic>;
    } catch (_) { return {}; }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final appMonitorServiceProvider = Provider((_) => AppMonitorService());

/// Whether the native monitor service is running
final monitorRunningProvider = StateProvider<bool>((ref) => false);

/// In-memory list of events received since last app launch
final liveEventsProvider =
    StateNotifierProvider<_LiveEventsNotifier, List<InstallEvent>>(
        (_) => _LiveEventsNotifier());

class _LiveEventsNotifier extends StateNotifier<List<InstallEvent>> {
  _LiveEventsNotifier() : super([]);
  void add(InstallEvent ev) => state = [ev, ...state].take(100).toList();
  void clear() => state = [];
}

/// Stream provider that feeds the live-events notifier
final installEventStreamProvider = StreamProvider<InstallEvent>((ref) {
  final svc = ref.watch(appMonitorServiceProvider);
  return svc.liveEventStream.map((ev) {
    // Side-effect: add to in-memory list
    ref.read(liveEventsProvider.notifier).add(ev);
    // The native store already holds this event (it is stored before analysis); just ask the coordinator to upload soon.
    ref.read(monitorSyncProvider).requestSync();
    return ev;
  });
});

/// Server-side history
final monitorHistoryProvider =
    FutureProvider.family<Map<String, dynamic>, String?>((ref, riskLevel) async {
  final svc = ref.watch(appMonitorServiceProvider);
  return svc.fetchHistory(riskLevel: riskLevel);
});

final monitorSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(appMonitorServiceProvider).fetchSummary();
});

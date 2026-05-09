import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/dio_client.dart';
import 'models/install_event.dart';

// ── Platform channels ─────────────────────────────────────────────────────────
const _monitorChannel  = MethodChannel('secureshield/app_monitor');
const _analysisChannel = EventChannel('secureshield/install_analysis');

// ── Offline queue ─────────────────────────────────────────────────────────────
const _queueKey = 'install_event_queue_v1';

class AppMonitorService {
  final _client = DioClient();

  // ── Monitor lifecycle ─────────────────────────────────────────────────────
  Future<bool> startMonitor() async {
    try { return await _monitorChannel.invokeMethod<bool>('startMonitor') ?? false; }
    catch (_) { return false; }
  }

  Future<bool> stopMonitor() async {
    try { return await _monitorChannel.invokeMethod<bool>('stopMonitor') ?? false; }
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

  // ── Offline-first queue ───────────────────────────────────────────────────

  /// Enqueue an event for backend sync (called right after receiving it from Kotlin)
  Future<void> enqueue(InstallEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_queueKey) ?? [];
    raw.add(jsonEncode(event.toSyncPayload()));
    await prefs.setStringList(_queueKey, raw);
  }

  /// Upload all queued events in one batch; clear queue on success
  Future<int> syncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_queueKey) ?? [];
    if (raw.isEmpty) return 0;

    final events = raw.map(jsonDecode).toList();
    try {
      final resp = await _client.dio.post(
        '/app-monitor/sync',
        data: {'events': events},
      );
      if (resp.statusCode == 200) {
        await prefs.remove(_queueKey);
        return (resp.data['synced'] as int? ?? 0);
      }
      return 0;
    } catch (_) {
      return 0;   // keep in queue; retry later
    }
  }

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
    // Side-effect: enqueue for backend sync
    svc.enqueue(ev);
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

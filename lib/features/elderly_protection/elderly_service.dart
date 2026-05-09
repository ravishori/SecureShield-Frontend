import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import 'models/elderly_config.dart';

const _elderlyChannel = MethodChannel('secureshield/elderly');
const _elderlyEvents  = EventChannel('secureshield/elderly_events');

class ElderlyService {
  final _client = DioClient();

  // ── Kotlin config sync ────────────────────────────────────────────────────

  Future<bool> setNativeConfig(ElderlyConfig cfg) async {
    try {
      return await _elderlyChannel.invokeMethod<bool>(
            'setConfig', cfg.toNativeMap()) ?? false;
    } catch (_) { return false; }
  }

  Future<ElderlyConfig?> getNativeConfig() async {
    try {
      final map = await _elderlyChannel.invokeMapMethod<String, dynamic>('getConfig');
      if (map == null) return null;
      return ElderlyConfig(
        enabled:            map['enabled']        as bool? ?? false,
        alertThreshold:     (map['alertThreshold'] as num?)?.toInt() ?? 40,
        blockRiskyInstalls: map['blockRisky']     as bool? ?? true,
        autoAlertGuardian:  map['autoAlert']      as bool? ?? true,
        guardianName:       map['guardianName']?.toString(),
        guardianPhone:      map['guardianPhone']?.toString(),
      );
    } catch (_) { return null; }
  }

  // ── Backend sync ──────────────────────────────────────────────────────────

  Future<ElderlyConfig?> fetchConfig() async {
    try {
      final resp = await _client.dio.get('/elderly/config');
      return ElderlyConfig.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  Future<ElderlyConfig?> saveConfig(ElderlyConfig cfg) async {
    try {
      final resp = await _client.dio.put('/elderly/config', data: cfg.toJson());
      final saved = ElderlyConfig.fromJson(resp.data as Map<String, dynamic>);
      // Mirror to Kotlin layer for offline-first blocking
      await setNativeConfig(saved);
      return saved;
    } catch (_) { return null; }
  }

  Future<bool> sendGuardianAlert({
    required String packageName,
    required String appName,
    required int riskScore,
    required String riskLevel,
    required List<String> riskTags,
    String? cloneVerdict,
  }) async {
    try {
      await _client.dio.post('/elderly/guardian-alert', data: {
        'package_name':  packageName,
        'app_name':      appName,
        'risk_score':    riskScore,
        'risk_level':    riskLevel,
        'risk_tags':     riskTags,
        if (cloneVerdict != null) 'clone_verdict': cloneVerdict,
      });
      return true;
    } catch (_) { return false; }
  }

  // ── Guardian alert event stream ───────────────────────────────────────────
  Stream<Map<String, dynamic>> get guardianAlertStream =>
      _elderlyEvents.receiveBroadcastStream().map(
          (e) => Map<String, dynamic>.from(e as Map));
}

// ── Providers ─────────────────────────────────────────────────────────────────

final elderlyServiceProvider = Provider((_) => ElderlyService());

class ElderlyConfigNotifier extends StateNotifier<ElderlyConfig> {
  final ElderlyService _svc;
  ElderlyConfigNotifier(this._svc) : super(const ElderlyConfig());

  Future<void> load() async {
    final cfg = await _svc.fetchConfig();
    if (cfg != null) state = cfg;
  }

  Future<bool> save(ElderlyConfig cfg) async {
    final saved = await _svc.saveConfig(cfg);
    if (saved != null) { state = saved; return true; }
    return false;
  }

  void update(ElderlyConfig cfg) => state = cfg;
}

final elderlyConfigProvider =
    StateNotifierProvider<ElderlyConfigNotifier, ElderlyConfig>((ref) {
  return ElderlyConfigNotifier(ref.watch(elderlyServiceProvider));
});

/// Stream of guardian alert events from Kotlin — auto-relayed to backend
final guardianAlertStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final svc = ref.watch(elderlyServiceProvider);
  return svc.guardianAlertStream.asyncMap((event) async {
    // Relay to backend asynchronously
    await svc.sendGuardianAlert(
      packageName: event['packageName']?.toString() ?? '',
      appName:     event['appName']?.toString()     ?? '',
      riskScore:   (event['riskScore'] as num?)?.toInt() ?? 0,
      riskLevel:   event['riskLevel']?.toString()   ?? 'warning',
      riskTags:    (event['riskTags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      cloneVerdict: event['cloneVerdict']?.toString(),
    );
    return event;
  });
});

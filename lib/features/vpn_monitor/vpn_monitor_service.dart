import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrafficEvent {
  final String destIp;
  final String destDomain;
  final String threatLevel; // safe / suspicious / malicious
  final DateTime timestamp;

  const TrafficEvent({
    required this.destIp,
    required this.destDomain,
    required this.threatLevel,
    required this.timestamp,
  });

  bool get isThreat => threatLevel != 'safe';
}

/// Result of attempting to start the VPN monitor.
class VpnStartResult {
  final bool started;
  final String? errorMessage; // user-facing reason if started==false

  const VpnStartResult({required this.started, this.errorMessage});

  factory VpnStartResult.success() => const VpnStartResult(started: true);
  factory VpnStartResult.failure(String msg) =>
      VpnStartResult(started: false, errorMessage: msg);
}

class VpnMonitorService {
  static const _method = MethodChannel('secureshield/vpn_monitor');
  static const _events = EventChannel('secureshield/vpn_events');

  /// Stream of traffic events from the native VPN service.
  ///
  /// Returns an empty stream that swallows ALL errors (cast errors, plugin
  /// errors, native crashes). The UI just gets fewer events on failure
  /// instead of throwing.
  Stream<TrafficEvent> get trafficStream {
    return _events
        .receiveBroadcastStream()
        .handleError((Object e, StackTrace? st) {
          debugPrint('[VPN] event-stream error swallowed: $e');
        })
        .where((dynamic e) => e is Map)
        .map<TrafficEvent?>((dynamic e) {
          try {
            final m = e as Map;
            return TrafficEvent(
              destIp:      m['destIp']      as String? ?? '',
              destDomain:  m['destDomain']  as String? ?? '',
              threatLevel: m['threatLevel'] as String? ?? 'safe',
              timestamp:   DateTime.now(),
            );
          } catch (err) {
            debugPrint('[VPN] event-map decode failed: $err');
            return null;
          }
        })
        .where((e) => e != null)
        .cast<TrafficEvent>();
  }

  /// Attempts to start the VPN. Never throws.
  ///
  /// Returns a [VpnStartResult] indicating whether the service started and
  /// — if not — a friendly error message to surface to the user.
  Future<VpnStartResult> startVpn() async {
    try {
      final ok = await _method.invokeMethod<bool>('startVpn') ?? false;
      if (ok) return VpnStartResult.success();
      return VpnStartResult.failure(
        'VPN permission was not granted. Please allow it in the system dialog '
        'and try again.',
      );
    } on MissingPluginException {
      return VpnStartResult.failure(
        'VPN monitor is unavailable on this device (plugin missing).',
      );
    } on PlatformException catch (e) {
      return VpnStartResult.failure(
        'Could not start the VPN monitor: ${e.message ?? e.code}',
      );
    } catch (e) {
      return VpnStartResult.failure(
        'Could not start the VPN monitor: $e',
      );
    }
  }

  Future<void> stopVpn() async {
    try { await _method.invokeMethod('stopVpn'); } catch (e) {
      debugPrint('[VPN] stopVpn ignored error: $e');
    }
  }

  Future<bool> isRunning() async {
    try {
      return await _method.invokeMethod<bool>('isVpnRunning') ?? false;
    } catch (_) { return false; }
  }
}

// Providers
final vpnMonitorServiceProvider =
    Provider<VpnMonitorService>((ref) => VpnMonitorService());

class VpnStateNotifier extends StateNotifier<bool> {
  final VpnMonitorService _service;
  VpnStateNotifier(this._service) : super(false);

  Future<VpnStartResult> start() async {
    final result = await _service.startVpn();
    if (result.started) state = true;
    return result;
  }

  Future<void> stop() async {
    await _service.stopVpn();
    state = false;
  }

  Future<void> sync() async {
    state = await _service.isRunning();
  }
}

final vpnStateProvider = StateNotifierProvider<VpnStateNotifier, bool>((ref) {
  return VpnStateNotifier(ref.watch(vpnMonitorServiceProvider));
});

final vpnTrafficStreamProvider = StreamProvider<TrafficEvent>((ref) {
  return ref.watch(vpnMonitorServiceProvider).trafficStream;
});

// Traffic log history
class TrafficLogNotifier extends StateNotifier<List<TrafficEvent>> {
  TrafficLogNotifier() : super([]);

  void add(TrafficEvent e) {
    state = [e, ...state].take(200).toList();
  }

  void clear() => state = [];
}

final trafficLogProvider =
    StateNotifierProvider<TrafficLogNotifier, List<TrafficEvent>>((ref) {
  final notifier = TrafficLogNotifier();
  ref.listen(vpnTrafficStreamProvider, (_, next) {
    next.whenData(notifier.add);
  });
  return notifier;
});

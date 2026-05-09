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

class VpnMonitorService {
  static const _method = MethodChannel('secureshield/vpn_monitor');
  static const _events = EventChannel('secureshield/vpn_events');

  Stream<TrafficEvent> get trafficStream {
    return _events
        .receiveBroadcastStream()
        .handleError((dynamic _) {
          // Silently swallow errors (e.g. service crash, MissingPluginException)
          // so the UI degrades gracefully instead of crashing the app.
        })
        .where((e) => e != null)
        .map((e) {
          final m = e as Map;
          return TrafficEvent(
            destIp:      m['destIp']      as String? ?? '',
            destDomain:  m['destDomain']  as String? ?? '',
            threatLevel: m['threatLevel'] as String? ?? 'safe',
            timestamp:   DateTime.now(),
          );
        })
        .handleError((dynamic _) {
          // Guard against map-cast errors
        });
  }

  Future<bool> startVpn() async {
    try {
      return await _method.invokeMethod<bool>('startVpn') ?? false;
    } catch (e) {
      // MissingPluginException or foreground service permission error
      return false;
    }
  }

  Future<void> stopVpn() async {
    try { await _method.invokeMethod('stopVpn'); } catch (_) {}
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

  Future<bool> start() async {
    final ok = await _service.startVpn();
    if (ok) state = true;
    return ok;
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

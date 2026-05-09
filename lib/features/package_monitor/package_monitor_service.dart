import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PackageInstallEvent {
  final String packageName;
  final String appName;
  final bool isReplacing;
  final bool isUnknownSource;
  final DateTime timestamp;

  const PackageInstallEvent({
    required this.packageName,
    required this.appName,
    required this.isReplacing,
    required this.isUnknownSource,
    required this.timestamp,
  });

  String get riskLevel {
    if (isUnknownSource) return 'high';
    if (isReplacing) return 'low';
    return 'medium';
  }
}

class PackageMonitorService {
  static const _events = EventChannel('secureshield/package_events');

  Stream<PackageInstallEvent> get installStream {
    return _events.receiveBroadcastStream().map((e) {
      final m = e as Map;
      return PackageInstallEvent(
        packageName:     m['packageName']     as String? ?? '',
        appName:         m['appName']         as String? ?? '',
        isReplacing:     m['isReplacing']     as bool?   ?? false,
        isUnknownSource: m['isUnknownSource'] as bool?   ?? false,
        timestamp:       DateTime.fromMillisecondsSinceEpoch(
                           m['timestamp'] as int? ?? 0),
      );
    });
  }
}

final packageMonitorServiceProvider =
    Provider<PackageMonitorService>((ref) => PackageMonitorService());

final packageInstallStreamProvider = StreamProvider<PackageInstallEvent>((ref) {
  return ref.watch(packageMonitorServiceProvider).installStream;
});

class PackageInstallHistoryNotifier
    extends StateNotifier<List<PackageInstallEvent>> {
  PackageInstallHistoryNotifier() : super([]);

  void add(PackageInstallEvent e) {
    state = [e, ...state].take(100).toList();
  }

  void clear() => state = [];
}

final packageInstallHistoryProvider = StateNotifierProvider<
    PackageInstallHistoryNotifier, List<PackageInstallEvent>>((ref) {
  final notifier = PackageInstallHistoryNotifier();
  ref.listen(packageInstallStreamProvider, (_, next) {
    next.whenData(notifier.add);
  });
  return notifier;
});

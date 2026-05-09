import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BankOtpAlert {
  final String otp;
  final String bank;
  final String packageName;
  final DateTime receivedAt;

  const BankOtpAlert({
    required this.otp,
    required this.bank,
    required this.packageName,
    required this.receivedAt,
  });
}

class BankOtpService {
  static const _channel = EventChannel('secureshield/bank_otp_events');
  static const _remote  = MethodChannel('secureshield/remote_detector');

  Stream<BankOtpAlert> get otpStream {
    return _channel.receiveBroadcastStream().map((event) {
      final m = event as Map;
      return BankOtpAlert(
        otp:         m['otp']     as String? ?? '',
        bank:        m['bank']    as String? ?? 'Bank',
        packageName: m['package'] as String? ?? '',
        receivedAt:  DateTime.now(),
      );
    });
  }

  Future<bool> isNotificationListenerEnabled() async {
    try {
      return await _remote.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
    } catch (_) { return false; }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _remote.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }
}

// Provider
final bankOtpServiceProvider = Provider<BankOtpService>((ref) => BankOtpService());

final bankOtpStreamProvider = StreamProvider<BankOtpAlert>((ref) {
  return ref.watch(bankOtpServiceProvider).otpStream;
});

// History list
class BankOtpHistoryNotifier extends StateNotifier<List<BankOtpAlert>> {
  BankOtpHistoryNotifier() : super([]);

  void addAlert(BankOtpAlert alert) {
    state = [alert, ...state].take(50).toList();
  }

  void clear() => state = [];
}

final bankOtpHistoryProvider =
    StateNotifierProvider<BankOtpHistoryNotifier, List<BankOtpAlert>>(
  (ref) {
    final notifier = BankOtpHistoryNotifier();
    // Listen to stream and append to history
    ref.listen(bankOtpStreamProvider, (_, next) {
      next.whenData(notifier.addAlert);
    });
    return notifier;
  },
);

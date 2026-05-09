import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../bank_otp_service.dart';

class BankOtpScreen extends ConsumerStatefulWidget {
  const BankOtpScreen({super.key});

  @override
  ConsumerState<BankOtpScreen> createState() => _BankOtpScreenState();
}

class _BankOtpScreenState extends ConsumerState<BankOtpScreen> {
  bool _listenerEnabled = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkListenerPermission();
  }

  Future<void> _checkListenerPermission() async {
    final enabled = await ref.read(bankOtpServiceProvider).isNotificationListenerEnabled();
    if (mounted) setState(() { _listenerEnabled = enabled; _checking = false; });
  }

  Future<void> _enableListener() async {
    await ref.read(bankOtpServiceProvider).openNotificationListenerSettings();
    await Future.delayed(const Duration(seconds: 1));
    await _checkListenerPermission();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(bankOtpHistoryProvider);
    // Keep listening to stream to update history
    ref.listen(bankOtpStreamProvider, (_, next) {
      next.whenData((alert) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.warning,
            content: Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Bank OTP from ${alert.bank}: ${alert.otp}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )),
              ],
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: () => Clipboard.setData(ClipboardData(text: alert.otp)),
            ),
          ),
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank OTP Monitor'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear history',
              onPressed: () => ref.read(bankOtpHistoryProvider.notifier).clear(),
            ),
        ],
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                // Permission banner
                if (!_listenerEnabled)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Notification Access Required',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Grant notification access so SecureShield can detect bank OTPs and alert you about suspicious activity.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _enableListener,
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('Grant Notification Access'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warning,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_listenerEnabled)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'OTP monitoring active',
                          style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                // Info card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield, color: AppTheme.accent, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'SecureShield monitors bank notifications for OTPs. '
                          'If an OTP arrives while you\'re not expecting it, '
                          'it could indicate fraud. Never share OTPs.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('OTP History', style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )),
                      const Spacer(),
                      Text('${history.length} detected',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_none,
                                size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text(
                                'No OTPs detected yet',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bank OTPs will appear here automatically',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: history.length,
                          itemBuilder: (_, i) => _OtpAlertCard(alert: history[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _OtpAlertCard extends StatelessWidget {
  final BankOtpAlert alert;
  const _OtpAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(alert.receivedAt);
    final timeStr = age.inMinutes < 1
        ? 'Just now'
        : age.inHours < 1
            ? '${age.inMinutes}m ago'
            : '${age.inHours}h ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_clock, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.bank,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(timeStr,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.otp,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: alert.otp)),
                child: const Text('Copy',
                  style: TextStyle(color: AppTheme.accent, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

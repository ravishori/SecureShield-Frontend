import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../vpn_monitor_service.dart';

class VpnMonitorScreen extends ConsumerStatefulWidget {
  const VpnMonitorScreen({super.key});

  @override
  ConsumerState<VpnMonitorScreen> createState() => _VpnMonitorScreenState();
}

class _VpnMonitorScreenState extends ConsumerState<VpnMonitorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulse;
  bool _showOnlyThreats = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    ref.read(vpnStateProvider.notifier).sync();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final isOn = ref.read(vpnStateProvider);
    try {
      if (isOn) {
        await ref.read(vpnStateProvider.notifier).stop();
      } else {
        final result = await ref.read(vpnStateProvider.notifier).start();
        if (!result.started && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 5),
              content: Text(
                result.errorMessage ??
                    'VPN permission denied. Grant it in the system dialog.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Last-resort: should never happen because the service never throws,
      // but guarantees the UI never crashes from a toggle.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Unexpected error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn   = ref.watch(vpnStateProvider);
    final allLog = ref.watch(trafficLogProvider);

    // Keep history live
    ref.listen(vpnTrafficStreamProvider, (_, __) {});

    final log = _showOnlyThreats
        ? allLog.where((e) => e.isThreat).toList()
        : allLog;

    final threats = allLog.where((e) => e.isThreat).length;
    final malicious = allLog.where((e) => e.threatLevel == 'malicious').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffic Monitor'),
        actions: [
          if (allLog.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => ref.read(trafficLogProvider.notifier).clear(),
              tooltip: 'Clear log',
            ),
        ],
      ),
      body: Column(
        children: [
          // VPN status card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                isOn ? AppTheme.success.withValues(alpha: 0.8) : AppTheme.primary,
                isOn ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.primary.withValues(alpha: 0.6),
              ]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isOn ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggle,
                  child: ScaleTransition(
                    scale: isOn ? _pulse : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: Icon(
                        isOn ? Icons.shield : Icons.shield_outlined,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOn ? 'Traffic Monitor Active' : 'Monitor Off',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOn
                            ? 'Blocking connections to known-malicious networks'
                            : 'Tap shield to start monitoring',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (isOn && allLog.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          _chip('${allLog.length}', 'Total', Colors.white30),
                          const SizedBox(width: 8),
                          _chip('$threats', 'Threats', AppTheme.warning.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          _chip('$malicious', 'Malicious', AppTheme.errorColor.withValues(alpha: 0.7)),
                        ]),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: (_) => _toggle(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white30,
                ),
              ],
            ),
          ),

          // Privacy notice
          if (!isOn)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.privacy_tip, color: AppTheme.accent, size: 18),
                    SizedBox(width: 8),
                    Text('Privacy First', style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    '• Only traffic to known-malicious network ranges is routed into a local VPN tunnel; everything else uses your normal connection\n'
                    '• A connection attempt to such a range is blocked and reported (only the destination address is read, never your data)\n'
                    '• Domain-name based detection is not available in this mode',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),

          if (isOn) ...[
            // Filter bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Live Connections',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showOnlyThreats = !_showOnlyThreats),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showOnlyThreats
                            ? AppTheme.errorColor.withValues(alpha: 0.2)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _showOnlyThreats
                              ? AppTheme.errorColor
                              : AppTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Threats only',
                        style: TextStyle(
                          color: _showOnlyThreats ? AppTheme.errorColor : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: log.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_tethering, size: 56,
                            color: AppTheme.accent.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('No blocked connection attempts yet',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: log.length,
                      itemBuilder: (_, i) => _TrafficCard(event: log[i]),
                    ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  final TrafficEvent event;
  const _TrafficCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.threatLevel == 'malicious'
        ? AppTheme.errorColor
        : event.threatLevel == 'suspicious'
            ? AppTheme.warning
            : AppTheme.success;
    final icon = event.threatLevel == 'malicious'
        ? Icons.dangerous
        : event.threatLevel == 'suspicious'
            ? Icons.warning_amber
            : Icons.check_circle_outline;

    final timeStr = '${event.timestamp.hour.toString().padLeft(2, '0')}:'
                    '${event.timestamp.minute.toString().padLeft(2, '0')}:'
                    '${event.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.destDomain == event.destIp
                      ? event.destIp
                      : event.destDomain,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.destDomain != event.destIp)
                  Text(event.destIp,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.threatLevel.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              Text(timeStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

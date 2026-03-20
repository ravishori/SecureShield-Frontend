import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../wifi_api.dart';

class WifiScannerScreen extends StatefulWidget {
  const WifiScannerScreen({super.key});

  @override
  State<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen> {
  final _api = WifiApi();
  final _ssidCtrl = TextEditingController();
  final _encryptionCtrl = TextEditingController(text: 'WPA2');
  Map<String, dynamic>? _result;
  bool _scanning = false;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _api.getHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {}
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _result = null; });
    try {
      const deviceId = '00000000-0000-0000-0000-000000000001';
      final result = await _api.scanWifi(
        deviceId: deviceId,
        ssid: _ssidCtrl.text.trim().isEmpty ? null : _ssidCtrl.text.trim(),
        encryptionType: _encryptionCtrl.text.trim().isEmpty ? null : _encryptionCtrl.text.trim(),
      );
      if (mounted) {
        setState(() { _result = result; _scanning = false; });
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Safety Checker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _ssidCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi Name (SSID)',
                      hintText: 'e.g. CafeWifi',
                      prefixIcon: Icon(Icons.wifi),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _encryptionCtrl.text,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Encryption Type',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'OPEN', child: Text('Open (No Password)')),
                      DropdownMenuItem(value: 'WEP', child: Text('WEP (Old/Weak)')),
                      DropdownMenuItem(value: 'WPA', child: Text('WPA')),
                      DropdownMenuItem(value: 'WPA2', child: Text('WPA2 (Recommended)')),
                      DropdownMenuItem(value: 'WPA3', child: Text('WPA3 (Best)')),
                    ],
                    onChanged: (v) => _encryptionCtrl.text = v ?? 'WPA2',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_protected_setup),
                      label: Text(_scanning ? 'Checking...' : 'Check Wi-Fi Safety'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.background),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_result != null) _buildResultCard(_result!),

            if (_history.isNotEmpty) ...[
              Text('Recent Scans', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._history.take(5).map((h) {
                final item = h as Map<String, dynamic>;
                final riskLevel = item['risk_level'] as String? ?? 'safe';
                final color = AppTheme.riskColor(riskLevel);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['ssid'] as String? ?? 'Unknown',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(riskLevel.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final riskLevel = result['risk_level'] as String? ?? 'safe';
    final isSuspicious = result['is_suspicious'] as bool? ?? false;
    final riskReasons = (result['risk_reasons'] as List?)?.cast<String>() ?? [];
    final color = AppTheme.riskColor(riskLevel);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Column(
        children: [
          Icon(
            isSuspicious ? Icons.wifi_off : Icons.wifi_protected_setup,
            size: 52,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(riskLevel.toUpperCase(), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (riskReasons.isEmpty)
            const Text('This Wi-Fi network appears safe.', style: TextStyle(color: AppTheme.textSecondary))
          else ...[
            const Text('Risk Factors:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            ...riskReasons.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

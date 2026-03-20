import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../link_scanner_api.dart';

class LinkScannerScreen extends StatefulWidget {
  const LinkScannerScreen({super.key});

  @override
  State<LinkScannerScreen> createState() => _LinkScannerScreenState();
}

class _LinkScannerScreenState extends State<LinkScannerScreen> {
  final _api = LinkScannerApi();
  final _urlController = TextEditingController();
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
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL to scan')),
      );
      return;
    }
    setState(() { _scanning = true; _result = null; });
    try {
      final result = await _api.scanLink(url);
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
      appBar: AppBar(title: const Text('Link Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Enter URL to scan',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.security),
                label: Text(_scanning ? 'Scanning...' : 'Scan URL'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.background),
              ),
            ),
            const SizedBox(height: 20),

            // Result card
            if (_result != null) _buildResultCard(_result!),

            // History
            if (_history.isNotEmpty) ...[
              Text('Recent Scans', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._history.take(5).map((h) {
                final item = h as Map<String, dynamic>;
                final isMalicious = item['is_malicious'] as bool? ?? false;
                final isPhishing = item['is_phishing'] as bool? ?? false;
                final riskScore = (item['risk_score'] as num?)?.toDouble() ?? 0.0;
                final url = item['url'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isMalicious || isPhishing ? Icons.dangerous : Icons.check_circle,
                        color: isMalicious || isPhishing ? AppTheme.errorColor : AppTheme.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          url.length > 40 ? '${url.substring(0, 40)}...' : url,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                      Text(
                        '${riskScore.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: riskScore > 50 ? AppTheme.errorColor : AppTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
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
    final isMalicious = result['is_malicious'] as bool? ?? false;
    final isPhishing = result['is_phishing'] as bool? ?? false;
    final riskScore = (result['risk_score'] as num?)?.toDouble() ?? 0.0;
    final threatCategory = result['threat_category'] as String? ?? '';
    final isSafe = !isMalicious && !isPhishing && riskScore < 30;

    final color = isSafe ? AppTheme.success : riskScore > 60 ? AppTheme.errorColor : AppTheme.warning;
    final icon = isSafe ? Icons.check_circle : isMalicious ? Icons.dangerous : Icons.warning_amber;
    final label = isSafe ? 'SAFE' : isMalicious ? 'MALICIOUS' : isPhishing ? 'PHISHING' : 'SUSPICIOUS';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Risk Score: ${riskScore.toStringAsFixed(0)}/100', style: TextStyle(color: color.withOpacity(0.8))),
          if (threatCategory.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                threatCategory.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
          if (!isSafe) ...[
            const SizedBox(height: 12),
            const Text(
              'Do not visit this website. It may steal your personal information or install malware.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

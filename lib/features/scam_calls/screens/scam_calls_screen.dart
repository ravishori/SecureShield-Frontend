import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../scam_calls_api.dart';

/// Report a suspicious call, see how the server scored it, block the number, and review past reports.
///
/// Reporting is user-initiated on purpose: reading the caller's number automatically needs the call-log
/// permission that Google Play restricts, and the user knows best which calls were scams.
class ScamCallsScreen extends StatefulWidget {
  const ScamCallsScreen({super.key});

  @override
  State<ScamCallsScreen> createState() => _ScamCallsScreenState();
}

class _ScamCallsScreenState extends State<ScamCallsScreen> {
  final _api = ScamCallsApi();
  final _number = TextEditingController();
  final _minutes = TextEditingController(text: '1');
  final _reason = TextEditingController();
  List<dynamic> _history = [];
  Map<String, dynamic>? _last;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    _minutes.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final h = await _api.history();
      if (mounted) setState(() => _history = h);
    } catch (_) {/* shown empty */}
  }

  bool get _numberValid => RegExp(r'^\+?[0-9][0-9\s\-()]{3,18}$').hasMatch(_number.text.trim());

  Future<void> _submit() async {
    if (!_numberValid) {
      setState(() => _error = 'Enter the caller\'s phone number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
      final result = await _api.report(
        callerNumber: _number.text.trim(),
        durationSeconds: (minutes.clamp(0, 1440)) * 60,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      setState(() => _last = result);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is DioException ? 'Could not report the call' : 'Could not report the call. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block(String number) async {
    try {
      await _api.block(number);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$number blocked')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not block the number')));
      }
    }
  }

  Color _riskColor(num score) =>
      score >= 70 ? AppTheme.errorColor : (score >= 40 ? AppTheme.warning : AppTheme.success);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scam Calls')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Got a call that felt wrong? Report the number: SecureShield scores it, warns you, and lets you block it.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('scamNumber'),
            controller: _number,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Caller number', counterText: ''),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('scamMinutes'),
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Call length (minutes)'),
              ),
            ),
          ]),
          TextField(
            key: const Key('scamReason'),
            controller: _reason,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'What did they ask for? (optional)'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor))),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            key: const Key('scamSubmit'),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.report_gmailerrorred),
            label: const Text('Report this call'),
          ),
          if (_last != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: _riskColor((_last!['risk_score'] as num?) ?? 0)),
                title: Text('Risk score ${((_last!['risk_score'] as num?) ?? 0).round()}/100'
                    '${_last!['is_blocked'] == true ? ' - blocked' : ''}'),
                subtitle: Text((_last!['detection_reason'] as String?) ?? ''),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Your reports', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No reported calls yet.', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          for (final c in _history.cast<Map<String, dynamic>>())
            Card(
              child: ListTile(
                title: Text(c['caller_number'] as String? ?? ''),
                subtitle: Text('Risk ${((c['risk_score'] as num?) ?? 0).round()}/100'
                    '${c['is_blocked'] == true ? ' - blocked' : ''}'),
                trailing: c['is_blocked'] == true
                    ? const Icon(Icons.block, color: AppTheme.errorColor)
                    : TextButton(onPressed: () => _block(c['caller_number'] as String), child: const Text('Block')),
              ),
            ),
        ],
      ),
    );
  }
}

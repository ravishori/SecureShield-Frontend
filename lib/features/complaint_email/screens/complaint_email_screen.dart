import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class ComplaintEmailScreen extends ConsumerStatefulWidget {
  const ComplaintEmailScreen({super.key});

  @override
  ConsumerState<ComplaintEmailScreen> createState() => _ComplaintEmailScreenState();
}

class _ComplaintEmailScreenState extends ConsumerState<ComplaintEmailScreen> {
  final _incidentCtrl   = TextEditingController();
  final _bankCtrl       = TextEditingController();
  final _amountCtrl     = TextEditingController();
  final _dateCtrl       = TextEditingController();
  final _formKey        = GlobalKey<FormState>();

  bool   _loading       = false;
  String _generatedEmail = '';
  String _selectedType  = 'Unauthorized Transaction';

  final _scamTypes = [
    'Unauthorized Transaction',
    'OTP/UPI Fraud',
    'Phishing — Fake Bank Website',
    'SIM Swap Fraud',
    'KYC Update Scam',
    'Loan App Fraud',
    'Investment Scam',
    'QR Code Scam',
    'Card Cloning',
    'Other',
  ];

  @override
  void dispose() {
    _incidentCtrl.dispose();
    _bankCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _generatedEmail = ''; });

    try {
      final dio = DioClient().dio;
      final response = await dio.post(
        AppConstants.generateEmail,
        data: {
          'incident_type':  _selectedType,
          'bank_name':      _bankCtrl.text.trim(),
          'amount':         _amountCtrl.text.trim(),
          'incident_date':  _dateCtrl.text.trim(),
          'description':    _incidentCtrl.text.trim(),
        },
      );
      setState(() => _generatedEmail = response.data['email'] as String? ?? '');
    } on DioException catch (e) {
      _showError(e.response?.data?['detail'] ?? 'Failed to generate email');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.errorColor, content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Bank Complaint Email')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.smart_toy, color: AppTheme.accent, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI will generate a formal complaint email for bank fraud. '
                        'Fill in the details below and share it with your bank\'s grievance cell.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Fraud Type', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    items: _scamTypes.map((t) => DropdownMenuItem(
                      value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _buildField(_bankCtrl, 'Bank / Institution Name', 'e.g. HDFC Bank',
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
              const SizedBox(height: 14),

              Row(children: [
                Expanded(child: _buildField(_amountCtrl, 'Amount Lost (₹)', 'e.g. 50000',
                  keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_dateCtrl, 'Incident Date', 'DD/MM/YYYY',
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null)),
              ]),
              const SizedBox(height: 14),

              const Text('Incident Description', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _incidentCtrl,
                maxLines: 5,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Describe what happened in detail...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Please describe the incident' : null,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generateEmail,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'Generating...' : 'Generate Complaint Email'),
                ),
              ),

              if (_generatedEmail.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Generated Email', style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, color: AppTheme.accent, size: 20),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email copied to clipboard')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppTheme.accent, size: 20),
                      tooltip: 'Share',
                      onPressed: () => Share.share(_generatedEmail,
                        subject: 'Bank Fraud Complaint — $_selectedType'),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: SelectableText(
                    _generatedEmail,
                    style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13, height: 1.6),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Tip: Also file a complaint at cybercrime.gov.in or call 1930 for faster resolution.',
                    style: TextStyle(color: AppTheme.warning, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl, String label, String hint, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.textPrimary),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

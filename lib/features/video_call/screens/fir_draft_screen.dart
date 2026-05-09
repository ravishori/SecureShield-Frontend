import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../video_call_api.dart';

class FirDraftScreen extends StatefulWidget {
  const FirDraftScreen({super.key});

  @override
  State<FirDraftScreen> createState() => _FirDraftScreenState();
}

class _FirDraftScreenState extends State<FirDraftScreen> {
  final _api = VideoCallApi();
  final _formKey = GlobalKey<FormState>();

  final _incidentTypeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _suspectCtrl = TextEditingController();
  final _evidenceCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _generating = false;
  Map<String, dynamic>? _firResult;
  DateTime _incidentDate = DateTime.now();

  static const incidentTypes = [
    'Online Banking Fraud',
    'UPI Fraud',
    'OTP Fraud',
    'Phishing Attack',
    'Fake Job Offer Fraud',
    'Investment Scam',
    'Romance Scam',
    'Social Media Hacking',
    'SIM Swap Fraud',
    'Identity Theft',
    'Ransomware Attack',
    'Online Shopping Fraud',
    'Other Cybercrime',
  ];

  String _selectedType = 'Online Banking Fraud';

  @override
  void dispose() {
    _incidentTypeCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _suspectCtrl.dispose();
    _evidenceCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateFir() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _generating = true; _firResult = null; });
    try {
      final result = await _api.generateFir(
        incidentType: _selectedType,
        description: _descCtrl.text.trim(),
        incidentDate: _incidentDate.toIso8601String().split('T')[0],
        incidentLocation: _locationCtrl.text.trim(),
        complainantName: _nameCtrl.text.trim(),
        complainantPhone: _phoneCtrl.text.trim(),
        suspectInfo: _suspectCtrl.text.trim().isEmpty ? null : _suspectCtrl.text.trim(),
        evidenceSummary: _evidenceCtrl.text.trim().isEmpty ? null : _evidenceCtrl.text.trim(),
        amountLost: _amountCtrl.text.trim().isEmpty ? null : _amountCtrl.text.trim(),
      );
      if (mounted) setState(() { _firResult = result; _generating = false; });
    } catch (e) {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate FIR Draft')),
      body: _firResult != null ? _buildFirResult() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Incident Details'),
          DropdownButtonFormField<String>(
            value: _selectedType,
            dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Incident Type *', Icons.category),
            items: incidentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
            onChanged: (v) => setState(() => _selectedType = v ?? _selectedType),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Incident Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            subtitle: Text(
              '${_incidentDate.day}/${_incidentDate.month}/${_incidentDate.year}',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            ),
            trailing: const Icon(Icons.calendar_today, color: AppTheme.accent, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _incidentDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _incidentDate = picked);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Incident Location *', Icons.location_on),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 5,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Detailed Description *', Icons.description),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          _section('Your Details'),
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Full Name *', Icons.person),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Phone Number *', Icons.phone),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          _section('Additional Information (Optional)'),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Amount Lost (₹)', Icons.currency_rupee),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _suspectCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Suspect Info (phone/email/name)', Icons.person_search),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _evidenceCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _deco('Evidence Summary (screenshots, chat logs, etc.)', Icons.folder_open),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generating ? null : _generateFir,
            icon: _generating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_generating ? 'Generating FIR Draft...' : 'Generate FIR Draft with AI'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: This draft is AI-generated. Review with a legal expert before submitting to police.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFirResult() {
    final fir = _firResult!['fir_draft'] as String? ?? '';
    final caseId = _firResult!['case_id'] as String? ?? '';
    final note = _firResult!['note'] as String? ?? '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.success.withOpacity(0.1),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FIR Draft Generated!', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                Text('Case ID: $caseId', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: AppTheme.accent),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fir));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FIR copied to clipboard'), backgroundColor: AppTheme.success),
                );
              },
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Text(note, style: const TextStyle(color: AppTheme.warning, fontSize: 12, height: 1.4)),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: Text(fir, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.6, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _firResult = null),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Details'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surface),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.accent, size: 18),
      filled: true,
      fillColor: AppTheme.cardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.accent.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.accent.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accent)),
    );
  }
}

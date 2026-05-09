import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../video_call_api.dart';
import 'fir_draft_screen.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _api = VideoCallApi();
  bool _loading = false;
  Map<String, dynamic>? _room;
  Map<String, dynamic>? _policeContacts;
  String _selectedCallType = 'police_report';

  static const callTypes = [
    {'value': 'police_report', 'label': 'Police Report Call', 'icon': Icons.local_police},
    {'value': 'evidence_recording', 'label': 'Evidence Recording', 'icon': Icons.videocam},
    {'value': 'family_sos', 'label': 'Family SOS Call', 'icon': Icons.family_restroom},
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _api.getPoliceContacts();
      if (mounted) setState(() => _policeContacts = contacts);
    } catch (_) {}
  }

  Future<void> _createRoom() async {
    setState(() { _loading = true; _room = null; });
    try {
      final room = await _api.createRoom(callType: _selectedCallType);
      if (mounted) setState(() { _room = room; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room link copied to clipboard'), backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Video Reporting')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.videocam_rounded, color: AppTheme.accent, size: 36),
                  const SizedBox(height: 12),
                  const Text('Secure Video Call', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Create an encrypted video room to report crime to police, record evidence, or connect with family during emergency.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Call type selector
            const Text('Select Call Type', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...callTypes.map((type) => GestureDetector(
              onTap: () => setState(() => _selectedCallType = type['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedCallType == type['value'] ? AppTheme.accent.withOpacity(0.15) : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedCallType == type['value'] ? AppTheme.accent : AppTheme.accent.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(type['icon'] as IconData, color: _selectedCallType == type['value'] ? AppTheme.accent : AppTheme.textSecondary, size: 22),
                    const SizedBox(width: 12),
                    Text(type['label'] as String, style: TextStyle(
                      color: _selectedCallType == type['value'] ? AppTheme.accent : AppTheme.textPrimary,
                      fontWeight: _selectedCallType == type['value'] ? FontWeight.bold : FontWeight.normal,
                    )),
                    const Spacer(),
                    if (_selectedCallType == type['value'])
                      const Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createRoom,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.video_call),
                label: Text(_loading ? 'Creating Room...' : 'Create Secure Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            if (_room != null) ...[
              const SizedBox(height: 20),
              _buildRoomCard(_room!),
            ],

            const SizedBox(height: 20),
            // FIR Draft button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.description, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    const Text('Generate FIR Draft', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('AI generates a formal First Information Report draft ready for police filing.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirDraftScreen())),
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Generate FIR Draft'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.black),
                  ),
                ],
              ),
            ),

            // Police contacts
            if (_policeContacts != null) ...[
              const SizedBox(height: 20),
              const Text('Emergency Contacts', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...[
                {'label': 'Cybercrime Helpline', 'value': _policeContacts!['cybercrime_helpline'], 'icon': Icons.phone_in_talk},
                {'label': 'Police', 'value': _policeContacts!['police'], 'icon': Icons.local_police},
                {'label': 'National Emergency', 'value': _policeContacts!['national_emergency'], 'icon': Icons.emergency},
              ].map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(c['icon'] as IconData, color: AppTheme.errorColor, size: 18),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['label'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text(c['value'].toString(), style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final url = room['room_url'] as String? ?? '';
    final instructions = (room['instructions'] as List?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            const Text('Room Created!', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(child: Text(url, style: const TextStyle(color: AppTheme.accent, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.copy, color: AppTheme.accent, size: 18), onPressed: () => _copyLink(url)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Instructions:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          ...instructions.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppTheme.accent)),
                Expanded(child: Text(i, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4))),
              ],
            ),
          )),
          const SizedBox(height: 12),
          const Text(
            'Tip: The link opens in any browser. Share it with the police officer or family member.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

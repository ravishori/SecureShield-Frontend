import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme.dart';
import '../call_recording_provider.dart';
import '../services/recording_storage_service.dart';
import '../services/recording_service.dart';

// ── Cyber Cell data for major Indian cities ────────────────────────────────────

class _CyberCell {
  final String city;
  final String phone;
  final String email;
  const _CyberCell({required this.city, required this.phone, required this.email});
}

const _cyberCells = [
  _CyberCell(city: 'National Helpline', phone: '1930',         email: 'cybercrime.gov.in'),
  _CyberCell(city: 'Mumbai',            phone: '022-26300738', email: 'cybercell@mumbaipolice.org'),
  _CyberCell(city: 'Delhi',             phone: '011-23490151', email: 'cybercrime@delhipolice.nic.in'),
  _CyberCell(city: 'Bengaluru',         phone: '080-22943050', email: 'cybercrime.blr@ksp.gov.in'),
  _CyberCell(city: 'Hyderabad',         phone: '040-27852600', email: 'cybercrime@hyd.tspolice.gov.in'),
  _CyberCell(city: 'Chennai',           phone: '044-28512500', email: 'cybercell@tn.gov.in'),
  _CyberCell(city: 'Kolkata',           phone: '033-22143004', email: 'cyber@kolkatapolice.gov.in'),
  _CyberCell(city: 'Pune',              phone: '020-26123346', email: 'cybercrime@punepolice.gov.in'),
  _CyberCell(city: 'Ahmedabad',         phone: '079-25507621', email: 'cybercrime@adityabirla.gujpol.in'),
  _CyberCell(city: 'Jaipur',            phone: '0141-2227700', email: 'cybercrime@rajpolice.in'),
];

class EmergencyShareScreen extends ConsumerStatefulWidget {
  const EmergencyShareScreen({super.key});

  @override
  ConsumerState<EmergencyShareScreen> createState() =>
      _EmergencyShareScreenState();
}

class _EmergencyShareScreenState extends ConsumerState<EmergencyShareScreen> {
  final _dio = DioClient().dio;

  // Upload state
  bool _isUploading = false;
  String? _shareUrl;
  String? _uploadError;

  // Family contacts from backend
  List<Map<String, dynamic>> _familyContacts = [];
  bool _loadingFamily = false;

  // Prep: export raw bytes from tempPath (unencrypted) or from savedMeta (decrypt)
  String? _tempExportPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareFile();
      _loadFamilyContacts();
    });
  }

  Future<void> _prepareFile() async {
    final state = ref.read(callRecordingProvider);

    if (state.savedMeta != null) {
      // Already saved — decrypt for sharing
      try {
        final path = await RecordingStorageService.decryptForPlayback(
            state.savedMeta!);
        if (mounted) setState(() => _tempExportPath = path);
      } catch (_) {}
    } else if (state.tempPath != null) {
      // Not saved yet — use the raw temp file directly
      setState(() => _tempExportPath = state.tempPath);
    }
  }

  @override
  void dispose() {
    // Clean up decrypted export file if it's separate from the tempPath
    final state = ref.read(callRecordingProvider);
    if (_tempExportPath != null && _tempExportPath != state.tempPath) {
      RecordingService.deleteTempFile(_tempExportPath!);
    }
    super.dispose();
  }

  // ── System share sheet (WhatsApp / Email / any app) ───────────────────────

  Future<void> _shareViaSystem({String? subject}) async {
    if (_tempExportPath == null) {
      _showSnack('Recording not ready yet');
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(_tempExportPath!, mimeType: 'audio/aac')],
        subject: subject ?? 'Emergency Recording',
        text: 'Secure audio recording from SecureShield AI',
      );
    } catch (e) {
      _showSnack('Share failed: $e');
    }
  }

  // ── Backend upload + expiring link ────────────────────────────────────────

  Future<void> _uploadToBackend() async {
    if (_tempExportPath == null) {
      _showSnack('Recording not ready yet');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _shareUrl = null;
    });

    try {
      final fileName =
          'emergency_${DateTime.now().millisecondsSinceEpoch}.aac';

      // 1. Upload to /recordings/upload
      final formData = FormData.fromMap({
        'title': 'Emergency Recording ${_dateStr()}',
        'duration_seconds': ref.read(callRecordingProvider).elapsed.inSeconds,
        'is_encrypted': false, // bytes already raw here; server-side storage
        'file': await MultipartFile.fromFile(_tempExportPath!, filename: fileName),
      });

      final uploadResp =
          await _dio.post('/recordings/upload', data: formData);
      final recordingId = uploadResp.data['id'] as String;

      // 2. Generate expiring share link (24 h)
      final linkResp = await _dio.post('/recordings/$recordingId/share-link');
      final url = linkResp.data['share_url'] as String;

      if (mounted) {
        setState(() {
          _isUploading = false;
          _shareUrl = url;
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Upload failed';
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = msg.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString();
        });
      }
    }
  }

  // ── Load family contacts from backend ─────────────────────────────────────

  Future<void> _loadFamilyContacts() async {
    setState(() => _loadingFamily = true);
    try {
      final resp = await _dio.get('/family/members');
      final list = (resp.data as List?) ?? [];
      if (mounted) {
        setState(() {
          _familyContacts = list.cast<Map<String, dynamic>>();
          _loadingFamily  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  // ── Share to 1930 WhatsApp with prefilled message ──────────────────────────

  Future<void> _shareToNationalHelpline() async {
    final message = Uri.encodeComponent(
      'I want to report a cybercrime / financial fraud. '
      'I have audio evidence recorded via SecureShield AI. '
      'Incident date: ${_dateStr()}. Please advise on next steps.',
    );
    final url = Uri.parse('https://wa.me/911930?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('WhatsApp not available. Call 1930 directly.');
    }
  }

  // ── Call a cyber cell ──────────────────────────────────────────────────────

  Future<void> _callCyberCell(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnack('Cannot make call from this device');
    }
  }

  // ── Share recording to a family contact via WhatsApp ──────────────────────

  Future<void> _shareToFamilyContact(Map<String, dynamic> contact) async {
    final phone = (contact['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      _showSnack('No phone number for this contact');
      return;
    }
    // First share the file via system sheet, then open WhatsApp
    if (_tempExportPath != null) {
      final name = contact['name'] as String? ?? 'Family Member';
      await Share.shareXFiles(
        [XFile(_tempExportPath!, mimeType: 'audio/aac')],
        subject: 'Emergency Recording — Please Help',
        text: 'Hi $name, I need help. This is an emergency recording from SecureShield AI.',
      );
    } else {
      // Fallback: open WhatsApp chat
      final message = Uri.encodeComponent(
        'I need help urgently. Please call me. — SecureShield Emergency Alert');
      final url = Uri.parse('https://wa.me/91$phone?text=$message');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _copyLink() {
    if (_shareUrl == null) return;
    Clipboard.setData(ClipboardData(text: _shareUrl!));
    _showSnack('Link copied to clipboard', success: true);
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.success : AppTheme.errorColor,
    ));
  }

  String _dateStr() {
    final n = DateTime.now();
    return '${n.day}/${n.month}/${n.year} ${n.hour}:${n.minute.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Share'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.emergency_share_rounded,
                        color: AppTheme.errorColor, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Share recording immediately with trusted contacts or upload securely.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Share options ────────────────────────────────────────────
              _ShareOptionCard(
                icon: Icons.chat_rounded,
                title: 'Share via WhatsApp / SMS',
                subtitle: 'Opens system share sheet — choose any app',
                color: const Color(0xFF25D366),
                onTap: () => _shareViaSystem(subject: 'Emergency Recording'),
              ),

              const SizedBox(height: 12),

              _ShareOptionCard(
                icon: Icons.email_rounded,
                title: 'Share via Email',
                subtitle: 'Opens system share sheet with email option',
                color: AppTheme.accent,
                onTap: () => _shareViaSystem(subject: 'Emergency Audio Evidence'),
              ),

              const SizedBox(height: 12),

              // ── 1930 WhatsApp ────────────────────────────────────────────
              _ShareOptionCard(
                icon: Icons.support_agent,
                title: 'Report to 1930 (Cybercrime)',
                subtitle: 'Open WhatsApp to National Cybercrime Helpline',
                color: const Color(0xFF25D366),
                onTap: _shareToNationalHelpline,
              ),

              const SizedBox(height: 20),

              // ── Cyber Cells ──────────────────────────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Local Police Cyber Cells',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: _cyberCells.map((cell) => ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.local_police, color: AppTheme.errorColor, size: 18),
                    ),
                    title: Text(cell.city,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      )),
                    subtitle: Text(cell.phone,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: AppTheme.success, size: 20),
                      tooltip: 'Call ${cell.city}',
                      onPressed: () => _callCyberCell(cell.phone),
                    ),
                  )).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // ── Family Contacts ──────────────────────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Share with Family Contacts',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingFamily)
                const Center(child: CircularProgressIndicator(color: AppTheme.accent))
              else if (_familyContacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.family_restroom, color: AppTheme.textSecondary, size: 20),
                      SizedBox(width: 10),
                      Text('No family contacts added yet.\nGo to Family to add contacts.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _familyContacts.map((contact) {
                      final name  = contact['name']  as String? ?? 'Family Member';
                      final phone = contact['phone'] as String? ?? '';
                      final relation = contact['relationship'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primary.withOpacity(0.3),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          )),
                        subtitle: Text(
                          relation.isNotEmpty ? '$relation • $phone' : phone,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.share, color: AppTheme.accent, size: 20),
                          tooltip: 'Share with $name',
                          onPressed: () => _shareToFamilyContact(contact),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Backend upload ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.cloud_upload_rounded,
                              color: AppTheme.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Secure Upload + Expiring Link',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text('Generate a 24-hour download link',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_isUploading)
                      const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accent),
                      )
                    else if (_shareUrl != null) ...[
                      // ── Share link available ─────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.success.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.check_circle_rounded,
                                    color: AppTheme.success, size: 16),
                                SizedBox(width: 6),
                                Text('Upload successful! Link expires in 24h',
                                    style: TextStyle(
                                        color: AppTheme.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _shareUrl!,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: BorderSide(
                                    color: AppTheme.accent.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _copyLink,
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Link'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: BorderSide(
                                    color: AppTheme.accent.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Share.share(
                                'Emergency recording link (expires 24h): $_shareUrl',
                                subject: 'Emergency Recording Link',
                              ),
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Share Link'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      if (_uploadError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _uploadError!,
                            style: const TextStyle(
                                color: AppTheme.errorColor, fontSize: 12),
                          ),
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.textPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _uploadToBackend,
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: const Text('Upload & Get Link'),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Done ─────────────────────────────────────────────────────
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Done',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable share option card ─────────────────────────────────────────────────

class _ShareOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ShareOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

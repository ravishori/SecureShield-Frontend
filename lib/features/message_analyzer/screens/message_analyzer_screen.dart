import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/security/fraud_keyword_engine.dart';
import '../message_analyzer_api.dart';

class MessageAnalyzerScreen extends StatefulWidget {
  const MessageAnalyzerScreen({super.key});

  @override
  State<MessageAnalyzerScreen> createState() => _MessageAnalyzerScreenState();
}

class _MessageAnalyzerScreenState extends State<MessageAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  final _api = MessageAnalyzerApi();
  final _picker = ImagePicker();
  late TabController _tabController;

  // SMS tab state
  final _messageCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  bool _analyzing = false;
  bool _extracting = false;
  File? _screenshotFile;
  String? _extractionNote;
  Map<String, dynamic>? _messageResult;

  // Job tab state
  final _jobCtrl = TextEditingController();
  bool _analyzingJob = false;
  Map<String, dynamic>? _jobResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageCtrl.dispose();
    _jobCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  // ── Screenshot picker ──────────────────────────────────────────────────────

  Future<void> _pickScreenshot(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (xFile == null) return;

      setState(() {
        _screenshotFile = File(xFile.path);
        _extracting = true;
        _extractionNote = null;
      });

      try {
        final extracted = await _api.extractFromScreenshot(_screenshotFile!);
        if (mounted) {
          setState(() {
            _extracting = false;
            if (extracted['sender'] != null) {
              _senderCtrl.text = extracted['sender'] as String;
            }
            if (extracted['message_text'] != null) {
              _messageCtrl.text = extracted['message_text'] as String;
            }
            _extractionNote = extracted['extraction_note'] as String?;
          });
          if (_senderCtrl.text.isNotEmpty || _messageCtrl.text.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Details extracted from screenshot — please verify before analyzing'),
                backgroundColor: AppTheme.accent,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _extracting = false;
            _extractionNote = 'Could not analyze screenshot. Please type manually.';
          });
        }
      }
    } catch (_) {}
  }

  void _showScreenshotPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload SMS Screenshot',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Claude AI will extract sender & message text automatically',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accent),
              title: const Text('Choose from Gallery', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickScreenshot(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accent),
              title: const Text('Take a Photo', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickScreenshot(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Analysis ───────────────────────────────────────────────────────────────

  Future<void> _analyzeMessage() async {
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or upload a message to analyze')),
      );
      return;
    }
    setState(() {
      _analyzing = true;
      _messageResult = null;
    });
    try {
      final messageText = _messageCtrl.text.trim();

      // Check for fraud keywords offline first
      final fraudAnalysis = FraudKeywordEngine.analyze(messageText);

      // Trigger notification if fraud is detected
      if (fraudAnalysis.suspicionScore > 0.5) {
        await NotificationService.showFraudAlert(
          fraudType: fraudAnalysis.category?.label ?? 'Unknown Fraud',
          message: messageText.length > 100 ? '${messageText.substring(0, 97)}...' : messageText,
          matchedKeywords: fraudAnalysis.matchedKeywords.join(', '),
        );
      }

      final result = await _api.analyzeMessage(
        messageText: messageText,
        sender: _senderCtrl.text.trim().isEmpty ? null : _senderCtrl.text.trim(),
      );
      if (mounted) setState(() { _messageResult = result; _analyzing = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _analyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _checkJobOffer() async {
    if (_jobCtrl.text.trim().isEmpty) return;
    setState(() { _analyzingJob = true; _jobResult = null; });
    try {
      final result = await _api.checkJobOffer(jobText: _jobCtrl.text.trim());
      if (mounted) setState(() { _jobResult = result; _analyzingJob = false; });
    } catch (e) {
      if (mounted) setState(() => _analyzingJob = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Analyzer'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.sms), text: 'SMS / Message'),
            Tab(icon: Icon(Icons.work), text: 'Job Offer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessageTab(),
          _buildJobTab(),
        ],
      ),
    );
  }

  // ── SMS Tab ────────────────────────────────────────────────────────────────

  Widget _buildMessageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(
            icon: Icons.info_outline,
            text:
                'Paste any suspicious SMS, or upload a screenshot — Claude AI will '
                'extract the details and validate the sender against the TRAI registry.',
          ),
          const SizedBox(height: 16),

          // ── Screenshot upload row ────────────────────────────────────
          _ScreenshotRow(
            file: _screenshotFile,
            extracting: _extracting,
            note: _extractionNote,
            onPick: _showScreenshotPicker,
            onClear: () => setState(() {
              _screenshotFile = null;
              _extractionNote = null;
            }),
          ),
          const SizedBox(height: 12),

          // ── Sender field ─────────────────────────────────────────────
          TextField(
            controller: _senderCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration(
              'Sender ID (e.g. VK-SBIBNK or +91 99xxxx)',
              Icons.person_outline,
            ),
          ),
          const SizedBox(height: 12),

          // ── Message body ─────────────────────────────────────────────
          TextField(
            controller: _messageCtrl,
            maxLines: 6,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Paste message here…', Icons.message_outlined),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_analyzing || _extracting) ? null : _analyzeMessage,
              icon: _analyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_analyzing ? 'Analyzing…' : 'Analyze Message'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
              ),
            ),
          ),

          if (_messageResult != null) ...[
            const SizedBox(height: 24),
            _buildMessageResult(_messageResult!),
          ],
        ],
      ),
    );
  }

  // ── Job Tab ────────────────────────────────────────────────────────────────

  Widget _buildJobTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(
            icon: Icons.work_outline,
            text: 'Received a job offer via SMS, WhatsApp, or email? Paste it here to check if it\'s real or fake.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _jobCtrl,
            maxLines: 8,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Paste job offer text here…', Icons.description_outlined),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _analyzingJob ? null : _checkJobOffer,
              icon: _analyzingJob
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(_analyzingJob ? 'Checking…' : 'Check Job Offer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.warning,
                foregroundColor: AppTheme.background,
              ),
            ),
          ),
          if (_jobResult != null) ...[
            const SizedBox(height: 24),
            _buildJobResult(_jobResult!),
          ],
        ],
      ),
    );
  }

  // ── Result builders ────────────────────────────────────────────────────────

  Widget _buildMessageResult(Map<String, dynamic> result) {
    final riskLevel = result['risk_level'] as String? ?? 'unknown';
    final isSafe = result['is_safe'] as bool? ?? true;
    final color = _riskColor(riskLevel);
    final sv = result['sender_validation'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(
          icon: isSafe ? Icons.check_circle : Icons.warning_amber,
          title: isSafe ? 'Message Appears Safe' : 'Suspicious Message!',
          subtitle: 'Risk Level: ${riskLevel.replaceAll('_', ' ').toUpperCase()}',
          color: color,
        ),
        const SizedBox(height: 12),

        // ── TRAI Sender Validation card ──────────────────────────────
        if (sv != null) _SenderValidationCard(data: sv),

        if (result['explanation'] != null && (result['explanation'] as String).isNotEmpty)
          _resultCard('Analysis', result['explanation'] as String, Icons.analytics_outlined),
        if (result['action'] != null && (result['action'] as String).isNotEmpty)
          _resultCard('What To Do', result['action'] as String, Icons.task_alt),
        _redFlagsList(result['red_flags'] as List? ?? []),
      ],
    );
  }

  Widget _buildJobResult(Map<String, dynamic> result) {
    final isFake = result['is_fake'] as bool?;
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;
    final color = isFake == true
        ? AppTheme.errorColor
        : isFake == false
            ? AppTheme.success
            : AppTheme.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(
          icon: isFake == true
              ? Icons.dangerous
              : isFake == false
                  ? Icons.verified
                  : Icons.help_outline,
          title: isFake == true
              ? 'Likely Fake Job Offer!'
              : isFake == false
                  ? 'Appears Legitimate'
                  : 'Could Not Determine',
          subtitle: 'Confidence: ${confidence.toStringAsFixed(0)}%',
          color: color,
        ),
        const SizedBox(height: 12),
        if (result['explanation'] != null && (result['explanation'] as String).isNotEmpty)
          _resultCard('Analysis', result['explanation'] as String, Icons.analytics_outlined),
        if (result['action'] != null && (result['action'] as String).isNotEmpty)
          _resultCard('What To Do', result['action'] as String, Icons.task_alt),
        _redFlagsList(result['red_flags'] as List? ?? []),
        if (isFake == true)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning, color: AppTheme.errorColor, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Warning',
                    style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                  ),
                ]),
                SizedBox(height: 6),
                Text(
                  'Legitimate employers never ask for money. If asked for registration/training fee — it is 100% a scam.',
                  style: const TextStyle(color: const Color.fromARGB(222, 255, 255, 255), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _infoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: const Color.fromARGB(222, 255, 255, 255), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(String title, String content, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.accent, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(color: const Color.fromARGB(222, 255, 255, 255), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _redFlagsList(List flags) {
    if (flags.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.flag, color: AppTheme.errorColor, size: 14),
            SizedBox(width: 6),
            Text(
              'Red Flags',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ...flags.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppTheme.errorColor)),
                Expanded(
                  child: Text(
                    f.toString(),
                    style: const TextStyle(color: const Color.fromARGB(222, 255, 255, 255), fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _riskColor(String level) => switch (level) {
        'critical' || 'high_risk_scam' => AppTheme.errorColor,
        'high' || 'suspicious_message' || 'medium' || 'potentially_suspicious' => AppTheme.warning,
        _ => AppTheme.success,
      };

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.accent),
      filled: true,
      fillColor: AppTheme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppTheme.accent),
      ),
    );
  }
}

// ── Screenshot Row ─────────────────────────────────────────────────────────────
class _ScreenshotRow extends StatelessWidget {
  final File? file;
  final bool extracting;
  final String? note;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ScreenshotRow({
    required this.file,
    required this.extracting,
    required this.note,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload button
        OutlinedButton.icon(
          onPressed: extracting ? null : onPick,
          icon: extracting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                )
              : const Icon(Icons.screenshot_monitor, size: 18),
          label: Text(
            extracting
                ? 'Extracting details…'
                : file != null
                    ? 'Change Screenshot'
                    : 'Upload SMS Screenshot  (optional)',
            style: const TextStyle(fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.accent,
            side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),

        // Screenshot preview
        if (file != null && !extracting) ...[
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  file!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],

        // AI extraction note
        if (note != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 12, color: AppTheme.warning),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  note!,
                  style: const TextStyle(color: AppTheme.warning, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── TRAI Sender Validation Card ────────────────────────────────────────────────
class _SenderValidationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SenderValidationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final verdict = data['verdict'] as String? ?? 'UNKNOWN';
    final isRegistered = data['is_registered'] as bool?;
    final senderIdDisplay = data['sender_id'] as String? ?? data['header'] as String? ?? '—';
    final entityName = data['principal_entity_name'] as String?;
    final tspName = data['tsp_name'] as String?;
    final lsaName = data['lsa_name'] as String?;
    final verdictDetail = data['verdict_detail'] as String? ?? '';

    final (Color color, IconData icon, String label) = switch (verdict) {
      'REGISTERED' => (AppTheme.success, Icons.verified, 'TRAI Registered'),
      'UNREGISTERED' => (AppTheme.errorColor, Icons.gpp_bad, 'Not in TRAI Registry'),
      'PHONE_NUMBER' => (AppTheme.warning, Icons.phone_android, 'Personal Phone Number'),
      _ => (AppTheme.textSecondary, Icons.help_outline, 'Unknown Sender'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.sim_card, size: 16, color: color),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'TRAI Sender Verification',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // Sender ID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Sender ID', senderIdDisplay,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    )),

                if (entityName != null) ...[
                  const SizedBox(height: 6),
                  _infoRow('Registered Entity', entityName),
                ],

                if (tspName != null || lsaName != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    'Network',
                    [if (tspName != null) tspName, if (lsaName != null) lsaName].join(' · '),
                  ),
                ],

                const SizedBox(height: 8),
                Text(
                  verdictDetail,
                  style: TextStyle(
                    color: isRegistered == true
                        ? AppTheme.success
                        : isRegistered == false
                            ? AppTheme.errorColor
                            : AppTheme.warning,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {TextStyle? style}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: style ??
                const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
          ),
        ),
      ],
    );
  }
}

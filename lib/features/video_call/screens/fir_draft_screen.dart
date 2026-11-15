import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/providers/language_provider.dart';
import '../video_call_api.dart';
import 'package:secureshield_app/core/utils/safe_error.dart';

class FirDraftScreen extends ConsumerStatefulWidget {
  const FirDraftScreen({super.key});

  @override
  ConsumerState<FirDraftScreen> createState() => _FirDraftScreenState();
}

class _FirDraftScreenState extends ConsumerState<FirDraftScreen> {
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

  // Streaming state — populated incrementally as deltas arrive from the
  // backend SSE endpoint. When the stream completes, _firResult is set
  // and these are cleared.
  String _streamingText = '';
  String? _streamingCaseId;

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
    setState(() {
      _generating       = true;
      _firResult        = null;
      _streamingText    = '';
      _streamingCaseId  = null;
    });

    final language = ref.read(languageProvider);

    // We'll capture the final values via the stream's "done" event.
    String? finalCaseId;
    String? finalEvidenceId;
    String? finalNote;
    String? streamError;

    try {
      final stream = _api.generateFirStream(
        incidentType:      _selectedType,
        description:       _descCtrl.text.trim(),
        incidentDate:      _incidentDate.toIso8601String().split('T')[0],
        incidentLocation:  _locationCtrl.text.trim(),
        complainantName:   _nameCtrl.text.trim(),
        complainantPhone:  _phoneCtrl.text.trim(),
        suspectInfo:       _suspectCtrl.text.trim().isEmpty  ? null : _suspectCtrl.text.trim(),
        evidenceSummary:   _evidenceCtrl.text.trim().isEmpty ? null : _evidenceCtrl.text.trim(),
        amountLost:        _amountCtrl.text.trim().isEmpty   ? null : _amountCtrl.text.trim(),
        language:          language,
      );

      await for (final event in stream) {
        if (!mounted) return;
        if (event is FirStartEvent) {
          setState(() => _streamingCaseId = event.caseId);
        } else if (event is FirDeltaEvent) {
          // Append incoming chunk — Flutter rebuilds and the markdown
          // partially renders. As each new heading/paragraph arrives the
          // user sees their draft growing in real time.
          setState(() => _streamingText += event.text);
        } else if (event is FirDoneEvent) {
          finalCaseId      = event.caseId      ?? _streamingCaseId;
          finalEvidenceId  = event.evidenceId;
          finalNote        = event.note;
          streamError      = event.error;
          // Prefer the backend's authoritative full text if it gave us
          // one (e.g. when a fallback template was substituted).
          final fullText = event.firText ?? _streamingText;
          setState(() {
            _firResult = {
              'fir_draft':   fullText,
              'case_id':     finalCaseId,
              'evidence_id': finalEvidenceId,
              'note':        finalNote ??
                  'This is a draft. Review with a legal expert before filing at police station.',
            };
            _generating = false;
          });
        } else if (event is FirErrorEvent) {
          streamError = event.message;
        }
      }

      // Stream completed without a "done" event — fall back to whatever
      // text accumulated.
      if (!mounted) return;
      if (_firResult == null) {
        setState(() {
          _firResult = {
            'fir_draft':   _streamingText.isNotEmpty
                              ? _streamingText
                              : 'Could not generate FIR — please try again.',
            'case_id':     _streamingCaseId ?? '',
            'note':        streamError ??
                'Streaming ended unexpectedly. Please review the partial draft.',
          };
          _generating = false;
        });
      }

      // Surface "quota exhausted" or other warnings as a non-blocking toast.
      if (finalNote != null &&
          finalNote.toLowerCase().contains('exhausted') &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalNote),
            backgroundColor: AppTheme.warning,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _generateFir,
          ),
        ),
      );
    }
  }

  /// Human-readable error message for the FIR draft generation flow.
  /// Distinguishes timeouts (AI is slow, retry) from connection failures
  /// (network problem) from quota errors (need to top up).
  String _friendlyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.receiveTimeout:
          return 'The AI is taking longer than expected to generate the FIR. '
              'Please tap Retry — it should finish in under 2 minutes.';
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          return 'Cannot reach the SecureShield server. Check your Wi-Fi or '
              'mobile data and tap Retry.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          if (code == 401) {
            return 'Your session has expired. Please log in again.';
          }
          if (code == 429) {
            return 'Too many requests. Please wait a minute before retrying.';
          }
          if (code >= 500) {
            return 'The SecureShield server is having trouble. '
                'Our team has been notified. Please try again in a few minutes.';
          }
          return safeErrorMessage(e, prefix: 'Could not generate FIR draft');
        default:
          break;
      }
    }
    return safeErrorMessage(e, prefix: 'Could not generate FIR draft');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate FIR Draft')),
      body: _firResult != null
          ? _buildFirResult()
          : _generating && _streamingText.isNotEmpty
              ? _buildStreamingPreview()
              : _buildForm(),
    );
  }

  /// Live document preview while Claude is still generating.
  /// Shows the partial FIR with a small "Generating…" indicator on top.
  Widget _buildStreamingPreview() {
    final cs = Theme.of(context).colorScheme;
    final cleaned = _cleanFirMarkdown(_streamingText);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: cs.primary.withValues(alpha: 0.08),
          child: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generating FIR Draft…',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        )),
                    if (_streamingCaseId != null && _streamingCaseId!.isNotEmpty)
                      Text('Case ID: $_streamingCaseId',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          )),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            reverse: true,  // Auto-scroll so newest text stays in view
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: MarkdownBody(
                data: cleaned.isNotEmpty ? cleaned : '_Awaiting response…_',
                selectable: true,
                styleSheet: _firMarkdownStyle(context),
              ),
            ),
          ),
        ),
      ],
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
            initialValue: _selectedType,
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
    final cs = Theme.of(context).colorScheme;

    // Sanitise the raw text — Claude sometimes wraps the FIR in a single
    // giant code fence which would render the whole document in monospace.
    // We strip standalone ``` markers and convert OUR ``` headers into
    // proper markdown so flutter_markdown renders headings instead of code.
    final cleanedFir = _cleanFirMarkdown(fir);

    return Column(
      children: [
        // ── Header banner ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.success.withValues(alpha: 0.1),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FIR Draft Generated!',
                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                Text('Case ID: $caseId',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              ]),
            ),
            IconButton(
              tooltip: 'Copy plain text',
              icon: Icon(Icons.copy_rounded, color: cs.primary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cleanedFir));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('FIR copied to clipboard'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
            ),
          ]),
        ),

        // ── Scrollable body ─────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional note (e.g. "AI quota exhausted — local template")
                if (note.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppTheme.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(note,
                            style: const TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            )),
                        ),
                      ],
                    ),
                  ),

                // ── "Document" card — looks like a paper FIR ─────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: cleanedFir,
                    selectable: true,
                    styleSheet: _firMarkdownStyle(context),
                  ),
                ),

                // ── Action buttons ──────────────────────────────────────
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _firResult = null),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cleanedFir));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('FIR draft copied to clipboard'),
                            backgroundColor: AppTheme.success,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      label: const Text('Copy FIR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Strip junk markdown that Claude sometimes emits — outer code fences,
  /// stray fence markers — so the document renders as a proper letter
  /// instead of a console dump. Preserves intentional `**bold**`,
  /// `# heading` and `> blockquote` syntax.
  String _cleanFirMarkdown(String raw) {
    var text = raw.trim();

    // 1. Outer wrap: ```...``` around the whole doc → unwrap
    final outerFence = RegExp(r'^```\w*\s*\n([\s\S]*?)\n```$');
    final outerMatch = outerFence.firstMatch(text);
    if (outerMatch != null) {
      text = outerMatch.group(1)!.trim();
    }

    // 2. Standalone ``` lines (Claude using fences for visual dividers)
    //    → convert to horizontal rule
    text = text.replaceAll(RegExp(r'^```\s*$', multiLine: true), '---');

    // 3. Convert long ASCII underline rows ("____________") into HR.
    //    Markdown's HR is just "---", which renders as a thin line.
    text = text.replaceAll(
      RegExp(r'^_{20,}\s*$', multiLine: true),
      '---',
    );

    // 4. Collapse 3+ consecutive blank lines into a single blank line
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text;
  }

  /// Markdown style sheet that gives the FIR a clean official-document look:
  /// serif-ish weights, justified body, indented quotes, no monospace code
  /// formatting (Claude often wraps tables in fences which would otherwise
  /// look ugly).
  MarkdownStyleSheet _firMarkdownStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return MarkdownStyleSheet(
      // ── Body paragraph ────────────────────────────────────────────────
      p: TextStyle(
        color: onSurface,
        fontSize: 14,
        height: 1.65,
        letterSpacing: 0.1,
      ),
      pPadding: const EdgeInsets.only(bottom: 8),

      // ── Headings ──────────────────────────────────────────────────────
      h1: TextStyle(
        color: onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        height: 1.35,
      ),
      h1Padding: const EdgeInsets.only(top: 4, bottom: 12),
      h2: TextStyle(
        color: cs.primary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        height: 1.4,
      ),
      h2Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h3: TextStyle(
        color: onSurface,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h3Padding: const EdgeInsets.only(top: 10, bottom: 6),
      h4: TextStyle(
        color: onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),

      // ── Inline emphasis ───────────────────────────────────────────────
      strong: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
      em:     TextStyle(color: onSurface, fontStyle: FontStyle.italic),

      // ── Lists ─────────────────────────────────────────────────────────
      listBullet: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      listIndent: 22,

      // ── Blockquote (the "नोट:" callout) ───────────────────────────────
      blockquoteDecoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        border: const Border(
          left: BorderSide(color: AppTheme.warning, width: 3.5),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      blockquote: TextStyle(
        color: onSurface,
        fontStyle: FontStyle.italic,
        fontSize: 13.5,
        height: 1.5,
      ),

      // ── Horizontal rule ───────────────────────────────────────────────
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 1.2),
        ),
      ),

      // ── Code: render INLINE code subtly; render BLOCK code as a
      // monospace "header table" because that's how Claude formats
      // the FIR header (Thana / Date / Section table). Keep readable. ─
      code: TextStyle(
        color: onSurface,
        backgroundColor: cs.primary.withValues(alpha: 0.08),
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      codeblockPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),

      // ── Tables ────────────────────────────────────────────────────────
      tableBorder: TableBorder.all(color: cs.outlineVariant, width: 1),
      tableHead: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      tableBody: TextStyle(color: onSurface, fontSize: 13),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

      // Tighter vertical rhythm — official documents are dense.
      blockSpacing: 10,
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accent)),
    );
  }
}

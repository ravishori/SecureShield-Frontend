import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../digital_arrest_classifier.dart';

class DigitalArrestScreen extends StatefulWidget {
  const DigitalArrestScreen({super.key});

  @override
  State<DigitalArrestScreen> createState() => _DigitalArrestScreenState();
}

class _DigitalArrestScreenState extends State<DigitalArrestScreen> {
  final _ctrl = TextEditingController();
  DigitalArrestReport? _report;
  bool _analyzing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _analyzing = true);
    await Future.delayed(const Duration(milliseconds: 250));
    final report = DigitalArrestClassifier.analyze(_ctrl.text);
    setState(() {
      _report = report;
      _analyzing = false;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _ctrl.text = data.text!;
        _report = null;
      });
    }
  }

  Future<void> _call1930() async {
    final uri = Uri.parse('tel:1930');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openCybercrimePortal() async {
    final uri = Uri.parse('https://cybercrime.gov.in');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        title: const Text(
          'Digital Arrest Protection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hero(),
              const SizedBox(height: 16),
              _checklist(),
              const SizedBox(height: 16),
              _analyzerCard(theme),
              if (_report != null) ...[
                const SizedBox(height: 16),
                _verdictCard(_report!),
                if (_report!.signals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _signalsCard(_report!),
                ],
              ],
              const SizedBox(height: 24),
              _emergencyActions(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB71C1C), Color(0xFFFF5252)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gavel, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'India\'s #1 scam',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '₹2,140 crore lost in 2024',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Don\'t become a victim. Learn the red flags below.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklist() {
    final items = [
      ('NEVER over phone/video', 'CBI, Police, ED, Customs, NCB never arrest you over Skype, Zoom, WhatsApp or any video call.'),
      ('NEVER pay to prove innocence', 'No real agency asks you to transfer money to "verify" or "clear" your account.'),
      ('NEVER share OTP or screen', 'Refuse all screen-share requests. Refuse all OTP / PIN / CVV requests.'),
      ('Always verify on 1930', 'Hang up and call 1930 yourself. Real officers visit in person, with a printed warrant.'),
      ('Stay calm, stay silent', 'Scammers create panic. Take a deep breath. Tell a family member before doing anything.'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check, color: Color(0xFF00E5FF), size: 22),
              SizedBox(width: 8),
              Text(
                'Red-flag checklist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Color(0xFF90A4AE),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _analyzerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_snippet, color: Color(0xFF00E5FF), size: 22),
              SizedBox(width: 8),
              Text(
                'Analyze a message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste the text from a suspicious call transcript, SMS or WhatsApp message.',
            style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            minLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type or paste the message here…',
              hintStyle: const TextStyle(color: Color(0xFF6E7B8C)),
              fillColor: const Color(0xFF0A0E27),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _analyzing ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text('Paste'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(_analyzing ? 'Analyzing…' : 'Analyze for scam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5252),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verdictCard(DigitalArrestReport report) {
    final (color, icon) = _verdictStyle(report.verdict);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  report.headline,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.advice,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _scoreBadge('Score', '${report.totalScore}', color),
              const SizedBox(width: 10),
              _scoreBadge('Signals', '${report.signals.length}', color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalsCard(DigitalArrestReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detected red flags',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...report.signals.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _weightColor(s.weight).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${s.weight}',
                    style: TextStyle(
                      color: _weightColor(s.weight),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '"${s.matchedPhrase}"',
                        style: const TextStyle(
                          color: Color(0xFF90A4AE),
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _emergencyActions() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _call1930,
          icon: const Icon(Icons.phone_in_talk, size: 22),
          label: const Text(
            'Call 1930 (Cyber-crime helpline)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openCybercrimePortal,
          icon: const Icon(Icons.open_in_new, size: 20),
          label: const Text('Report on cybercrime.gov.in'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00E5FF),
            side: const BorderSide(color: Color(0xFF00E5FF)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  (Color, IconData) _verdictStyle(DigitalArrestVerdict v) {
    switch (v) {
      case DigitalArrestVerdict.critical:
        return (const Color(0xFFFF1744), Icons.gpp_bad);
      case DigitalArrestVerdict.likely:
        return (const Color(0xFFFF5252), Icons.warning);
      case DigitalArrestVerdict.suspicious:
        return (const Color(0xFFFF9800), Icons.report_problem);
      case DigitalArrestVerdict.safe:
        return (const Color(0xFF4CAF50), Icons.verified);
    }
  }

  Color _weightColor(int weight) {
    if (weight >= 5) return const Color(0xFFFF1744);
    if (weight >= 3) return const Color(0xFFFF9800);
    return const Color(0xFF00E5FF);
  }
}

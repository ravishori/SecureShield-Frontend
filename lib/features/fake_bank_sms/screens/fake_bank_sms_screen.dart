import 'package:secureshield_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../fake_bank_sms_classifier.dart';

class FakeBankSmsScreen extends StatefulWidget {
  const FakeBankSmsScreen({super.key});

  @override
  State<FakeBankSmsScreen> createState() => _FakeBankSmsScreenState();
}

class _FakeBankSmsScreenState extends State<FakeBankSmsScreen> {
  final _senderCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  FakeBankSmsReport? _report;

  @override
  void dispose() {
    _senderCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final sender = _senderCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (sender.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).fbBothReq)),
      );
      return;
    }
    setState(() {
      _report = FakeBankSmsClassifier.classify(sender: sender, body: body);
    });
  }

  Future<void> _pasteBody() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() => _bodyCtrl.text = data!.text!);
    }
  }

  void _loadExample() {
    setState(() {
      _senderCtrl.text = '9876543210';
      _bodyCtrl.text =
          'Dear Customer, your HDFC Bank a/c will be blocked. Update KYC immediately: '
          'https://bit.ly/hdfc-kyc-verify — urgent action required.';
      _report = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).fbTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _loadExample,
            child: const Text('Example', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _intro(),
              const SizedBox(height: 16),
              _form(),
              if (_report != null) ...[
                const SizedBox(height: 16),
                _verdictCard(_report!),
                const SizedBox(height: 12),
                _reasonsCard(_report!),
                if (_report!.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _recommendationsCard(_report!),
                ],
              ],
              const SizedBox(height: 24),
              _educationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).fbVerify,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Banks send SMS only from TRAI-registered headers (VK-HDFCBK, etc.). A 10-digit number claiming to be your bank is a scam.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
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
          Text(
            AppLocalizations.of(context).fbSender,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _senderCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. VK-HDFCBK or 9876543210',
              hintStyle: const TextStyle(color: Color(0xFF6E7B8C)),
              fillColor: const Color(0xFF0A0E27),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                AppLocalizations.of(context).fbBody,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pasteBody,
                icon: const Icon(Icons.content_paste, size: 16, color: Color(0xFF00E5FF)),
                label: Text(AppLocalizations.of(context).fbPaste, style: const TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyCtrl,
            maxLines: 6,
            minLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Paste the full SMS body here',
              hintStyle: const TextStyle(color: Color(0xFF6E7B8C)),
              fillColor: const Color(0xFF0A0E27),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _analyze,
            icon: const Icon(Icons.shield_outlined),
            label: Text(AppLocalizations.of(context).fbCheck),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF0A0E27),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictCard(FakeBankSmsReport r) {
    final (color, icon, label) = _verdictStyle(r.verdict);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          if (r.matchedBank != null) ...[
            const SizedBox(height: 8),
            Text(
              'Identified as: ${r.matchedBank}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
          if (r.matchedHeader != null) ...[
            const SizedBox(height: 4),
            Text(
              'Entity code: ${r.matchedHeader}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reasonsCard(FakeBankSmsReport r) {
    if (r.reasons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).fbWhy,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ...r.reasons.map((reason) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chevron_right, color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _recommendationsCard(FakeBankSmsReport r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).fbNext,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...r.recommendations.map((rec) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _educationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to spot a fake bank SMS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 10),
          _Tip(
            icon: Icons.numbers,
            title: '10-digit sender = scam',
            body: 'Real banks send from TRAI headers like VK-HDFCBK or AX-AXISBK, never from a personal number.',
          ),
          _Tip(
            icon: Icons.link_off,
            title: 'Beware of bit.ly / tinyurl',
            body: 'Banks rarely send shortened links. If you see one in an SMS, do not click.',
          ),
          _Tip(
            icon: Icons.warning_amber,
            title: '"KYC expired" = scam',
            body: 'Banks never block accounts via SMS. The KYC-update-or-account-blocked SMS is the most common Indian scam.',
          ),
          _Tip(
            icon: Icons.call,
            title: 'Verify by calling',
            body: 'When in doubt, call the number printed on the back of your debit/credit card. Never use the number in the SMS.',
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _verdictStyle(FakeBankSmsVerdict v) {
    switch (v) {
      case FakeBankSmsVerdict.legitimate:
        return (const Color(0xFF4CAF50), Icons.verified, 'Likely legitimate');
      case FakeBankSmsVerdict.unverifiable:
        return (const Color(0xFFFF9800), Icons.help_outline, 'Cannot verify');
      case FakeBankSmsVerdict.suspicious:
        return (const Color(0xFFFF9800), Icons.warning_amber, 'Suspicious');
      case FakeBankSmsVerdict.fake:
        return (const Color(0xFFFF1744), Icons.gpp_bad, 'Fake — do not trust');
    }
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Tip({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF90A4AE),
                    fontSize: 12.5,
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
}

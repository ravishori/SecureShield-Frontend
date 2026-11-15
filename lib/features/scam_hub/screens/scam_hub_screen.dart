import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/verdict/scam_verdict.dart';
import '../../../core/verdict/verdict_headline.dart';
import '../hub_input.dart';
import '../hub_result.dart';
import '../scam_hub_provider.dart';
import '../widgets/confirm_send_sheet.dart';
import 'hub_qr_capture.dart';

/// One entry point for pasted text, a link, or a QR payload. It routes to the existing detectors and shows the shared verdict.
/// It never opens a link, never runs QR content, stores nothing, and never asks for an OTP, PIN, CVV or password.
class ScamHubScreen extends ConsumerStatefulWidget {
  /// Replaces the camera page in tests.
  final Future<String?> Function(BuildContext)? captureQr;
  const ScamHubScreen({super.key, this.captureQr});

  @override
  ConsumerState<ScamHubScreen> createState() => _ScamHubScreenState();
}

class _ScamHubScreenState extends ConsumerState<ScamHubScreen> {
  final _controller = TextEditingController();
  HubRoute? _override;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain); // only on an explicit tap
    if (data?.text != null) setState(() => _controller.text = data!.text!);
  }

  Future<void> _scan() async {
    final raw = await (widget.captureQr != null
        ? widget.captureQr!(context)
        : Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const HubQrCapturePage())));
    if (raw != null && mounted) ref.read(scamHubProvider.notifier).submitCamera(raw);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(scamHubProvider);
    final n = ref.read(scamHubProvider.notifier);
    final detected = classifyScamInput(_controller.text);
    final route = _override ?? (detected is HubClassified ? detected.route : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Scam Check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s.phase == HubPhase.confirming)
            ConfirmSendPanel(
              state: s,
              onEdit: n.cancelConfirm,
              onSendOriginal: () => n.confirmSend(useMasked: false),
              onSendMasked: () => n.confirmSend(useMasked: true),
            )
          else if (s.phase == HubPhase.analysing)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (s.phase == HubPhase.result && s.outcome != null)
            _ResultCard(
              outcome: s.outcome!,
              onCheckReputation: n.requestReputationCheck,
              onAgain: () {
                if (s.outcome is HubVerdict) _controller.clear(); // a finished check leaves no text behind; a failed one keeps it for retry
                n.reset();
                setState(() => _override = null);
              },
            )
          else ...[
            const Text('Paste a message, a link or a QR payload, or scan a QR code. Nothing is sent until you confirm.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('hub_input'),
              controller: _controller,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste here',
                helperText: 'Do not paste PINs, OTPs or passwords.',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final r in HubRoute.values)
                ChoiceChip(
                  key: Key('chip_${r.name}'),
                  label: Text(switch (r) {
                    HubRoute.message => 'Message',
                    HubRoute.url => 'Link',
                    HubRoute.qrPayload => 'QR-style payload',
                  }),
                  selected: route == r,
                  onSelected: (_) => setState(() => _override = r),
                ),
            ]),
            if (s.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.error!, key: const Key('hub_error'), style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  key: const Key('analyze_button'),
                  onPressed: () => n.submitPasted(_controller.text, override: _override),
                  child: const Text('Analyze'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(key: const Key('paste_button'), onPressed: _paste, icon: const Icon(Icons.paste), label: const Text('Paste')),
              const SizedBox(width: 8),
              OutlinedButton.icon(key: const Key('scan_button'), onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan QR')),
            ]),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final HubOutcome outcome;
  final VoidCallback onCheckReputation;
  final VoidCallback onAgain;
  const _ResultCard({required this.outcome, required this.onCheckReputation, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    final String label;
    final Color color;
    if (o is HubVerdict) {
      label = verdictHeadlineLabel(o.verdict.riskLevel);
      color = switch (o.verdict.riskLevel) {
        RiskLevel.safe || RiskLevel.low => Colors.green,
        RiskLevel.unknown || RiskLevel.medium => Colors.orange,
        RiskLevel.high || RiskLevel.critical => Colors.red,
      };
    } else {
      label = couldNotCheckLabel; // not a risk level: no verdict exists
      color = Colors.grey;
    }
    final notices = explainCompleteness(o);
    final verdict = o is HubVerdict ? o.verdict : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text(label, key: const Key('hub_headline'), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
            const SizedBox(height: 12),
            for (final nt in notices)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(nt.text, key: Key('notice_${nt.kind.name}'), style: const TextStyle(fontSize: 13))),
            if (verdict != null) ...[
              for (final r in verdict.reasons) Text('• ${r.text}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              for (final l in verdict.limitations) Text(l, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              for (final a in verdict.recommendedActions) Text('→ ${a.text}', style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (o is HubVerdict && o.checkableUrl != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('check_reputation_button'),
                  onPressed: onCheckReputation,
                  child: const Text("Check this link's reputation (sends the link to SecureShield)"),
                ),
              ),
            SizedBox(width: double.infinity, child: TextButton(key: const Key('again_button'), onPressed: onAgain, child: Text(o is HubRequestFailed ? 'Try again' : 'Check something else'))),
          ],
        ),
      ),
    );
  }
}

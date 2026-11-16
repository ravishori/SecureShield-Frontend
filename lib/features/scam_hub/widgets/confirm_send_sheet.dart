import 'package:flutter/material.dart';

import '../hub_input.dart';
import '../scam_hub_provider.dart';
import '../sensitive_content.dart';

/// Shown before ANY submission to the backend. It shows the exact content that will be sent, what is stored, and that
/// external AI is off. Edit is the primary action; "Send anyway" is secondary and only exists when a warning fired.
class ConfirmSendPanel extends StatelessWidget {
  final HubState state;
  final VoidCallback onEdit;
  final VoidCallback onSendOriginal;
  final VoidCallback onSendMasked;
  const ConfirmSendPanel({super.key, required this.state, required this.onEdit, required this.onSendOriginal, required this.onSendMasked});

  @override
  Widget build(BuildContext context) {
    final isUrl = state.route == HubRoute.url;
    final warn = state.hasSensitive;
    final kinds = state.sensitive.map(sensitiveKindLabel).join(', ');
    final cs = Theme.of(context).colorScheme;

    Widget preview(String label, String text, {Key? key}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              key: key,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(text, style: const TextStyle(fontSize: 13)),
            ),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isUrl ? 'Send this link for checking?' : 'Send this message for checking?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (warn) ...[
              Container(
                key: const Key('sensitive_warning'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'This looks like it contains $kinds. Remove it before sending. SecureShield never needs your OTP, PIN, password or card details. '
                  'This check is a guess and can miss things.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              preview('Masked version (exactly what "Send masked version" sends)', state.masked, key: const Key('preview_masked')),
              const SizedBox(height: 8),
              preview('Original (exactly what "Send anyway" sends)', state.original, key: const Key('preview_original')),
            ] else
              preview(isUrl ? 'This link will be sent exactly as shown:' : 'This text will be sent exactly as shown:', state.original, key: const Key('preview_original')),
            const SizedBox(height: 12),
            Text(
              isUrl
                  ? '• The link goes to SecureShield, which also checks it with Google Safe Browsing and URLhaus.\n'
                      '• The page is never opened.\n'
                      '• Your scan history keeps the full link. A risky result also creates an alert holding the first 200 characters of the link.'
                  : '• The text (and nothing else from your device) goes to SecureShield.\n'
                      '• If the result is risky, an alert keeps the first 100 characters of the message. A message that is not risky is not saved.',
              key: const Key('storage_disclosure'),
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 6),
            const Text(
              '• External AI analysis is switched off. Your content is not sent to any AI service.',
              key: Key('ai_disclosure'),
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: warn
                  ? FilledButton(key: const Key('edit_button'), onPressed: onEdit, child: const Text('Edit'))
                  : FilledButton(key: const Key('send_button'), onPressed: onSendOriginal, child: const Text('Send for analysis')),
            ),
            const SizedBox(height: 8),
            if (warn) ...[
              SizedBox(width: double.infinity, child: OutlinedButton(key: const Key('send_masked_button'), onPressed: onSendMasked, child: const Text('Send masked version'))),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: TextButton(key: const Key('send_anyway_button'), onPressed: onSendOriginal, child: const Text('Send anyway'))),
            ] else
              Align(alignment: Alignment.centerRight, child: TextButton(key: const Key('cancel_button'), onPressed: onEdit, child: const Text('Cancel'))),
          ],
        ),
      ),
    );
  }
}

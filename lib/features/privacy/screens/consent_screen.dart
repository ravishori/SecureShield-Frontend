import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../consent_choices.dart';
import '../consent_gate.dart';
import '../privacy_api.dart';
import '../privacy_content.dart';
import 'privacy_notice_screen.dart';

export '../consent_choices.dart';

/// The consent given on this device during a sign-up that is still in progress (never persisted to disk).
final consentDraftProvider = StateProvider<ConsentChoices?>((ref) => null);

/// Shows the consent screen until it is accepted, then the wrapped screen (used in front of the registration form).
class ConsentGate extends ConsumerWidget {
  final Widget child;
  const ConsentGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(consentDraftProvider);
    if (draft != null) return child;
    return ConsentScreen(onAccepted: (c) => ref.read(consentDraftProvider.notifier).state = c);
  }
}

/// Mandatory service terms and privacy acknowledgement, kept apart from the optional processing choice.
/// Android permissions are NOT part of this screen: each is requested later, on its own, when a feature needs it.
class ConsentScreen extends StatefulWidget {
  final ValueChanged<ConsentChoices> onAccepted;
  final String title;
  final String buttonLabel;
  const ConsentScreen({
    super.key,
    required this.onAccepted,
    this.title = 'Before you start',
    this.buttonLabel = 'Continue',
  });

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _ai = false; // optional, off by default

  bool get _canContinue => _terms && _privacy;

  void _openNotice() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyNoticeScreen()));

  void _showTerms() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Terms of service'),
          content: const SingleChildScrollView(child: Text(kTermsSummary)),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
        ),
      );

  void _continue() {
    if (!_canContinue) return;
    widget.onAccepted(ConsentChoices(
      termsVersion: kTermsVersion,
      privacyVersion: kPrivacyVersion,
      aiProcessing: _ai,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              header: true,
              child: Text('Required to create an account', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('termsCheckbox'),
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('I agree to the Terms of Service'),
              subtitle: TextButton(
                key: const Key('readTermsButton'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
                onPressed: _showTerms,
                child: const Text('Read the terms'),
              ),
            ),
            CheckboxListTile(
              key: const Key('privacyCheckbox'),
              value: _privacy,
              onChanged: (v) => setState(() => _privacy = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('I have read the Privacy notice'),
              subtitle: TextButton(
                key: const Key('readNoticeButton'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
                onPressed: _openNotice,
                child: const Text('Read the privacy notice'),
              ),
            ),
            const Divider(height: 32),
            Semantics(
              header: true,
              child: Text('Optional', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(
              'You can say no and still use the app. You can change this later in Settings > Privacy and data.',
              style: theme.textTheme.bodySmall,
            ),
            SwitchListTile(
              key: const Key('aiSwitch'),
              value: _ai,
              onChanged: (v) => setState(() => _ai = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow AI features to process text I submit (not active yet)'),
              subtitle: const Text(
                'External AI processing is currently disabled, so nothing is sent to an AI provider. This choice is '
                'only recorded for a future version and does not turn anything on.',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Android permissions (camera, location, microphone and so on) are not part of this agreement. The app '
              'asks for each one separately, only when you use a feature that needs it.',
              key: const Key('permissionsNote'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('consentContinue'),
              onPressed: _canContinue ? _continue : null,
              child: Text(widget.buttonLabel),
            ),
            if (!_canContinue)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Accept both required items to continue.',
                  key: const Key('consentHint'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// For a signed-in account that has no up-to-date acceptance on record (existing users, or after the notice changed).
/// Records the two acknowledgements through the server, which stays authoritative.
class ConsentUpdateScreen extends ConsumerStatefulWidget {
  const ConsentUpdateScreen({super.key});

  @override
  ConsumerState<ConsentUpdateScreen> createState() => _ConsentUpdateScreenState();
}

class _ConsentUpdateScreenState extends ConsumerState<ConsentUpdateScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _record(ConsentChoices c) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(privacyApiProvider);
      await api.putConsent(kPurposeTerms, true, c.termsVersion);
      await api.putConsent(kPurposePrivacy, true, c.privacyVersion);
      if (c.aiProcessing) await api.putConsent(kPurposeAi, true, kAiProcessingVersion);
      ref.invalidate(consentGateProvider);
    } on PrivacyFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ConsentScreen(
          title: 'Terms and privacy notice updated',
          buttonLabel: 'Accept and continue',
          onAccepted: (c) => _busy ? null : _record(c),
        ),
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, key: const Key('consentUpdateError')),
              ),
            ),
          ),
      ],
    );
  }
}

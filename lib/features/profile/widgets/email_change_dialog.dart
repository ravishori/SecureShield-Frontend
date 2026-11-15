import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/identity_api.dart';
import '../../auth/screens/phone_verify_screen.dart' show identityApiProvider;

/// Changes the account e-mail address with proof of ownership of the NEW address.
///
/// Step 1: enter the new address - a code is sent to it (and only to it). Step 2: enter the code. The old address
/// keeps working until the server confirms the new one. An address that belongs to another account is refused by the
/// server (409) and nothing is sent. Returns true when the change was confirmed.
Future<bool> showEmailChangeDialog(BuildContext context) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const EmailChangeDialog(),
  );
  return done ?? false;
}

class EmailChangeDialog extends ConsumerStatefulWidget {
  const EmailChangeDialog({super.key});

  @override
  ConsumerState<EmailChangeDialog> createState() => _EmailChangeDialogState();
}

class _EmailChangeDialogState extends ConsumerState<EmailChangeDialog> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim().toLowerCase();

  Future<void> _run(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } on IdentityFailure catch (f) {
      if (mounted) {
        setState(() => _error = f.message);
        if (f.kind == IdentityErrorKind.invalidCode) _codeCtrl.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await _run(() async {
      await ref.read(identityApiProvider).startEmailChange(_email);
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code we sent.');
      return;
    }
    await _run(() async {
      await ref.read(identityApiProvider).confirmEmailChange(_email, code);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _codeSent
                  ? 'We sent a code to the new address. Your current email stays active until you confirm it.'
                  : 'We will send a code to the new address to prove it is yours. Your current email stays active until then.',
              key: const Key('emailChangeHelp'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('newEmailField'),
              controller: _emailCtrl,
              enabled: !_codeSent && !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New email address'),
            ),
            if (_codeSent)
              TextField(
                key: const Key('emailCodeField'),
                controller: _codeCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Verification code'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('emailChangeError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('emailChangeCancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_codeSent)
          TextButton(
            key: const Key('emailChangeResend'),
            onPressed: _busy ? null : _start,
            child: const Text('Resend'),
          ),
        FilledButton(
          key: Key(_codeSent ? 'emailChangeConfirm' : 'emailChangeSend'),
          onPressed: _busy ? null : (_codeSent ? _confirm : _start),
          child: Text(_codeSent ? 'Confirm' : 'Send code'),
        ),
      ],
    );
  }
}

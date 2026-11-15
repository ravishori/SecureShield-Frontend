import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_provider.dart';
import '../identity_api.dart';

/// Overridable in tests.
final identityApiProvider = Provider<IdentityApi>((ref) => IdentityApi());

/// Verifies a phone number on its own, after the account exists (the e-mail was verified first).
///
/// The code is sent to the phone number only. Until the server confirms it, the number cannot be used to sign in;
/// this screen never decides that for itself, it re-reads the verification state from the server afterwards.
class PhoneVerifyScreen extends ConsumerStatefulWidget {
  /// Where to go when the user finishes or skips. Defaults to the dashboard.
  final String doneRoute;
  const PhoneVerifyScreen({super.key, this.doneRoute = '/home'});

  @override
  ConsumerState<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends ConsumerState<PhoneVerifyScreen> {
  static const resendCooldownSeconds = 30;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _maskedPhone;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Digits only, with a leading + (the server requires the country code).
  String get _phone {
    final raw = _phoneCtrl.text.trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return '+$digits';
  }

  bool get _phoneLooksValid => _phone.length >= 8 && _phone.length <= 21;

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (!_phoneLooksValid) {
      setState(() => _error = 'Enter your phone number including the country code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(identityApiProvider).startPhoneVerification(_phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _maskedPhone = r.maskedIdentifier ?? _phone;
      });
      _startCooldown();
    } on IdentityFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code we sent.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(identityApiProvider).confirmPhone(_phone, code);
      await ref.read(authProvider.notifier).refreshVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number verified.')),
      );
      context.go(widget.doneRoute);
    } on IdentityFailure catch (f) {
      if (mounted) {
        setState(() => _error = f.message);
        // A wrong or expired code is retried from a clean field; a claimed number needs a different number.
        if (f.kind == IdentityErrorKind.invalidCode) _codeCtrl.clear();
        if (f.kind == IdentityErrorKind.claimed) setState(() => _codeSent = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skip() => context.go(widget.doneRoute);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your phone')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your email is verified and your account is ready. Verify your phone number too, so you can '
              'also sign in with it. Until you do, the number cannot be used to log in.',
              key: Key('phoneVerifyIntro'),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('phoneField'),
              controller: _phoneCtrl,
              enabled: !_codeSent && !_busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              decoration: const InputDecoration(
                labelText: 'Phone number with country code',
                hintText: '+91 98765 43210',
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              Text('Code sent to $_maskedPhone', key: const Key('codeSentTo')),
              const SizedBox(height: 8),
              TextField(
                key: const Key('codeField'),
                controller: _codeCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Verification code'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('phoneVerifyError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if (!_codeSent)
              FilledButton(
                key: const Key('sendCodeButton'),
                onPressed: _busy ? null : _send,
                child: _busy ? const _Spinner() : const Text('Send code'),
              )
            else ...[
              FilledButton(
                key: const Key('confirmCodeButton'),
                onPressed: _busy ? null : _confirm,
                child: _busy ? const _Spinner() : const Text('Verify phone'),
              ),
              TextButton(
                key: const Key('resendButton'),
                onPressed: (_busy || _cooldown > 0) ? null : _send,
                child: Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
              ),
              TextButton(
                key: const Key('changeNumberButton'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _codeCtrl.clear();
                          _error = null;
                        }),
                child: const Text('Use a different number'),
              ),
            ],
            TextButton(
              key: const Key('skipButton'),
              onPressed: _busy ? null : _skip,
              child: const Text('Do this later'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
}

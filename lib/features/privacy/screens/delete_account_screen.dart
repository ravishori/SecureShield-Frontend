import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_provider.dart';
import '../../app_monitor/monitor_sync_coordinator.dart';
import '../../auth/identity_api.dart' show IdentityErrorKind;
import '../privacy_api.dart';

/// Permanent account deletion, in two deliberate steps:
///  1. read what is deleted and kept, tick "I understand", and ask for a confirmation code (nothing is deleted yet);
///  2. enter the code that was sent to your verified email/phone AND type DELETE.
/// Success is shown, and local data cleared, ONLY after the server answers that the account was deleted.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  final String doneRoute;
  const DeleteAccountScreen({super.key, this.doneRoute = '/welcome'});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _code = TextEditingController();
  final _typed = TextEditingController();
  bool _understood = false;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _maskedTo;

  @override
  void dispose() {
    _code.dispose();
    _typed.dispose();
    super.dispose();
  }

  bool get _canDelete => _code.text.trim().length >= 4 && _typed.text == 'DELETE' && !_busy;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(privacyApiProvider).startDeletion();
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _maskedTo = r.maskedIdentifier;
      });
    } on PrivacyFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!_canDelete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(privacyApiProvider).deleteAccount(_code.text.trim());
    } on PrivacyFailure catch (f) {
      // The account still exists: show why and let the person retry (or request a new code).
      if (mounted) {
        setState(() {
          _error = f.message;
          _busy = false;
          if (f.kind == IdentityErrorKind.invalidCode) _code.clear();
        });
      }
      return;
    }
    // Confirmed by the server: only now is local data removed and success shown.
    // every stored monitor event of every account; false = the device data could NOT be confirmed removed
    final purged = await ref.read(monitorSyncProvider).purgeAll();
    await ref.read(authProvider.notifier).clearAllLocalData();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(purged
            ? 'Your account has been deleted.'
            : 'Your account has been deleted, but some app monitor data could not be removed from this device. '
                'Clear SecureShield\'s storage in Android settings to remove it.'),
      ),
    );
    context.go(widget.doneRoute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              header: true,
              child: Text('This cannot be undone', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 12),
            const Text('Deleted: evidence and recordings (including files), devices and alerts, scans, AI conversations, '
                'family links, emergency contacts, reports and your consent records, plus your name, email, phone and address.',
                key: Key('deletedList')),
            const SizedBox(height: 8),
            const Text('Kept: an empty account record (internal id and creation date only) and an audit trail of moderation '
                'actions. Backups made earlier may hold your data until they expire.',
                key: Key('keptList')),
            const SizedBox(height: 16),
            if (!_codeSent) ...[
              CheckboxListTile(
                key: const Key('understoodCheckbox'),
                value: _understood,
                onChanged: _busy ? null : (v) => setState(() => _understood = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('I understand my account and data will be permanently deleted'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('sendDeletionCode'),
                onPressed: (_understood && !_busy) ? _send : null,
                child: _busy ? const _Spinner() : const Text('Send confirmation code'),
              ),
            ] else ...[
              Text('We sent a code to ${_maskedTo ?? 'your verified email or phone'}. Nothing has been deleted yet.',
                  key: const Key('codeSentNote')),
              const SizedBox(height: 8),
              TextField(
                key: const Key('deletionCodeField'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Confirmation code'),
              ),
              TextField(
                key: const Key('typeDeleteField'),
                controller: _typed,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Type DELETE to confirm'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('confirmDeletion'),
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                onPressed: _canDelete ? _delete : null,
                child: _busy ? const _Spinner() : const Text('Delete my account permanently'),
              ),
              TextButton(
                key: const Key('resendDeletionCode'),
                onPressed: _busy ? null : _send,
                child: const Text('Send a new code'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_error!, key: const Key('deleteError'), style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
            TextButton(
              key: const Key('cancelDeletion'),
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Cancel, keep my account'),
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

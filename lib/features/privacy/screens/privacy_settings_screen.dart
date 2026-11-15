import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../privacy_api.dart';
import '../privacy_content.dart';
import 'privacy_notice_screen.dart';

/// Settings > Privacy and data: read the notice, change the optional AI choice, delete the account.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  ConsentSnapshot? _snap;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(privacyApiProvider).getConsents();
      if (mounted) setState(() => _snap = s);
    } on PrivacyFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setAi(bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The switch shows what the SERVER recorded, so it only moves after the server confirms.
      final s = await ref.read(privacyApiProvider).putConsent(kPurposeAi, value, kAiProcessingVersion);
      if (mounted) setState(() => _snap = s);
    } on PrivacyFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _snap?.item(kPurposeAi);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              key: const Key('openNotice'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy notice'),
              subtitle: const Text('What we collect, why, who receives it, and how to delete it'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const PrivacyNoticeScreen())),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(key: Key('consentLoading'))),
              )
            else if (_snap != null)
              SwitchListTile(
                key: const Key('aiConsentSwitch'),
                value: ai?.granted == true,
                onChanged: _saving ? null : _setAi,
                title: const Text('Allow AI features to process text I submit (not active yet)'),
                subtitle: const Text(
                  'External AI processing is currently disabled. This only records your preference for a future version; you can change it any time.',
                ),
              )
            else
              ListTile(
                title: const Text('Could not load your choices'),
                trailing: TextButton(key: const Key('retryConsent'), onPressed: _load, child: const Text('Retry')),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_error!, key: const Key('privacySettingsError'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const Divider(height: 32),
            ListTile(
              key: const Key('openDelete'),
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
              title: const Text('Delete account'),
              subtitle: const Text('Permanently delete your account and data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/delete-account'),
            ),
          ],
        ),
      ),
    );
  }
}

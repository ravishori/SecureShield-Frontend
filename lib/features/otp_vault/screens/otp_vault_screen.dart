import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/theme.dart';
import '../otp_vault_store.dart';

/// Locked list of the bank OTPs the monitor captured. Nothing is shown until the user authenticates with
/// biometrics or the device PIN/pattern; a device with no screen lock cannot open the vault.
class OtpVaultScreen extends StatefulWidget {
  const OtpVaultScreen({super.key, OtpVaultStore? store, Future<bool> Function()? authenticate})
      : _store = store,
        _authenticate = authenticate;

  final OtpVaultStore? _store;
  final Future<bool> Function()? _authenticate;

  @override
  State<OtpVaultScreen> createState() => _OtpVaultScreenState();
}

class _OtpVaultScreenState extends State<OtpVaultScreen> with WidgetsBindingObserver {
  late final OtpVaultStore _store = widget._store ?? OtpVaultStore();
  bool _unlocked = false;
  bool _authing = false;
  bool _showArchived = false;
  List<VaultEntry> _entries = [];
  final Set<String> _revealed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Leaving the app locks the vault again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _unlocked) {
      setState(() {
        _unlocked = false;
        _entries = [];
        _revealed.clear();
      });
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    setState(() => _authing = true);
    final ok = await (widget._authenticate ?? () => BiometricService.authenticate(reason: 'Unlock your OTP vault'))();
    if (!mounted) return;
    if (ok) {
      final entries = await _store.load();
      if (!mounted) return;
      setState(() {
        _unlocked = true;
        _entries = entries;
      });
    }
    if (mounted) setState(() => _authing = false);
  }

  Future<void> _reload() async {
    final entries = await _store.load();
    if (mounted) setState(() => _entries = entries);
  }

  String _mask(String otp) => '•' * otp.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Vault'), actions: [
        if (_unlocked)
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
      ]),
      body: !_unlocked ? _locked() : _list(),
    );
  }

  Widget _locked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 56, color: AppTheme.accent),
          const SizedBox(height: 12),
          const Text('OTP Vault is locked', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Unlock with your fingerprint, face or device PIN. If your phone has no screen lock, set one to use the vault.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('vaultUnlock'),
            onPressed: _authing ? null : _unlock,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Unlock'),
          ),
        ]),
      ),
    );
  }

  Widget _list() {
    final shown = _entries.where((e) => e.isArchived == _showArchived).toList();
    if (shown.isEmpty) {
      return Center(
        child: Text(
          _showArchived ? 'No archived OTPs' : 'No OTPs saved yet.\nBank OTPs detected by the Bank OTP Monitor appear here.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final e = shown[i];
        final revealed = _revealed.contains(e.id);
        return Card(
          child: ListTile(
            key: Key('vaultEntry-${e.id}'),
            leading: Icon(e.isRead ? Icons.mark_email_read : Icons.mark_email_unread, color: AppTheme.accent),
            title: Text(revealed ? e.otp : _mask(e.otp), style: const TextStyle(fontFamily: 'monospace', fontSize: 20, letterSpacing: 3)),
            subtitle: Text('${e.sender}  -  ${e.receivedAt.toLocal().toString().substring(0, 16)}'),
            onTap: () async {
              setState(() => revealed ? _revealed.remove(e.id) : _revealed.add(e.id));
              if (!e.isRead) {
                await _store.markRead(e.id);
                await _reload();
              }
            },
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'copy') {
                  await Clipboard.setData(ClipboardData(text: e.otp));
                } else if (v == 'archive') {
                  _revealed.remove(e.id); // re-mask when it moves between lists
                  await _store.setArchived(e.id, !e.isArchived);
                } else if (v == 'delete') {
                  await _store.delete(e.id);
                }
                await _reload();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'copy', child: Text('Copy')),
                PopupMenuItem(value: 'archive', child: Text(e.isArchived ? 'Unarchive' : 'Archive')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme.dart';
import '../otp_vault_api.dart';

class OtpVaultScreen extends StatefulWidget {
  const OtpVaultScreen({super.key});

  @override
  State<OtpVaultScreen> createState() => _OtpVaultScreenState();
}

class _OtpVaultScreenState extends State<OtpVaultScreen> {
  final _api = OtpVaultApi();
  final _localAuth = LocalAuthentication();
  List<dynamic> _entries = [];
  bool _loading = true;
  bool _unlocked = false;
  final Set<String> _revealedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await _api.getEntries();
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _authenticate() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canAuth) return true;
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access OTP Vault',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (e) {
      return true; // Allow access if auth fails gracefully
    }
  }

  void _revealOtp(String entryId) async {
    if (_revealedIds.contains(entryId)) {
      setState(() => _revealedIds.remove(entryId));
      return;
    }
    final auth = await _authenticate();
    if (auth) {
      setState(() => _revealedIds.add(entryId));
      await _api.markRead(entryId);
    }
  }

  void _showAddDialog() {
    final senderCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final appCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add OTP Manually', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: senderCtrl, decoration: const InputDecoration(labelText: 'Sender (e.g. HDFCBANK)')),
            const SizedBox(height: 8),
            TextField(controller: otpCtrl, decoration: const InputDecoration(labelText: 'OTP Code'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: appCtrl, decoration: const InputDecoration(labelText: 'Source App (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.addEntry(
                  sender: senderCtrl.text.trim(),
                  rawOtp: otpCtrl.text.trim(),
                  encryptedContent: '***${otpCtrl.text.trim()}***',
                  sourceApp: appCtrl.text.trim().isEmpty ? null : appCtrl.text.trim(),
                );
                await _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Vault'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 64, color: AppTheme.accent),
                      const SizedBox(height: 16),
                      const Text('OTP Vault is empty', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                      const Text('Your OTPs will appear here', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add OTP'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final entry = _entries[i] as Map<String, dynamic>;
                      final id = entry['id'] as String;
                      final isRevealed = _revealedIds.contains(id);
                      final isRead = entry['is_read'] as bool? ?? false;

                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) async {
                          await _api.delete(id);
                          await _load();
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead ? const Color(0xFF2A3560) : AppTheme.accent.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lock, color: AppTheme.accent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          entry['sender'] as String? ?? 'Unknown Sender',
                                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                        ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 6, height: 6,
                                            decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isRevealed
                                          ? (entry['raw_otp'] as String? ?? entry['encrypted_content'] as String? ?? '****')
                                          : '● ● ● ● ● ●',
                                      style: TextStyle(
                                        color: isRevealed ? AppTheme.success : AppTheme.textSecondary,
                                        fontSize: isRevealed ? 18 : 14,
                                        fontWeight: isRevealed ? FontWeight.bold : FontWeight.normal,
                                        letterSpacing: isRevealed ? 2 : 4,
                                      ),
                                    ),
                                    if (entry['source_app'] != null)
                                      Text(
                                        entry['source_app'] as String,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isRevealed ? Icons.visibility_off : Icons.fingerprint,
                                  color: AppTheme.accent,
                                ),
                                onPressed: () => _revealOtp(id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

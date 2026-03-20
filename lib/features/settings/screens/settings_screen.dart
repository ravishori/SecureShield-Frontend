import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/auth/user_api.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _userApi = UserApi();
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _seniorMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _userApi.getMe();
      if (mounted) {
        setState(() {
          _user = user;
          _seniorMode = user['senior_mode'] as bool? ?? false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSeniorMode(bool val) async {
    setState(() => _seniorMode = val);
    try {
      await _userApi.updateProfile(seniorMode: val);
    } catch (e) {
      setState(() => _seniorMode = !val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            (_user?['phone'] as String? ?? '?').isNotEmpty
                                ? (_user?['phone'] as String).substring(0, 1)
                                : '?',
                            style: const TextStyle(color: AppTheme.accent, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user?['full_name'] as String? ?? 'User',
                                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              Text(
                                _user?['phone'] as String? ?? '',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (_user?['subscription_tier'] as String? ?? 'free').toUpperCase(),
                                  style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Security Settings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _settingTile(
                    icon: Icons.elderly,
                    label: 'Senior Citizen Mode',
                    subtitle: 'Larger text, simplified UI',
                    trailing: Switch(
                      value: _seniorMode,
                      onChanged: _toggleSeniorMode,
                      activeColor: AppTheme.accent,
                    ),
                  ),
                  _settingTile(
                    icon: Icons.lock_outline,
                    label: 'OTP Vault',
                    subtitle: 'Secure your OTPs',
                    onTap: () => context.push('/otp-vault'),
                  ),
                  _settingTile(
                    icon: Icons.folder_special,
                    label: 'Evidence Locker',
                    subtitle: 'Manage your evidence files',
                    onTap: () => context.push('/evidence'),
                  ),
                  _settingTile(
                    icon: Icons.family_restroom,
                    label: 'Family Dashboard',
                    subtitle: 'Manage family members',
                    onTap: () => context.push('/family'),
                  ),
                  const SizedBox(height: 16),
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _settingTile(
                    icon: Icons.info_outline,
                    label: 'App Version',
                    subtitle: '1.0.0',
                  ),
                  _settingTile(
                    icon: Icons.shield,
                    label: 'Cybercrime Helpline',
                    subtitle: '1930 (India National Cybercrime Helpline)',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor.withOpacity(0.2),
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 20),
        ),
        title: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)) : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary) : null),
        onTap: onTap,
      ),
    );
  }
}

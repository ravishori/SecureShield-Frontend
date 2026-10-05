import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/security/banking_threat_provider.dart';
import '../../../core/theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/theme_switcher.dart';
import '../../../core/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/auth/user_api.dart';
import '../../../features/auth/user_profile_provider.dart';
import '../../banking_protection/widgets/banking_threat_strip.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

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
  String _currentServerUrl = AppConfig.baseUrl;

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
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [ThemeSwitcher()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Device safety summary (banking-threat strip) ────────
                  // Wrapped in a Consumer so the strip rebuilds reactively
                  // when any other screen invalidates the shared provider.
                  Consumer(builder: (_, ref, __) {
                    final report = ref.watch(bankingThreatReportProvider);
                    if (report == null || !report.hasThreats) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'DEVICE SAFETY SUMMARY',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          BankingThreatStrip(
                            report: report,
                            margin: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  }),

                  // Profile section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        // Profile completeness ring
                        GestureDetector(
                          onTap: () => context.push('/profile-details'),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Consumer(builder: (_, ref, __) {
                                  final completeness = ref.watch(profileCompletenessProvider);
                                  final pct = completeness.valueOrNull ?? 0;
                                  return CircularProgressIndicator(
                                    value: pct / 100,
                                    backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        pct >= 80 ? AppTheme.success : AppTheme.accent),
                                    strokeWidth: 3,
                                  );
                                }),
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppTheme.primary,
                                  child: Text(
                                    (_user?['full_name'] as String? ??
                                            _user?['phone'] as String? ?? '?')
                                        .isNotEmpty
                                        ? (_user?['full_name'] as String? ??
                                                _user?['phone'] as String? ?? '?')
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
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
                                  color: AppTheme.accent.withValues(alpha: 0.1),
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

                  // ── Appearance section ──────────────────────────────────
                  Text(AppLocalizations.of(context).appearance, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  // Theme dropdown
                  Builder(builder: (ctx) {
                    final themeMode    = ref.watch(themeProvider);
                    final themeNotifier = ref.read(themeProvider.notifier);
                    final isDark = themeMode == ThemeMode.dark;
                    final accent = AppTheme.accentOf(context);
                    return _settingTile(
                      icon: isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                      label: AppLocalizations.of(context).appTheme,
                      subtitle: isDark ? 'Dark Mode' : 'Light Mode',
                      trailing: DropdownButton<ThemeMode>(
                        value: themeMode,
                        underline: const SizedBox(),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.nights_stay_rounded, size: 16, color: accent),
                                const SizedBox(width: 6),
                                Text('Dark', style: TextStyle(color: accent, fontSize: 12)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wb_sunny_rounded, size: 16, color: accent),
                                const SizedBox(width: 6),
                                Text('Light', style: TextStyle(color: accent, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) => themeNotifier.setTheme(v!),
                      ),
                    );
                  }),

                  // Language selector
                  Builder(builder: (ctx) {
                    final langCode    = ref.watch(languageProvider);
                    final langNotifier = ref.read(languageProvider.notifier);
                    final current = langNotifier.current;
                    return _settingTile(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      subtitle: '${current.nativeName} (${current.name})',
                      onTap: () => _showLanguagePicker(langCode, langNotifier),
                    );
                  }),

                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).securitySettings, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _settingTile(
                    icon: Icons.elderly,
                    label: AppLocalizations.of(context).seniorCitizenMode,
                    subtitle: AppLocalizations.of(context).seniorModeSubtitle,
                    trailing: Switch(
                      value: _seniorMode,
                      onChanged: _toggleSeniorMode,
                      activeThumbColor: AppTheme.accent,
                    ),
                  ),
                  _settingTile(
                    icon: Icons.folder_special,
                    label: AppLocalizations.of(context).evidenceLocker,
                    subtitle: AppLocalizations.of(context).evidenceLockerSubtitle,
                    onTap: () => context.push('/evidence'),
                  ),
                  _settingTile(
                    icon: Icons.family_restroom,
                    label: AppLocalizations.of(context).familyDashboard,
                    subtitle: AppLocalizations.of(context).familyDashboardSubtitle,
                    onTap: () => context.push('/family'),
                  ),
                  _settingTile(
                    icon: Icons.lock_clock,
                    label: 'Bank OTP Monitor',
                    subtitle: 'Detect bank OTPs in real-time',
                    onTap: () => context.push('/bank-otp-monitor'),
                  ),
                  _settingTile(
                    icon: Icons.desktop_access_disabled,
                    label: 'Remote Control Detector',
                    subtitle: 'Detect AnyDesk, TeamViewer & ADB',
                    onTap: () => context.push('/remote-detector'),
                  ),
                  _settingTile(
                    icon: Icons.tune,
                    label: 'Permission Manager',
                    subtitle: 'View & manage app permissions',
                    onTap: () => context.push('/consent-manager'),
                  ),
                  _settingTile(
                    icon: Icons.vpn_lock,
                    label: 'VPN Traffic Monitor',
                    subtitle: 'Monitor outbound connections for threats',
                    onTap: () => context.push('/vpn-monitor'),
                  ),
                  _settingTile(
                    icon: Icons.install_mobile,
                    label: 'App Install Monitor',
                    subtitle: 'Track newly installed apps',
                    onTap: () => context.push('/package-monitor'),
                  ),
                  const SizedBox(height: 16),
                  Text('Developer', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _settingTile(
                    icon: Icons.dns_outlined,
                    label: 'Server URL',
                    subtitle: _currentServerUrl,
                    onTap: _showServerUrlDialog,
                  ),
                  const SizedBox(height: 16),
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _settingTile(
                    icon: Icons.info_outline,
                    label: AppLocalizations.of(context).appVersion,
                    subtitle: '1.0.0',
                  ),
                  _settingTile(
                    icon: Icons.shield,
                    label: AppLocalizations.of(context).cybercrimeHelpline,
                    subtitle: AppLocalizations.of(context).cybercrimeHelplineNumber,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) router.go('/welcome');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
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

  void _showServerUrlDialog() {
    final ctrl = TextEditingController(text: AppConfig.baseUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, color: AppTheme.accent, size: 20),
            SizedBox(width: 8),
            Text('Server URL', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update this if your PC\'s IP address changed. '
              'Format: http://192.168.x.x:8000/api/v1',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
                  onPressed: () => Clipboard.setData(ClipboardData(text: ctrl.text)),
                  tooltip: 'Copy',
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Quick preset chips
            Wrap(
              spacing: 6,
              children: [
                _urlChip('Emulator', 'http://10.0.2.2:8000/api/v1', ctrl),
                _urlChip('LAN', 'http://${AppConfig.deviceLanIp}:8000/api/v1', ctrl),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await AppConfig.clearCustomUrl();
              DioClient.reset();
              if (mounted) {
                setState(() => _currentServerUrl = AppConfig.baseUrl);
              }
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Server URL reset to auto-detected value')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await AppConfig.setCustomUrl(url);
              DioClient.reset();
              if (mounted) {
                setState(() => _currentServerUrl = url);
              }
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Server URL updated to $url'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _urlChip(String label, String url, TextEditingController ctrl) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
      side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
      labelStyle: const TextStyle(color: AppTheme.accent),
      onPressed: () => ctrl.text = url,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _showLanguagePicker(String currentCode, LanguageNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(AppLocalizations.of(context).selectLanguage,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            const Divider(color: Color(0xFF2A3560)),
            ...supportedLanguages.map((lang) => ListTile(
                  leading: Icon(
                    Icons.language_rounded,
                    color: lang.code == currentCode ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                  title: Text(lang.nativeName,
                      style: TextStyle(
                        color: lang.code == currentCode ? AppTheme.accent : AppTheme.textPrimary,
                        fontWeight: lang.code == currentCode ? FontWeight.w600 : FontWeight.normal,
                      )),
                  subtitle: Text(lang.name,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: lang.code == currentCode
                      ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                      : null,
                  onTap: () {
                    notifier.setLanguage(lang.code);
                    Navigator.pop(context);
                  },
                )),
          ],
        );
      },
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
            color: AppTheme.accent.withValues(alpha: 0.1),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../elderly_service.dart';
import '../models/elderly_config.dart';

class ElderlyModeScreen extends ConsumerStatefulWidget {
  const ElderlyModeScreen({super.key});
  @override
  ConsumerState<ElderlyModeScreen> createState() => _ElderlyModeScreenState();
}

class _ElderlyModeScreenState extends ConsumerState<ElderlyModeScreen> {
  final _guardianNameCtrl  = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _guardianEmailCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(elderlyConfigProvider.notifier).load();
  }

  @override
  void dispose() {
    _guardianNameCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _guardianEmailCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFrom(ElderlyConfig cfg) {
    if (_guardianNameCtrl.text.isEmpty && cfg.guardianName != null)
      _guardianNameCtrl.text = cfg.guardianName!;
    if (_guardianPhoneCtrl.text.isEmpty && cfg.guardianPhone != null)
      _guardianPhoneCtrl.text = cfg.guardianPhone!;
    if (_guardianEmailCtrl.text.isEmpty && cfg.guardianEmail != null)
      _guardianEmailCtrl.text = cfg.guardianEmail!;
  }

  Future<void> _save() async {
    final cfg = ref.read(elderlyConfigProvider);
    setState(() => _saving = true);
    final updated = cfg.copyWith(
      guardianName:  _guardianNameCtrl.text.trim().isEmpty ? null : _guardianNameCtrl.text.trim(),
      guardianPhone: _guardianPhoneCtrl.text.trim().isEmpty ? null : _guardianPhoneCtrl.text.trim(),
      guardianEmail: _guardianEmailCtrl.text.trim().isEmpty ? null : _guardianEmailCtrl.text.trim(),
    );
    final ok = await ref.read(elderlyConfigProvider.notifier).save(updated);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Settings saved' : '❌ Failed to save'),
          backgroundColor: ok ? AppTheme.success : AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(elderlyConfigProvider);
    _syncControllersFrom(cfg);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elderly Protection Mode'),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save settings',
              onPressed: _save,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _heroCard(cfg),
          const SizedBox(height: 20),
          if (cfg.enabled) ...[
            _sectionTitle('Guardian Contact'),
            const SizedBox(height: 8),
            _guardianCard(),
            const SizedBox(height: 20),
            _sectionTitle('Protection Settings'),
            const SizedBox(height: 8),
            _settingsCard(cfg),
            const SizedBox(height: 20),
            _howItWorksCard(),
          ] else
            _disabledHint(),
        ]),
      ),
    );
  }

  // ── Hero toggle card ──────────────────────────────────────────────────────
  Widget _heroCard(ElderlyConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cfg.enabled
              ? [const Color(0xFF9C27B0).withOpacity(0.85), const Color(0xFF7B1FA2).withOpacity(0.5)]
              : [AppTheme.cardColor, AppTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cfg.enabled ? const Color(0xFF9C27B0) : AppTheme.textSecondary.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(Icons.elderly, size: 52,
            color: cfg.enabled ? Colors.white : AppTheme.textSecondary),
        const SizedBox(height: 8),
        Text(
          cfg.enabled ? 'Elderly Mode Active' : 'Elderly Mode Off',
          style: TextStyle(
            color: cfg.enabled ? Colors.white : AppTheme.textPrimary,
            fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          cfg.enabled
              ? 'Your device is protected.\nFamily will be alerted on risky installs.'
              : 'Enable to activate senior-citizen safety protection.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cfg.enabled ? Colors.white70 : AppTheme.textSecondary,
            fontSize: 13),
        ),
        const SizedBox(height: 16),
        Transform.scale(
          scale: 1.2,
          child: Switch(
            value: cfg.enabled,
            onChanged: (v) {
              final updated = cfg.copyWith(enabled: v);
              ref.read(elderlyConfigProvider.notifier).update(updated);
              ref.read(elderlyConfigProvider.notifier).save(updated);
            },
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF9C27B0),
          ),
        ),
      ]),
    );
  }

  // ── Guardian contact ──────────────────────────────────────────────────────
  Widget _guardianCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      _textField(_guardianNameCtrl,  'Guardian Name',  'e.g. Rahul (Son)', Icons.person),
      const SizedBox(height: 12),
      _textField(_guardianPhoneCtrl, 'Guardian Phone', '+91 9XXXXXXXXX',    Icons.phone,
          type: TextInputType.phone),
      const SizedBox(height: 12),
      _textField(_guardianEmailCtrl, 'Guardian Email', 'guardian@email.com', Icons.email,
          type: TextInputType.emailAddress),
    ]),
  );

  // ── Settings card ─────────────────────────────────────────────────────────
  Widget _settingsCard(ElderlyConfig cfg) => Container(
    decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      _switchTile(
        icon: Icons.block, color: AppTheme.errorColor,
        title: 'Block Risky App Installs',
        subtitle: 'Show a blocking dialog when a dangerous app is installed',
        value: cfg.blockRiskyInstalls,
        onChanged: (v) => ref.read(elderlyConfigProvider.notifier)
            .update(cfg.copyWith(blockRiskyInstalls: v)),
      ),
      const Divider(height: 1, color: Colors.white10),
      _switchTile(
        icon: Icons.notifications_active, color: AppTheme.warning,
        title: 'Alert Guardian Automatically',
        subtitle: 'Send SMS / email to guardian when a risky app installs',
        value: cfg.autoAlertGuardian,
        onChanged: (v) => ref.read(elderlyConfigProvider.notifier)
            .update(cfg.copyWith(autoAlertGuardian: v)),
      ),
      const Divider(height: 1, color: Colors.white10),
      _switchTile(
        icon: Icons.text_increase, color: AppTheme.accent,
        title: 'Large Text Mode',
        subtitle: 'Use bigger fonts in security alerts for better readability',
        value: cfg.largeText,
        onChanged: (v) => ref.read(elderlyConfigProvider.notifier)
            .update(cfg.copyWith(largeText: v)),
      ),
      const Divider(height: 1, color: Colors.white10),
      // Alert threshold slider
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune, color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Alert Sensitivity',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
              child: Text('${cfg.alertThreshold}/100',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Lower = alert on more apps  |  Higher = alert on fewer',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          Slider(
            value: cfg.alertThreshold.toDouble(),
            min: 10, max: 90, divisions: 8,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.accent.withOpacity(0.2),
            onChanged: (v) => ref.read(elderlyConfigProvider.notifier)
                .update(cfg.copyWith(alertThreshold: v.round())),
          ),
        ]),
      ),
    ]),
  );

  // ── How it works ──────────────────────────────────────────────────────────
  Widget _howItWorksCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.tips_and_updates, color: AppTheme.accent, size: 18),
        SizedBox(width: 8),
        Text('How Elderly Mode Works',
            style: TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
      const SizedBox(height: 10),
      ...[
        '🔍  Every app install is automatically scanned for risk.',
        '🚨  If a risky or fake app is detected, a large ALERT dialog appears.',
        '📲  Your guardian (family member) is notified via SMS/email immediately.',
        '🛡️  Fake apps (clones of WhatsApp, PhonePe etc.) are blocked with an uninstall prompt.',
        '🔕  Safe apps (Play Store verified) install silently without interruption.',
      ].map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      )),
    ]),
  );

  Widget _disabledHint() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
    child: const Row(children: [
      Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
      SizedBox(width: 10),
      Expanded(child: Text(
        'Enable Elderly Mode above to configure guardian contacts and protection settings.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      )),
    ]),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t, style: const TextStyle(color: AppTheme.textPrimary,
        fontWeight: FontWeight.bold, fontSize: 15)),
  );

  Widget _textField(TextEditingController ctrl, String label, String hint,
      IconData icon, {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          prefixIcon: Icon(icon, color: AppTheme.accent, size: 20),
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          hintStyle:  const TextStyle(color: AppTheme.textSecondary),
          enabledBorder:  OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.accent)),
        ),
      );

  Widget _switchTile({
    required IconData icon, required Color color,
    required String title, required String subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) => ListTile(
    leading: Icon(icon, color: color, size: 22),
    title:   Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
    subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    trailing: Switch(value: value, onChanged: onChanged, activeColor: color),
  );
}

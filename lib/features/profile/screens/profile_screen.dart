import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/data/india_locations.dart';
import '../../../features/auth/user_api.dart';
import '../../../features/auth/user_profile_provider.dart';
import '../profile_api.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Screen — edit profile + manage emergency contacts
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).profMy),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.person_rounded), text: 'Profile'),
            Tab(icon: Icon(Icons.emergency_rounded), text: 'Emergency Contacts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ProfileTab(),
          _EmergencyContactsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Edit profile
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  final _formKey      = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _pinCtrl       = TextEditingController();

  String? _selectedState;
  String? _selectedCity;
  bool _loading = true;
  bool _saving  = false;

  final _api = UserApi();

  List<String> get _cities =>
      _selectedState != null ? (indiaLocations[_selectedState] ?? []) : [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await _api.getMe();
      if (mounted) {
        setState(() {
          _firstNameCtrl.text = user['first_name'] as String? ?? '';
          _lastNameCtrl.text  = user['last_name']  as String? ?? '';
          _emailCtrl.text     = user['email']       as String? ?? '';
          _phoneCtrl.text     = user['phone']       as String? ?? '';
          _pinCtrl.text       = user['pin_code']    as String? ?? '';
          _selectedState      = user['state']       as String?;
          _selectedCity       = user['city']        as String?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        city:      _selectedCity,
        state:     _selectedState,
        pinCode:   _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
      );
      ref.invalidate(userProfileProvider);
      if (mounted) {
        _showSuccess('Profile updated! A security notification has been sent to your email.');
      }
    } catch (e) {
      if (mounted) _showError('Failed to save: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccess(String msg) {
    final accent = AppTheme.accentOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).profSaved,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    final onSurf = Theme.of(context).colorScheme.onSurface;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name ───────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Icon(Icons.person_rounded, color: accent, size: 42),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim().isEmpty
                        ? 'Your Name'
                        : '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim(),
                    style: TextStyle(
                      color: onSurf,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _emailCtrl.text.isEmpty ? 'No email set' : _emailCtrl.text,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Security notification banner ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).profChangeEmail,
                      style: TextStyle(color: onSurf.withValues(alpha: 0.7), fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Personal Info ────────────────────────────────────────────────
            _sectionHeader(accent, Icons.person_outlined, AppLocalizations.of(context).personalInformation),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _field(
                  controller: _firstNameCtrl,
                  label: AppLocalizations.of(context).firstName,
                  icon: Icons.badge_outlined,
                  accent: accent,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                )),
                const SizedBox(width: 12),
                Expanded(child: _field(
                  controller: _lastNameCtrl,
                  label: AppLocalizations.of(context).lastName,
                  icon: Icons.badge_outlined,
                  accent: accent,
                )),
              ],
            ),
            const SizedBox(height: 14),

            // ── Contact Details ──────────────────────────────────────────────
            _sectionHeader(accent, Icons.contact_mail_outlined, 'Contact Details'),
            const SizedBox(height: 12),

            _field(
              controller: _emailCtrl,
              label: AppLocalizations.of(context).profEmailAddr,
              icon: Icons.email_outlined,
              accent: accent,
              keyboardType: TextInputType.emailAddress,
              hint: 'your@email.com',
              validator: (v) {
                if (v != null && v.isNotEmpty && !v.contains('@')) return 'Enter valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Phone (read-only, shown from backend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, color: accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).mobileNumber, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          _phoneCtrl.text.isEmpty ? 'Not set' : _phoneCtrl.text,
                          style: TextStyle(color: onSurf, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(AppLocalizations.of(context).gVerified, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Location ─────────────────────────────────────────────────────
            _sectionHeader(accent, Icons.location_on_outlined, 'Location'),
            const SizedBox(height: 12),

            // State dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedState,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).selectState,
                prefixIcon: Icon(Icons.map_outlined, color: accent, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: (indiaLocations.keys.toList()..sort())
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() { _selectedState = v; _selectedCity = null; }),
              hint: Text(AppLocalizations.of(context).profSelectState, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 12),

            // City dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCity,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).selectCity,
                prefixIcon: Icon(Icons.location_city_outlined, color: accent, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _cities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: _selectedState == null ? null : (v) => setState(() => _selectedCity = v),
              hint: Text(_selectedState == null ? 'Select State first' : 'Select City', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 12),

            _field(
              controller: _pinCtrl,
              label: AppLocalizations.of(context).profPin,
              icon: Icons.pin_drop_outlined,
              accent: accent,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length != 6) return 'PIN must be 6 digits';
                return null;
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Profile'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color accent,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: accent, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }

  Widget _sectionHeader(Color accent, IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accent, size: 16),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Emergency Contacts
// ─────────────────────────────────────────────────────────────────────────────
class _EmergencyContactsTab extends StatefulWidget {
  const _EmergencyContactsTab();

  @override
  State<_EmergencyContactsTab> createState() => _EmergencyContactsTabState();
}

class _EmergencyContactsTabState extends State<_EmergencyContactsTab> {
  final _api = ProfileApi();
  List<dynamic> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _api.getEmergencyContacts();
      if (mounted) setState(() { _contacts = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _api.deleteEmergencyContact(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).profContactRemoved),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete contact: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Open the bottom-sheet for either creating a new contact (existing=null)
  /// or editing an existing one (existing=<contact map>).
  void _showContactSheet({Map<String, dynamic>? existing}) {
    final isEdit    = existing != null;
    final nameCtrl  = TextEditingController(text: (existing?['name']         as String?) ?? '');
    final relCtrl   = TextEditingController(text: (existing?['relationship'] as String?) ?? '');
    final phoneCtrl = TextEditingController(text: (existing?['phone']        as String?) ?? '');
    final emailCtrl = TextEditingController(text: (existing?['email']        as String?) ?? '');
    final formKey   = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final accent = AppTheme.accentOf(context);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_outlined
                                : Icons.emergency_rounded,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(isEdit ? 'Edit Emergency Contact' : 'Add Emergency Contact',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Name
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).profFullName,
                        prefixIcon: Icon(Icons.person_outlined, color: accent, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    // Relationship
                    TextFormField(
                      controller: relCtrl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).profRelationship,
                        prefixIcon: Icon(Icons.people_outlined, color: accent, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Phone
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).profPhone,
                        prefixIcon: Icon(Icons.phone_outlined, color: accent, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if ((v == null || v.trim().isEmpty) && emailCtrl.text.trim().isEmpty) {
                          return 'At least one of phone or email is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Email
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).profEmailAddr,
                        prefixIcon: Icon(Icons.email_outlined, color: accent, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context).profContactsInfo,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => saving = true);
                          try {
                            if (isEdit) {
                              await _api.updateEmergencyContact(
                                id:           existing['id'] as String,
                                name:         nameCtrl.text.trim(),
                                relationship: relCtrl.text.trim(),
                                phone:        phoneCtrl.text.trim(),
                                email:        emailCtrl.text.trim(),
                              );
                            } else {
                              await _api.addEmergencyContact(
                                name:         nameCtrl.text.trim(),
                                relationship: relCtrl.text.trim(),
                                phone:        phoneCtrl.text.trim(),
                                email:        emailCtrl.text.trim(),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Contact updated' : 'Contact added'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            _load();
                          } catch (e) {
                            setSheetState(() => saving = false);
                            if (context.mounted) {
                              // ignore: use_build_context_synchronously (guarded by context.mounted above)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
                              );
                            }
                          }
                        },
                        icon: saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                        label: Text(
                          saving
                              ? (isEdit ? 'Saving…' : 'Adding…')
                              : (isEdit ? 'Save Changes' : 'Add Contact'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Back-compat shim — older call sites still invoke _showAddSheet().
  void _showAddSheet() => _showContactSheet();

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppTheme.errorColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(AppLocalizations.of(context).profAddContact, style: const TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _contacts.isEmpty
              ? _buildEmpty(accent)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) => _contactCard(_contacts[i] as Map<String, dynamic>),
                ),
    );
  }

  Widget _buildEmpty(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_rounded, size: 48, color: AppTheme.errorColor),
            ),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context).profNoContacts,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).profNoContactsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(Map<String, dynamic> c) {
    final name         = c['name'] as String? ?? 'Unknown';
    final relationship = c['relationship'] as String? ?? '';
    final phone        = c['phone'] as String? ?? '';
    final email        = c['email'] as String? ?? '';
    final id           = c['id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (relationship.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          relationship,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.phone, size: 11, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ]),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.email, size: 11, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                  ]),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit pencil — opens the same bottom-sheet pre-filled.
              IconButton(
                onPressed: () => _showContactSheet(existing: c),
                tooltip: AppLocalizations.of(context).gEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppTheme.accentOf(context),
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(height: 2),
              IconButton(
                onPressed: () => _confirmDelete(id, name),
                tooltip: AppLocalizations.of(context).gDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).profRemoveContact, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
        content: Text('Remove $name from emergency contacts?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _delete(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context).gRemove),
          ),
        ],
      ),
    );
  }
}

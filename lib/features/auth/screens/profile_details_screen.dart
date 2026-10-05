import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/data/india_locations.dart';
import '../../../core/utils/validators.dart';
import '../user_api.dart';
import '../user_profile_provider.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl   = TextEditingController();
  final _lastNameCtrl    = TextEditingController();
  final _altPhoneCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _flatCtrl        = TextEditingController();
  final _buildingCtrl    = TextEditingController();
  final _streetCtrl      = TextEditingController();
  final _pinCtrl         = TextEditingController();

  String? _selectedState;
  String? _selectedCity;
  bool _saving = false;

  List<String> get _citiesForState =>
      _selectedState != null ? (indiaLocations[_selectedState] ?? []) : [];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _flatCtrl.dispose();
    _buildingCtrl.dispose();
    _streetCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final api = UserApi();
      await api.updateProfile(
        firstName:   _firstNameCtrl.text.trim(),
        lastName:    _lastNameCtrl.text.trim(),
        altPhone:    _altPhoneCtrl.text.trim().isEmpty ? null : _altPhoneCtrl.text.trim(),
        email:       _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        flatNo:      _flatCtrl.text.trim(),
        building:    _buildingCtrl.text.trim(),
        street:      _streetCtrl.text.trim(),
        city:        _selectedCity ?? '',
        state:       _selectedState ?? '',
        country:     'India',
        pinCode:     _pinCtrl.text.trim(),
      );

      if (mounted) {
        // Invalidate profile cache so completeness banner refreshes
        ref.invalidate(userProfileProvider);
        ref.invalidate(profileCompletenessProvider);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile saved successfully!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        // Even if save fails, allow user to proceed
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text('Skip', style: TextStyle(color: accent)),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _SectionHeader(
                  icon: Icons.person_outline_rounded,
                  title: 'Personal Information',
                  accent: accent,
                ),
                const SizedBox(height: 12),

                // First + Last name row
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _firstNameCtrl,
                        label: 'First Name *',
                        icon: Icons.badge_outlined,
                        validator: Validators.required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        controller: _lastNameCtrl,
                        label: 'Last Name *',
                        icon: Icons.badge_outlined,
                        validator: Validators.required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _altPhoneCtrl,
                  label: 'Alternate Phone (optional)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 15,
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _emailCtrl,
                  label: 'Email Address (optional)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(r'^[\w.]+@[\w.]+\.\w{2,}$').hasMatch(v.trim())) {
                        return 'Invalid email address';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                _SectionHeader(
                  icon: Icons.location_on_outlined,
                  title: 'Complete Address',
                  accent: accent,
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _flatCtrl,
                  label: 'Flat / House No. *',
                  icon: Icons.home_outlined,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _buildingCtrl,
                  label: 'Building / Society',
                  icon: Icons.apartment_outlined,
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _streetCtrl,
                  label: 'Street / Area',
                  icon: Icons.streetview_outlined,
                ),
                const SizedBox(height: 12),

                // State dropdown
                _DropdownField<String>(
                  label: 'State *',
                  icon: Icons.map_outlined,
                  value: _selectedState,
                  items: indiaStates,
                  itemLabel: (s) => s,
                  onChanged: (v) => setState(() {
                    _selectedState = v;
                    _selectedCity = null; // reset city when state changes
                  }),
                  validator: (v) => v == null ? 'Please select a state' : null,
                ),
                const SizedBox(height: 12),

                // City dropdown (depends on selected state)
                _DropdownField<String>(
                  label: 'City *',
                  icon: Icons.location_city_outlined,
                  value: _selectedCity,
                  items: _citiesForState,
                  itemLabel: (c) => c,
                  onChanged: (v) => setState(() => _selectedCity = v),
                  validator: (v) => v == null ? 'Please select a city' : null,
                  enabled: _selectedState != null,
                  disabledHint: 'Select state first',
                ),
                const SizedBox(height: 12),

                // Country (fixed India)
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: accent, size: 20),
                      const SizedBox(width: 12),
                      const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('India', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Fixed', style: TextStyle(color: accent.withValues(alpha: 0.5), fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _pinCtrl,
                  label: 'Pin Code *',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.trim().length != 6) return '6-digit pin code required';
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_saving ? 'Saving…' : 'Save & Continue'),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'Fill this in later',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  const _SectionHeader({required this.icon, required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator: validator,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        counterText: '',
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final String disabledHint;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.disabledHint = '',
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      hint: Text(
        enabled ? 'Select…' : disabledHint,
        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
      ),
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down_rounded, color: enabled ? accent : Colors.grey),
      dropdownColor: AppTheme.cardColor,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      items: enabled
          ? items.map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              )).toList()
          : [],
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}

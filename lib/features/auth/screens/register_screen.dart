import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/data/india_locations.dart';
import '../auth_provider.dart';
import '../../privacy/screens/consent_screen.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

// ── Country codes ─────────────────────────────────────────────────────────────
class _Country {
  final String name;
  final String code;
  final String flag;
  const _Country(this.name, this.code, this.flag);
}

const _countries = [
  _Country('India',          '+91',  '🇮🇳'),
  _Country('USA',            '+1',   '🇺🇸'),
  _Country('UK',             '+44',  '🇬🇧'),
  _Country('UAE',            '+971', '🇦🇪'),
  _Country('Australia',      '+61',  '🇦🇺'),
  _Country('Canada',         '+1',   '🇨🇦'),
  _Country('Singapore',      '+65',  '🇸🇬'),
  _Country('Germany',        '+49',  '🇩🇪'),
  _Country('Saudi Arabia',   '+966', '🇸🇦'),
  _Country('Nepal',          '+977', '🇳🇵'),
  _Country('Bangladesh',     '+880', '🇧🇩'),
  _Country('Sri Lanka',      '+94',  '🇱🇰'),
  _Country('Malaysia',       '+60',  '🇲🇾'),
];

// ── RegisterScreen ────────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController(); // MANDATORY
  final _flatCtrl      = TextEditingController();
  final _buildingCtrl  = TextEditingController();
  final _streetCtrl    = TextEditingController();
  final _pinCtrl       = TextEditingController();

  // State
  _Country _selectedCountry  = _countries.first;
  String?  _selectedState;
  String?  _selectedCity;
  bool     _addressExpanded  = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _flatCtrl.dispose();
    _buildingCtrl.dispose();
    _streetCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // Both email and phone are mandatory
    final phone = '${_selectedCountry.code}${_phoneCtrl.text.trim()}';

    try {
      final result = await ref.read(authProvider.notifier).register(
        consent:   ref.read(consentDraftProvider),
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim().toLowerCase(),
        phone:     phone,
        flatNo:    _flatCtrl.text.trim().isEmpty    ? null : _flatCtrl.text.trim(),
        building:  _buildingCtrl.text.trim().isEmpty ? null : _buildingCtrl.text.trim(),
        street:    _streetCtrl.text.trim().isEmpty   ? null : _streetCtrl.text.trim(),
        city:      _selectedCity,
        state:     _selectedState,
        country:   'India',
        pinCode:   _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
      );

      if (mounted) {
        // The code goes to the e-mail address only; the phone number is verified separately afterwards.
        context.push('/otp', extra: {
          'identifier':  _emailCtrl.text.trim().toLowerCase(),
          'maskedEmail': result.maskedEmail,
          'isRegister':  true,
        });
      }
    } catch (e) {
      if (!mounted) return;

      // ── Special handling: HTTP 409 = account already exists ──────────────
      // Detect either via DioException status OR by message content (covers
      // the case where the error has already been wrapped by the provider).
      final providerError = ref.read(authProvider).error;
      final isConflict =
          (e is DioException && e.response?.statusCode == 409) ||
          (providerError?.toLowerCase().contains('already') ?? false) ||
          (providerError?.toLowerCase().contains('conflict') ?? false);

      if (isConflict) {
        await _showAccountExistsDialog(providerError);
        return;
      }

      final msg = providerError ?? e.toString();
      AppSnackBar.error(context, msg);
    }
  }

  /// Show a friendly "account exists" dialog with two actions: go to login
  /// (pre-fills the identifier) or amend the form.
  Future<void> _showAccountExistsDialog(String? backendMessage) async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final phone = '${_selectedCountry.code}${_phoneCtrl.text.trim()}';

    // The backend says either "email already" or "phone already" — pick the
    // most-relevant identifier to pre-fill on the login screen.
    final mentionsPhone = backendMessage?.toLowerCase().contains('phone') ?? false;
    final loginIdentifier = mentionsPhone ? phone : email;

    final accent = AppTheme.accentOf(context);
    final cs = Theme.of(context).colorScheme;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.account_circle_outlined, color: accent, size: 48),
        title: Text(
          'Account already exists',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              backendMessage ??
                  'An account is already registered with this email or phone number.',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                loginIdentifier,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: Text(
              'Edit details',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'login'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in instead'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'login') {
      // Navigate to login with identifier pre-filled.
      context.go('/login', extra: {'identifier': loginIdentifier});
    }
    // 'edit' (or dismiss) → stay on register screen so user can change details
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final accent = AppTheme.accentOf(context);
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            slivers: [
              // ── Header ───────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(context, accent)),

              // ── Form ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── SECTION: Personal Info ────────────────────────
                        _sectionLabel(accent, Icons.person_rounded, AppLocalizations.of(context).personalInformation),
                        Sp.gapMd,

                        // First + Last name
                        Row(children: [
                          Expanded(
                            child: AppTextField(
                              controller: _firstNameCtrl,
                              label: 'First Name *',
                              prefixIcon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.words,
                              validator: Validators.name,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _lastNameCtrl,
                              label: AppLocalizations.of(context).lastName,
                              prefixIcon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.words,
                              validator: (_) => null,
                            ),
                          ),
                        ]),
                        Sp.gapMd,

                        // ── SECTION: Contact Details (both MANDATORY) ────
                        _sectionLabel(accent, Icons.contact_mail_rounded, 'Contact Details'),
                        Sp.gapSm,

                        // Mandatory badge info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Both email and phone number are required. '
                                  'We verify your email first; your phone is verified next, separately.',
                                  style: TextStyle(
                                    color: onSurf.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Sp.gapMd,

                        // Email — MANDATORY
                        AppTextField(
                          controller: _emailCtrl,
                          label: 'Email Address *',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.emailRequired,
                        ),
                        Sp.gapMd,

                        // Phone — MANDATORY (always visible, with country picker)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phone Number *',
                              style: TextStyle(
                                color: onSurf.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Country code picker
                                GestureDetector(
                                  onTap: _showCountryPicker,
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).inputDecorationTheme.fillColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_selectedCountry.flag,
                                          style: const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _selectedCountry.code,
                                          style: TextStyle(
                                            color: onSurf,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(Icons.arrow_drop_down,
                                          size: 18,
                                          color: onSurf.withValues(alpha: 0.6)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: TextStyle(color: onSurf, fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'Mobile Number *',
                                      prefixIcon: Icon(Icons.phone_rounded,
                                        color: accent, size: 20),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Phone number is required';
                                      }
                                      if (v.trim().length < 7) {
                                        return 'Enter a valid phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Sp.gapXl,

                        // ── SECTION: Address (Optional) ──────────────────
                        _sectionLabel(accent, Icons.home_rounded, 'Address'),
                        Sp.gapSm,
                        _buildAddressToggle(accent, onSurf),
                        if (_addressExpanded) ...[
                          Sp.gapMd,
                          _buildAddressFields(accent),
                        ],
                        Sp.gapXl,

                        // ── Terms notice ─────────────────────────────────
                        _buildTermsNotice(accent, onSurf),
                        Sp.gapXl,

                        // ── Submit button ────────────────────────────────
                        AppButton(
                          label:        'Create Account & Get OTP',
                          icon:         Icons.how_to_reg_rounded,
                          loading:      auth.isLoading,
                          onPressed:    _submit,
                        ),
                        Sp.gapLg,

                        // ── Login link ───────────────────────────────────
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/login'),
                            child: RichText(
                              text: TextSpan(
                                text: 'Already have an account? ',
                                style: TextStyle(
                                  color: onSurf.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Login',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label ────────────────────────────────────────────────────────

  Widget _sectionLabel(Color accent, IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ── App header ───────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 16),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.person_add_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).registerTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Email & phone required - email is verified first',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Country picker ───────────────────────────────────────────────────────

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView.builder(
        itemCount: _countries.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (ctx, i) {
          final c = _countries[i];
          return ListTile(
            leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
            title: Text(c.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            trailing: Text(c.code,
              style: TextStyle(
                color: AppTheme.accentOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              setState(() => _selectedCountry = c);
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }

  // ── Address section ──────────────────────────────────────────────────────

  Widget _buildAddressToggle(Color accent, Color onSurf) {
    return GestureDetector(
      onTap: () => setState(() => _addressExpanded = !_addressExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _addressExpanded
                    ? 'Address Details (Optional)'
                    : '+ Add Address Details (Optional)',
                style: TextStyle(
                  color: _addressExpanded ? onSurf : accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              _addressExpanded ? Icons.expand_less : Icons.expand_more,
              color: accent, size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressFields(Color accent) {
    final states = indiaLocations.keys.toList()..sort();
    final cities = _selectedState != null
        ? (indiaLocations[_selectedState] ?? [])
        : <String>[];

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: AppTextField(
              controller: _flatCtrl,
              label: AppLocalizations.of(context).flatHouseNo,
              prefixIcon: Icons.home_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppTextField(
              controller: _buildingCtrl,
              label: AppLocalizations.of(context).buildingSociety,
              prefixIcon: Icons.apartment_outlined,
            ),
          ),
        ]),
        Sp.gapMd,
        AppTextField(
          controller: _streetCtrl,
          label: AppLocalizations.of(context).streetArea,
          prefixIcon: Icons.add_road_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        Sp.gapMd,
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).selectState,
            prefixIcon: Icon(Icons.map_outlined, color: accent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: states
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            _selectedState = v;
            _selectedCity  = null;
          }),
          hint: const Text('Select State', style: TextStyle(fontSize: 13)),
        ),
        Sp.gapMd,
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).selectCity,
            prefixIcon: Icon(Icons.location_city_outlined, color: accent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: cities
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: _selectedState == null
              ? null
              : (v) => setState(() => _selectedCity = v),
          hint: Text(
            _selectedState == null ? 'Select State first' : 'Select City',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Sp.gapMd,
        Row(children: [
          Expanded(
            child: AppTextField(
              controller: _pinCtrl,
              label: 'PIN Code',
              prefixIcon: Icons.pin_drop_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.pinCode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'India',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Terms notice ─────────────────────────────────────────────────────────

  Widget _buildTermsNotice(Color accent, Color onSurf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'A 6-digit OTP will be sent to BOTH your email and mobile number '
              'to verify your identity. OTP expires in 10 minutes.',
              style: TextStyle(
                color: onSurf.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

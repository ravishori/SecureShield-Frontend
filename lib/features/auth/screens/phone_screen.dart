import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth_provider.dart';
import '../../../core/theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/biometric_service.dart';

enum _LoginMethod { phone, email }

// ---------------------------------------------------------------------------
// Country codes list
// ---------------------------------------------------------------------------
class _Country {
  final String flag;
  final String name;
  final String code; // e.g. +91

  const _Country(this.flag, this.name, this.code);
}

const _countries = [
  _Country('🇮🇳', 'India', '+91'),
  _Country('🇺🇸', 'USA', '+1'),
  _Country('🇬🇧', 'UK', '+44'),
  _Country('🇦🇺', 'Australia', '+61'),
  _Country('🇸🇬', 'Singapore', '+65'),
  _Country('🇦🇪', 'UAE', '+971'),
  _Country('🇨🇦', 'Canada', '+1'),
  _Country('🇳🇿', 'New Zealand', '+64'),
  _Country('🇿🇦', 'South Africa', '+27'),
  _Country('🇲🇾', 'Malaysia', '+60'),
];

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  _LoginMethod _method = _LoginMethod.phone;
  _Country _selectedCountry = _countries[0]; // India (+91) default
  bool _loading = false;

  // Biometric login state
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Check biometric availability asynchronously
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _identifier => _method == _LoginMethod.phone
      ? '${_selectedCountry.code}${_phoneController.text.trim()}'
      : _emailController.text.trim();

  void _switchMethod(_LoginMethod m) {
    if (_method == m) return;
    setState(() => _method = m);
    _fadeCtrl
      ..reset()
      ..forward();
  }

  String? _validate() {
    if (_method == _LoginMethod.phone) {
      final v = _phoneController.text.trim();
      if (v.isEmpty) return 'Please enter your phone number.';
      // Strip any spaces/dashes; must be 5–15 digits (local portion only)
      final digits = v.replaceAll(RegExp(r'[\s\-]'), '');
      if (!RegExp(r'^\d{5,15}$').hasMatch(digits)) {
        return 'Enter a valid phone number (digits only, e.g. 9987671916).';
      }
    } else {
      final v = _emailController.text.trim();
      if (v.isEmpty) return 'Please enter your email address.';
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
        return 'Enter a valid email address.';
      }
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).sendOtp(_identifier);
      if (mounted) context.push('/otp', extra: _identifier);
    } catch (e) {
      if (mounted) {
        _showError(e is DioException
            ? e.friendlyMessage
            : 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _biometricLoading = true);
    try {
      final success = await BiometricService.authenticate(
        reason: 'Use your biometric to sign in to SecureShield AI',
      );
      if (!success) {
        if (mounted) {
          _showError('Biometric authentication failed. Please try again or use OTP.');
        }
        return;
      }

      // Refresh tokens silently using stored refresh token
      await ref.read(authProvider.notifier).refreshTokens();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        _showError('Biometric login failed. Please log in with OTP.');
      }
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ───────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.security, size: 48, color: AppTheme.accent),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'SecureShield AI',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                ),
              ),
              Center(
                child: Text(
                  'Cyber Safety & Threat Prevention',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),

              const SizedBox(height: 36),

              Text(
                'Sign in to SecureShield',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'We\'ll send a one-time verification code',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 24),

              // ── Toggle: Phone / Email ──────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Phone',
                      icon: Icons.phone_android,
                      selected: _method == _LoginMethod.phone,
                      onTap: () => _switchMethod(_LoginMethod.phone),
                    ),
                    _TabButton(
                      label: 'Email',
                      icon: Icons.email_outlined,
                      selected: _method == _LoginMethod.email,
                      onTap: () => _switchMethod(_LoginMethod.email),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Input field (animated swap) ───────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _method == _LoginMethod.phone
                    ? _PhoneInputRow(
                        controller: _phoneController,
                        selectedCountry: _selectedCountry,
                        countries: _countries,
                        onCountryChanged: (c) =>
                            setState(() => _selectedCountry = c),
                        onSubmitted: (_) => _sendOtp(),
                      )
                    : TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _sendOtp(),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 16),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              // ── Delivery hint ─────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    _method == _LoginMethod.phone
                        ? Icons.sms_outlined
                        : Icons.mail_outline,
                    size: 14,
                    color: AppTheme.accent.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _method == _LoginMethod.phone
                        ? 'OTP will be sent via SMS'
                        : 'OTP will be sent to your inbox',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accent.withOpacity(0.7),
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Send OTP Button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _sendOtp,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.textPrimary),
                        )
                      : Icon(
                          _method == _LoginMethod.phone
                              ? Icons.sms_outlined
                              : Icons.send_outlined,
                          size: 20,
                        ),
                  label: Text(_loading ? 'Sending…' : 'Send OTP'),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Text(
                  'By continuing you agree to our Terms of Service',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Biometric login (only shown when available & enabled) ─
              if (_biometricAvailable && _biometricEnabled) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF2a2e4a))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF2a2e4a))),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _biometricLoading ? null : _loginWithBiometric,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _biometricLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accent),
                          )
                        : const Icon(Icons.fingerprint, size: 22),
                    label: Text(
                      _biometricLoading ? 'Authenticating…' : 'Login with Biometric',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone input: country-code picker + number field
// ---------------------------------------------------------------------------
class _PhoneInputRow extends StatelessWidget {
  final TextEditingController controller;
  final _Country selectedCountry;
  final List<_Country> countries;
  final ValueChanged<_Country> onCountryChanged;
  final ValueChanged<String> onSubmitted;

  const _PhoneInputRow({
    required this.controller,
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
    required this.onSubmitted,
  });

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: const Color(0xFF1a1e3a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: countries.length,
        itemBuilder: (_, i) {
          final c = countries[i];
          return ListTile(
            leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
            title: Text(
              c.name,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            trailing: Text(
              c.code,
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => Navigator.pop(context, c),
          );
        },
      ),
    );
    if (picked != null) onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Country code button ──────────────────────────────────────
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedCountry.flag,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 6),
                Text(
                  selectedCountry.code,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── Phone number input ───────────────────────────────────────
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmitted,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
            ),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '9987671916',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal tab button widget
// ---------------------------------------------------------------------------
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: AppTheme.accent, width: 1.5)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

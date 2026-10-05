import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/google_auth_service.dart';
import '../auth_provider.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

// ── Country codes ─────────────────────────────────────────────────────────────

class _Country {
  final String name;
  final String code;
  final String flag;
  const _Country(this.name, this.code, this.flag);
}

const _countries = [
  _Country('India',        '+91',  '🇮🇳'),
  _Country('USA',          '+1',   '🇺🇸'),
  _Country('UK',           '+44',  '🇬🇧'),
  _Country('UAE',          '+971', '🇦🇪'),
  _Country('Australia',    '+61',  '🇦🇺'),
  _Country('Canada',       '+1',   '🇨🇦'),
  _Country('Singapore',    '+65',  '🇸🇬'),
  _Country('Germany',      '+49',  '🇩🇪'),
  _Country('Saudi Arabia', '+966', '🇸🇦'),
  _Country('Nepal',        '+977', '🇳🇵'),
  _Country('Bangladesh',   '+880', '🇧🇩'),
  _Country('Sri Lanka',    '+94',  '🇱🇰'),
  _Country('Malaysia',     '+60',  '🇲🇾'),
];

// ── Input tabs ────────────────────────────────────────────────────────────────

enum _InputMode { phone, email }

// ── PhoneScreen ───────────────────────────────────────────────────────────────

class PhoneScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled identifier (email or phone). Used when the user is
  /// redirected here from the register screen after hitting a 409 conflict.
  final String? initialIdentifier;

  const PhoneScreen({super.key, this.initialIdentifier});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  _InputMode _mode            = _InputMode.phone;
  _Country   _selectedCountry = _countries.first;
  bool       _isBioAvailable  = false;
  bool       _checking        = false;
  String?    _errorMsg;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _checkBiometrics();
    _prefillIdentifier(widget.initialIdentifier);
  }

  /// If the caller passed an email/phone (e.g. from "Sign in instead" on
  /// the register screen), drop it into the right field and switch input mode.
  void _prefillIdentifier(String? value) {
    if (value == null || value.isEmpty) return;
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      _mode = _InputMode.email;
      _emailCtrl.text = trimmed.toLowerCase();
      return;
    }
    _mode = _InputMode.phone;
    // Strip leading country code if present so the phone box shows only the digits.
    final match = RegExp(r'^(\+\d{1,4})(.+)$').firstMatch(trimmed);
    if (match != null) {
      final code = match.group(1)!;
      final digits = match.group(2)!;
      final country = _countries.firstWhere(
        (c) => c.code == code,
        orElse: () => _selectedCountry,
      );
      _selectedCountry = country;
      _phoneCtrl.text = digits;
    } else {
      _phoneCtrl.text = trimmed;
    }
  }

  Future<void> _checkBiometrics() async {
    final avail = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _isBioAvailable = avail && enabled);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Login flow ──────────────────────────────────────────────────────────

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() { _checking = true; _errorMsg = null; });

    final identifier = _mode == _InputMode.phone
        ? '${_selectedCountry.code}${_phoneCtrl.text.trim()}'
        : _emailCtrl.text.trim().toLowerCase();

    try {
      // Check if user is registered
      final check = await ref.read(authProvider.notifier).checkUserExists(identifier);
      if (!check.exists) {
        setState(() {
          _checking = false;
          _errorMsg = 'No account found for this ${_mode == _InputMode.email ? "email" : "number"}. Please register first.';
        });
        return;
      }

      // Send OTP (backend sends to both email + phone if user has both)
      await ref.read(authProvider.notifier).sendOtp(identifier);

      if (mounted) {
        context.push('/otp', extra: {
          'identifier':  identifier,
          'maskedPhone': _mode == _InputMode.phone ? _maskPhone(identifier) : null,
          'maskedEmail': _mode == _InputMode.email ? _maskEmail(identifier) : null,
          'isRegister':  false,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _errorMsg = ref.read(authProvider).error ?? 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _maskPhone(String p) {
    if (p.length <= 6) return p;
    return '${p.substring(0, 3)}*****${p.substring(p.length - 3)}';
  }

  String _maskEmail(String e) {
    final parts = e.split('@');
    if (parts.length != 2) return e;
    final local = parts[0];
    if (local.length <= 2) return '${local[0]}*@${parts[1]}';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@${parts[1]}';
  }

  // ── Biometric login ─────────────────────────────────────────────────────

  Future<void> _biometricLogin() async {
    try {
      await BiometricService.authenticateAndLogin(ref);
      if (mounted && ref.read(authProvider).isAuthenticated) {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
      }
    }
  }

  // ── Google login ────────────────────────────────────────────────────────

  Future<void> _googleLogin() async {
    if (!kGoogleAuthEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In is not set up in this build.')),
      );
      return;
    }
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final accent = AppTheme.accentOf(context);
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isLoading = auth.isLoading || _checking;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Back
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
                  const SizedBox(height: 28),

                  // Title
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.lock_open_rounded, color: accent, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome Back',
                            style: TextStyle(
                              color: onSurf,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Login to your account',
                            style: TextStyle(
                              color: onSurf.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // ── Input mode tabs ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        _modeTab(_InputMode.phone, Icons.phone_rounded, 'Phone', accent),
                        _modeTab(_InputMode.email, Icons.email_rounded,  AppLocalizations.of(context).emailTab, accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Phone input ─────────────────────────────────────
                  if (_mode == _InputMode.phone) ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _showCountryPicker,
                          child: Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).inputDecorationTheme.fillColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 4),
                                Text(_selectedCountry.code,
                                  style: TextStyle(color: onSurf, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_drop_down, size: 18, color: onSurf.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(color: onSurf, fontSize: 15),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).mobileNumber,
                              prefixIcon: Icon(Icons.phone_rounded, color: accent, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your mobile number';
                              if (v.trim().length < 7) return 'Enter a valid number';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Email input ─────────────────────────────────────
                  if (_mode == _InputMode.email) ...[
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: onSurf, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_rounded, color: accent, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your email address';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                  ],

                  // ── Error message ───────────────────────────────────
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Continue button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _continue,
                      child: isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(AppLocalizations.of(context).sendOtp),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Divider ─────────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: onSurf.withValues(alpha: 0.15))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: onSurf.withValues(alpha: 0.4), fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: onSurf.withValues(alpha: 0.15))),
                  ]),
                  const SizedBox(height: 20),

                  // ── Alternative login buttons ───────────────────────
                  if (_isBioAvailable)
                    _altButton(
                      onTap:  _biometricLogin,
                      icon:   Icons.fingerprint_rounded,
                      label:  AppLocalizations.of(context).loginWithBiometric,
                      color:  AppTheme.success,
                    ),
                  if (_isBioAvailable) const SizedBox(height: 12),
                  _altButton(
                    onTap:  _googleLogin,
                    icon:   Icons.g_mobiledata_rounded,
                    label:  kGoogleAuthEnabled ? 'Continue with Google' : 'Google Sign-In (Setup Required)',
                    color:  accent,
                  ),

                  const SizedBox(height: 32),

                  // ── Register link ───────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/register'),
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: onSurf.withValues(alpha: 0.6), fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'Register',
                              style: TextStyle(
                                color: accent, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
      ),
    );
  }

  // ── Mode tab ────────────────────────────────────────────────────────────

  Widget _modeTab(_InputMode mode, IconData icon, String label, Color accent) {
    final isActive = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mode     = mode;
          _errorMsg = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        isActive ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(label,
                style: TextStyle(
                  color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Country picker ──────────────────────────────────────────────────────

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
            title: Text(c.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
            trailing: Text(c.code,
              style: TextStyle(color: AppTheme.accentOf(context), fontWeight: FontWeight.w600)),
            onTap: () { setState(() => _selectedCountry = c); Navigator.pop(ctx); },
          );
        },
      ),
    );
  }

  // ── Alt login button ────────────────────────────────────────────────────

  Widget _altButton({
    required VoidCallback onTap,
    required IconData     icon,
    required String       label,
    required Color        color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, color: color, size: 20),
        label: Text(label,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

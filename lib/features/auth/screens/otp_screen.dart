import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth_provider.dart';
import '../../../core/theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/biometric_service.dart';

class OtpScreen extends ConsumerStatefulWidget {
  /// The phone number or email address the OTP was sent to.
  final String phone; // keep param name 'phone' for router compatibility

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;

  // Identify whether login is via email or phone
  bool get _isEmail => widget.phone.contains('@');
  String get _identifier => widget.phone;

  /// Nicely masked display label
  String get _maskedIdentifier {
    if (_isEmail) {
      final parts = _identifier.split('@');
      final local = parts[0];
      final domain = parts[1];
      if (local.length <= 2) return '${local[0]}*@$domain';
      return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
    } else {
      if (_identifier.length <= 4) return _identifier;
      return '${_identifier.substring(0, 3)}${'*' * (_identifier.length - 6)}${_identifier.substring(_identifier.length - 3)}';
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  // ---------------------------------------------------------------------------
  // Device info gathering
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _gatherDeviceInfo() async {
    try {
      if (!Platform.isAndroid) return null;

      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Build a stable device fingerprint from hardware identifiers
      final fingerprintSource = [
        androidInfo.brand ?? '',
        androidInfo.model ?? '',
        androidInfo.device ?? '',
        androidInfo.product ?? '',
        androidInfo.hardware ?? '',
        androidInfo.id ?? '',
      ].join('|');

      // SHA-256 of the fingerprint = device_token
      final deviceToken = sha256
          .convert(utf8.encode(fingerprintSource))
          .toString();

      final deviceName =
          '${androidInfo.brand ?? 'Unknown'} ${androidInfo.model ?? 'Device'}';
      final osVersion = androidInfo.version.release ?? 'unknown';

      return {
        'device_token': deviceToken,
        'device_name': deviceName,
        'platform': 'android',
        'os_version': osVersion,
        'app_version': '1.0.0',
      };
    } catch (e) {
      // Never let device-info gathering crash the login flow
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Verify OTP
  // ---------------------------------------------------------------------------

  Future<void> _verify() async {
    if (_otp.length != 6) {
      _showSnack('Please enter the complete 6-digit code.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      // Gather device info in parallel with the UI — non-blocking
      final deviceInfo = await _gatherDeviceInfo();

      await ref.read(authProvider.notifier).verifyOtp(
            _identifier,
            _otp,
            deviceInfo: deviceInfo,
          );

      if (!mounted) return;

      // ── Offer biometric enrollment if available but not yet enabled ────
      final biometricAvailable = await BiometricService.isAvailable();
      final biometricEnabled = await BiometricService.isEnabled();

      if (mounted && biometricAvailable && !biometricEnabled) {
        await _showBiometricEnrollmentSheet();
      } else {
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException ? e.friendlyMessage : 'Invalid OTP. Please try again.';
        _showSnack(msg, error: true);
        // Clear boxes on failure so user can retype
        for (final c in _controllers) c.clear();
        _focusNodes.first.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Biometric enrollment bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _showBiometricEnrollmentSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1a1e3a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.fingerprint, size: 52, color: AppTheme.accent),
              const SizedBox(height: 16),
              const Text(
                'Enable Biometric Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sign in faster next time using your fingerprint or face unlock — no OTP needed.',
                style: TextStyle(color: Color(0xFF8892b0), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  // Skip
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        if (mounted) context.go('/home');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Enable
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await BiometricService.setEnabled(true);
                        Navigator.of(sheetContext).pop();
                        if (mounted) context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint, size: 18),
                      label: const Text(
                        'Enable',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    // If bottom sheet was dismissed without action, navigate home
    if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        context.go('/home');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Resend OTP
  // ---------------------------------------------------------------------------

  Future<void> _resendOtp() async {
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).sendOtp(_identifier);
      if (mounted) {
        _showSnack(
          _isEmail
              ? 'New code sent to your inbox.'
              : 'New code sent via SMS.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          e is DioException ? e.friendlyMessage : 'Failed to resend OTP.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.errorColor : AppTheme.accent.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Verify Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Header icon ──────────────────────────────────────────
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined,
                    size: 36,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Enter verification code',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: _isEmail
                            ? 'We sent a 6-digit code to\n'
                            : 'We sent a 6-digit SMS to\n',
                      ),
                      TextSpan(
                        text: _maskedIdentifier,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── OTP boxes ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.accent, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        } else if (v.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        // Auto-submit when last digit entered
                        if (i == 5 && v.isNotEmpty) _verify();
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 36),

              // ── Verify button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _verify,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.textPrimary),
                        )
                      : const Icon(Icons.verified_outlined, size: 20),
                  label: Text(_loading ? 'Verifying…' : 'Verify Code'),
                ),
              ),

              const SizedBox(height: 20),

              // ── Resend ────────────────────────────────────────────────
              Center(
                child: _resending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _resendOtp,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Resend Code'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

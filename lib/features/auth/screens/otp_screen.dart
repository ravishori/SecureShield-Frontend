import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../auth_provider.dart';

// ── OtpScreen ─────────────────────────────────────────────────────────────────

class OtpScreen extends ConsumerStatefulWidget {
  /// The actual identifier that will be sent to /auth/verify-otp.
  final String  identifier;
  /// Whether this is a new account registration flow (vs login).
  final bool    isRegister;
  /// Masked display email — shown in the "sent to" message.
  final String? maskedEmail;
  /// Masked display phone — shown in the "sent to" message.
  final String? maskedPhone;

  const OtpScreen({
    super.key,
    required this.identifier,
    this.isRegister  = false,
    this.maskedEmail,
    this.maskedPhone,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  // 6 individual digit controllers + focus nodes
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  bool _verifying = false;
  bool _didShowSuccess = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Build OTP code from boxes ───────────────────────────────────────────

  String get _code => _controllers.map((c) => c.text).join();

  // ── Verify ──────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    final code = _code;
    if (code.length < 6) return;

    setState(() => _verifying = true);

    try {
      final deviceInfo = await _buildDeviceInfo();
      await ref.read(authProvider.notifier).verifyOtp(
        widget.identifier,
        code,
        deviceInfo: deviceInfo,
      );

      if (!mounted) return;

      final auth = ref.read(authProvider);
      if (auth.isAuthenticated) {
        if (widget.isRegister) {
          _showRegisterSuccessDialog();
        } else {
          _showLoginSuccessDialog();
        }
      }
    } catch (e) {
      setState(() => _verifying = false);
      if (mounted) {
        final msg = ref.read(authProvider).error ?? 'Invalid OTP. Please try again.';
        _showErrorSnack(msg);
        // Shake + clear boxes on error
        _clearBoxes();
      }
    }
  }

  void _navigateHome() {
    if (mounted) context.go('/home');
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  // ── Login success popup (auto-dismisses after 3 seconds) ──────────────────

  void _showLoginSuccessDialog() {
    if (_didShowSuccess) return;
    _didShowSuccess = true;
    ref.read(authProvider.notifier).clearLoginSuccess();

    final accent = AppTheme.accentOf(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AutoDismissSuccessDialog(
        icon: Icons.verified_rounded,
        iconColor: AppTheme.success,
        title: 'Login Successful!',
        message: 'Welcome back to SecureShield AI.\nYour account is protected.',
        badgeIcon: Icons.security_rounded,
        badgeLabel: 'Session secured with JWT',
        badgeColor: accent,
        buttonLabel: 'Go to Dashboard',
        onDismiss: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
          _navigateHome();
        },
      ),
    );
  }

  // ── Registration success popup (auto-dismisses after 3 seconds) ───────────

  void _showRegisterSuccessDialog() {
    if (_didShowSuccess) return;
    _didShowSuccess = true;

    final accent = AppTheme.accentOf(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AutoDismissSuccessDialog(
        icon: Icons.how_to_reg_rounded,
        iconColor: AppTheme.success,
        title: 'Account Created!',
        message: 'Welcome to SecureShield AI.\nYour account is verified and secured.',
        badgeIcon: Icons.shield_rounded,
        badgeLabel: 'Identity verified · JWT secured',
        badgeColor: accent,
        buttonLabel: 'Start Protecting',
        onDismiss: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
          _navigateHome();
        },
      ),
    );
  }

  // ── Resend OTP ──────────────────────────────────────────────────────────

  Future<void> _resend() async {
    _clearBoxes();
    try {
      await ref.read(authProvider.notifier).sendOtp(widget.identifier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP resent successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showErrorSnack('Failed to resend OTP. Please try again.');
    }
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Device info ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _buildDeviceInfo() async {
    if (!Platform.isAndroid) return null;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final fingerprint = sha256
          .convert(utf8.encode(
              '${info.id}|${info.model}|${info.brand}|${info.hardware}'))
          .toString();
      return {
        'device_token': fingerprint,
        'device_name': '${info.brand} ${info.model}',
        'platform': 'android',
        'os_version': 'Android ${info.version.release}',
        'app_version': '1.0.0',
      };
    } catch (_) {
      return null;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final accent = AppTheme.accentOf(context);
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isLoading = auth.isLoading || _verifying;

    // Determine display message for OTP channels
    final channels = _buildChannelText();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // Back
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
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
                ),
                const SizedBox(height: 36),

                // Lock icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Icon(
                    widget.isRegister ? Icons.how_to_reg_rounded : Icons.lock_rounded,
                    color: accent, size: 38,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  widget.isRegister ? 'Verify Your Account' : 'Enter OTP',
                  style: TextStyle(
                    color: onSurf,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Channel info
                _buildChannelInfo(channels, accent, onSurf),

                const SizedBox(height: 36),

                // ── OTP boxes ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) => _buildOtpBox(i, accent, onSurf)),
                ),

                const SizedBox(height: 32),

                // ── Verify button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_code.length == 6 && !isLoading) ? _verify : null,
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
                              Text(widget.isRegister ? 'Verify & Activate' : 'Verify OTP'),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Resend ──────────────────────────────────────────
                TextButton.icon(
                  onPressed: isLoading ? null : _resend,
                  icon: Icon(Icons.refresh_rounded, size: 16, color: accent),
                  label: Text(
                    'Resend OTP',
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 12),

                // OTP expiry note
                Text(
                  'OTP expires in 10 minutes',
                  style: TextStyle(
                    color: onSurf.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── OTP input box ───────────────────────────────────────────────────────

  Widget _buildOtpBox(int index, Color accent, Color onSurf) {
    return Container(
      width: 46, height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: _controllers[index].text.isNotEmpty
              ? accent
              : onSurf.withValues(alpha: 0.25),
          width: _controllers[index].text.isNotEmpty ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).inputDecorationTheme.fillColor,
      ),
      child: TextFormField(
        controller:       _controllers[index],
        focusNode:        _focusNodes[index],
        maxLength:        1,
        textAlign:        TextAlign.center,
        keyboardType:     TextInputType.number,
        inputFormatters:  [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          color:      onSurf,
          fontSize:   22,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
        onChanged: (v) {
          setState(() {});  // refresh border colour
          if (v.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (v.isNotEmpty && index == 5) {
            _focusNodes[index].unfocus();
            _verify();
          }
        },
        onEditingComplete: () {
          if (_controllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  // ── Channel display helpers ─────────────────────────────────────────────

  String _buildChannelText() {
    if (widget.maskedEmail != null && widget.maskedPhone != null) {
      return 'OTP sent to ${widget.maskedEmail} and ${widget.maskedPhone}';
    } else if (widget.maskedEmail != null) {
      return 'OTP sent to ${widget.maskedEmail}';
    } else if (widget.maskedPhone != null) {
      return 'OTP sent to ${widget.maskedPhone}';
    }
    // Fallback: mask the identifier
    final id = widget.identifier;
    if (id.contains('@')) {
      final parts = id.split('@');
      final local = parts[0];
      final masked = local.length <= 2
          ? '${local[0]}*@${parts[1]}'
          : '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@${parts[1]}';
      return 'OTP sent to $masked';
    } else {
      final masked = id.length <= 6 ? id
          : '${id.substring(0, 3)}*****${id.substring(id.length - 3)}';
      return 'OTP sent to $masked';
    }
  }

  Widget _buildChannelInfo(String text, Color accent, Color onSurf) {
    final hasDual = widget.maskedEmail != null && widget.maskedPhone != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (hasDual) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(widget.maskedEmail!,
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(widget.maskedPhone!,
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'OTP sent to both channels above',
              style: TextStyle(color: onSurf.withValues(alpha: 0.55), fontSize: 11),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.maskedEmail != null ? Icons.email_outlined : Icons.phone_outlined,
                  size: 14, color: accent,
                ),
                const SizedBox(width: 8),
                Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onSurf.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable auto-dismiss success dialog
// Shows a 3-second countdown in the button, then auto-navigates.
// ─────────────────────────────────────────────────────────────────────────────
class _AutoDismissSuccessDialog extends StatefulWidget {
  final IconData  icon;
  final Color     iconColor;
  final String    title;
  final String    message;
  final IconData  badgeIcon;
  final String    badgeLabel;
  final Color     badgeColor;
  final String    buttonLabel;
  final VoidCallback onDismiss;

  const _AutoDismissSuccessDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.badgeColor,
    required this.buttonLabel,
    required this.onDismiss,
  });

  @override
  State<_AutoDismissSuccessDialog> createState() => _AutoDismissSuccessDialogState();
}

class _AutoDismissSuccessDialogState extends State<_AutoDismissSuccessDialog> {
  static const _totalSeconds = 3;
  int _remaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: surface,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.iconColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(widget.icon, size: 42, color: widget.iconColor),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.title,
              style: TextStyle(color: onSurf, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurf.withValues(alpha: 0.6), fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: widget.badgeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.badgeColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.badgeIcon, size: 14, color: widget.badgeColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.badgeLabel,
                      style: TextStyle(color: widget.badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Countdown shrinking progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(seconds: _totalSeconds),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: widget.iconColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.iconColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  '${widget.buttonLabel} ($_remaining)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

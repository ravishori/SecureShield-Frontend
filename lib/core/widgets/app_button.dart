import 'package:flutter/material.dart';
import '../theme.dart';

/// Reusable primary elevated button with built-in loading state.
///
/// Usage:
/// ```dart
/// AppButton(
///   label: 'Send OTP',
///   icon: Icons.send_rounded,
///   loading: _loading,
///   onPressed: _submit,
/// )
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final String? loadingLabel;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.loading = false,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: backgroundColor != null
            ? ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor ?? Colors.white,
              )
            : null,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor ?? Colors.white,
                ),
              )
            : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
        label: Text(loading ? (loadingLabel ?? label) : label),
      ),
    );
  }
}

/// Outlined variant
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;
  final Color? color;

  const AppOutlinedButton({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accentOf(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c),
        ),
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: c),
              )
            : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
        label: Text(label),
      ),
    );
  }
}

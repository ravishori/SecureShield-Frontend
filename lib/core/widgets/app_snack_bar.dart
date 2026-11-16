import 'package:flutter/material.dart';
import '../theme.dart';

/// Consistent snack bar helper — call `AppSnackBar.show(context, ...)`.
abstract class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    bool error = false,
    bool success = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    final color = error
        ? AppTheme.errorColor
        : success
            ? AppTheme.success
            : AppTheme.accentOf(context).withValues(alpha: 0.85);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  static void error(BuildContext context, String message) =>
      show(context, message, error: true);

  static void success(BuildContext context, String message) =>
      show(context, message, success: true);
}

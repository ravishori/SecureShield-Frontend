/// Backward compatibility layer for old AppTheme static API
///
/// This file provides static accessors for the dark theme colors
/// to maintain compatibility with existing code that hasn't been migrated yet.
///
/// For new code, use the new theme system:
/// - AppThemeType enum for theme selection
/// - AppTheme.getTheme() for ThemeData
/// - context.accentColor for color access

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme_enum.dart';

/// Backward compatibility class - static accessors for dark theme
///
/// **DEPRECATED**: Use `AppThemeType.dark.palette` or context extensions instead
class AppTheme {
  // ──────────────────────────────────────────────────────────────────────────
  // DARK THEME COLORS (for backward compatibility)
  // ──────────────────────────────────────────────────────────────────────────

  /// Get the dark theme palette (backward compatible)
  static ColorPalette get darkPalette => AppColors.darkPalette;

  // Brand colors
  static Color get primary => AppColors.darkPalette.primary;
  static Color get secondary => AppColors.darkPalette.secondary;
  static Color get accent => AppColors.darkPalette.accent;

  // Layout colors
  static Color get background => AppColors.darkPalette.background;
  static Color get surface => AppColors.darkPalette.surface;
  static Color get cardColor => AppColors.darkPalette.card;
  static Color get overlay => AppColors.darkPalette.overlay;

  // Text colors
  static Color get textPrimary => AppColors.darkPalette.textPrimary;
  static Color get textSecondary => AppColors.darkPalette.textSecondary;
  static Color get textTertiary => AppColors.darkPalette.textTertiary;

  // Status colors
  static Color get threat => AppColors.darkPalette.threat;
  static Color get safe => AppColors.darkPalette.safe;
  static Color get warning => AppColors.darkPalette.warning;
  static Color get emergency => AppColors.darkPalette.emergency;
  static Color get errorColor => AppColors.darkPalette.threat; // Alias
  static Color get success => AppColors.darkPalette.safe; // Alias

  // Feature colors
  static Color get cyan => AppColors.darkPalette.cyan;
  static Color get red => AppColors.darkPalette.red;
  static Color get orange => AppColors.darkPalette.orange;
  static Color get green => AppColors.darkPalette.green;
  static Color get purple => AppColors.darkPalette.purple;
  static Color get lightPurple => AppColors.darkPalette.lightPurple;
  static Color get lightCyan => AppColors.darkPalette.lightCyan;

  // Borders
  static Color get borderColor => AppColors.darkPalette.borderColor;
  static Color get dividerColor => AppColors.darkPalette.dividerColor;
  static Color get disabledColor => AppColors.darkPalette.disabledColor;
  static Color get shadowColor => AppColors.darkPalette.shadowColor;

  // ──────────────────────────────────────────────────────────────────────────
  // SEMANTIC COLOR HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get risk color based on risk level
  static Color riskColor(String riskLevel) {
    return switch (riskLevel.toLowerCase()) {
      'critical' => AppColors.darkPalette.threat,
      'high' => AppColors.darkPalette.warning,
      'medium' => AppColors.darkPalette.orange,
      'low' => AppColors.darkPalette.safe,
      'safe' => AppColors.darkPalette.safe,
      _ => AppColors.darkPalette.textSecondary,
    };
  }

  /// Get threat color (red)
  static Color threatColor() => AppColors.darkPalette.threat;

  /// Get safe color (green)
  static Color safeColor() => AppColors.darkPalette.safe;

  /// Get warning color (yellow/orange)
  static Color warningColor() => AppColors.darkPalette.warning;

  /// Get emergency color (bright red)
  static Color emergencyColor() => AppColors.darkPalette.emergency;

  /// Get severity color based on severity level
  static Color severityColor(String severity) {
    return switch (severity.toLowerCase()) {
      'info' => AppColors.darkPalette.cyan,
      'warning' => AppColors.darkPalette.warning,
      'critical' => AppColors.darkPalette.threat,
      _ => AppColors.darkPalette.textSecondary,
    };
  }
}

/// Extension on BuildContext for backward compatible color access
extension AppThemeContextCompat on BuildContext {
  Color get appPrimary => AppTheme.primary;
  Color get appAccent => AppTheme.accent;
  Color get appBackground => AppTheme.background;
  Color get appSurface => AppTheme.surface;
  Color get appTextPrimary => AppTheme.textPrimary;
  Color get appWarning => AppTheme.warning;
  Color get appSuccess => AppTheme.success;
  Color get appError => AppTheme.errorColor;
}

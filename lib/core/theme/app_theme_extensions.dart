/// Theme extensions for accessibility settings and semantic color tokens
///
/// Provides:
/// - ThemeAccessibility: Font sizes, contrast ratios, and UI element sizing per theme
/// - Extensions to map theme types to accessibility configurations
/// - Semantic color getters that map theme-agnostic tokens to actual colors
library;

import 'package:flutter/material.dart';
import 'app_theme_enum.dart';
import 'app_colors.dart';

// ──────────────────────────────────────────────────────────────────────────
// ACCESSIBILITY CONFIGURATION CLASS
// ──────────────────────────────────────────────────────────────────────────

/// Accessibility settings for a theme
///
/// Configures font sizes, contrast ratios, and UI element sizing
/// to support different user groups (general, elderly, high contrast).
class ThemeAccessibility {
  /// Base font size for body text
  final double baseFontSize;

  /// Headline/title font size
  final double headlineFontSize;

  /// Button text and label font size
  final double buttonFontSize;

  /// Minimum contrast ratio (4.5 = WCAG AA, 7.0 = WCAG AAA)
  final double contrastRatio;

  /// Border/outline width for UI elements
  final double outlineWidth;

  /// Button padding for touch targets
  final EdgeInsets buttonPadding;

  /// Minimum button size (accessibility requirement: 48x48)
  final Size buttonMinSize;

  const ThemeAccessibility({
    this.baseFontSize = 14.0,
    this.headlineFontSize = 24.0,
    this.buttonFontSize = 14.0,
    this.contrastRatio = 4.5, // WCAG AA
    this.outlineWidth = 1.0,
    this.buttonPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.buttonMinSize = const Size(48, 48),
  });

  /// Standard accessibility (default for general users)
  static const ThemeAccessibility standard = ThemeAccessibility(
    baseFontSize: 14.0,
    headlineFontSize: 24.0,
    buttonFontSize: 14.0,
    contrastRatio: 4.5, // WCAG AA
    outlineWidth: 1.0,
    buttonPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    buttonMinSize: Size(48, 48),
  );

  /// Senior citizen accessibility (enlarged text, higher contrast)
  static const ThemeAccessibility senior = ThemeAccessibility(
    baseFontSize: 18.0, // 28% larger
    headlineFontSize: 32.0, // 33% larger
    buttonFontSize: 16.0,
    contrastRatio: 7.0, // WCAG AAA (stricter)
    outlineWidth: 2.0, // Thicker borders
    buttonPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    buttonMinSize: Size(56, 56), // Larger touch targets
  );

  /// High contrast accessibility (better distinction, maximum contrast)
  static const ThemeAccessibility highContrast = ThemeAccessibility(
    baseFontSize: 16.0,
    headlineFontSize: 28.0,
    buttonFontSize: 14.0,
    contrastRatio: 7.0, // WCAG AAA
    outlineWidth: 1.5,
    buttonPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    buttonMinSize: Size(52, 52),
  );

  /// Light theme accessibility (standard for light backgrounds)
  static const ThemeAccessibility light = ThemeAccessibility(
    baseFontSize: 14.0,
    headlineFontSize: 24.0,
    buttonFontSize: 14.0,
    contrastRatio: 4.5,
    outlineWidth: 1.0,
    buttonPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    buttonMinSize: Size(48, 48),
  );

  /// Copyable version for modifications
  ThemeAccessibility copyWith({
    double? baseFontSize,
    double? headlineFontSize,
    double? buttonFontSize,
    double? contrastRatio,
    double? outlineWidth,
    EdgeInsets? buttonPadding,
    Size? buttonMinSize,
  }) {
    return ThemeAccessibility(
      baseFontSize: baseFontSize ?? this.baseFontSize,
      headlineFontSize: headlineFontSize ?? this.headlineFontSize,
      buttonFontSize: buttonFontSize ?? this.buttonFontSize,
      contrastRatio: contrastRatio ?? this.contrastRatio,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      buttonPadding: buttonPadding ?? this.buttonPadding,
      buttonMinSize: buttonMinSize ?? this.buttonMinSize,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// THEME CONFIGURATION EXTENSIONS
// ──────────────────────────────────────────────────────────────────────────

/// Baseline accessibility per theme. NOTE: the *user-facing* Accessibility
/// Mode toggle is orthogonal to this — see `accessibilityModeProvider` in
/// `theme_provider.dart`. This getter only returns the built-in baseline
/// each theme was designed for.
extension ThemeAccessibilityConfig on AppThemeType {
  ThemeAccessibility get accessibility => switch (this) {
        AppThemeType.defenderBlue      => ThemeAccessibility.standard,
        AppThemeType.enterpriseDark    => ThemeAccessibility.standard,
        AppThemeType.midnightSecurity  => ThemeAccessibility.standard,
        AppThemeType.bankingSecure     => ThemeAccessibility.standard,
        AppThemeType.cyberIntelligence => ThemeAccessibility.standard,
        AppThemeType.corporateLight    => ThemeAccessibility.light,
        AppThemeType.highContrast      => ThemeAccessibility.highContrast,
      };

  ColorPalette get palette => switch (this) {
        AppThemeType.defenderBlue      => AppColors.defenderBluePalette,
        AppThemeType.enterpriseDark    => AppColors.enterpriseDarkPalette,
        AppThemeType.midnightSecurity  => AppColors.midnightSecurityPalette,
        AppThemeType.bankingSecure     => AppColors.bankingSecurePalette,
        AppThemeType.cyberIntelligence => AppColors.cyberIntelligencePalette,
        AppThemeType.corporateLight    => AppColors.corporateLightPalette,
        AppThemeType.highContrast      => AppColors.highContrastPalette,
      };

  String get display => displayName;
  String get icon    => emoji;
}

// ──────────────────────────────────────────────────────────────────────────
// SEMANTIC COLOR GETTERS
// ──────────────────────────────────────────────────────────────────────────

/// Semantic colors mapped by theme
extension SemanticColorsByTheme on AppThemeType {
  /// Color indicating a threat or critical issue
  Color threatColor() => palette.threat;

  /// Color indicating safe or secure state
  Color safeColor() => palette.safe;

  /// Color indicating a warning or caution
  Color warningColor() => palette.warning;

  /// Color indicating an emergency or immediate action needed
  Color emergencyColor() => palette.emergency;

  /// Color for informational content
  Color infoColor() => palette.accent;

  /// Color for success state
  Color successColor() => palette.safe;

  /// Color for error state
  Color errorColor() => palette.threat;

  /// Color for disabled/inactive elements
  Color disabledColor() => palette.disabledColor;

  /// Get all status colors as a map
  Map<String, Color> get statusColors => {
        'threat': threatColor(),
        'safe': safeColor(),
        'warning': warningColor(),
        'emergency': emergencyColor(),
        'info': infoColor(),
        'success': successColor(),
        'error': errorColor(),
        'disabled': disabledColor(),
      };
}

// ──────────────────────────────────────────────────────────────────────────
// COLOR PALETTE ABSTRACTION (re-export from app_colors.dart for convenience)
// ──────────────────────────────────────────────────────────────────────────

/// Base class for all color palettes (same as in app_colors.dart)
// ignore: unused_element
abstract class _ColorPalette {
  Color get primary;
  Color get secondary;
  Color get accent;
  Color get background;
  Color get surface;
  Color get card;
  Color get overlay;
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get threat;
  Color get safe;
  Color get warning;
  Color get emergency;
  Color get cyan;
  Color get red;
  Color get orange;
  Color get green;
  Color get purple;
  Color get lightPurple;
  Color get lightCyan;
  Color get borderColor;
  Color get dividerColor;
  Color get disabledColor;
  Color get shadowColor;
}

// ──────────────────────────────────────────────────────────────────────────
// CONVENIENT GETTERS FOR CONTEXT
// ──────────────────────────────────────────────────────────────────────────

/// Extensions on BuildContext for easy theme access
extension ThemeContextExtension on BuildContext {
  /// Get the current theme's TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get the current theme's ColorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get the current theme's accent color
  Color get accentColor => Theme.of(this).colorScheme.secondary;

  /// Get the current theme's primary color
  Color get primaryColor => Theme.of(this).colorScheme.primary;

  /// Get the current theme's error color
  Color get errorColor => Theme.of(this).colorScheme.error;

  /// Get the current theme's surface color
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
}

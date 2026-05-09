/// Comprehensive color palettes for all 5 themes
///
/// Each theme has its own color palette with semantic naming:
/// - Primary/Secondary: Brand colors
/// - Background/Surface/Card: Layout colors
/// - Text colors: Hierarchy (Primary, Secondary, Tertiary)
/// - Status colors: Threat, Safe, Warning, Emergency
/// - Feature colors: Category-specific colors
library;

import 'package:flutter/material.dart';

/// Central color repository for all 5 themes
class AppColors {
  // ──────────────────────────────────────────────────────────────────────────
  // THEME PALETTES
  // ──────────────────────────────────────────────────────────────────────────

  /// Light theme palette - Professional, accessible
  static const ColorPalette lightPalette = _LightPalette();

  /// Dark theme palette - Default dark mode with cyan accent
  static const ColorPalette darkPalette = _DarkPalette();

  /// Cybersecurity theme palette - Security-focused with neon colors
  static const ColorPalette cybersecurityPalette = _CybersecurityPalette();

  /// Senior citizen theme palette - High contrast, simplified
  static const ColorPalette seniorCitizenPalette = _SeniorCitizenPalette();

  /// Nature green theme palette - Calming, outdoor-inspired
  static const ColorPalette natureGreenPalette = _NatureGreenPalette();

  // ──────────────────────────────────────────────────────────────────────────
  // SEMANTIC COLOR TOKENS (theme-agnostic)
  // ──────────────────────────────────────────────────────────────────────────

  static const String threatColorToken = 'threat';
  static const String safeColorToken = 'safe';
  static const String warningColorToken = 'warning';
  static const String emergencyColorToken = 'emergency';

  // ──────────────────────────────────────────────────────────────────────────
  // HELPER METHOD TO GET PALETTE BY THEME
  // ──────────────────────────────────────────────────────────────────────────

  static ColorPalette getPalette(String themeType) {
    return switch (themeType) {
      'light' => lightPalette,
      'dark' => darkPalette,
      'cybersecurity' => cybersecurityPalette,
      'seniorCitizen' => seniorCitizenPalette,
      'natureGreen' => natureGreenPalette,
      _ => darkPalette, // Default to dark
    };
  }
}

// ──────────────────────────────────────────────────────────────────────────
// ABSTRACT BASE PALETTE CLASS
// ──────────────────────────────────────────────────────────────────────────

/// Base class for all color palettes
abstract class ColorPalette {
  /// Const constructor to allow subclasses to be const
  const ColorPalette();

  // Brand colors
  Color get primary;
  Color get secondary;
  Color get accent;

  // Layout colors
  Color get background;
  Color get surface;
  Color get card;
  Color get overlay;

  // Text colors (hierarchy)
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;

  // Status colors
  Color get threat;      // Red - dangerous/critical
  Color get safe;        // Green - secure/good
  Color get warning;     // Yellow/Orange - caution
  Color get emergency;   // Bright red - immediate action needed

  // Feature colors (category indicators)
  Color get cyan;
  Color get red;
  Color get orange;
  Color get green;
  Color get purple;
  Color get lightPurple;
  Color get lightCyan;

  // Borders & Dividers
  Color get borderColor;
  Color get dividerColor;

  // Additional utilities
  Color get disabledColor;
  Color get shadowColor;
}

// ──────────────────────────────────────────────────────────────────────────
// LIGHT THEME PALETTE
// ──────────────────────────────────────────────────────────────────────────

class _LightPalette extends ColorPalette {
  const _LightPalette();

  @override
  Color get primary => const Color(0xFF1A237E); // Dark navy
  @override
  Color get secondary => const Color(0xFF283593); // Indigo
  @override
  Color get accent => const Color(0xFF0066CC); // Professional blue

  @override
  Color get background => const Color(0xFFF5F7FF); // Light lavender
  @override
  Color get surface => const Color(0xFFFFFFFF); // Pure white
  @override
  Color get card => const Color(0xFFEEF2FF); // Soft lavender
  @override
  Color get overlay => Colors.black12;

  @override
  Color get textPrimary => const Color(0xFF0D1B3E); // Dark navy text
  @override
  Color get textSecondary => const Color(0xFF5C6B8A); // Medium gray
  @override
  Color get textTertiary => const Color(0xFF8B95A7); // Light gray

  @override
  Color get threat => const Color(0xFFD32F2F); // Deep red
  @override
  Color get safe => const Color(0xFF388E3C); // Deep green
  @override
  Color get warning => const Color(0xFFF57C00); // Deep orange
  @override
  Color get emergency => const Color(0xFFC62828); // Crimson red

  @override
  Color get cyan => const Color(0xFF0097A7);
  @override
  Color get red => const Color(0xFFD32F2F);
  @override
  Color get orange => const Color(0xFFF57C00);
  @override
  Color get green => const Color(0xFF388E3C);
  @override
  Color get purple => const Color(0xFF512DA8);
  @override
  Color get lightPurple => const Color(0xFF7E57C2);
  @override
  Color get lightCyan => const Color(0xFF00ACC1);

  @override
  Color get borderColor => const Color(0xFFE0E0E0);
  @override
  Color get dividerColor => const Color(0xFFEEEEEE);
  @override
  Color get disabledColor => const Color(0xFFBDBDBD);
  @override
  Color get shadowColor => Colors.black12;
}

// ──────────────────────────────────────────────────────────────────────────
// DARK THEME PALETTE (Original)
// ──────────────────────────────────────────────────────────────────────────

class _DarkPalette extends ColorPalette {
  const _DarkPalette();

  @override
  Color get primary => const Color(0xFF1A2040); // Dark navy blue
  @override
  Color get secondary => const Color(0xFF2D3E5F); // Slate blue
  @override
  Color get accent => const Color(0xFF00E5FF); // Cyan

  @override
  Color get background => const Color(0xFF0A0E27); // Very dark navy
  @override
  Color get surface => const Color(0xFF12172E); // Dark blue
  @override
  Color get card => const Color(0xFF1A2040); // Card blue
  @override
  Color get overlay => Colors.black54;

  @override
  Color get textPrimary => const Color(0xFFFFFFFF); // White
  @override
  Color get textSecondary => const Color(0xFF90A4AE); // Light gray
  @override
  Color get textTertiary => const Color(0xFF607D8B); // Medium gray

  @override
  Color get threat => const Color(0xFFFF1744); // Bright red
  @override
  Color get safe => const Color(0xFF00C853); // Bright green
  @override
  Color get warning => const Color(0xFFFFC400); // Bright amber
  @override
  Color get emergency => const Color(0xFFFF3D00); // Bright orange-red

  @override
  Color get cyan => const Color(0xFF00E5FF);
  @override
  Color get red => const Color(0xFFFF5252);
  @override
  Color get orange => const Color(0xFFFF9800);
  @override
  Color get green => const Color(0xFF4CAF50);
  @override
  Color get purple => const Color(0xFF7C4DFF);
  @override
  Color get lightPurple => const Color(0xFF9C27B0);
  @override
  Color get lightCyan => const Color(0xFF00BCD4);

  @override
  Color get borderColor => const Color(0xFF2A3560);
  @override
  Color get dividerColor => const Color(0xFF1E2B47);
  @override
  Color get disabledColor => const Color(0xFF37474F);
  @override
  Color get shadowColor => Colors.black26;
}

// ──────────────────────────────────────────────────────────────────────────
// CYBERSECURITY THEME PALETTE
// ──────────────────────────────────────────────────────────────────────────

class _CybersecurityPalette extends ColorPalette {
  const _CybersecurityPalette();

  @override
  Color get primary => const Color(0xFF0A0E27); // Very dark
  @override
  Color get secondary => const Color(0xFF1A2040); // Dark navy
  @override
  Color get accent => const Color(0xFF00FF00); // Neon green for "secure"

  @override
  Color get background => const Color(0xFF0A0E27); // Very dark
  @override
  Color get surface => const Color(0xFF12172E); // Dark blue
  @override
  Color get card => const Color(0xFF1A2040); // Card blue
  @override
  Color get overlay => Colors.black87;

  @override
  Color get textPrimary => const Color(0xFFFFFFFF); // White
  @override
  Color get textSecondary => const Color(0xFF00E5FF); // Cyan
  @override
  Color get textTertiary => const Color(0xFF90A4AE); // Light gray

  @override
  Color get threat => const Color(0xFFFF0000); // Pure red for maximum alert
  @override
  Color get safe => const Color(0xFF00FF00); // Neon green
  @override
  Color get warning => const Color(0xFFFFFF00); // Neon yellow
  @override
  Color get emergency => const Color(0xFFFF0000); // Pure red

  @override
  Color get cyan => const Color(0xFF00E5FF);
  @override
  Color get red => const Color(0xFFFF0000);
  @override
  Color get orange => const Color(0xFFFFAA00);
  @override
  Color get green => const Color(0xFF00FF00);
  @override
  Color get purple => const Color(0xFF9C27B0);
  @override
  Color get lightPurple => const Color(0xFFB39DDB);
  @override
  Color get lightCyan => const Color(0xFF00E5FF);

  @override
  Color get borderColor => const Color(0xFF00E5FF);
  @override
  Color get dividerColor => const Color(0xFF1E2B47);
  @override
  Color get disabledColor => const Color(0xFF37474F);
  @override
  Color get shadowColor => const Color(0xFF00FF00).withOpacity(0.1);
}

// ──────────────────────────────────────────────────────────────────────────
// SENIOR CITIZEN THEME PALETTE
// ──────────────────────────────────────────────────────────────────────────

class _SeniorCitizenPalette extends ColorPalette {
  const _SeniorCitizenPalette();

  @override
  Color get primary => const Color(0xFF0D47A1); // Deep blue
  @override
  Color get secondary => const Color(0xFF1565C0); // Bright blue
  @override
  Color get accent => const Color(0xFF0066CC); // Saturated blue

  @override
  Color get background => const Color(0xFFF5F5F5); // Soft white (not pure)
  @override
  Color get surface => const Color(0xFFFFFFFF); // Pure white
  @override
  Color get card => const Color(0xFFEBEBEB); // Very light gray
  @override
  Color get overlay => Colors.black12;

  @override
  Color get textPrimary => const Color(0xFF1A1A1A); // Very dark (high contrast)
  @override
  Color get textSecondary => const Color(0xFF424242); // Dark gray
  @override
  Color get textTertiary => const Color(0xFF616161); // Medium gray

  @override
  Color get threat => const Color(0xFFC62828); // Deep red
  @override
  Color get safe => const Color(0xFF2E7D32); // Deep green
  @override
  Color get warning => const Color(0xFFE65100); // Deep orange
  @override
  Color get emergency => const Color(0xFFB71C1C); // Very deep red

  @override
  Color get cyan => const Color(0xFF00838F);
  @override
  Color get red => const Color(0xFFD32F2F);
  @override
  Color get orange => const Color(0xFFF57C00);
  @override
  Color get green => const Color(0xFF388E3C);
  @override
  Color get purple => const Color(0xFF512DA8);
  @override
  Color get lightPurple => const Color(0xFF6A1B9A);
  @override
  Color get lightCyan => const Color(0xFF00838F);

  @override
  Color get borderColor => const Color(0xFFBDBDBD); // Thick borders
  @override
  Color get dividerColor => const Color(0xFFE0E0E0);
  @override
  Color get disabledColor => const Color(0xFF9E9E9E);
  @override
  Color get shadowColor => Colors.black12;
}

// ──────────────────────────────────────────────────────────────────────────
// NATURE GREEN THEME PALETTE
// ──────────────────────────────────────────────────────────────────────────

class _NatureGreenPalette extends ColorPalette {
  const _NatureGreenPalette();

  @override
  Color get primary => const Color(0xFF2D5016); // Dark forest green
  @override
  Color get secondary => const Color(0xFF33691E); // Medium forest green
  @override
  Color get accent => const Color(0xFF4CAF50); // Natural green

  @override
  Color get background => const Color(0xFFF1F8E9); // Light nature white
  @override
  Color get surface => const Color(0xFFFAFAFA); // Off-white
  @override
  Color get card => const Color(0xFFE8F5E9); // Very light green
  @override
  Color get overlay => Colors.black12;

  @override
  Color get textPrimary => const Color(0xFF1B5E20); // Dark green text
  @override
  Color get textSecondary => const Color(0xFF558B2F); // Medium green
  @override
  Color get textTertiary => const Color(0xFF7CB342); // Light green

  @override
  Color get threat => const Color(0xFFE57373); // Muted red
  @override
  Color get safe => const Color(0xFF4CAF50); // Natural green
  @override
  Color get warning => const Color(0xFFFFCA28); // Warm amber
  @override
  Color get emergency => const Color(0xFFEF5350); // Muted red-orange

  @override
  Color get cyan => const Color(0xFF00897B); // Teal
  @override
  Color get red => const Color(0xFFE57373);
  @override
  Color get orange => const Color(0xFFFFB74D);
  @override
  Color get green => const Color(0xFF4CAF50);
  @override
  Color get purple => const Color(0xFF7E57C2);
  @override
  Color get lightPurple => const Color(0xFFB39DDB);
  @override
  Color get lightCyan => const Color(0xFF4DB6AC);

  @override
  Color get borderColor => const Color(0xFFC5E1A5); // Light green border
  @override
  Color get dividerColor => const Color(0xFFF1F8E9);
  @override
  Color get disabledColor => const Color(0xFFC5E1A5);
  @override
  Color get shadowColor => const Color(0xFF4CAF50).withOpacity(0.1);
}

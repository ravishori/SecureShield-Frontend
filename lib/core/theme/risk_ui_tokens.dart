/// Adaptive UI color tokens for risk-level cards.
///
/// Every risk level resolves to a coherent palette (card bg, border, text,
/// badge) that is **WCAG-AA compliant in BOTH light and dark themes**. This
/// is the canonical source of card styling for the App Scanner, Device Scan
/// results, and the App Detail screens.
///
/// The palette is built around four perceptual zones:
///   • Green     → SAFE / LOW
///   • Amber     → MEDIUM
///   • Orange    → HIGH
///   • Deep red  → CRITICAL
///
/// Each token bundle exposes:
///   • [cardBg]         — card background
///   • [cardBorder]     — soft tinted border (1.5–2 px)
///   • [textPrimary]    — app name; contrast ratio ≥ 7:1 vs cardBg (AAA)
///   • [textSecondary]  — package name; contrast ratio ≥ 4.5:1 (AA)
///   • [iconBg]/[iconFg]— Android icon chip
///   • [badgeBg]/[badgeBorder]/[badgeText] — solid risk-level badge
///   • [scoreText]      — bold score number
library;

import 'package:flutter/material.dart';
import 'app_theme_enum.dart';
import '../security/app_risk_engine.dart';

class RiskUiTokens {
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconBg;
  final Color iconFg;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final Color scoreText;

  const RiskUiTokens({
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconBg,
    required this.iconFg,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.scoreText,
  });

  /// Resolve tokens for the given [level] using the active [BuildContext]'s
  /// theme brightness. Use this everywhere; do not hard-code colours.
  factory RiskUiTokens.of(BuildContext context, AppRiskLevel level) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? _light(level) : _dark(level);
  }

  /// Variant for explicitly chosen theme type (used when the widget needs
  /// to render outside a Material parent — e.g. dialogs, system shade UI).
  factory RiskUiTokens.forTheme(AppThemeType themeType, AppRiskLevel level) {
    // `isDark` on the new enum is the single source of truth for brightness.
    return themeType.isDark ? _dark(level) : _light(level);
  }

  // ── Light-theme palettes ────────────────────────────────────────────────
  static RiskUiTokens _light(AppRiskLevel l) {
    switch (l) {
      case AppRiskLevel.safe:
      case AppRiskLevel.low:
        return const RiskUiTokens(
          cardBg:        Color(0xFFF4FFF6),  // very pale mint
          cardBorder:    Color(0xFFB7E4C7),  // soft mint outline
          textPrimary:   Color(0xFF0E2417),  // near-black; AAA on cardBg
          textSecondary: Color(0xFF4A6353),  // medium grey-green; AA
          iconBg:        Color(0xFFC8EFD2),
          iconFg:        Color(0xFF146C2E),
          badgeBg:       Color(0xFFD9F2DF),
          badgeBorder:   Color(0xFF2E7D32),
          badgeText:     Color(0xFF146C2E),
          scoreText:     Color(0xFF146C2E),
        );
      case AppRiskLevel.medium:
        return const RiskUiTokens(
          cardBg:        Color(0xFFFFF8E8),
          cardBorder:    Color(0xFFFFD27A),
          textPrimary:   Color(0xFF2A1A00),  // near-black-brown
          textSecondary: Color(0xFF6B4A1A),
          iconBg:        Color(0xFFFFE6B0),
          iconFg:        Color(0xFF8A5200),
          badgeBg:       Color(0xFFFFE9B8),
          badgeBorder:   Color(0xFF8A5200),
          badgeText:     Color(0xFF6B4200),
          scoreText:     Color(0xFF8A5200),
        );
      case AppRiskLevel.high:
        return const RiskUiTokens(
          cardBg:        Color(0xFFFFF0F0),
          cardBorder:    Color(0xFFFFB3B3),
          textPrimary:   Color(0xFF2A0000),
          textSecondary: Color(0xFF6B2A2A),
          iconBg:        Color(0xFFFFD6D6),
          iconFg:        Color(0xFFB00020),
          badgeBg:       Color(0xFFFFDADA),
          badgeBorder:   Color(0xFFB00020),
          badgeText:     Color(0xFF8B0000),
          scoreText:     Color(0xFFB00020),
        );
      case AppRiskLevel.critical:
        return const RiskUiTokens(
          cardBg:        Color(0xFFFFE5E5),
          cardBorder:    Color(0xFFFF6B6B),
          textPrimary:   Color(0xFF1A0000),
          textSecondary: Color(0xFF5A1212),
          iconBg:        Color(0xFFFFC6C6),
          iconFg:        Color(0xFF8B0000),
          badgeBg:       Color(0xFFFFC6C6),
          badgeBorder:   Color(0xFF8B0000),
          badgeText:     Color(0xFF6B0000),
          scoreText:     Color(0xFF8B0000),
        );
    }
  }

  // ── Dark-theme palettes ─────────────────────────────────────────────────
  static RiskUiTokens _dark(AppRiskLevel l) {
    switch (l) {
      case AppRiskLevel.safe:
      case AppRiskLevel.low:
        return const RiskUiTokens(
          cardBg:        Color(0xFF0F1E15),
          cardBorder:    Color(0xFF1F4D2F),
          textPrimary:   Color(0xFFE8F5EC),  // near-white; AAA
          textSecondary: Color(0xFFA5C9B0),
          iconBg:        Color(0xFF143821),
          iconFg:        Color(0xFF7DE5A0),
          badgeBg:       Color(0xFF143821),
          badgeBorder:   Color(0xFF2E7D32),
          badgeText:     Color(0xFF7DE5A0),
          scoreText:     Color(0xFF7DE5A0),
        );
      case AppRiskLevel.medium:
        return const RiskUiTokens(
          cardBg:        Color(0xFF1F1808),
          cardBorder:    Color(0xFF7A5A1A),
          textPrimary:   Color(0xFFFFF3D6),
          textSecondary: Color(0xFFD9B68B),
          iconBg:        Color(0xFF3D2A0E),
          iconFg:        Color(0xFFFFC857),
          badgeBg:       Color(0xFF3D2A0E),
          badgeBorder:   Color(0xFFFFC857),
          badgeText:     Color(0xFFFFC857),
          scoreText:     Color(0xFFFFC857),
        );
      case AppRiskLevel.high:
        return const RiskUiTokens(
          cardBg:        Color(0xFF1F0A0A),
          cardBorder:    Color(0xFF7A1F1F),
          textPrimary:   Color(0xFFFFE6E6),
          textSecondary: Color(0xFFE5A6A6),
          iconBg:        Color(0xFF3D0F0F),
          iconFg:        Color(0xFFFF8585),
          badgeBg:       Color(0xFF3D0F0F),
          badgeBorder:   Color(0xFFFF6B6B),
          badgeText:     Color(0xFFFF8585),
          scoreText:     Color(0xFFFF8585),
        );
      case AppRiskLevel.critical:
        return const RiskUiTokens(
          cardBg:        Color(0xFF2A0000),
          cardBorder:    Color(0xFFB22222),
          textPrimary:   Color(0xFFFFEAEA),
          textSecondary: Color(0xFFEFB0B0),
          iconBg:        Color(0xFF4D0000),
          iconFg:        Color(0xFFFF5252),
          badgeBg:       Color(0xFF4D0000),
          badgeBorder:   Color(0xFFFF5252),
          badgeText:     Color(0xFFFF7575),
          scoreText:     Color(0xFFFF5252),
        );
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Adaptive text-colour helper.
//
// Compute a high-contrast foreground for an arbitrary background. Uses
// WCAG relative luminance: light backgrounds (>0.5) → near-black text,
// dark backgrounds → near-white text.
// ────────────────────────────────────────────────────────────────────────────
Color readableTextColor(Color background, {bool secondary = false}) {
  final l = background.computeLuminance();
  final isLightBg = l > 0.5;
  if (secondary) {
    return isLightBg ? const Color(0xFF5C6470) : const Color(0xFFB8C0CC);
  }
  return isLightBg ? const Color(0xFF1A1A1A) : Colors.white;
}

// ────────────────────────────────────────────────────────────────────────────
// Senior-citizen / accessibility size scaling.
//
// Centralised so the entire app reads the same multipliers. Pass-through for
// "normal" themes; bumps for accessibility-optimised themes.
// ────────────────────────────────────────────────────────────────────────────
class A11ySizing {
  /// Multiplier applied to text sizes (1.0 = no change).
  final double textScale;

  /// Multiplier applied to padding / spacing.
  final double padScale;

  /// Extra border width added on top of normal weight.
  final double extraBorder;

  /// Hit target minimum (Material 3 default is 48; senior is 56).
  final double minTouchTarget;

  const A11ySizing({
    this.textScale = 1.0,
    this.padScale = 1.0,
    this.extraBorder = 0.0,
    this.minTouchTarget = 48.0,
  });

  static const standard = A11ySizing();
  static const senior = A11ySizing(
    textScale: 1.18,
    padScale: 1.20,
    extraBorder: 0.5,
    minTouchTarget: 56.0,
  );

  /// Picks the right preset for the active theme type.
  /// High Contrast + Corporate Light are the only baselines that need the
  /// larger senior preset; every other theme uses standard sizing. Users who
  /// want big text with a different theme should turn on Accessibility Mode.
  static A11ySizing forTheme(AppThemeType t) =>
      t == AppThemeType.highContrast ? senior : standard;
}

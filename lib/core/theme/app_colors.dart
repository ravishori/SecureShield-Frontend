/// Color palettes for the 7 SecureShield themes.
///
/// **Design rules every palette follows:**
///  • Body text vs. background contrast ≥ 4.5:1 (WCAG AA)
///  • Headline text vs. background contrast ≥ 7:1 where possible
///  • No neon greens, no washed pastels, no fluorescent accents
///  • Status colors (safe / warning / critical) share the same hue family
///    across every theme so users learn "red = danger" once
///  • `borderColor` is a HAIRLINE (8–12% white / 10–15% black) — cards
///    are separated by contrast, not by heavy outlines
///  • `shadowColor` is a neutral drop, never colored
library;

import 'package:flutter/material.dart';

/// Central lookup: theme string → palette.
class AppColors {
  AppColors._();

  static const ColorPalette defenderBluePalette      = _DefenderBluePalette();
  static const ColorPalette enterpriseDarkPalette    = _EnterpriseDarkPalette();
  static const ColorPalette midnightSecurityPalette  = _MidnightSecurityPalette();
  static const ColorPalette bankingSecurePalette     = _BankingSecurePalette();
  static const ColorPalette cyberIntelligencePalette = _CyberIntelligencePalette();
  static const ColorPalette corporateLightPalette    = _CorporateLightPalette();
  static const ColorPalette highContrastPalette      = _HighContrastPalette();

  /// Legacy aliases — kept so any file that still references
  /// `AppColors.darkPalette` / `.lightPalette` etc. keeps compiling.
  static const ColorPalette darkPalette  = defenderBluePalette;
  static const ColorPalette lightPalette = corporateLightPalette;

  static ColorPalette getPalette(String themeType) => switch (themeType) {
        'defenderBlue'      => defenderBluePalette,
        'enterpriseDark'    => enterpriseDarkPalette,
        'midnightSecurity'  => midnightSecurityPalette,
        'bankingSecure'     => bankingSecurePalette,
        'cyberIntelligence' => cyberIntelligencePalette,
        'corporateLight'    => corporateLightPalette,
        'highContrast'      => highContrastPalette,
        // Legacy fall-throughs
        'dark'          => defenderBluePalette,
        'light'         => corporateLightPalette,
        'cybersecurity' => cyberIntelligencePalette,
        'seniorCitizen' => highContrastPalette,
        'natureGreen'   => enterpriseDarkPalette,
        _               => defenderBluePalette,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// ABSTRACT PALETTE
// ═══════════════════════════════════════════════════════════════════════════

abstract class ColorPalette {
  const ColorPalette();

  // Brand
  Color get primary;
  Color get secondary;
  Color get accent;

  // Layout
  Color get background;
  Color get surface;
  Color get card;
  Color get overlay;

  // Text
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;

  // Status
  Color get threat;
  Color get safe;
  Color get warning;
  Color get emergency;

  // Feature accents
  Color get cyan;
  Color get red;
  Color get orange;
  Color get green;
  Color get purple;
  Color get lightPurple;
  Color get lightCyan;

  // Structure
  Color get borderColor;
  Color get dividerColor;
  Color get disabledColor;
  Color get shadowColor;
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. DEFENDER BLUE — Microsoft Defender inspiration.
// ═══════════════════════════════════════════════════════════════════════════

class _DefenderBluePalette extends ColorPalette {
  const _DefenderBluePalette();

  @override Color get primary   => const Color(0xFF0078D4); // MS-flavored blue
  @override Color get secondary => const Color(0xFF106EBE);
  @override Color get accent    => const Color(0xFF00C2FF); // electric blue

  @override Color get background => const Color(0xFF071321);
  @override Color get surface    => const Color(0xFF0D1B2A);
  @override Color get card       => const Color(0xFF14263D);
  @override Color get overlay    => const Color(0x99000000);

  @override Color get textPrimary   => const Color(0xFFFFFFFF);
  @override Color get textSecondary => const Color(0xFFB8C2D1);
  @override Color get textTertiary  => const Color(0xFF7A8699);

  @override Color get threat    => const Color(0xFFEF4444);
  @override Color get safe      => const Color(0xFF22C55E);
  @override Color get warning   => const Color(0xFFF59E0B);
  @override Color get emergency => const Color(0xFFEF4444);

  @override Color get cyan        => const Color(0xFF00E5FF);
  @override Color get red         => const Color(0xFFEF4444);
  @override Color get orange      => const Color(0xFFF59E0B);
  @override Color get green       => const Color(0xFF22C55E);
  @override Color get purple      => const Color(0xFF8B5CF6);
  @override Color get lightPurple => const Color(0xFFA78BFA);
  @override Color get lightCyan   => const Color(0xFF67E8F9);

  @override Color get borderColor   => const Color(0x1AFFFFFF); // 10% white
  @override Color get dividerColor  => const Color(0x14FFFFFF); // 8%
  @override Color get disabledColor => const Color(0xFF3A4A66);
  @override Color get shadowColor   => const Color(0xE6000000);
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. ENTERPRISE DARK — CrowdStrike Falcon inspiration.
//    Deep graphite with slate grays and a restrained cyan spark.
// ═══════════════════════════════════════════════════════════════════════════

class _EnterpriseDarkPalette extends ColorPalette {
  const _EnterpriseDarkPalette();

  @override Color get primary   => const Color(0xFFE10600); // CrowdStrike red — used for CTAs sparingly
  @override Color get secondary => const Color(0xFF5B6472);
  @override Color get accent    => const Color(0xFF00B4D8); // muted cyan

  @override Color get background => const Color(0xFF0F1216); // graphite
  @override Color get surface    => const Color(0xFF161B21);
  @override Color get card       => const Color(0xFF1D242D);
  @override Color get overlay    => const Color(0x99000000);

  @override Color get textPrimary   => const Color(0xFFF4F5F7);
  @override Color get textSecondary => const Color(0xFFB4BAC3);
  @override Color get textTertiary  => const Color(0xFF7F8794);

  @override Color get threat    => const Color(0xFFE10600);
  @override Color get safe      => const Color(0xFF10B981);
  @override Color get warning   => const Color(0xFFF59E0B);
  @override Color get emergency => const Color(0xFFE10600);

  @override Color get cyan        => const Color(0xFF00B4D8);
  @override Color get red         => const Color(0xFFE10600);
  @override Color get orange      => const Color(0xFFF59E0B);
  @override Color get green       => const Color(0xFF10B981);
  @override Color get purple      => const Color(0xFF7C3AED);
  @override Color get lightPurple => const Color(0xFF9F7AEA);
  @override Color get lightCyan   => const Color(0xFF4CC9F0);

  @override Color get borderColor   => const Color(0x14FFFFFF);
  @override Color get dividerColor  => const Color(0x0FFFFFFF);
  @override Color get disabledColor => const Color(0xFF3A4048);
  @override Color get shadowColor   => const Color(0xB3000000);
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. MIDNIGHT SECURITY — AMOLED-optimized. Pure black canvas, blue highlights.
// ═══════════════════════════════════════════════════════════════════════════

class _MidnightSecurityPalette extends ColorPalette {
  const _MidnightSecurityPalette();

  @override Color get primary   => const Color(0xFF3B82F6); // Tailwind blue-500
  @override Color get secondary => const Color(0xFF60A5FA);
  @override Color get accent    => const Color(0xFF60A5FA);

  @override Color get background => const Color(0xFF000000); // AMOLED black
  @override Color get surface    => const Color(0xFF0A0A0A);
  @override Color get card       => const Color(0xFF141414);
  @override Color get overlay    => const Color(0xB3000000);

  @override Color get textPrimary   => const Color(0xFFFFFFFF);
  @override Color get textSecondary => const Color(0xFFD1D5DB);
  @override Color get textTertiary  => const Color(0xFF9CA3AF);

  @override Color get threat    => const Color(0xFFF87171);
  @override Color get safe      => const Color(0xFF34D399);
  @override Color get warning   => const Color(0xFFFBBF24);
  @override Color get emergency => const Color(0xFFF87171);

  @override Color get cyan        => const Color(0xFF22D3EE);
  @override Color get red         => const Color(0xFFF87171);
  @override Color get orange      => const Color(0xFFFB923C);
  @override Color get green       => const Color(0xFF34D399);
  @override Color get purple      => const Color(0xFFA78BFA);
  @override Color get lightPurple => const Color(0xFFC4B5FD);
  @override Color get lightCyan   => const Color(0xFF67E8F9);

  @override Color get borderColor   => const Color(0x1FFFFFFF); // 12% white — a bit stronger on pure black
  @override Color get dividerColor  => const Color(0x14FFFFFF);
  @override Color get disabledColor => const Color(0xFF3F3F46);
  @override Color get shadowColor   => const Color(0xE6000000);
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. BANKING SECURE — Premium navy, emerald, gold. For BFSI protection UX.
// ═══════════════════════════════════════════════════════════════════════════

class _BankingSecurePalette extends ColorPalette {
  const _BankingSecurePalette();

  @override Color get primary   => const Color(0xFF0A2540); // deep navy
  @override Color get secondary => const Color(0xFF10B981); // emerald
  @override Color get accent    => const Color(0xFF10B981);

  @override Color get background => const Color(0xFF0A1929);
  @override Color get surface    => const Color(0xFF102A43);
  @override Color get card       => const Color(0xFF1B3A5C);
  @override Color get overlay    => const Color(0x99000000);

  @override Color get textPrimary   => const Color(0xFFFFFFFF);
  @override Color get textSecondary => const Color(0xFFBFD1E5);
  @override Color get textTertiary  => const Color(0xFF829AB1);

  @override Color get threat    => const Color(0xFFE11D48); // deep rose — theft
  @override Color get safe      => const Color(0xFF10B981); // emerald — verified
  @override Color get warning   => const Color(0xFFD4AF37); // gold
  @override Color get emergency => const Color(0xFFE11D48);

  @override Color get cyan        => const Color(0xFF06B6D4);
  @override Color get red         => const Color(0xFFE11D48);
  @override Color get orange      => const Color(0xFFF59E0B);
  @override Color get green       => const Color(0xFF10B981);
  @override Color get purple      => const Color(0xFF7C3AED);
  @override Color get lightPurple => const Color(0xFFA78BFA);
  @override Color get lightCyan   => const Color(0xFF67E8F9);

  @override Color get borderColor   => const Color(0x1AFFFFFF);
  @override Color get dividerColor  => const Color(0x14FFFFFF);
  @override Color get disabledColor => const Color(0xFF486581);
  @override Color get shadowColor   => const Color(0xCC000000);
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. CYBER INTELLIGENCE — SOC dashboard: indigo, blue, purple. Subtle.
// ═══════════════════════════════════════════════════════════════════════════

class _CyberIntelligencePalette extends ColorPalette {
  const _CyberIntelligencePalette();

  @override Color get primary   => const Color(0xFF6366F1); // indigo-500
  @override Color get secondary => const Color(0xFF8B5CF6); // violet-500
  @override Color get accent    => const Color(0xFF8B5CF6);

  @override Color get background => const Color(0xFF0B1023); // deep indigo
  @override Color get surface    => const Color(0xFF141B36);
  @override Color get card       => const Color(0xFF1B2445);
  @override Color get overlay    => const Color(0x99000000);

  @override Color get textPrimary   => const Color(0xFFF8FAFC);
  @override Color get textSecondary => const Color(0xFFC7CDE0);
  @override Color get textTertiary  => const Color(0xFF8790AF);

  @override Color get threat    => const Color(0xFFEC4899); // pink — alerts pop against indigo
  @override Color get safe      => const Color(0xFF14B8A6); // teal
  @override Color get warning   => const Color(0xFFF59E0B);
  @override Color get emergency => const Color(0xFFEC4899);

  @override Color get cyan        => const Color(0xFF06B6D4);
  @override Color get red         => const Color(0xFFEC4899);
  @override Color get orange      => const Color(0xFFF59E0B);
  @override Color get green       => const Color(0xFF14B8A6);
  @override Color get purple      => const Color(0xFF8B5CF6);
  @override Color get lightPurple => const Color(0xFFA78BFA);
  @override Color get lightCyan   => const Color(0xFF67E8F9);

  @override Color get borderColor   => const Color(0x1AFFFFFF);
  @override Color get dividerColor  => const Color(0x14FFFFFF);
  @override Color get disabledColor => const Color(0xFF3F4570);
  @override Color get shadowColor   => const Color(0xE6000000);
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. CORPORATE LIGHT — Office-friendly. High-contrast dark text on white.
// ═══════════════════════════════════════════════════════════════════════════

class _CorporateLightPalette extends ColorPalette {
  const _CorporateLightPalette();

  @override Color get primary   => const Color(0xFF0F4C81); // conservative navy
  @override Color get secondary => const Color(0xFF1976D2);
  @override Color get accent    => const Color(0xFF1976D2);

  @override Color get background => const Color(0xFFF6F8FB);
  @override Color get surface    => const Color(0xFFFFFFFF);
  @override Color get card       => const Color(0xFFFFFFFF);
  @override Color get overlay    => const Color(0x40000000);

  @override Color get textPrimary   => const Color(0xFF0F172A); // slate-900
  @override Color get textSecondary => const Color(0xFF475569); // slate-600 — 8.6:1 on white
  @override Color get textTertiary  => const Color(0xFF64748B);

  @override Color get threat    => const Color(0xFFDC2626);
  @override Color get safe      => const Color(0xFF16A34A);
  @override Color get warning   => const Color(0xFFCA8A04);
  @override Color get emergency => const Color(0xFFDC2626);

  @override Color get cyan        => const Color(0xFF0891B2);
  @override Color get red         => const Color(0xFFDC2626);
  @override Color get orange      => const Color(0xFFCA8A04);
  @override Color get green       => const Color(0xFF16A34A);
  @override Color get purple      => const Color(0xFF7C3AED);
  @override Color get lightPurple => const Color(0xFF9F7AEA);
  @override Color get lightCyan   => const Color(0xFF22D3EE);

  @override Color get borderColor   => const Color(0xFFE2E8F0); // slate-200
  @override Color get dividerColor  => const Color(0xFFEEF2F7);
  @override Color get disabledColor => const Color(0xFFCBD5E1);
  @override Color get shadowColor   => const Color(0x1F000000); // 12% black
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. HIGH CONTRAST — Accessibility-first. WCAG AAA. Best with a11y mode on.
// ═══════════════════════════════════════════════════════════════════════════

class _HighContrastPalette extends ColorPalette {
  const _HighContrastPalette();

  @override Color get primary   => const Color(0xFFFFD700); // saturated yellow (Windows HC-black standard)
  @override Color get secondary => const Color(0xFF00FFFF);
  @override Color get accent    => const Color(0xFFFFD700);

  @override Color get background => const Color(0xFF000000);
  @override Color get surface    => const Color(0xFF000000);
  @override Color get card       => const Color(0xFF0A0A0A);
  @override Color get overlay    => const Color(0xCC000000);

  @override Color get textPrimary   => const Color(0xFFFFFFFF); // 21:1 contrast
  @override Color get textSecondary => const Color(0xFFE5E7EB); // 15:1
  @override Color get textTertiary  => const Color(0xFFC7CDDA); // 11:1

  @override Color get threat    => const Color(0xFFFF6B6B);
  @override Color get safe      => const Color(0xFF00FF88);
  @override Color get warning   => const Color(0xFFFFD700);
  @override Color get emergency => const Color(0xFFFF6B6B);

  @override Color get cyan        => const Color(0xFF00FFFF);
  @override Color get red         => const Color(0xFFFF6B6B);
  @override Color get orange      => const Color(0xFFFFA500);
  @override Color get green       => const Color(0xFF00FF88);
  @override Color get purple      => const Color(0xFFC77DFF);
  @override Color get lightPurple => const Color(0xFFE0AAFF);
  @override Color get lightCyan   => const Color(0xFF00FFFF);

  @override Color get borderColor   => const Color(0xFFFFFFFF); // solid white — visible always
  @override Color get dividerColor  => const Color(0xFFFFFFFF);
  @override Color get disabledColor => const Color(0xFF9CA3AF);
  @override Color get shadowColor   => const Color(0xFF000000);
}

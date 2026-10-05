/// SecureShield Design System — single source of truth for spacing, radii,
/// motion, shadows, gradients and glow.
///
/// Every premium widget reads from these tokens. If a value needs to change
/// (e.g. tighten spacing, slow motion), edit it here — the whole app follows.
///
/// Naming convention:
///   • Spacing:   xs / sm / md / lg / xl / xxl  (8px base grid)
///   • Radius:    sm / md / lg / xl / pill / round
///   • Motion:    fast / normal / slow / hero
///   • Curves:    enter (easeOutCubic) / exit (easeInCubic) / spring
///
/// All tokens are `const` and can be used inside `const` widgets.
library;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SPACING — 8px base grid, the industry standard for enterprise design.
// ═══════════════════════════════════════════════════════════════════════════

class SpacingTokens {
  SpacingTokens._();

  /// 4  — hairline gaps between icon + label
  static const double xs  = 4;
  /// 8  — chip padding, tight rows
  static const double sm  = 8;
  /// 12 — small card padding, list items
  static const double md  = 12;
  /// 16 — screen edge insets, standard card padding
  static const double lg  = 16;
  /// 20 — hero card padding, section spacing
  static const double xl  = 20;
  /// 24 — top-level section gaps
  static const double xxl = 24;
  /// 32 — hero → body transition
  static const double xxxl = 32;

  // Common insets ready to use — no need to re-build EdgeInsets each time
  static const EdgeInsets screenPadding      = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingDefault = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLarge   = EdgeInsets.all(xl);
  static const EdgeInsets sectionGapY        = EdgeInsets.only(bottom: xxl);
}

// ═══════════════════════════════════════════════════════════════════════════
// RADIUS — premium enterprise radii
// ═══════════════════════════════════════════════════════════════════════════

class RadiusTokens {
  RadiusTokens._();

  static const double sm    = 8;   // chips, small badges
  static const double md    = 12;  // input fields
  static const double lg    = 16;  // small cards, tiles
  static const double xl    = 20;  // standard cards
  static const double xxl   = 24;  // hero cards
  static const double pill  = 999; // pills, filter chips
  static const double round = 9999; // circular

  static const BorderRadius smBR   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBR   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBR   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBR   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlBR  = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillBR = BorderRadius.all(Radius.circular(pill));
}

// ═══════════════════════════════════════════════════════════════════════════
// MOTION — durations + curves used across every premium widget.
// Enterprise apps use restrained motion: fast interactions, slow ambience.
// ═══════════════════════════════════════════════════════════════════════════

class MotionTokens {
  MotionTokens._();

  // Durations
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast    = Duration(milliseconds: 180);
  static const Duration normal  = Duration(milliseconds: 260);
  static const Duration slow    = Duration(milliseconds: 420);
  static const Duration hero    = Duration(milliseconds: 900);
  static const Duration ambient = Duration(seconds: 3);      // idle pulse
  static const Duration ticker  = Duration(seconds: 5);      // per-item feed
  static const Duration rotate  = Duration(seconds: 3);      // status text rotation

  // Curves
  static const Curve enter  = Curves.easeOutCubic;
  static const Curve exit   = Curves.easeInCubic;
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0); // gentle overshoot
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve press  = Curves.easeOut;
}

// ═══════════════════════════════════════════════════════════════════════════
// SHADOWS — subtle by default, coloured glow for status.
// ═══════════════════════════════════════════════════════════════════════════

class ShadowTokens {
  ShadowTokens._();

  /// Base card shadow — a single, soft drop that doesn't fight the glass.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 24,
      offset: Offset(0, 12),
      spreadRadius: -8,
    ),
  ];

  /// Small tile / chip shadow.
  static const List<BoxShadow> tile = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 6),
      spreadRadius: -4,
    ),
  ];

  /// Hero card — deeper drop for the top-of-screen container.
  static const List<BoxShadow> hero = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 40,
      offset: Offset(0, 18),
      spreadRadius: -12,
    ),
  ];

  /// Coloured glow — pass in the accent colour to build a status glow.
  /// Use `ShadowTokens.glow(SecurityStatusColors.safe)` etc.
  static List<BoxShadow> glow(Color color, {double intensity = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: 32,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ];
}

// ═══════════════════════════════════════════════════════════════════════════
// GRADIENTS — the three brand gradients used across the redesign.
// ═══════════════════════════════════════════════════════════════════════════

class GradientTokens {
  GradientTokens._();

  /// Brand gradient — Electric blue → Purple. Use on hero CTAs and the
  /// "AI-POWERED" pill.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C2FF), Color(0xFF8B5CF6)],
  );

  /// Emergency gradient — for SOS strips, critical alerts.
  static const LinearGradient danger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
  );

  /// Success gradient.
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
  );

  /// Warning gradient.
  static const LinearGradient warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
  );

  /// Glass tint — used inside GlassCard on top of the BackdropFilter.
  static LinearGradient glassTint(Color surface) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface.withValues(alpha: 0.75),
          surface.withValues(alpha: 0.45),
        ],
      );

  /// Radial ambient glow used behind hero components.
  static RadialGradient ambient(Color color) => RadialGradient(
        center: const Alignment(-0.5, -0.6),
        radius: 1.4,
        colors: [
          color.withValues(alpha: 0.25),
          const Color(0xFF8B5CF6).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// SEMANTIC STATUS COLOURS — canonical status palette. Widgets should read
// from here, not hard-code hexes.
// ═══════════════════════════════════════════════════════════════════════════

class SecurityStatusColors {
  SecurityStatusColors._();

  static const Color safe      = Color(0xFF22C55E); // Emerald
  static const Color info      = Color(0xFF00C2FF); // Electric blue
  static const Color warning   = Color(0xFFF59E0B); // Amber
  static const Color critical  = Color(0xFFEF4444); // Red
  static const Color aiAccent  = Color(0xFF8B5CF6); // Purple glow

  /// Colour ramp for security score 0-100.
  ///   ≥ 75 → safe
  ///   ≥ 50 → info blue
  ///   ≥ 30 → warning
  ///   <  30 → critical
  static Color forScore(double score) {
    if (score >= 75) return safe;
    if (score >= 50) return info;
    if (score >= 30) return warning;
    return critical;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLOW — hairline glowing borders used on premium cards.
// ═══════════════════════════════════════════════════════════════════════════

class GlowTokens {
  GlowTokens._();

  /// Standard hairline glowing border for a given accent.
  static Border hairline(Color color, {double opacity = 0.35, double width = 1}) =>
      Border.all(color: color.withValues(alpha: opacity), width: width);

  /// Subtle interior border used inside GlassCards.
  static Border glass({double opacity = 0.08}) =>
      Border.all(color: Colors.white.withValues(alpha: opacity), width: 1);
}

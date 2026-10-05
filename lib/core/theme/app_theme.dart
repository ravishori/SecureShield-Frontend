/// SecureShield ThemeData factory.
///
/// A single generic builder produces the ThemeData for all 7 themes — every
/// theme just supplies a `ColorPalette` + `Brightness` and gets a consistent,
/// enterprise-grade Material 3 theme back. This replaces the previous
/// approach of 5 near-identical `_buildXTheme()` copy-pasted functions.
///
/// Design rules baked into the builder (aligned with Microsoft Defender,
/// CrowdStrike, Bitdefender):
///   • Cards: 1 px hairline borders, subtle drop shadow, NO coloured glow
///   • Buttons: solid fills for primary CTAs, minimum 48-dp touch targets
///   • Inputs: filled with `card` color, 1.5 px focused ring
///   • App bar: no elevation, no scroll shadow, respects surface color
///   • Chips: neutral background, accent border, no glow
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_theme_enum.dart';
import 'app_theme_extensions.dart';

class AppTheme {
  AppTheme._();

  /// Returns the ThemeData for the given [AppThemeType].
  static ThemeData getTheme(AppThemeType themeType) => _build(
        brightness: themeType.isDark ? Brightness.dark : Brightness.light,
        palette:    themeType.palette,
        a11y:       themeType.accessibility,
      );

  // ── One builder to rule them all ─────────────────────────────────────────
  static ThemeData _build({
    required Brightness brightness,
    required ColorPalette palette,
    required ThemeAccessibility a11y,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary:               palette.primary,
      onPrimary:             _onColorFor(palette.primary),
      primaryContainer:      palette.primary.withValues(alpha: isDark ? 0.20 : 0.10),
      onPrimaryContainer:    palette.primary,
      secondary:             palette.accent,
      onSecondary:           _onColorFor(palette.accent),
      secondaryContainer:    palette.accent.withValues(alpha: isDark ? 0.18 : 0.10),
      onSecondaryContainer:  palette.accent,
      tertiary:              palette.secondary,
      onTertiary:            _onColorFor(palette.secondary),
      tertiaryContainer:     palette.secondary.withValues(alpha: 0.15),
      onTertiaryContainer:   palette.secondary,
      surface:               palette.surface,
      onSurface:             palette.textPrimary,
      surfaceContainerHighest: palette.card,
      error:                 palette.threat,
      onError:               Colors.white,
      errorContainer:        palette.threat.withValues(alpha: 0.15),
      onErrorContainer:      palette.threat,
      outline:               palette.borderColor,
      outlineVariant:        palette.dividerColor,
      scrim:                 isDark ? Colors.black87 : Colors.black26,
    );

    return ThemeData(
      useMaterial3:            true,
      brightness:              brightness,
      colorScheme:             scheme,
      scaffoldBackgroundColor: palette.background,
      cardTheme:               _cardTheme(palette, a11y),
      appBarTheme:             _appBarTheme(palette, a11y),
      textTheme:               _textTheme(a11y, palette.textPrimary),
      inputDecorationTheme:    _inputTheme(palette, a11y),
      elevatedButtonTheme:     _elevatedButtonTheme(palette, a11y),
      outlinedButtonTheme:     _outlinedButtonTheme(palette, a11y),
      textButtonTheme:         _textButtonTheme(palette, a11y),
      floatingActionButtonTheme: _fabTheme(palette),
      chipTheme:               _chipTheme(palette, a11y),
      dividerTheme:            DividerThemeData(
        color:     palette.dividerColor,
        thickness: a11y.outlineWidth,
        space:     1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:            palette.accent,
        linearTrackColor: palette.dividerColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? palette.accent : palette.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? palette.accent.withValues(alpha: 0.4)
                : palette.dividerColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      palette.surface,
        selectedItemColor:    palette.accent,
        unselectedItemColor:  palette.textSecondary,
        type:                 BottomNavigationBarType.fixed,
        elevation:            isDark ? 0 : 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor:  palette.accent.withValues(alpha: 0.15),
        labelTextStyle:  WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize:  a11y.buttonFontSize * 0.85,
            color:     selected ? palette.accent : palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  palette.surface,
        contentTextStyle: TextStyle(
          color:    palette.textPrimary,
          fontSize: a11y.baseFontSize,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.borderColor, width: a11y.outlineWidth),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Component builders (previously duplicated 5x) ────────────────────────

  static CardThemeData _cardTheme(ColorPalette p, ThemeAccessibility a) =>
      CardThemeData(
        color:       p.card,
        elevation:   1,                       // NO coloured glow anywhere
        shadowColor: p.shadowColor,
        margin:      const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.borderColor, width: a.outlineWidth),
        ),
      );

  static AppBarThemeData _appBarTheme(ColorPalette p, ThemeAccessibility a) =>
      AppBarThemeData(
        backgroundColor:       p.surface,
        foregroundColor:       p.textPrimary,
        elevation:             0,             // flat — matches Defender/CrowdStrike
        scrolledUnderElevation: 0,
        centerTitle:           false,
        titleTextStyle: GoogleFonts.inter(
          fontSize:  a.headlineFontSize * 0.75,
          fontWeight: FontWeight.w700,
          color:     p.textPrimary,
          letterSpacing: -0.2,
        ),
      );

  static TextTheme _textTheme(ThemeAccessibility a, Color textColor) {
    final base = GoogleFonts.inter(color: textColor);
    return TextTheme(
      displayLarge:   base.copyWith(fontSize: a.headlineFontSize * 1.7, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1),
      displayMedium:  base.copyWith(fontSize: a.headlineFontSize * 1.4, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15),
      displaySmall:   base.copyWith(fontSize: a.headlineFontSize * 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2),
      headlineLarge:  base.copyWith(fontSize: a.headlineFontSize,        fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2),
      headlineMedium: base.copyWith(fontSize: a.headlineFontSize * 0.85, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.25),
      headlineSmall:  base.copyWith(fontSize: a.headlineFontSize * 0.7,  fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3),
      titleLarge:     base.copyWith(fontSize: a.baseFontSize * 1.2,      fontWeight: FontWeight.w600, height: 1.3),
      titleMedium:    base.copyWith(fontSize: a.baseFontSize * 1.05,     fontWeight: FontWeight.w600, height: 1.35),
      titleSmall:     base.copyWith(fontSize: a.baseFontSize * 0.92,     fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge:      base.copyWith(fontSize: a.baseFontSize * 1.05,     fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium:     base.copyWith(fontSize: a.baseFontSize,            fontWeight: FontWeight.w400, height: 1.5),
      bodySmall:      base.copyWith(fontSize: a.baseFontSize * 0.85,     fontWeight: FontWeight.w400, height: 1.45),
      labelLarge:     base.copyWith(fontSize: a.buttonFontSize,          fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium:    base.copyWith(fontSize: a.baseFontSize * 0.82,     fontWeight: FontWeight.w500, letterSpacing: 0.3),
      labelSmall:     base.copyWith(fontSize: a.baseFontSize * 0.72,     fontWeight: FontWeight.w500, letterSpacing: 0.4),
    );
  }

  static InputDecorationTheme _inputTheme(ColorPalette p, ThemeAccessibility a) =>
      InputDecorationTheme(
        filled:      true,
        fillColor:   p.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: a.baseFontSize * 0.8),
        labelStyle:  GoogleFonts.inter(fontSize: a.baseFontSize,       color: p.textSecondary),
        hintStyle:   GoogleFonts.inter(fontSize: a.baseFontSize * 0.95, color: p.textSecondary.withValues(alpha: 0.6)),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        border:        _inputBorder(p.borderColor, a.outlineWidth),
        enabledBorder: _inputBorder(p.borderColor, a.outlineWidth),
        focusedBorder: _inputBorder(p.accent,       a.outlineWidth * 1.5),
        errorBorder:   _inputBorder(p.threat,       a.outlineWidth),
        focusedErrorBorder: _inputBorder(p.threat, a.outlineWidth * 1.5),
      );

  static OutlineInputBorder _inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: color, width: width),
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(
          ColorPalette p, ThemeAccessibility a) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: _onColorFor(p.primary),
          padding:         a.buttonPadding,
          minimumSize:     a.buttonMinSize,
          elevation:       0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize:  a.buttonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(
          ColorPalette p, ThemeAccessibility a) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side:            BorderSide(color: p.primary, width: a.outlineWidth),
          padding:         a.buttonPadding,
          minimumSize:     a.buttonMinSize,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize:  a.buttonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static TextButtonThemeData _textButtonTheme(
          ColorPalette p, ThemeAccessibility a) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          padding:         a.buttonPadding,
          minimumSize:     a.buttonMinSize,
          textStyle: GoogleFonts.inter(
            fontSize:  a.buttonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static FloatingActionButtonThemeData _fabTheme(ColorPalette p) =>
      FloatingActionButtonThemeData(
        backgroundColor:   p.primary,
        foregroundColor:   _onColorFor(p.primary),
        elevation:         2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );

  static ChipThemeData _chipTheme(ColorPalette p, ThemeAccessibility a) =>
      ChipThemeData(
        backgroundColor: p.card,
        labelStyle: GoogleFonts.inter(
          fontSize: a.baseFontSize * 0.9,
          color:    p.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: p.borderColor, width: a.outlineWidth),
        ),
        selectedColor:           p.accent.withValues(alpha: 0.20),
        secondarySelectedColor:  p.accent.withValues(alpha: 0.20),
        deleteIconColor:         p.textSecondary,
      );

  /// Chooses white or near-black for text placed on a solid color background,
  /// based on the color's relative luminance. Guarantees the "on X" text
  /// meets contrast requirements without hard-coding per-palette overrides.
  static Color _onColorFor(Color bg) =>
      bg.computeLuminance() > 0.5 ? const Color(0xFF0F172A) : Colors.white;
}

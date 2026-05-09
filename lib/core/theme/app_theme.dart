/// Complete ThemeData builders for all 5 themes
///
/// Provides Material 3 themed applications with comprehensive component styling
/// for Light, Dark, Cybersecurity, Senior Citizen, and Nature Green themes.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme_enum.dart';
import 'app_colors.dart';
import 'app_theme_extensions.dart';

// ──────────────────────────────────────────────────────────────────────────
// MAIN THEME CLASS
// ──────────────────────────────────────────────────────────────────────────

/// Central theme provider for all 5 themes
class AppTheme {
  /// Get ThemeData for a specific theme type
  ///
  /// Returns a complete Material 3 ThemeData configured for the given theme.
  static ThemeData getTheme(AppThemeType themeType) {
    return switch (themeType) {
      AppThemeType.light => _buildLightTheme(),
      AppThemeType.dark => _buildDarkTheme(),
      AppThemeType.cybersecurity => _buildCybersecurityTheme(),
      AppThemeType.seniorCitizen => _buildSeniorCitizenTheme(),
      AppThemeType.natureGreen => _buildNatureGreenTheme(),
    };
  }

  // ──────────────────────────────────────────────────────────────────────
  // THEME BUILDERS
  // ──────────────────────────────────────────────────────────────────────

  /// Light Theme - Professional, clean, accessibility-focused
  static ThemeData _buildLightTheme() {
    final palette = AppColors.lightPalette;
    final a11y = AppThemeType.light.accessibility;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: palette.primary,
        onPrimary: Colors.white,
        primaryContainer: palette.primary.withOpacity(0.1),
        onPrimaryContainer: palette.primary,
        secondary: palette.accent,
        onSecondary: Colors.white,
        secondaryContainer: palette.accent.withOpacity(0.1),
        onSecondaryContainer: palette.accent,
        tertiary: palette.secondary,
        onTertiary: Colors.white,
        tertiaryContainer: palette.secondary.withOpacity(0.1),
        onTertiaryContainer: palette.secondary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.card,
        error: palette.threat,
        onError: Colors.white,
        errorContainer: palette.threat.withOpacity(0.1),
        onErrorContainer: palette.threat,
        outline: palette.borderColor,
        outlineVariant: palette.dividerColor,
        scrim: Colors.black26,
      ),
      scaffoldBackgroundColor: palette.background,
      cardTheme: _buildCardTheme(palette, a11y),
      appBarTheme: _buildAppBarTheme(palette, a11y),
      textTheme: _buildTextTheme(a11y, palette.textPrimary),
      inputDecorationTheme: _buildInputDecorationTheme(palette, a11y),
      elevatedButtonTheme: _buildElevatedButtonTheme(palette, a11y),
      outlinedButtonTheme: _buildOutlinedButtonTheme(palette, a11y),
      textButtonTheme: _buildTextButtonTheme(palette, a11y),
      floatingActionButtonTheme: _buildFabTheme(palette, a11y),
      chipTheme: _buildChipTheme(palette, a11y),
      dividerTheme: DividerThemeData(
        color: palette.dividerColor,
        thickness: 1.0,
        space: 1.0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.dividerColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent;
          }
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent.withOpacity(0.4);
          }
          return palette.dividerColor;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accent.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: isSelected ? palette.accent : palette.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Dark Theme - Original dark mode with cyan accents
  static ThemeData _buildDarkTheme() {
    final palette = AppColors.darkPalette;
    final a11y = AppThemeType.dark.accessibility;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: palette.primary,
        onPrimary: palette.textPrimary,
        primaryContainer: palette.primary.withOpacity(0.5),
        onPrimaryContainer: palette.accent,
        secondary: palette.accent,
        onSecondary: Colors.black,
        secondaryContainer: palette.accent.withOpacity(0.2),
        onSecondaryContainer: palette.accent,
        tertiary: palette.secondary,
        onTertiary: palette.textPrimary,
        tertiaryContainer: palette.secondary.withOpacity(0.2),
        onTertiaryContainer: palette.secondary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.card,
        error: palette.threat,
        onError: Colors.white,
        errorContainer: palette.threat.withOpacity(0.2),
        onErrorContainer: palette.threat,
        outline: palette.borderColor,
        outlineVariant: palette.dividerColor,
        scrim: Colors.black87,
      ),
      scaffoldBackgroundColor: palette.background,
      cardTheme: _buildCardTheme(palette, a11y),
      appBarTheme: _buildAppBarTheme(palette, a11y),
      textTheme: _buildTextTheme(a11y, palette.textPrimary),
      inputDecorationTheme: _buildInputDecorationTheme(palette, a11y),
      elevatedButtonTheme: _buildElevatedButtonTheme(palette, a11y),
      outlinedButtonTheme: _buildOutlinedButtonTheme(palette, a11y),
      textButtonTheme: _buildTextButtonTheme(palette, a11y),
      floatingActionButtonTheme: _buildFabTheme(palette, a11y),
      chipTheme: _buildChipTheme(palette, a11y),
      dividerTheme: DividerThemeData(
        color: palette.dividerColor,
        thickness: 1.0,
        space: 1.0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.dividerColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent;
          }
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent.withOpacity(0.4);
          }
          return palette.dividerColor;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accent.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: isSelected ? palette.accent : palette.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Cybersecurity Theme - Dark with neon security colors
  static ThemeData _buildCybersecurityTheme() {
    final palette = AppColors.cybersecurityPalette;
    final a11y = AppThemeType.cybersecurity.accessibility;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: palette.primary,
        onPrimary: palette.accent,
        primaryContainer: palette.primary.withOpacity(0.5),
        onPrimaryContainer: palette.accent,
        secondary: palette.accent,
        onSecondary: Colors.black,
        secondaryContainer: palette.accent.withOpacity(0.2),
        onSecondaryContainer: palette.accent,
        tertiary: palette.safe,
        onTertiary: Colors.black,
        tertiaryContainer: palette.safe.withOpacity(0.2),
        onTertiaryContainer: palette.safe,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.card,
        error: palette.threat,
        onError: Colors.white,
        errorContainer: palette.threat.withOpacity(0.2),
        onErrorContainer: palette.threat,
        outline: palette.accent,
        outlineVariant: palette.dividerColor,
        scrim: Colors.black87,
      ),
      scaffoldBackgroundColor: palette.background,
      cardTheme: _buildCardTheme(palette, a11y),
      appBarTheme: _buildAppBarTheme(palette, a11y),
      textTheme: _buildTextTheme(a11y, palette.textPrimary),
      inputDecorationTheme: _buildInputDecorationTheme(palette, a11y),
      elevatedButtonTheme: _buildElevatedButtonTheme(palette, a11y),
      outlinedButtonTheme: _buildOutlinedButtonTheme(palette, a11y),
      textButtonTheme: _buildTextButtonTheme(palette, a11y),
      floatingActionButtonTheme: _buildFabTheme(palette, a11y),
      chipTheme: _buildChipTheme(palette, a11y),
      dividerTheme: DividerThemeData(
        color: palette.accent.withOpacity(0.3),
        thickness: 1.0,
        space: 1.0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.safe,
        linearTrackColor: palette.dividerColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.safe;
          }
          return palette.threat;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.safe.withOpacity(0.4);
          }
          return palette.threat.withOpacity(0.3);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accent.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: isSelected ? palette.accent : palette.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Senior Citizen Theme - Large fonts, high contrast, simplified UI
  static ThemeData _buildSeniorCitizenTheme() {
    final palette = AppColors.seniorCitizenPalette;
    final a11y = AppThemeType.seniorCitizen.accessibility;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: palette.primary,
        onPrimary: Colors.white,
        primaryContainer: palette.primary.withOpacity(0.1),
        onPrimaryContainer: palette.primary,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        secondaryContainer: palette.secondary.withOpacity(0.1),
        onSecondaryContainer: palette.secondary,
        tertiary: palette.accent,
        onTertiary: Colors.white,
        tertiaryContainer: palette.accent.withOpacity(0.1),
        onTertiaryContainer: palette.accent,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.card,
        error: palette.threat,
        onError: Colors.white,
        errorContainer: palette.threat.withOpacity(0.1),
        onErrorContainer: palette.threat,
        outline: palette.borderColor,
        outlineVariant: palette.dividerColor,
        scrim: Colors.black26,
      ),
      scaffoldBackgroundColor: palette.background,
      cardTheme: _buildCardTheme(palette, a11y),
      appBarTheme: _buildAppBarTheme(palette, a11y),
      textTheme: _buildTextTheme(a11y, palette.textPrimary),
      inputDecorationTheme: _buildInputDecorationTheme(palette, a11y),
      elevatedButtonTheme: _buildElevatedButtonTheme(palette, a11y),
      outlinedButtonTheme: _buildOutlinedButtonTheme(palette, a11y),
      textButtonTheme: _buildTextButtonTheme(palette, a11y),
      floatingActionButtonTheme: _buildFabTheme(palette, a11y),
      chipTheme: _buildChipTheme(palette, a11y),
      dividerTheme: DividerThemeData(
        color: palette.dividerColor,
        thickness: a11y.outlineWidth,
        space: 1.0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.dividerColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent;
          }
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent.withOpacity(0.4);
          }
          return palette.dividerColor;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: a11y.buttonFontSize,
            color: isSelected ? palette.primary : palette.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(
          color: palette.textPrimary,
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

  /// Nature Green Theme - Calming green palette, outdoor-inspired
  static ThemeData _buildNatureGreenTheme() {
    final palette = AppColors.natureGreenPalette;
    final a11y = AppThemeType.natureGreen.accessibility;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: palette.primary,
        onPrimary: Colors.white,
        primaryContainer: palette.primary.withOpacity(0.1),
        onPrimaryContainer: palette.primary,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        secondaryContainer: palette.secondary.withOpacity(0.1),
        onSecondaryContainer: palette.secondary,
        tertiary: palette.accent,
        onTertiary: Colors.white,
        tertiaryContainer: palette.accent.withOpacity(0.1),
        onTertiaryContainer: palette.accent,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.card,
        error: palette.threat,
        onError: Colors.white,
        errorContainer: palette.threat.withOpacity(0.1),
        onErrorContainer: palette.threat,
        outline: palette.borderColor,
        outlineVariant: palette.dividerColor,
        scrim: Colors.black12,
      ),
      scaffoldBackgroundColor: palette.background,
      cardTheme: _buildCardTheme(palette, a11y),
      appBarTheme: _buildAppBarTheme(palette, a11y),
      textTheme: _buildTextTheme(a11y, palette.textPrimary),
      inputDecorationTheme: _buildInputDecorationTheme(palette, a11y),
      elevatedButtonTheme: _buildElevatedButtonTheme(palette, a11y),
      outlinedButtonTheme: _buildOutlinedButtonTheme(palette, a11y),
      textButtonTheme: _buildTextButtonTheme(palette, a11y),
      floatingActionButtonTheme: _buildFabTheme(palette, a11y),
      chipTheme: _buildChipTheme(palette, a11y),
      dividerTheme: DividerThemeData(
        color: palette.dividerColor,
        thickness: 1.0,
        space: 1.0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.dividerColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent;
          }
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.accent.withOpacity(0.4);
          }
          return palette.dividerColor;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accent.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: isSelected ? palette.primary : palette.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // More rounded for nature feel
          side: BorderSide(color: palette.borderColor, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // SHARED COMPONENT THEME BUILDERS
  // ──────────────────────────────────────────────────────────────────────

  static CardThemeData _buildCardTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return CardThemeData(
      color: palette.card,
      elevation: 2,
      shadowColor: palette.shadowColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.borderColor, width: a11y.outlineWidth),
      ),
    );
  }

  static AppBarThemeData _buildAppBarTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return AppBarThemeData(
      backgroundColor: palette.surface,
      foregroundColor: palette.textPrimary,
      elevation: 2,
      scrolledUnderElevation: 4,
      centerTitle: false,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        side: BorderSide(color: palette.borderColor, width: 0.5),
      ),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: a11y.headlineFontSize,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
    );
  }

  static TextTheme _buildTextTheme(ThemeAccessibility a11y, Color textColor) {
    final baseStyle = GoogleFonts.poppins(color: textColor);

    return TextTheme(
      displayLarge: baseStyle.copyWith(
        fontSize: a11y.headlineFontSize * 2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: baseStyle.copyWith(
        fontSize: a11y.headlineFontSize * 1.75,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: baseStyle.copyWith(
        fontSize: a11y.headlineFontSize * 1.5,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: baseStyle.copyWith(
        fontSize: a11y.headlineFontSize,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseStyle.copyWith(
        fontSize: a11y.headlineFontSize * 0.9,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: baseStyle.copyWith(
        fontSize: a11y.headlineFontSize * 0.8,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseStyle.copyWith(
        fontSize: a11y.baseFontSize * 1.3,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseStyle.copyWith(
        fontSize: a11y.baseFontSize * 1.1,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseStyle.copyWith(
        fontSize: a11y.baseFontSize,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseStyle.copyWith(
        fontSize: a11y.baseFontSize * 1.1,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: baseStyle.copyWith(
        fontSize: a11y.baseFontSize,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: baseStyle.copyWith(
        fontSize: a11y.baseFontSize * 0.9,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: baseStyle.copyWith(
        fontSize: a11y.buttonFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelMedium: baseStyle.copyWith(
        fontSize: a11y.baseFontSize * 0.85,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: baseStyle.copyWith(
        fontSize: a11y.baseFontSize * 0.75,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return InputDecorationTheme(
      filled: true,
      fillColor: palette.card,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: a11y.baseFontSize * 0.75,
      ),
      labelStyle: GoogleFonts.poppins(
        fontSize: a11y.baseFontSize,
        color: palette.textSecondary,
      ),
      hintStyle: GoogleFonts.poppins(
        fontSize: a11y.baseFontSize,
        color: palette.textSecondary.withOpacity(0.6),
      ),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return palette.accent;
        }
        return palette.textSecondary;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return palette.accent;
        }
        return palette.textSecondary;
      }),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.borderColor, width: a11y.outlineWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.borderColor, width: a11y.outlineWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.accent, width: a11y.outlineWidth * 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.threat, width: a11y.outlineWidth),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.threat, width: a11y.outlineWidth * 1.5),
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: Colors.black87,
        padding: a11y.buttonPadding,
        minimumSize: a11y.buttonMinSize,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.poppins(
          fontSize: a11y.buttonFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.accent, width: a11y.outlineWidth),
        padding: a11y.buttonPadding,
        minimumSize: a11y.buttonMinSize,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.poppins(
          fontSize: a11y.buttonFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        padding: a11y.buttonPadding,
        minimumSize: a11y.buttonMinSize,
        textStyle: GoogleFonts.poppins(
          fontSize: a11y.buttonFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData _buildFabTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: Colors.black87,
      elevation: 4,
      highlightElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  static ChipThemeData _buildChipTheme(ColorPalette palette, ThemeAccessibility a11y) {
    return ChipThemeData(
      backgroundColor: palette.card,
      labelStyle: GoogleFonts.poppins(
        fontSize: a11y.baseFontSize * 0.9,
        color: palette.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.borderColor, width: a11y.outlineWidth),
      ),
      selectedColor: palette.accent.withOpacity(0.2),
      secondarySelectedColor: palette.accent.withOpacity(0.2),
      deleteIconColor: palette.textSecondary,
    );
  }
}

import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1A237E);
  static const Color accent = Color(0xFF00E5FF);
  static const Color background = Color(0xFF0A0E27);
  static const Color surface = Color(0xFF12172E);
  static const Color errorColor = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFF9100);
  static const Color success = Color(0xFF00E676);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF90A4AE);
  static const Color cardColor = Color(0xFF1A2040);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        background: background,
        error: errorColor,
        onPrimary: textPrimary,
        onSecondary: background,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A3560)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A3560)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        prefixIconColor: accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        titleMedium: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: textPrimary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A3560)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A3560),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: const IconThemeData(color: accent),
    );
  }

  static Color riskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'safe':
        return success;
      case 'low':
        return const Color(0xFF69F0AE);
      case 'medium':
        return warning;
      case 'high':
        return const Color(0xFFFF6D00);
      case 'critical':
        return errorColor;
      default:
        return textSecondary;
    }
  }

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'info':
        return accent;
      case 'warning':
        return warning;
      case 'critical':
        return errorColor;
      default:
        return textSecondary;
    }
  }
}

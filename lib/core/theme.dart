import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart' as new_theme;
import 'theme/app_theme_enum.dart';

// ────────────────────────────────────────────────────────────────────────────
// Shared colour constants (same in both themes unless overridden)
// ────────────────────────────────────────────────────────────────────────────
class AppColors {
  // Brand
  static const accentDark  = Color(0xFF00E5FF); // cyan
  static const accentLight = Color(0xFF0066CC); // professional blue

  // Backgrounds — dark
  static const bgDark      = Color(0xFF0A0E27);
  static const surfaceDark = Color(0xFF12172E);
  static const cardDark    = Color(0xFF1A2040);
  static const primaryDark = Color(0xFF1A237E);

  // Backgrounds — light
  static const bgLight      = Color(0xFFF5F7FF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const cardLight    = Color(0xFFEEF2FF);
  static const primaryLight = Color(0xFF1A237E);

  // Status (same in both)
  static const error   = Color(0xFFE53935);
  static const warning = Color(0xFFFB8C00);
  static const success = Color(0xFF00C853);

  // Text — dark
  static const textPrimaryDark   = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFF90A4AE);

  // Text — light
  static const textPrimaryLight   = Color(0xFF0D1B3E);
  static const textSecondaryLight = Color(0xFF5C6B8A);
}

// ────────────────────────────────────────────────────────────────────────────
// AppTheme — static helpers used throughout the app
// ────────────────────────────────────────────────────────────────────────────
class AppTheme {
  // NEW: Get ThemeData for any theme type (delegates to new system)
  static ThemeData getTheme(AppThemeType themeType) =>
      new_theme.AppTheme.getTheme(themeType);

  // LEGACY: These getters adapt based on current brightness — use in widgets via
  // Theme.of(context).brightness when needed, or use the static constants
  // below for the dark-mode defaults (most of the app uses dark).

  // Dark-mode statics (unchanged so existing code doesn't break)
  static const Color primary       = AppColors.primaryDark;
  static const Color accent        = AppColors.accentDark;
  static const Color background    = AppColors.bgDark;
  static const Color surface       = AppColors.surfaceDark;
  static const Color errorColor    = AppColors.error;
  static const Color warning       = AppColors.warning;
  static const Color success       = AppColors.success;
  static const Color textPrimary   = AppColors.textPrimaryDark;
  static const Color textSecondary = AppColors.textSecondaryDark;
  static const Color cardColor     = AppColors.cardDark;

  // ── Helper: pick colour based on brightness ────────────────────────────
  static Color accentOf(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
          ? AppColors.accentDark
          : AppColors.accentLight;

  // ── Base text theme (Poppins) ──────────────────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary) =>
      GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge:  GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w700, fontSize: 28),
        headlineMedium: GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w700, fontSize: 22),
        headlineSmall:  GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w600, fontSize: 18),
        titleLarge:     GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w600, fontSize: 16),
        titleMedium:    GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w500, fontSize: 14),
        titleSmall:     GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w500, fontSize: 13),
        bodyLarge:      GoogleFonts.poppins(color: primary, fontSize: 15),
        bodyMedium:     GoogleFonts.poppins(color: secondary, fontSize: 13),
        bodySmall:      GoogleFonts.poppins(color: secondary, fontSize: 11),
        labelLarge:     GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium:    GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall:     GoogleFonts.poppins(color: secondary, fontSize: 10, letterSpacing: 0.5),
      );

  // ── Dark theme ─────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme(
        brightness:   Brightness.dark,
        accent:       AppColors.accentDark,
        bg:           AppColors.bgDark,
        surface:      AppColors.surfaceDark,
        card:         AppColors.cardDark,
        textPrimary:  AppColors.textPrimaryDark,
        textSecondary:AppColors.textSecondaryDark,
        divider:      const Color(0xFF2A3560),
        border:       const Color(0xFF2A3560),
      );

  // ── Light theme ────────────────────────────────────────────────────────
  static ThemeData get lightTheme => _buildTheme(
        brightness:   Brightness.light,
        accent:       AppColors.accentLight,
        bg:           AppColors.bgLight,
        surface:      AppColors.surfaceLight,
        card:         AppColors.cardLight,
        textPrimary:  AppColors.textPrimaryLight,
        textSecondary:AppColors.textSecondaryLight,
        divider:      const Color(0xFFCFD8DC),
        border:       const Color(0xFFBBCBE8),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color accent,
    required Color bg,
    required Color surface,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness:   brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness:     brightness,
        primary:        AppColors.primaryDark,
        onPrimary:      Colors.white,
        secondary:      accent,
        onSecondary:    isDark ? AppColors.bgDark : Colors.white,
        surface:        surface,
        onSurface:      textPrimary,
        error:          AppColors.error,
        onError:        Colors.white,
      ),
      textTheme: _textTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor:  surface,
        foregroundColor:  textPrimary,
        elevation:        0,
        centerTitle:      true,
        titleTextStyle:   GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: accent),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 4 : 2,
        shadowColor: isDark ? Colors.black38 : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF12172E) : const Color(0xFFF0F4FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
        hintStyle:  GoogleFonts.poppins(color: textSecondary.withOpacity(0.6), fontSize: 13),
        prefixIconColor: accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          elevation: isDark ? 4 : 2,
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:     surface,
        selectedItemColor:   accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:   GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        labelStyle: GoogleFonts.poppins(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: GoogleFonts.poppins(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: IconThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? accent.withOpacity(0.4)
                : Colors.grey.withOpacity(0.3)),
      ),
    );
  }

  // ── Risk / severity colour helpers (unchanged) ─────────────────────────
  static Color riskColor(String level) => switch (level.toLowerCase()) {
        'safe'     => AppColors.success,
        'low'      => const Color(0xFF69F0AE),
        'medium'   => AppColors.warning,
        'high'     => const Color(0xFFFF6D00),
        'critical' => AppColors.error,
        _          => AppColors.textSecondaryDark,
      };

  static Color severityColor(String s) => switch (s.toLowerCase()) {
        'info'     => AppColors.accentDark,
        'warning'  => AppColors.warning,
        'critical' => AppColors.error,
        _          => AppColors.textSecondaryDark,
      };
}

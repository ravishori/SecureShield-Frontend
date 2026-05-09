/// Theme state management using Riverpod
///
/// Handles:
/// - Theme persistence via SharedPreferences
/// - Theme switching with reactive updates
/// - Theme state retrieval
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_enum.dart';

// ──────────────────────────────────────────────────────────────────────────
// SHARED PREFERENCES PROVIDER (if not already defined)
// ──────────────────────────────────────────────────────────────────────────

/// Provider for SharedPreferences singleton
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// ──────────────────────────────────────────────────────────────────────────
// THEME STATE
// ──────────────────────────────────────────────────────────────────────────

/// Theme state containing the selected theme and related configuration
class ThemeState {
  /// Default timestamp for initial state
  static final DateTime _defaultTime = DateTime(2024, 1, 1);

  /// The currently selected theme
  final AppThemeType themeType;

  /// Whether the theme matches system dark mode (optional)
  final bool isSystemDark;

  /// Last changed timestamp
  final DateTime lastChanged;

  ThemeState({
    required this.themeType,
    this.isSystemDark = false,
    DateTime? lastChanged,
  }) : lastChanged = lastChanged ?? DateTime(2024, 1, 1);

  /// Convenience getter - returns true if theme has dark background
  bool get isDark => themeType == AppThemeType.dark ||
      themeType == AppThemeType.cybersecurity;

  /// Convenience getter - returns true if theme is accessibility-focused
  bool get isAccessible => themeType == AppThemeType.seniorCitizen ||
      themeType == AppThemeType.cybersecurity;

  /// Returns the ThemeMode for MaterialApp
  ThemeMode get themeMode {
    if (themeType == AppThemeType.light) {
      return ThemeMode.light;
    } else if (isDark) {
      return ThemeMode.dark;
    }
    return ThemeMode.system;
  }

  /// Copy with modifications
  ThemeState copyWith({
    AppThemeType? themeType,
    bool? isSystemDark,
    DateTime? lastChanged,
  }) {
    return ThemeState(
      themeType: themeType ?? this.themeType,
      isSystemDark: isSystemDark ?? this.isSystemDark,
      lastChanged: lastChanged ?? this.lastChanged,
    );
  }

  @override
  String toString() => 'ThemeState(theme: ${themeType.name}, '
      'isDark: $isDark, isAccessible: $isAccessible)';
}

// ──────────────────────────────────────────────────────────────────────────
// THEME NOTIFIER
// ──────────────────────────────────────────────────────────────────────────

/// StateNotifier for managing theme state
class ThemeNotifier extends StateNotifier<ThemeState> {
  final SharedPreferences prefs;

  static const String _prefKeyTheme = 'app_theme_type';
  static const String _prefKeyLastChanged = 'app_theme_last_changed';

  /// Initialize with default theme
  ThemeNotifier(this.prefs)
      : super(ThemeState(themeType: AppThemeType.dark)) {
    _loadTheme();
  }

  /// Load theme from persistent storage asynchronously
  Future<void> _loadTheme() async {
    try {
      final savedTheme = prefs.getString(_prefKeyTheme);
      final lastChanged = prefs.getString(_prefKeyLastChanged);

      AppThemeType themeType = AppThemeType.dark;
      DateTime? changedTime;

      if (savedTheme != null) {
        try {
          themeType = AppThemeType.values.firstWhere(
            (t) => t.name == savedTheme,
          );
          if (lastChanged != null) {
            changedTime = DateTime.parse(lastChanged);
          }
        } catch (e) {
          // Ignore parsing errors, use default
          debugPrint('Error loading theme: $e');
        }
      }

      state = ThemeState(
        themeType: themeType,
        lastChanged: changedTime ?? state.lastChanged,
      );
    } catch (e) {
      debugPrint('Error loading theme from storage: $e');
    }
  }

  /// Set the theme and persist to storage
  Future<void> setTheme(AppThemeType themeType) async {
    try {
      // Update state
      state = ThemeState(
        themeType: themeType,
        isSystemDark: state.isSystemDark,
        lastChanged: DateTime.now(),
      );

      // Persist to storage
      await prefs.setString(_prefKeyTheme, themeType.name);
      await prefs.setString(
        _prefKeyLastChanged,
        DateTime.now().toIso8601String(),
      );

      debugPrint('Theme changed to: ${themeType.displayName}');
    } catch (e) {
      debugPrint('Error saving theme: $e');
      rethrow;
    }
  }

  /// Toggle between light and dark themes
  Future<void> toggleTheme() async {
    final next = state.isDark ? AppThemeType.light : AppThemeType.dark;
    await setTheme(next);
  }

  /// Cycle through all themes
  Future<void> cycleTheme() async {
    final currentIndex = AppThemeType.values.indexOf(state.themeType);
    final nextIndex = (currentIndex + 1) % AppThemeType.values.length;
    await setTheme(AppThemeType.values[nextIndex]);
  }

  /// Reset to default theme (dark)
  Future<void> resetToDefault() async {
    await setTheme(AppThemeType.dark);
  }

  /// Get all available themes
  List<AppThemeType> getAvailableThemes() {
    return AppThemeType.values;
  }

  /// Get theme info
  String getThemeInfo(AppThemeType theme) {
    return '${theme.emoji} ${theme.displayName}';
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PROVIDER DEFINITIONS
// ──────────────────────────────────────────────────────────────────────────

/// StateNotifierProvider for theme management
///
/// Usage:
/// ```dart
/// // Watch current theme
/// final themeState = ref.watch(themeProvider);
///
/// // Get theme type
/// final themeType = themeState.themeType;
///
/// // Set theme
/// await ref.read(themeProvider.notifier).setTheme(AppThemeType.light);
///
/// // Toggle theme
/// await ref.read(themeProvider.notifier).toggleTheme();
/// ```
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  // Get SharedPreferences from a synchronous source
  // This will be initialized in main() and stored in a static variable
  return ThemeNotifier(ThemeStorage.prefs);
});

/// Internal storage for SharedPreferences instance
class ThemeStorage {
  static late SharedPreferences prefs;
}

// Alternative synchronous provider (for testing)
final themeTypeProvider = Provider<AppThemeType>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.themeType;
});

// Provider for theme mode (for MaterialApp)
final themeModeProvider = Provider<ThemeMode>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.themeMode;
});

// Provider for checking if theme is dark
final isDarkThemeProvider = Provider<bool>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.isDark;
});

// Provider for checking if theme is accessibility-focused
final isAccessibleThemeProvider = Provider<bool>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.isAccessible;
});

// ──────────────────────────────────────────────────────────────────────────
// CONSUMER HELPER EXTENSIONS
// ──────────────────────────────────────────────────────────────────────────

/// Extensions for easy theme access in ConsumerWidgets
extension ThemeConsumerExtension on WidgetRef {
  /// Get the current theme type
  AppThemeType get currentTheme {
    return watch(themeTypeProvider);
  }

  /// Get the current theme state
  ThemeState get themeState {
    return watch(themeProvider);
  }

  /// Set a new theme
  Future<void> setTheme(AppThemeType themeType) async {
    return read(themeProvider.notifier).setTheme(themeType);
  }

  /// Toggle between light and dark
  Future<void> toggleTheme() async {
    return read(themeProvider.notifier).toggleTheme();
  }

  /// Cycle through all themes
  Future<void> cycleTheme() async {
    return read(themeProvider.notifier).cycleTheme();
  }

  /// Check if current theme is dark
  bool get isDark {
    return watch(isDarkThemeProvider);
  }

  /// Check if current theme is accessibility-focused
  bool get isAccessible {
    return watch(isAccessibleThemeProvider);
  }
}

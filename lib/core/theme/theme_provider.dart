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
  // ignore: unused_field
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

  /// True for themes with a dark surface (bg brightness = dark).
  bool get isDark => themeType.isDark;

  /// True for themes that come pre-tuned for accessibility (currently only
  /// High Contrast). Regular themes can still be paired with the orthogonal
  /// Accessibility Mode toggle for the same benefits.
  bool get isAccessible => themeType == AppThemeType.highContrast;

  /// Returns the ThemeMode for MaterialApp.
  ThemeMode get themeMode =>
      themeType == AppThemeType.corporateLight ? ThemeMode.light : ThemeMode.dark;

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

  /// Initialize with the new default theme (Defender Blue).
  ThemeNotifier(this.prefs)
      : super(ThemeState(themeType: AppThemeType.defenderBlue)) {
    _loadTheme();
  }

  /// Load theme from SharedPreferences.
  ///
  /// Includes MIGRATION for legacy stored keys — users who last used the
  /// old themes (dark / light / cybersecurity / seniorCitizen / natureGreen)
  /// will be transparently upgraded to the closest new equivalent.
  Future<void> _loadTheme() async {
    try {
      final savedTheme  = prefs.getString(_prefKeyTheme);
      final lastChanged = prefs.getString(_prefKeyLastChanged);

      AppThemeType themeType = AppThemeType.defenderBlue;
      DateTime? changedTime;

      if (savedTheme != null) {
        // `fromLegacyKey` handles BOTH old and new keys, so calling it here
        // means we don't need a separate migration pass.
        final migrated = AppThemeType.fromLegacyKey(savedTheme);
        if (migrated != null) {
          themeType = migrated;
          if (migrated.storageKey != savedTheme) {
            // Persist the migrated key so we don't do this lookup again.
            await prefs.setString(_prefKeyTheme, migrated.storageKey);
            debugPrint(
                'Migrated legacy theme "$savedTheme" → "${migrated.storageKey}"');
          }
        } else {
          debugPrint('Unknown saved theme "$savedTheme" — falling back to default');
        }
        if (lastChanged != null) {
          changedTime = DateTime.tryParse(lastChanged);
        }
      }

      state = ThemeState(
        themeType:   themeType,
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

  /// Toggle between the flagship light and dark themes.
  Future<void> toggleTheme() async {
    final next = state.isDark
        ? AppThemeType.corporateLight
        : AppThemeType.defenderBlue;
    await setTheme(next);
  }

  /// Cycle through all themes
  Future<void> cycleTheme() async {
    final currentIndex = AppThemeType.values.indexOf(state.themeType);
    final nextIndex = (currentIndex + 1) % AppThemeType.values.length;
    await setTheme(AppThemeType.values[nextIndex]);
  }

  /// Reset to default theme (Defender Blue).
  Future<void> resetToDefault() async {
    await setTheme(AppThemeType.defenderBlue);
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

// ═══════════════════════════════════════════════════════════════════════════
// ACCESSIBILITY MODE — orthogonal to theme selection.
//
// A user can pick Enterprise Dark *and* turn on Accessibility Mode; the
// accessibility settings (larger fonts, ≥48dp targets, reduced motion,
// higher-contrast text) layer on top of whatever theme they chose. This
// follows Microsoft/Apple/Google's separation of "look" from "assistive
// controls" and lets users get accessibility without being restricted to
// one hard-coded palette.
// ═══════════════════════════════════════════════════════════════════════════

/// Accessibility mode preferences — persisted separately from the theme.
class AccessibilityMode {
  /// Larger typography across the app (approx 15–20% up).
  final bool largerText;

  /// Minimum 56 dp touch targets, extra padding on cards/buttons.
  final bool largerTouchTargets;

  /// Boost text contrast (text tertiary → text primary, disable overlays).
  final bool higherContrast;

  /// Cut idle animations (grid drift, pulses) for motion-sensitive users.
  final bool reduceMotion;

  const AccessibilityMode({
    this.largerText         = false,
    this.largerTouchTargets = false,
    this.higherContrast     = false,
    this.reduceMotion       = false,
  });

  /// Convenience: is ANY accessibility feature on?
  bool get isActive =>
      largerText || largerTouchTargets || higherContrast || reduceMotion;

  AccessibilityMode copyWith({
    bool? largerText,
    bool? largerTouchTargets,
    bool? higherContrast,
    bool? reduceMotion,
  }) =>
      AccessibilityMode(
        largerText:         largerText         ?? this.largerText,
        largerTouchTargets: largerTouchTargets ?? this.largerTouchTargets,
        higherContrast:     higherContrast     ?? this.higherContrast,
        reduceMotion:       reduceMotion       ?? this.reduceMotion,
      );
}

/// StateNotifier managing the accessibility mode preferences.
class AccessibilityModeNotifier extends StateNotifier<AccessibilityMode> {
  final SharedPreferences prefs;

  static const _kLargerText     = 'a11y_larger_text';
  static const _kLargerTargets  = 'a11y_larger_targets';
  static const _kHigherContrast = 'a11y_higher_contrast';
  static const _kReduceMotion   = 'a11y_reduce_motion';

  AccessibilityModeNotifier(this.prefs) : super(const AccessibilityMode()) {
    _load();
  }

  void _load() {
    state = AccessibilityMode(
      largerText:         prefs.getBool(_kLargerText)     ?? false,
      largerTouchTargets: prefs.getBool(_kLargerTargets)  ?? false,
      higherContrast:     prefs.getBool(_kHigherContrast) ?? false,
      reduceMotion:       prefs.getBool(_kReduceMotion)   ?? false,
    );
  }

  Future<void> setLargerText(bool v) async {
    state = state.copyWith(largerText: v);
    await prefs.setBool(_kLargerText, v);
  }

  Future<void> setLargerTouchTargets(bool v) async {
    state = state.copyWith(largerTouchTargets: v);
    await prefs.setBool(_kLargerTargets, v);
  }

  Future<void> setHigherContrast(bool v) async {
    state = state.copyWith(higherContrast: v);
    await prefs.setBool(_kHigherContrast, v);
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    await prefs.setBool(_kReduceMotion, v);
  }

  Future<void> disableAll() async {
    state = const AccessibilityMode();
    await Future.wait([
      prefs.setBool(_kLargerText,     false),
      prefs.setBool(_kLargerTargets,  false),
      prefs.setBool(_kHigherContrast, false),
      prefs.setBool(_kReduceMotion,   false),
    ]);
  }
}

/// Provider for reading + updating accessibility mode from anywhere.
final accessibilityModeProvider =
    StateNotifierProvider<AccessibilityModeNotifier, AccessibilityMode>((ref) {
  return AccessibilityModeNotifier(ThemeStorage.prefs);
});

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

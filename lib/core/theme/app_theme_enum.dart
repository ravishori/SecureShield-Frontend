/// Theme type enum for the SecureShield app
///
/// Supports 5 distinct themes optimized for different use cases:
/// - Light: Professional, clean, accessibility-focused
/// - Dark: Default dark mode, balanced blue/cyan accents
/// - Cybersecurity: Dark theme with neon security colors for threat visualization
/// - Senior Citizen: High contrast, large fonts, simplified for elderly users
/// - Nature Green: Calming green palette with earthy, outdoor-inspired colors
library;

enum AppThemeType {
  /// Light theme - Professional white background with dark text
  /// Best for: Office environments, accessibility-focused users
  /// Contrast Ratio: WCAG AA (4.5:1)
  light('Light', '💡'),

  /// Dark theme - Original dark mode with cyan accents
  /// Best for: Reduced eye strain, modern appearance
  /// Accent Color: Cyan (#00E5FF)
  dark('Dark', '🌙'),

  /// Cybersecurity theme - Dark with neon security colors
  /// Best for: Security professionals, threat visualization
  /// Accent: Neon green (#00FF00), Threat: Pure red (#FF0000)
  /// Contrast Ratio: WCAG AAA (7:1)
  cybersecurity('Cyber Security', '🔐'),

  /// Senior Citizen theme - Large fonts, high contrast, simplified UI
  /// Best for: Elderly users, accessibility-first design
  /// Base Font Size: 18px (28% larger than standard)
  /// Contrast Ratio: WCAG AAA (7:1)
  seniorCitizen('Senior Citizen', '👴'),

  /// Nature Green theme - Green palette with calming, outdoor colors
  /// Best for: Relaxing interface, nature-inspired design
  /// Primary: Forest green (#2D5016), Accent: Natural green (#4CAF50)
  natureGreen('Nature Green', '🌿');

  /// Display name for UI
  final String displayName;

  /// Emoji icon for visual identification in theme picker
  final String emoji;

  const AppThemeType(this.displayName, this.emoji);

  /// Returns true if this theme has a dark background
  bool get isDark {
    return this == AppThemeType.dark ||
        this == AppThemeType.cybersecurity ||
        this == AppThemeType.seniorCitizen;
  }

  /// Returns true if this theme is designed for accessibility
  bool get isAccessibilityMode {
    return this == AppThemeType.seniorCitizen ||
        this == AppThemeType.cybersecurity;
  }

  /// Returns the theme name as a string key for storage
  String get storageKey => name;
}

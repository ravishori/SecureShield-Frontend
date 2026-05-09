# 🎨 SecureShield Theme System

A comprehensive, scalable theme architecture supporting 5 distinct themes with Material 3, accessibility features, and persistent user preferences.

## Overview

This theme system provides:

- **5 Complete Themes**: Light, Dark, Cybersecurity, Senior Citizen, Nature Green
- **Material 3 Support**: Full Material Design 3 implementation
- **Accessibility**: Theme-specific settings for font sizes and contrast ratios
- **Persistence**: SharedPreferences-backed theme storage
- **Type Safety**: Enum-based theme selection
- **Reactive Updates**: Riverpod-powered reactive state management
- **Semantic Colors**: Theme-agnostic color tokens mapped to theme-specific values

## File Structure

```
lib/core/theme/
├── app_theme_enum.dart           # Theme type enum with metadata
├── app_colors.dart               # 5 color palettes with semantic colors
├── app_theme.dart                # ThemeData builders for all 5 themes
├── app_theme_extensions.dart     # Accessibility settings & semantic colors
├── theme_provider.dart           # Riverpod state management
└── README.md                      # This file
```

## Quick Start

### 1. Get Current Theme

```dart
// In a ConsumerWidget
final themeState = ref.watch(themeProvider);
final currentTheme = themeState.themeType;
```

### 2. Change Theme

```dart
// Toggle between light/dark
await ref.read(themeProvider.notifier).toggleTheme();

// Set specific theme
await ref.read(themeProvider.notifier).setTheme(AppThemeType.seniorCitizen);

// Cycle through all themes
await ref.read(themeProvider.notifier).cycleTheme();
```

### 3. Use Theme Colors

```dart
// Access colors from palette
final palette = AppThemeType.light.palette;
Color threatColor = palette.threat;

// Use semantic colors
Color threatColor = AppThemeType.cybersecurity.threatColor();
Color safeColor = AppThemeType.natureGreen.safeColor();

// From BuildContext
Color accentColor = context.accentColor;
Color threatColor = context.threatColor;
```

## Theme Specifications

### 1. Light Theme 💡

**Best for**: Office environments, professional users, accessibility

- **Background**: Light lavender (#F5F7FF)
- **Text**: Dark navy (#0D1B3E)
- **Accent**: Professional blue (#0066CC)
- **Threat**: Deep red (#D32F2F)
- **Contrast**: WCAG AA (4.5:1)

### 2. Dark Theme 🌙

**Best for**: Reduced eye strain, modern appearance (default)

- **Background**: Very dark navy (#0A0E27)
- **Accent**: Cyan (#00E5FF)
- **Threat**: Bright red (#FF1744)
- **Safe**: Bright green (#00C853)
- **Contrast**: WCAG AA (4.5:1)

### 3. Cybersecurity Theme 🔐

**Best for**: Security professionals, threat visualization

- **Background**: Very dark (#0A0E27)
- **Accent**: Neon green (#00FF00) for "secure"
- **Threat**: Pure red (#FF0000) for maximum alert
- **Warning**: Neon yellow (#FFFF00)
- **Contrast**: WCAG AAA (7:1)
- **Font Size**: Standard 14px
- **Border Width**: 1.5px

### 4. Senior Citizen Theme 👴

**Best for**: Elderly users, accessibility-first design

- **Background**: Soft white (#F5F5F5)
- **Text**: Very dark (#1A1A1A) - high contrast
- **Accent**: Saturated blue (#0066CC)
- **Threat**: Deep red (#C62828)
- **Contrast**: WCAG AAA (7:1)
- **Font Size**: 18px (28% larger)
- **Button Size**: 56x56 (larger touch targets)
- **Border Width**: 2px (thicker for clarity)

### 5. Nature Green Theme 🌿

**Best for**: Calming interface, nature-inspired design

- **Primary**: Dark forest green (#2D5016)
- **Accent**: Natural green (#4CAF50)
- **Background**: Light nature white (#F1F8E9)
- **Threat**: Muted red (#E57373)
- **Card Borders**: Green (#C5E1A5)
- **Contrast**: WCAG AA (4.5:1)
- **Border Radius**: Increased (16px) for natural feel

## Accessibility Features

Each theme includes theme-specific accessibility settings:

### Standard Accessibility (Light, Dark, Nature Green)

```dart
ThemeAccessibility.standard:
- Base Font: 14px
- Headline Font: 24px
- Button Size: 48x48
- Contrast Ratio: 4.5:1 (WCAG AA)
- Border Width: 1px
```

### High Contrast (Cybersecurity)

```dart
ThemeAccessibility.highContrast:
- Base Font: 16px
- Headline Font: 28px
- Button Size: 52x52
- Contrast Ratio: 7:1 (WCAG AAA)
- Border Width: 1.5px
```

### Senior Citizen

```dart
ThemeAccessibility.senior:
- Base Font: 18px (28% larger)
- Headline Font: 32px (33% larger)
- Button Size: 56x56 (larger touch targets)
- Contrast Ratio: 7:1 (WCAG AAA)
- Border Width: 2px (thicker borders)
```

## Semantic Colors

Colors are named by their semantic purpose, not appearance:

```dart
// Status colors
- threatColor()       // Red/danger
- safeColor()        // Green/secure
- warningColor()     // Yellow/caution
- emergencyColor()   // Bright red/immediate action
- errorColor()       // Same as threat
- successColor()     // Same as safe
- infoColor()        // Accent color
- disabledColor()    // Gray/inactive
```

Access via theme extension:

```dart
final threatRed = AppThemeType.light.threatColor();
final safeGreen = AppThemeType.dark.safeColor();

// Get all status colors
final colors = AppThemeType.cybersecurity.statusColors;
// Returns: Map<String, Color> with all semantic colors
```

## Integration in main.dart

```dart
class SecureShieldApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeType = themeState.themeType;

    return MaterialApp.router(
      theme: AppTheme.getTheme(AppThemeType.light),  // Light fallback
      darkTheme: AppTheme.getTheme(AppThemeType.dark), // Dark fallback
      themeMode: themeState.themeMode,                 // User's choice
      // Use dynamic theme based on user selection
      home: Material(
        child: Theme(
          data: AppTheme.getTheme(themeType),
          child: YourApp(),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

## Usage Examples

### Example 1: Theme Switcher Button

```dart
Consumer(
  builder: (context, ref, child) {
    final themeState = ref.watch(themeProvider);
    
    return PopupMenuButton<AppThemeType>(
      itemBuilder: (_) => [
        for (final theme in AppThemeType.values)
          PopupMenuItem(
            value: theme,
            child: Row(
              children: [
                Text(theme.emoji),
                SizedBox(width: 8),
                Text(theme.displayName),
              ],
            ),
          ),
      ],
      onSelected: (theme) {
        ref.read(themeProvider.notifier).setTheme(theme);
      },
      child: Icon(Icons.palette),
    );
  },
)
```

### Example 2: Adapt Colors to Theme

```dart
Container(
  color: AppThemeType.light.threatColor(),  // Get threat color for light theme
  child: Text(
    'Threat Detected',
    style: TextStyle(
      color: AppThemeType.light.safeColor(), // Contrast against threat color
    ),
  ),
)
```

### Example 3: Accessibility-Aware Widget

```dart
final a11y = AppThemeType.seniorCitizen.accessibility;

ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    padding: a11y.buttonPadding,
    minimumSize: a11y.buttonMinSize,
  ),
  child: Text(
    'Click Me',
    style: TextStyle(fontSize: a11y.buttonFontSize),
  ),
)
```

### Example 4: Check Current Theme

```dart
Consumer(
  builder: (context, ref, child) {
    final isDark = ref.watch(isDarkThemeProvider);
    final isAccessible = ref.watch(isAccessibleThemeProvider);
    
    return Text(
      isDark ? '🌙 Dark Mode' : '☀️ Light Mode',
      style: TextStyle(
        fontSize: isAccessible ? 18 : 14,
      ),
    );
  },
)
```

## Color Palette Structure

Each palette implements `_ColorPalette` with:

- **Brand Colors**: primary, secondary, accent
- **Layout Colors**: background, surface, card, overlay
- **Text Colors**: textPrimary, textSecondary, textTertiary
- **Status Colors**: threat, safe, warning, emergency
- **Feature Colors**: cyan, red, orange, green, purple, lightPurple, lightCyan
- **Utility Colors**: borderColor, dividerColor, disabledColor, shadowColor

## Testing

### Visual Testing Checklist

- [ ] Light theme - Verify dark text on light backgrounds
- [ ] Dark theme - Verify cyan accent visibility
- [ ] Cybersecurity - Verify neon colors (green/red) are distinct
- [ ] Senior citizen - Verify font sizes (18px+), button sizes (56x56)
- [ ] Nature green - Verify green palette cohesion

### Functional Testing

- [ ] Theme persists after app kill
- [ ] All screens update when theme changes
- [ ] Theme picker shows all 5 options
- [ ] Switching themes is responsive (no lag)

### Accessibility Testing

- [ ] Senior citizen theme has 18px base font
- [ ] All text meets WCAG AA/AAA contrast ratios
- [ ] Buttons are minimum 48x48 (or 56x56 for senior)
- [ ] Non-color indicators present (not just color)

## Migration from Old Theme System

### Old Code
```dart
// OLD: Using AppTheme static helpers
Color color = AppTheme.accent;
ThemeMode mode = ThemeMode.dark;
```

### New Code
```dart
// NEW: Using type-safe enums
Color color = AppThemeType.dark.palette.accent;
ThemeMode mode = AppThemeType.dark.themeMode;

// Or via provider
final themeType = ref.watch(themeTypeProvider);
```

## API Reference

### AppThemeType Enum

```dart
enum AppThemeType {
  light,           // Professional light theme
  dark,            // Default dark mode
  cybersecurity,   // Security-focused with neon colors
  seniorCitizen,   // High contrast, large fonts
  natureGreen;     // Calming green palette
  
  String get displayName;   // "Light", "Dark", etc.
  String get emoji;         // 💡, 🌙, 🔐, 👴, 🌿
  bool get isDark;          // true if dark background
  bool get isAccessibilityMode;  // true if accessibility-focused
}
```

### ThemeState

```dart
class ThemeState {
  final AppThemeType themeType;
  final bool isDark;           // Convenience getter
  final bool isAccessible;     // Convenience getter
  final ThemeMode themeMode;   // For MaterialApp
  final DateTime lastChanged;
}
```

### ThemeAccessibility

```dart
class ThemeAccessibility {
  final double baseFontSize;        // Default 14.0
  final double headlineFontSize;    // Default 24.0
  final double buttonFontSize;      // Default 14.0
  final double contrastRatio;       // 4.5 (AA) or 7.0 (AAA)
  final double outlineWidth;        // 1.0-2.0
  final EdgeInsets buttonPadding;
  final Size buttonMinSize;
}
```

## Performance Considerations

- Theme switching is instant (no rebuild lag)
- Theme persists asynchronously without blocking UI
- ColorScheme is computed once at app startup
- No theme data re-created on every rebuild
- Riverpod caches theme state efficiently

## Future Enhancements

- [ ] Dynamic theme creation from seed color
- [ ] User-custom color overrides
- [ ] Theme animation on switch
- [ ] Locale-specific color schemes
- [ ] High contrast mode toggle
- [ ] Per-component theme overrides

## Support

For issues or questions about the theme system:

1. Check the theme enum display names and accessibility settings
2. Verify semantic colors are being used correctly
3. Ensure SharedPreferences is initialized before using theme
4. Check that MaterialApp is using AppTheme.getTheme()

## License

Part of SecureShield AI - Confidential

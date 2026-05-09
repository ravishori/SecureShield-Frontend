# 🔄 Theme System Migration Guide

This guide helps you upgrade existing code from the old theme system to the new scalable multi-theme architecture.

## Summary of Changes

| Aspect | Old System | New System |
|--------|-----------|-----------|
| **Theme Selection** | `ThemeMode.light/.dark` | `AppThemeType` enum (5 themes) |
| **Color Access** | `AppTheme.accent`, `AppTheme.cardColor` | `AppThemeType.dark.palette.accent` |
| **State Management** | `StateNotifier<ThemeMode>` | `StateNotifier<ThemeState>` |
| **Storage Key** | `'app_theme_mode'` | `'app_theme_type'` |
| **Provider** | `themeProvider` (same) | `themeProvider` (enhanced) |
| **Import Path** | `core/theme.dart` | `core/theme/app_theme_enum.dart`, `core/theme/app_theme.dart` |

## Migration Steps

### Step 1: Update Imports

**Old:**
```dart
import 'core/theme.dart';
import 'core/providers/theme_provider.dart';
```

**New:**
```dart
import 'core/theme/app_theme_enum.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme_extensions.dart';  // For accessibility
```

### Step 2: Color Access Patterns

**Old:**
```dart
Color accentColor = AppTheme.accent;
Color cardColor = AppTheme.cardColor;
Color threatColor = AppTheme.threatColor;
```

**New:**
```dart
// Via palette
Color accentColor = AppThemeType.dark.palette.accent;
Color cardColor = AppThemeType.dark.palette.card;

// Via semantic colors
Color threatColor = AppThemeType.dark.threatColor();

// From BuildContext (recommended)
Color accentColor = context.accentColor;
Color threatColor = context.threatColor;
```

### Step 3: Theme Switching

**Old:**
```dart
// Switching between light/dark
await ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);

// Toggle
await ref.read(themeProvider.notifier).toggle();
```

**New:**
```dart
// Switching to any of 5 themes
await ref.read(themeProvider.notifier).setTheme(AppThemeType.seniorCitizen);

// Toggle between light/dark
await ref.read(themeProvider.notifier).toggleTheme();

// Cycle through all themes
await ref.read(themeProvider.notifier).cycleTheme();
```

### Step 4: Theme Checking

**Old:**
```dart
final themeMode = ref.watch(themeProvider);
if (themeMode == ThemeMode.dark) {
  // Dark mode logic
}
```

**New:**
```dart
// Option 1: Watch theme type
final themeType = ref.watch(themeTypeProvider);
if (themeType == AppThemeType.dark) {
  // Dark mode logic
}

// Option 2: Use convenience getter
final isDark = ref.watch(isDarkThemeProvider);
if (isDark) {
  // Dark mode logic
}

// Option 3: Full theme state
final themeState = ref.watch(themeProvider);
if (themeState.isDark) {
  // Dark mode logic
}
```

### Step 5: Accessibility Settings

**Old:**
```dart
// No built-in accessibility per theme
```

**New:**
```dart
// Get accessibility settings for theme
final a11y = AppThemeType.seniorCitizen.accessibility;

ElevatedButton(
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

### Step 6: Theme Picker UI

**Old:**
```dart
PopupMenuButton<ThemeMode>(
  initialValue: themeMode,
  onSelected: (mode) => ref.read(themeProvider.notifier).setTheme(mode),
  itemBuilder: (_) => [
    PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
    PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
  ],
)
```

**New:**
```dart
// Use the updated ThemeSwitcher widget (already done for you!)
PopupMenuButton<AppThemeType>(
  initialValue: themeState.themeType,
  onSelected: (theme) => ref.read(themeProvider.notifier).setTheme(theme),
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
)
```

## Common Patterns - Before & After

### Pattern 1: Adapt Widget Color to Theme

**Before:**
```dart
Container(
  color: AppTheme.accent,  // Always uses current theme's accent
  child: Text('Hello'),
)
```

**After:**
```dart
// Option A: Get from context (most common)
Container(
  color: context.accentColor,
  child: Text('Hello'),
)

// Option B: Get from palette directly
Container(
  color: AppThemeType.dark.palette.accent,
  child: Text('Hello'),
)

// Option C: Use semantic color
Container(
  color: AppThemeType.dark.threatColor(),
  child: Text('Hello'),
)
```

### Pattern 2: Check Current Theme for Conditional Logic

**Before:**
```dart
Consumer(
  builder: (context, ref, child) {
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;
    
    return Text(
      isDarkMode ? 'Dark Mode Active' : 'Light Mode Active',
    );
  },
)
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final isDark = ref.watch(isDarkThemeProvider);
    final themeType = ref.watch(themeTypeProvider);
    
    return Text(
      isDark ? '🌙 Dark Theme' : '☀️ Light Theme',
      // Optional: Use theme-specific logic
      style: TextStyle(
        fontSize: themeType.accessibility.baseFontSize,
      ),
    );
  },
)
```

### Pattern 3: Theme-Aware Button Styling

**Before:**
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.accent,
    foregroundColor: Colors.white,
  ),
  onPressed: () {},
  child: Text('Click'),
)
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final a11y = ref.watch(themeProvider).themeType.accessibility;
    final accentColor = context.accentColor;
    
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        padding: a11y.buttonPadding,
        minimumSize: a11y.buttonMinSize,
      ),
      onPressed: () {},
      child: Text(
        'Click',
        style: TextStyle(fontSize: a11y.buttonFontSize),
      ),
    );
  },
)
```

## Static References - Backward Compatibility

The old `AppTheme` class still exists in `lib/core/theme.dart` for backward compatibility:

```dart
// OLD - Still works, but uses dark theme colors only
Color color = AppTheme.accent;
Color cardColor = AppTheme.cardColor;

// NEW - Recommended approach
Color color = context.accentColor;
Color cardColor = context.surfaceColor;
```

**Note**: The old static accessors only show colors from the dark theme. For multi-theme support, use the new system.

## Provider Usage Patterns

### Watching Theme Changes

```dart
// Watch specific properties
final themeType = ref.watch(themeTypeProvider);
final isDark = ref.watch(isDarkThemeProvider);
final isAccessible = ref.watch(isAccessibleThemeProvider);

// Watch full theme state
final themeState = ref.watch(themeProvider);

// Read (not watch) for one-time access
final currentTheme = ref.read(themeTypeProvider);
```

### Setting Theme

```dart
// Use the notifier
final notifier = ref.read(themeProvider.notifier);

// Set specific theme
await notifier.setTheme(AppThemeType.light);

// Toggle light/dark
await notifier.toggleTheme();

// Cycle through all themes
await notifier.cycleTheme();

// Reset to default
await notifier.resetToDefault();
```

## Testing Migration

### Before Migration

```dart
testWidgets('Theme changes text color', (WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MyApp()),
  );
  
  // Verify dark theme
  expect(find.byType(Text), findsWidgets);
});
```

### After Migration

```dart
testWidgets('Theme changes text color', (WidgetTester tester) async {
  final container = ProviderContainer();
  
  addTearDown(container.dispose);
  
  // Set specific theme
  await container.read(themeProvider.notifier)
    .setTheme(AppThemeType.light);
  
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
  
  // Verify light theme colors
  final text = find.byType(Text).first;
  expect(text, findsOneWidget);
});
```

## Files to Update in Your Codebase

### 1. Files Using `AppTheme.accent` etc.

Search for:
- `AppTheme.accent`
- `AppTheme.cardColor`
- `AppTheme.textPrimary`
- `AppTheme.threatColor`

Replace with:
- `context.accentColor`
- `context.surfaceColor` 
- `Theme.of(context).colorScheme.onSurface`
- `AppThemeType.dark.threatColor()`

### 2. Files Using `ref.watch(themeProvider)` as `ThemeMode`

Update to:
```dart
final themeState = ref.watch(themeProvider);
final themeType = themeState.themeType;
final isDark = themeState.isDark;
```

### 3. Theme Switcher Widget References

Old imports:
```dart
import 'core/providers/theme_provider.dart';
import 'core/theme.dart';
```

New imports:
```dart
import 'core/theme/app_theme_enum.dart';
import 'core/theme/theme_provider.dart';
```

## Deprecation Timeline

**Phase 1 (Current)**: New system available, old system still works
- Use new system in new code
- Gradually migrate existing code

**Phase 2 (After 1 release)**: Old `lib/core/theme.dart` will be deprecated
- Strong recommendation to migrate
- Examples and guides provided

**Phase 3 (After 2 releases)**: Old system removed
- Must use new system
- Migration period over

## Troubleshooting

### Issue: "Cannot find type ThemeMode in new code"

**Solution**: Use `AppThemeType` instead
```dart
// ❌ Wrong
final mode = ThemeMode.dark;

// ✅ Correct
final mode = AppThemeType.dark;
```

### Issue: "AppTheme.accent not working with new themes"

**Solution**: Use context accessor or palette directly
```dart
// ❌ Wrong (uses dark theme colors only)
final color = AppTheme.accent;

// ✅ Correct (uses current theme)
final color = context.accentColor;

// ✅ Correct (explicit theme)
final color = AppThemeType.light.palette.accent;
```

### Issue: "SharedPreferences storage key mismatch"

**Solution**: Old data will auto-migrate on first load
- Old key: `'app_theme_mode'` → stores "light" or "dark"
- New key: `'app_theme_type'` → stores theme enum name
- Migration happens automatically in ThemeNotifier

## FAQ

**Q: Can I use both old and new systems together?**
A: Yes, for a transition period. New code should use the new system exclusively.

**Q: Will my saved theme preference be lost?**
A: No, users with saved "light" or "dark" preferences will have them automatically converted.

**Q: How do I get a theme-specific color?**
A: Use semantic colors: `AppThemeType.cybersecurity.threatColor()`

**Q: Can I still use `Theme.of(context)`?**
A: Yes, `Theme.of(context).colorScheme` still works and respects the current theme.

**Q: What about custom themes?**
A: Extend `_ColorPalette` class and add a new value to `AppThemeType` enum.

## Support

For questions during migration:
1. Check the theme README.md in lib/core/theme/
2. Review examples in this guide
3. See actual usage in lib/core/widgets/theme_switcher.dart

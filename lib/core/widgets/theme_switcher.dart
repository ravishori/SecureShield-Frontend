import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_enum.dart';
import '../theme/theme_provider.dart';
import '../theme.dart';

/// A compact dropdown button that lets the user switch between 5 themes:
/// Light, Dark, Cybersecurity, Senior Citizen, and Nature Green.
///
/// Persists the preference via [ThemeNotifier] → SharedPreferences.
///
/// Usage — in any AppBar actions list:
///   actions: [ const ThemeSwitcher(), ... ]
class ThemeSwitcher extends ConsumerWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final currentTheme = themeState.themeType;
    final accent = Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<AppThemeType>(
        initialValue: currentTheme,
        tooltip: 'Switch theme',
        icon: Icon(
          currentTheme.emoji == '🎨' ? Icons.palette : Icons.palette,
          color: accent,
          size: 22,
        ),
        // Custom icon showing current theme emoji
        // Alternatively, use: Text(currentTheme.emoji, style: TextStyle(fontSize: 22))
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withOpacity(0.25)),
        ),
        onSelected: (selectedTheme) async {
          await ref.read(themeProvider.notifier).setTheme(selectedTheme);

          // Show snackbar feedback
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Theme changed to ${selectedTheme.displayName}'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        itemBuilder: (_) => [
          for (final theme in AppThemeType.values)
            _buildThemeMenuItem(theme, currentTheme, context),
        ],
      ),
    );
  }

  /// Build a menu item for a single theme
  PopupMenuItem<AppThemeType> _buildThemeMenuItem(
    AppThemeType theme,
    AppThemeType currentTheme,
    BuildContext context,
  ) {
    final isSelected = theme == currentTheme;
    final accent = Theme.of(context).colorScheme.secondary;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return PopupMenuItem<AppThemeType>(
      value: theme,
      child: Row(
        children: [
          // Theme emoji
          Text(
            theme.emoji,
            style: TextStyle(
              fontSize: 18,
              color: isSelected ? accent : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          // Theme display name
          Expanded(
            child: Text(
              theme.displayName,
              style: TextStyle(
                color: isSelected ? accent : textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          // Checkmark if selected
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: accent,
            ),
        ],
      ),
    );
  }
}


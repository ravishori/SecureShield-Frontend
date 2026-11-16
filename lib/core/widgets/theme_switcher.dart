import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_enum.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/theme_provider.dart';

/// Compact app-bar action that opens a **modal bottom sheet** with:
///   • 7 professional visual themes, each shown with its swatch strip
///   • An independent Accessibility Mode toggle (larger text / targets /
///     contrast / reduced motion)
///
/// Persists both preferences via the Riverpod providers, which persist to
/// SharedPreferences internally. No context is used across async gaps —
/// `ScaffoldMessenger.of(context)` is captured before the theme change fires.
class ThemeSwitcher extends ConsumerWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Icon(Icons.palette_outlined, color: scheme.secondary, size: 22),
        tooltip: 'Themes & accessibility',
        onPressed: () => _openSheet(context, ref),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    // Capture messenger BEFORE the async gap — after the theme change the
    // widget's context is at a different tree position and would fail the
    // "descendant of ScaffoldMessenger" assertion.
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ThemeSheet(),
    );

    // The user may have applied a theme inside the sheet — the sheet itself
    // handles its own snackbar, so we only need this messenger reference if
    // future logic (e.g. a "themes updated" toast) is added here.
    // ignore: unused_local_variable
    final _ = messenger;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme  = Theme.of(context).colorScheme;
    final current = ref.watch(themeProvider).themeType;
    final a11y    = ref.watch(accessibilityModeProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: scheme.outline, width: 1)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _grip(scheme),
              const SizedBox(height: 8),
              Text('Appearance',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
              const SizedBox(height: 4),
              Text('7 curated enterprise themes and independent accessibility controls.',
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              _sectionHeader(context, 'Visual theme', Icons.palette_rounded),
              const SizedBox(height: 10),
              ...AppThemeType.values.map((t) => _ThemeRow(
                theme:      t,
                selected:   t == current,
                onSelected: () => _apply(context, ref, t),
              )),
              const SizedBox(height: 24),
              _sectionHeader(context, 'Accessibility mode',
                  Icons.accessibility_new_rounded),
              const SizedBox(height: 4),
              Text('Layers on top of any visual theme.',
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _A11yToggle(
                label:   'Larger text',
                caption: 'Increase font sizes across the app',
                icon:    Icons.text_increase_rounded,
                value:   a11y.largerText,
                onChanged: (v) => ref
                    .read(accessibilityModeProvider.notifier)
                    .setLargerText(v),
              ),
              _A11yToggle(
                label:   'Larger touch targets',
                caption: '≥56 dp taps and generous card padding',
                icon:    Icons.touch_app_rounded,
                value:   a11y.largerTouchTargets,
                onChanged: (v) => ref
                    .read(accessibilityModeProvider.notifier)
                    .setLargerTouchTargets(v),
              ),
              _A11yToggle(
                label:   'Higher contrast',
                caption: 'Stronger text and outlines',
                icon:    Icons.contrast_rounded,
                value:   a11y.higherContrast,
                onChanged: (v) => ref
                    .read(accessibilityModeProvider.notifier)
                    .setHigherContrast(v),
              ),
              _A11yToggle(
                label:   'Reduce motion',
                caption: 'Cut idle pulses and background animation',
                icon:    Icons.motion_photos_off_rounded,
                value:   a11y.reduceMotion,
                onChanged: (v) => ref
                    .read(accessibilityModeProvider.notifier)
                    .setReduceMotion(v),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, AppThemeType t) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(themeProvider.notifier).setTheme(t);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Applied ${t.displayName}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _grip(ColorScheme s) => Center(
        child: Container(
          width: 42, height: 4,
          decoration: BoxDecoration(
            color: s.outline,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

  Widget _sectionHeader(BuildContext context, String text, IconData icon) => Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      );
}

// ─── Theme row: swatch strip + display name + tagline + check ─────────────

class _ThemeRow extends StatelessWidget {
  final AppThemeType theme;
  final bool selected;
  final VoidCallback onSelected;
  const _ThemeRow({
    required this.theme,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final palette = theme.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelected,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.secondary.withValues(alpha: 0.10)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.secondary : scheme.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Palette swatch — 5 dots showing the theme's key colors
              _swatchStrip(palette),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(theme.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        // Flexible + ellipsis so long names ("Midnight Security",
                        // "Cyber Intelligence") never push the row past the
                        // card edge on narrow (≤360dp) phones.
                        Flexible(
                          child: Text(theme.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(theme.tagline,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: selected ? 1 : 0,
                child: Icon(Icons.check_circle_rounded,
                    color: scheme.secondary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatchStrip(dynamic palette) {
    // 5-dot color preview (bg / surface / primary / accent / status)
    final dots = <Color>[
      palette.background as Color,
      palette.card       as Color,
      palette.primary    as Color,
      palette.accent     as Color,
      palette.safe       as Color,
    ];
    return SizedBox(
      width: 68,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < dots.length; i++)
            Positioned(
              left: (i * 12).toDouble(),
              top: 4,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: dots[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Accessibility toggle row — enterprise settings row inspired by Microsoft
// 365 admin center and Salesforce Lightning. The entire row is a tap target,
// the toggle is a hand-styled pill (not the default Material Switch), and
// the "active" state uses the theme's secondary accent so it always fits.
// ═══════════════════════════════════════════════════════════════════════════

class _A11yToggle extends StatelessWidget {
  final String label;
  final String caption;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _A11yToggle({
    required this.label,
    required this.caption,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;

    // Adaptive divider that separates rows without adding visual weight.
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: scheme.outline.withValues(alpha: 0.5),
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _IconBadge(icon: icon, color: scheme.secondary, active: value),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(caption,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: onSurface.withValues(alpha: 0.6),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EnterpriseSwitch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
        divider,
      ],
    );
  }
}

/// Icon chip that dims when the associated toggle is off — gives the row
/// a clearer "on / off" visual state at a glance.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool active;
  const _IconBadge({required this.icon, required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 36, height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active
            ? color.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.45)
              : Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Icon(icon,
        color: active
            ? color
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        size: 18,
      ),
    );
  }
}

/// Hand-built pill switch — 46 x 26 dp. Off: outlined pill with hairline
/// border, thumb on the left. On: filled accent, thumb slides right with
/// a small check inside. Both states animate together in 180 ms.
class _EnterpriseSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _EnterpriseSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final onColor = scheme.secondary;
    // Off track: subtle surface tint. Never white on white.
    final offTrack = scheme.onSurface.withValues(alpha: 0.10);

    const w  = 46.0;
    const h  = 26.0;
    const th = 22.0; // thumb size

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width:  w, height: h,
          decoration: BoxDecoration(
            color: value ? onColor : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? onColor : offTrack,
              width: 1.5,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: th, height: th,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: value
                    ? Icon(Icons.check_rounded, size: 14, color: onColor)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';

/// Adaptive surface card.
///
/// **Dark themes** → frosted glass: real BackdropFilter blur, two-tone
/// gradient tint, hairline white border, optional coloured glow. This is
/// what makes the dark SOC dashboard feel premium.
///
/// **Light themes** → clean opaque enterprise card, in the vein of Microsoft
/// 365 Admin Center / Google Workspace Admin: pure `surface` fill, hairline
/// `outline` border, subtle neutral drop shadow. **No blur, no gradient
/// tint, no coloured glow.** Because glassmorphism on white washes out text
/// contrast and picks up ambient bleed from anything behind it, which fails
/// WCAG on light backgrounds.
///
/// Same public API in both cases — callers don't need to branch.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? glowColor;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 22,
    this.blurSigma = 18,
    this.glowColor,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = isDark
        ? _buildGlass(context, radius)
        : _buildOpaqueCard(context, radius);

    // Colored glow — only in dark themes. On light backgrounds it produces
    // the exact "green/pink halo behind cards" problem enterprise users
    // report as unprofessional.
    if (isDark && glowColor != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: content,
      );
    }

    final withMargin = margin == null ? content : Padding(padding: margin!, child: content);
    if (onTap == null) return withMargin;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : theme.colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : theme.colorScheme.primary.withValues(alpha: 0.04),
        child: withMargin,
      ),
    );
  }

  // ── Dark themes: frosted glass ─────────────────────────────────────────
  Widget _buildGlass(BuildContext context, BorderRadius radius) {
    final scheme = Theme.of(context).colorScheme;
    final tint = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: 0.75),
            scheme.surface.withValues(alpha: 0.45),
          ],
        );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: tint,
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Light themes: clean, opaque enterprise card ────────────────────────
  Widget _buildOpaqueCard(BuildContext context, BorderRadius radius) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:        scheme.surface,           // pure white (opaque)
        borderRadius: radius,
        border:       Border.all(color: scheme.outline, width: 1),
        // Neutral gray shadow — never colored, never green, never blue.
        boxShadow: const [
          BoxShadow(
            color:      Color(0x0F000000),      // 6% black
            blurRadius: 10,
            offset:     Offset(0, 2),
          ),
          BoxShadow(
            color:      Color(0x08000000),      // 3% black
            blurRadius: 24,
            offset:     Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: child,
    );
  }
}

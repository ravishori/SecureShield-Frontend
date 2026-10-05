/// SecureShield theme catalog — 7 professionally curated themes.
///
/// Design philosophy: enterprise cybersecurity products (Microsoft Defender,
/// CrowdStrike Falcon, SentinelOne, Palo Alto Cortex, Darktrace, IBM QRadar,
/// Bitdefender GravityZone). Every palette is WCAG-AA at minimum for body
/// text, and none rely on glow, neon, or bloom to look "premium" — they use
/// restrained contrast, hairline borders, subtle shadows, and clear typography.
///
/// Accessibility is INTENTIONALLY orthogonal to theme choice:
///   • Theme  = the visual palette (color scheme)
///   • A11y   = a separate toggle (larger fonts, bigger touch targets, higher
///              contrast, reduced motion) that layers on top of any theme.
///
/// This mirrors how Microsoft, Apple, and Google structure their systems —
/// a senior user can pick Enterprise Dark AND turn on Accessibility Mode,
/// rather than being forced into a green- or pastel-only theme.
library;

enum AppThemeType {
  /// **Defender Blue** — Default. Inspired by Microsoft Defender.
  /// Deep navy canvas, electric blue primary, minimal glow, high contrast.
  defenderBlue(
    'Defender Blue',
    '🛡️',
    'Microsoft Defender — deep navy, electric blue',
  ),

  /// **Enterprise Dark** — Inspired by CrowdStrike Falcon.
  /// Deep graphite, slate gray, subtle cyan. Muted, professional, elegant.
  enterpriseDark(
    'Enterprise Dark',
    '🏢',
    'CrowdStrike — graphite, slate, subtle cyan',
  ),

  /// **Midnight Security** — AMOLED-optimized. Almost-black canvas, blue
  /// highlights, highest contrast. Best for OLED battery + outdoor readability.
  midnightSecurity(
    'Midnight Security',
    '🌑',
    'AMOLED-black, high-contrast blue',
  ),

  /// **Banking Secure** — Premium navy, emerald accents, gold warnings.
  /// Designed for banking / UPI protection UX.
  bankingSecure(
    'Banking Secure',
    '🏦',
    'Premium navy, emerald, gold warnings',
  ),

  /// **Cyber Intelligence** — SOC-dashboard aesthetic. Dark indigo, blue,
  /// purple highlights. Very subtle gradients.
  cyberIntelligence(
    'Cyber Intelligence',
    '🧠',
    'SOC dashboard — indigo, blue, purple',
  ),

  /// **Corporate Light** — Professional light theme. Office environments,
  /// daytime readability, high-contrast dark text.
  corporateLight(
    'Corporate Light',
    '☀️',
    'Office-friendly light — white, dark text, blue',
  ),

  /// **High Contrast** — Accessibility-first. Pure-black background, pure
  /// white text, saturated status colors. No blur, no transparency, thick
  /// borders. WCAG AAA. Best combined with Accessibility Mode ON.
  highContrast(
    'High Contrast',
    '⚡',
    'Accessibility-first — pure black, pure white',
  );

  /// Human-readable display name for the theme picker.
  final String displayName;

  /// Emoji glyph for compact preview.
  final String emoji;

  /// One-line tagline shown under the display name in the theme gallery.
  final String tagline;

  const AppThemeType(this.displayName, this.emoji, this.tagline);

  /// True for themes with a dark surface. Used by MaterialApp.themeMode
  /// and by widgets that need to pick brightness-dependent assets.
  bool get isDark => switch (this) {
        AppThemeType.defenderBlue      => true,
        AppThemeType.enterpriseDark    => true,
        AppThemeType.midnightSecurity  => true,
        AppThemeType.bankingSecure     => true,
        AppThemeType.cyberIntelligence => true,
        AppThemeType.corporateLight    => false,
        AppThemeType.highContrast      => true,
      };

  /// Storage key used in SharedPreferences. `.name` is the enum identifier
  /// (e.g. `defenderBlue`).
  String get storageKey => name;

  /// Migration: map legacy stored theme names (from before this rebuild)
  /// to their nearest new equivalent. Returns null if the string is unknown.
  static AppThemeType? fromLegacyKey(String key) => switch (key) {
        // Old enum values — mapped to closest new theme
        'dark'          => AppThemeType.defenderBlue,
        'light'         => AppThemeType.corporateLight,
        'cybersecurity' => AppThemeType.cyberIntelligence,
        'seniorCitizen' => AppThemeType.highContrast,
        'natureGreen'   => AppThemeType.enterpriseDark,
        // New enum values — accept as-is
        'defenderBlue'      => AppThemeType.defenderBlue,
        'enterpriseDark'    => AppThemeType.enterpriseDark,
        'midnightSecurity'  => AppThemeType.midnightSecurity,
        'bankingSecure'     => AppThemeType.bankingSecure,
        'cyberIntelligence' => AppThemeType.cyberIntelligence,
        'corporateLight'    => AppThemeType.corporateLight,
        'highContrast'      => AppThemeType.highContrast,
        _                   => null,
      };
}

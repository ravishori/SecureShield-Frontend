/// Catalog of accessibility-service signatures used by known Android
/// banking trojans, RATs, and spyware families.
///
/// **Sources** (all public — IOC feeds, MalwareBazaar, ThreatFabric,
/// Cleafy, IBM X-Force, mobile-security research blogs):
///
///   • Cerberus / Alien   — credential stealer family, India targets
///   • Hydra              — banking trojan, overlay-based credential theft
///   • Anubis             — RAT with banking-app overlay + SMS interception
///   • TeaBot / Toddler   — Italian-origin banker, India campaigns 2023+
///   • SharkBot           — distributed via fake antivirus / cleaner apps
///   • SOVA               — successor to S.O.V.A. RAT, captures screen + keystrokes
///   • BRATA              — Brazilian RAT, factory-reset capability
///   • FluBot             — SMS-worm dropper, parcel-delivery phishing
///   • Hook               — Hydra fork with VNC streaming
///   • Joker / Ermac      — banking + adware hybrids
///
/// Matching strategy
/// =================
/// Trojan installers rename their package and accessibility-service class
/// to evade static lookups, so we use **three** signal types:
///
/// 1. **Exact package match** — for samples documented by name
/// 2. **Accessibility-service class-name pattern** (regex) — catches
///    repackaged variants because authors rarely rename internal
///    classes alongside the user-visible package
/// 3. **Label-keyword match** — many trojans use lure labels like
///    "Flash Player", "Chrome Update", "System Manager"
///
/// Any one of the three lines up → flag the app.
///
/// IMPORTANT: this list is intentionally narrow. False positives here
/// are very expensive (we'd recommend uninstalling a legit app). When
/// in doubt, the broader [BankingThreatCorrelator] still flags
/// untrusted accessibility services as "suspicious" — the catalog
/// upgrades the verdict to "critical / known trojan" only on a real hit.
library;

import 'package:flutter/foundation.dart';

import 'device_scanner_service.dart';

/// One match from the catalog.
@immutable
class AccessibilityAbuseMatch {
  /// Family ID (used as analytics key, e.g. "CERBERUS").
  final String familyId;
  /// Display name.
  final String familyName;
  /// Optional short description of capability.
  final String description;
  /// Package name that matched (may be null if matched by class pattern only).
  final String? packageName;
  /// What rule fired ("package" / "service_class" / "label_keyword").
  final String matchReason;

  const AccessibilityAbuseMatch({
    required this.familyId,
    required this.familyName,
    required this.description,
    required this.matchReason,
    this.packageName,
  });
}

@immutable
class _TrojanFamily {
  final String id;
  final String name;
  final String description;
  /// Hard-known package names (lowercase). Exact match.
  final Set<String> packages;
  /// Accessibility-service class names. Lowercase substring match.
  final Set<String> serviceClassMarkers;
  /// Common lure labels. Lowercase substring match against app label.
  final Set<String> lureLabels;

  const _TrojanFamily({
    required this.id,
    required this.name,
    required this.description,
    this.packages = const {},
    this.serviceClassMarkers = const {},
    this.lureLabels = const {},
  });
}

class AccessibilityAbuseCatalog {
  AccessibilityAbuseCatalog._();

  // ── Known legitimate accessibility services ─────────────────────────────
  // Packages here are NOT scored, even if they have accessibility enabled,
  // because they're authentic accessibility/assistive tools.
  static const Set<String> _knownLegitimate = {
    // Android system accessibility
    'com.google.android.marvin.talkback',
    'com.android.talkback',
    'com.google.android.accessibility.talkback',
    'com.google.android.accessibility.switchaccess',
    'com.google.android.accessibility.soundamplifier',
    'com.google.android.accessibility.brailleime',
    'com.android.switchaccess',
    // OEM screen readers
    'com.samsung.accessibility',
    'com.samsung.android.accessibility',
    'com.samsung.android.app.talkback',
    'com.samsung.android.app.assistantmenu',
    'com.samsung.android.universalswitch',
    'com.miui.accessibility',
    'com.huawei.accessibility',
    'com.oneplus.accessibility',
    // Major password managers (legit a11y use: autofill)
    'com.lastpass.lpandroid',
    'com.1password.android',
    'com.bitwarden.android',
    'com.dashlane',
    'com.keepersecurity.android',
    'com.password.manager',
    'com.google.android.apps.accessibility.maui.actionblocks',
    // Major launchers (legit a11y use: lockdown / kiosk)
    'com.google.android.apps.nexuslauncher',
    'com.miui.home',
    'com.samsung.android.app.launcher',
    'net.oneplus.launcher',
    // Audio / accessibility utilities
    'com.google.android.apps.accessibility.magnifier',
    'com.google.android.apps.accessibility.voiceaccess',
    'com.google.android.apps.accessibility.reveal',
  };

  /// True if a package is explicitly recognised as a legitimate
  /// accessibility-using app (do not flag).
  static bool isKnownLegitimate(String packageName) {
    return _knownLegitimate.contains(packageName);
  }

  // ── The trojan-family catalog ───────────────────────────────────────────
  static const List<_TrojanFamily> _families = [
    _TrojanFamily(
      id: 'CERBERUS',
      name: 'Cerberus / Alien',
      description:
          'Banking-credential stealer using accessibility for screen-reading '
          'and SMS-OTP interception. Active in India since 2020.',
      packages: {
        'com.cerberus.client',
        'com.cerberus.app',
        'com.alien.banker',
      },
      serviceClassMarkers: {
        'cerberusservice',
        'cerberusaccessibility',
        'alien.accessibility',
        'caservice',
      },
      lureLabels: {'flash player', 'flash update', 'system update service'},
    ),
    _TrojanFamily(
      id: 'HYDRA',
      name: 'Hydra',
      description:
          'Modular banking trojan with overlay phishing and live SMS '
          'forwarding to attacker C2.',
      packages: {
        'com.hydra.banker',
        'com.hydra.client',
      },
      serviceClassMarkers: {
        'hydraservice',
        'hydra.accessibility',
        'overlayaccessibility',
      },
      lureLabels: {'chrome update', 'system update', 'security update'},
    ),
    _TrojanFamily(
      id: 'ANUBIS',
      name: 'Anubis',
      description:
          'Android RAT with banking-app overlays, screen recording, SMS '
          'interception, and keylogging via accessibility.',
      packages: {
        'com.anubis.client',
        'com.anubis2.client',
      },
      serviceClassMarkers: {
        'anubisaccessibility',
        'anubisservice',
      },
      lureLabels: {'system update', 'play protect', 'security center'},
    ),
    _TrojanFamily(
      id: 'TEABOT',
      name: 'TeaBot / Toddler / Anatsa',
      description:
          'Banking trojan distributed via fake utility apps. Streams '
          'live screen and types on the user\'s behalf to drain accounts.',
      serviceClassMarkers: {
        'teabotservice',
        'toddler.accessibility',
        'anatsa.accessibility',
      },
      lureLabels: {
        'qr code reader', 'qr reader', 'pdf scanner', 'pdf reader',
        'cleaner pro', 'fast cleaner',
      },
    ),
    _TrojanFamily(
      id: 'SHARKBOT',
      name: 'SharkBot',
      description:
          'Distributed via fake antivirus / cleaner apps. Performs '
          'Automatic Transfer System (ATS) attacks via accessibility.',
      serviceClassMarkers: {
        'sharkservice',
        'sharkbot.accessibility',
        'shark.accessibility',
      },
      lureLabels: {
        'mister phone cleaner', 'kylhavy mobile security',
        'antivirus cleaner', 'phone cleaner pro',
      },
    ),
    _TrojanFamily(
      id: 'SOVA',
      name: 'SOVA',
      description:
          'Banking RAT with on-device keylogging, screen captures, and '
          'cookie theft. Successor to BlackRock and S.O.V.A.',
      serviceClassMarkers: {
        'sovaservice',
        'sova.accessibility',
        'screencaptureaccessibility',
      },
      lureLabels: {
        'chrome', 'amazon', 'google play store', 'paypal',
        'google authenticator', 'nfc payment',
      },
    ),
    _TrojanFamily(
      id: 'BRATA',
      name: 'BRATA',
      description:
          'Brazilian RAT capable of factory resetting the victim\'s '
          'device after fraud to delete evidence. India campaigns observed.',
      serviceClassMarkers: {
        'brataservice',
        'brata.accessibility',
      },
      lureLabels: {
        'banco safra', 'banco do brasil', 'caixa', // Brazil banking lures
        'system app update', 'security service',
      },
    ),
    _TrojanFamily(
      id: 'FLUBOT',
      name: 'FluBot / Cabassous',
      description:
          'SMS-worm dropper using parcel-delivery phishing. Steals banking '
          'credentials and contact lists for further distribution.',
      serviceClassMarkers: {
        'flubotservice',
        'cabassous.accessibility',
        'sms.relay.service',
      },
      lureLabels: {
        'dhl', 'fedex', 'voicemail', 'voice mail',
        'parcel', 'amazon parcel',
      },
    ),
    _TrojanFamily(
      id: 'HOOK',
      name: 'Hook',
      description:
          'Hydra fork adding VNC-style live screen streaming to attacker. '
          'Allows real-time hijacking of banking sessions.',
      serviceClassMarkers: {
        'hookservice',
        'hook.accessibility',
        'vncaccessibility',
      },
      lureLabels: {'system update', 'play protect update'},
    ),
    _TrojanFamily(
      id: 'ERMAC',
      name: 'Ermac / Cerberus2',
      description:
          'Cerberus successor — accessibility-based overlay attacks '
          'targeting 450+ banking and crypto apps.',
      serviceClassMarkers: {
        'ermacservice',
        'ermac.accessibility',
      },
      lureLabels: {'pdf converter', 'flash player'},
    ),
    _TrojanFamily(
      id: 'JOKER',
      name: 'Joker / Bread',
      description:
          'Premium-SMS subscription fraud. Often masquerades as wallpaper '
          'or photo-editing apps.',
      serviceClassMarkers: {
        'joker.accessibility',
        'jokeraccessibility',
      },
      lureLabels: {
        'wallpapers hd', 'wallpaper hd', 'photo editor pro',
        'smart wallpaper', 'live wallpapers',
      },
    ),
    _TrojanFamily(
      id: 'XENOMORPH',
      name: 'Xenomorph',
      description:
          'Modular banker derived from Alien lineage. Targets European '
          'and Indian banks via accessibility-driven overlay attacks.',
      serviceClassMarkers: {
        'xenomorphservice',
        'xenomorph.accessibility',
      },
      lureLabels: {'cleaner', 'fast cleaner', 'app cleaner'},
    ),
    _TrojanFamily(
      id: 'GENERIC_SPYWARE',
      name: 'Generic spyware / stalkerware',
      description:
          'Commercial stalkerware that uses accessibility to read messages, '
          'capture screens, and log keystrokes.',
      packages: {
        'com.mspy.app', 'com.mspy', 'com.hoverwatch',
        'com.flexispy.app', 'com.flexispy',
        'com.cocospy.app', 'com.spyic.app',
        'com.thetruthspy', 'com.copy9',
        'com.spapp.monitoring',
      },
      serviceClassMarkers: {
        'spy.accessibility', 'monitoring.accessibility',
        'tracker.accessibility', 'stealth.service',
      },
      lureLabels: {'parental control', 'family tracker', 'child safety'},
    ),
  ];

  /// Scan a list of enabled accessibility-service component strings (the
  /// raw values from `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`,
  /// i.e. `<package>/<full.class.Name>`) plus the installed-apps list and
  /// return any matches against the trojan catalog.
  static List<AccessibilityAbuseMatch> matchSignatures({
    required List<String> components,
    required List<DeviceAppInfo> installedApps,
  }) {
    final matches = <AccessibilityAbuseMatch>[];
    final seen = <String>{};  // de-dup by (familyId, packageName)

    void emit(AccessibilityAbuseMatch m) {
      final key = '${m.familyId}|${m.packageName ?? ''}';
      if (seen.add(key)) matches.add(m);
    }

    // Build lowercase indexes once.
    final enabledLower = components
        .map((c) => c.toLowerCase().trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final enabledPackages = enabledLower
        .map((c) => c.split('/').first)
        .toSet();

    final appsByPkg = {
      for (final a in installedApps) a.packageName.toLowerCase(): a,
    };

    for (final family in _families) {
      // ── Rule 1: exact package match against any installed app
      for (final pkg in family.packages) {
        final app = appsByPkg[pkg.toLowerCase()];
        if (app != null) {
          emit(AccessibilityAbuseMatch(
            familyId:    family.id,
            familyName:  family.name,
            description: family.description,
            packageName: app.packageName,
            matchReason: 'package',
          ));
        }
      }

      // ── Rule 2: enabled accessibility-service class contains a known marker
      for (final marker in family.serviceClassMarkers) {
        final lower = marker.toLowerCase();
        for (final component in enabledLower) {
          if (!component.contains(lower)) continue;
          final pkg = component.split('/').first;
          if (isKnownLegitimate(pkg)) continue;
          emit(AccessibilityAbuseMatch(
            familyId:    family.id,
            familyName:  family.name,
            description: family.description,
            packageName: pkg,
            matchReason: 'service_class:$marker',
          ));
        }
      }

      // ── Rule 3: enabled-accessibility app's label contains a lure keyword
      for (final label in family.lureLabels) {
        final lower = label.toLowerCase();
        for (final pkg in enabledPackages) {
          if (isKnownLegitimate(pkg)) continue;
          final app = appsByPkg[pkg];
          if (app == null) continue;
          if (!app.appName.toLowerCase().contains(lower)) continue;
          emit(AccessibilityAbuseMatch(
            familyId:    family.id,
            familyName:  family.name,
            description: family.description,
            packageName: pkg,
            matchReason: 'label_keyword:$label',
          ));
        }
      }
    }

    return matches;
  }

  /// Total number of trojan families in the catalog (for diagnostics).
  static int get familyCount => _families.length;
}

/// Represents a single app install/update/remove event observed on device.
/// Created locally by the Kotlin layer and enriched by the backend.
class InstallEvent {
  final String packageName;
  final String appName;
  final String versionName;
  final String eventType;          // installed / updated / removed
  final String? installerPackage;
  final bool isUnknownSource;
  final bool isSystemApp;
  final List<String> dangerousPerms;
  final int permCount;
  final bool hasOverlay;
  final int firstInstallTime;      // epoch millis
  // Clone detection
  final int cloneProbability;      // 0-100
  final String? cloneTargetPkg;
  final String? cloneTargetName;
  final String cloneVerdict;       // safe / suspicious / likely_clone / confirmed_clone
  final List<String> cloneSignals;
  // Local risk
  final int localRiskScore;        // 0-100
  final String localRiskLevel;     // safe / warning / danger
  final List<String> localRiskTags;
  // Server risk (populated after sync)
  final int serverRiskScore;
  final DateTime timestamp;

  const InstallEvent({
    required this.packageName,
    required this.appName,
    this.versionName = '',
    this.eventType   = 'installed',
    this.installerPackage,
    this.isUnknownSource = false,
    this.isSystemApp     = false,
    this.dangerousPerms  = const [],
    this.permCount       = 0,
    this.hasOverlay      = false,
    this.firstInstallTime = 0,
    this.cloneProbability = 0,
    this.cloneTargetPkg,
    this.cloneTargetName,
    this.cloneVerdict  = 'safe',
    this.cloneSignals  = const [],
    this.localRiskScore = 0,
    this.localRiskLevel = 'safe',
    this.localRiskTags  = const [],
    this.serverRiskScore = 0,
    required this.timestamp,
  });

  factory InstallEvent.fromMap(Map<dynamic, dynamic> m) {
    List<String> _list(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : [];

    return InstallEvent(
      packageName:       m['packageName']?.toString()  ?? '',
      appName:           m['appName']?.toString()      ?? '',
      versionName:       m['versionName']?.toString()  ?? '',
      eventType:         m['eventType']?.toString()    ?? 'installed',
      installerPackage:  m['installerPackage']?.toString(),
      isUnknownSource:   m['isUnknownSource'] as bool? ?? false,
      isSystemApp:       m['isSystemApp']     as bool? ?? false,
      dangerousPerms:    _list(m['dangerousPerms']),
      permCount:         (m['permCount'] as num?)?.toInt()        ?? 0,
      hasOverlay:         m['hasOverlay']     as bool? ?? false,
      firstInstallTime:  (m['firstInstallTime'] as num?)?.toInt() ?? 0,
      cloneProbability:  (m['cloneProbability'] as num?)?.toInt() ?? 0,
      cloneTargetPkg:    m['cloneTargetPkg']?.toString(),
      cloneTargetName:   m['cloneTargetName']?.toString(),
      cloneVerdict:      m['cloneVerdict']?.toString()            ?? 'safe',
      cloneSignals:      _list(m['cloneSignals']),
      localRiskScore:    (m['localRiskScore']  as num?)?.toInt()  ?? 0,
      localRiskLevel:    m['localRiskLevel']?.toString()          ?? 'safe',
      localRiskTags:     _list(m['localRiskTags']),
      serverRiskScore:   (m['serverRiskScore'] as num?)?.toInt()  ?? 0,
      timestamp: m['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((m['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSyncPayload() => {
    'package_name':       packageName,
    'app_name':           appName,
    'version_name':       versionName,
    'event_type':         eventType,
    'installer_package':  installerPackage,
    'is_unknown_source':  isUnknownSource,
    'is_system_app':      isSystemApp,
    'dangerous_perms':    dangerousPerms,
    'perm_count':         permCount,
    'local_risk_score':   localRiskScore,
    'has_overlay':        hasOverlay,
    'has_accessibility':  false,
    'first_install_time': firstInstallTime,
    'client_timestamp':   timestamp.millisecondsSinceEpoch,
  };

  bool get isFakeApp  => cloneVerdict == 'confirmed_clone' || cloneVerdict == 'likely_clone';
  bool get isSuspicious => cloneVerdict == 'suspicious';
  bool get isDanger   => localRiskLevel == 'danger';
  bool get isWarning  => localRiskLevel == 'warning';

  String get riskLabel {
    if (isFakeApp)   return 'FAKE APP';
    if (isDanger)    return 'DANGEROUS';
    if (isWarning)   return 'WARNING';
    if (isSuspicious) return 'SUSPICIOUS';
    return 'SAFE';
  }
}

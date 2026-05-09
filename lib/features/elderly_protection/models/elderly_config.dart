class ElderlyConfig {
  final bool enabled;
  final String? guardianName;
  final String? guardianPhone;
  final String? guardianEmail;
  final bool blockRiskyInstalls;
  final int alertThreshold;     // 0-100
  final bool autoAlertGuardian;
  final bool requireApproval;
  final bool simplifiedUi;
  final bool largeText;

  const ElderlyConfig({
    this.enabled             = false,
    this.guardianName,
    this.guardianPhone,
    this.guardianEmail,
    this.blockRiskyInstalls  = true,
    this.alertThreshold      = 40,
    this.autoAlertGuardian   = true,
    this.requireApproval     = false,
    this.simplifiedUi        = true,
    this.largeText           = true,
  });

  factory ElderlyConfig.fromJson(Map<String, dynamic> j) => ElderlyConfig(
    enabled:            j['enabled']              as bool? ?? false,
    guardianName:       j['guardian_name']?.toString(),
    guardianPhone:      j['guardian_phone']?.toString(),
    guardianEmail:      j['guardian_email']?.toString(),
    blockRiskyInstalls: j['block_risky_installs'] as bool? ?? true,
    alertThreshold:     (j['alert_threshold'] as num?)?.toInt() ?? 40,
    autoAlertGuardian:  j['auto_alert_guardian']  as bool? ?? true,
    requireApproval:    j['require_approval']     as bool? ?? false,
    simplifiedUi:       j['simplified_ui']        as bool? ?? true,
    largeText:          j['large_text']            as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'enabled':              enabled,
    'guardian_name':        guardianName,
    'guardian_phone':       guardianPhone,
    'guardian_email':       guardianEmail,
    'block_risky_installs': blockRiskyInstalls,
    'alert_threshold':      alertThreshold,
    'auto_alert_guardian':  autoAlertGuardian,
    'require_approval':     requireApproval,
    'simplified_ui':        simplifiedUi,
    'large_text':           largeText,
  };

  // Map for the Kotlin MethodChannel (uses camelCase keys)
  Map<String, dynamic> toNativeMap() => {
    'enabled':         enabled,
    'alertThreshold':  alertThreshold,
    'blockRisky':      blockRiskyInstalls,
    'autoAlert':       autoAlertGuardian,
    'guardianName':    guardianName,
    'guardianPhone':   guardianPhone,
  };

  ElderlyConfig copyWith({
    bool? enabled,
    String? guardianName,
    String? guardianPhone,
    String? guardianEmail,
    bool? blockRiskyInstalls,
    int? alertThreshold,
    bool? autoAlertGuardian,
    bool? requireApproval,
    bool? simplifiedUi,
    bool? largeText,
  }) => ElderlyConfig(
    enabled:            enabled            ?? this.enabled,
    guardianName:       guardianName       ?? this.guardianName,
    guardianPhone:      guardianPhone      ?? this.guardianPhone,
    guardianEmail:      guardianEmail      ?? this.guardianEmail,
    blockRiskyInstalls: blockRiskyInstalls ?? this.blockRiskyInstalls,
    alertThreshold:     alertThreshold     ?? this.alertThreshold,
    autoAlertGuardian:  autoAlertGuardian  ?? this.autoAlertGuardian,
    requireApproval:    requireApproval    ?? this.requireApproval,
    simplifiedUi:       simplifiedUi       ?? this.simplifiedUi,
    largeText:          largeText          ?? this.largeText,
  );
}

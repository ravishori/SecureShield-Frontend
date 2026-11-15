/// Shared, versioned scam-verdict contract (`scam_verdict/1`): the Dart twin of `backend/app/schemas/scam_verdict.py`.
///
/// Advisory only: nothing here blocks, deletes or reports anything. Parsing is STRICT: a malformed or unsupported
/// verdict is rejected (`fromJson` throws [FormatException]; `tryParse` returns null so the caller falls back to the old
/// fields). An unrecognised level is never repaired into [RiskLevel.safe].
library;

const int scamVerdictSchemaVersion = 1;

enum RiskLevel {
  unknown,
  safe,
  low,
  medium,
  high,
  critical;

  static RiskLevel parse(Object? raw) {
    for (final l in RiskLevel.values) {
      if (l.name == raw) return l;
    }
    throw FormatException('unrecognised risk_level: $raw');
  }
}

enum SourceType {
  url('url'),
  message('message'),
  jobOffer('job_offer'),
  qr('qr'),
  fakeBankSms('fake_bank_sms'),
  digitalArrest('digital_arrest'),
  paymentScreenshot('payment_screenshot'),
  dailyAggregate('daily_aggregate');

  const SourceType(this.wire);
  final String wire;

  static SourceType parse(Object? raw) {
    for (final s in SourceType.values) {
      if (s.wire == raw) return s;
    }
    throw FormatException('unrecognised source_type: $raw');
  }

  /// Rule-based on-device detectors: they report a category, not a 0-100 score, so a non-unknown verdict may have a null score.
  bool get isRuleBased =>
      this == qr || this == fakeBankSms || this == digitalArrest || this == paymentScreenshot;
}

enum EvidenceKind {
  signal('signal'),
  providerResult('provider_result'),
  providerUnavailable('provider_unavailable'),
  registryMatch('registry_match'),
  positive('positive');

  const EvidenceKind(this.wire);
  final String wire;

  static EvidenceKind parse(Object? raw) {
    for (final k in EvidenceKind.values) {
      if (k.wire == raw) return k;
    }
    throw FormatException('unrecognised evidence kind: $raw');
  }
}

enum Polarity {
  adverse,
  neutral,
  positive;

  static Polarity parse(Object? raw) {
    for (final p in Polarity.values) {
      if (p.name == raw) return p;
    }
    throw FormatException('unrecognised polarity: $raw');
  }
}

final RegExp _codeRe = RegExp(r'^[a-z][a-z0-9_]{2,48}$');
final RegExp _sourceRe = RegExp(r'^(heuristic|provider|registry|rule|aggregate|detector):[a-z0-9_+.\-]{1,48}$');
final RegExp _engineRe = RegExp(r'^[a-z0-9][a-z0-9_.\-]{1,48}/[0-9]{1,3}$');

Map<String, dynamic> _map(Object? raw, String what) {
  if (raw is Map) {
    try {
      return Map<String, dynamic>.from(raw);
    } catch (_) {}
  }
  throw FormatException('$what must be an object');
}

List<Object?> _list(Object? raw, String what, {int max = 20, int min = 0}) {
  if (raw is! List) throw FormatException('$what must be a list');
  if (raw.length > max || raw.length < min) throw FormatException('$what must have between $min and $max items');
  return raw;
}

String _text(Object? raw, String what) {
  if (raw is! String || raw.trim().isEmpty || raw.length > 200) throw FormatException('$what must be 1-200 characters');
  return raw;
}

String _code(Object? raw, String what) {
  if (raw is! String || !_codeRe.hasMatch(raw)) throw FormatException('$what must be a lowercase code');
  return raw;
}

int? _intIn(Object? raw, String what, int lo, int hi) {
  if (raw == null) return null;
  if (raw is! int || raw < lo || raw > hi) throw FormatException('$what must be an integer in $lo..$hi or null');
  return raw;
}

class Reason {
  final String code;
  final String text;
  const Reason({required this.code, required this.text});

  factory Reason.fromJson(Object? raw) {
    final m = _map(raw, 'reason');
    return Reason(code: _code(m['code'], 'reason.code'), text: _text(m['text'], 'reason.text'));
  }

  Map<String, dynamic> toJson() => {'code': code, 'text': text};

  @override
  bool operator ==(Object other) => other is Reason && other.code == code && other.text == text;
  @override
  int get hashCode => Object.hash(code, text);
}

typedef VerdictAction = Reason; // same shape (code + fixed advisory text); a distinct name avoids clashing with Flutter's Action

class Evidence {
  final EvidenceKind kind;
  final Polarity polarity;
  final String code;
  final String source;
  final int? weight;
  final int? count;

  const Evidence({
    required this.kind,
    required this.polarity,
    required this.code,
    required this.source,
    this.weight,
    this.count,
  });

  factory Evidence.fromJson(Object? raw) {
    final m = _map(raw, 'evidence');
    final kind = EvidenceKind.parse(m['kind']);
    final polarity = Polarity.parse(m['polarity']);
    final source = m['source'];
    if (source is! String || !_sourceRe.hasMatch(source)) throw const FormatException('evidence.source must look like "rule:qr"');
    if (kind == EvidenceKind.positive && polarity != Polarity.positive) throw const FormatException('positive evidence needs positive polarity');
    if (polarity == Polarity.positive && kind != EvidenceKind.positive && kind != EvidenceKind.registryMatch) {
      throw const FormatException('only registry matches or explicit positive evidence can be positive');
    }
    if (polarity == Polarity.positive && source.startsWith('provider:')) {
      throw const FormatException('a reputation provider can never supply positive trust evidence');
    }
    if (kind == EvidenceKind.providerUnavailable && polarity != Polarity.neutral) throw const FormatException('a provider outage is neutral');
    if ((kind == EvidenceKind.providerResult || kind == EvidenceKind.providerUnavailable) && !source.startsWith('provider:')) {
      throw const FormatException('provider evidence must name a provider');
    }
    return Evidence(
      kind: kind,
      polarity: polarity,
      code: _code(m['code'], 'evidence.code'),
      source: source,
      weight: _intIn(m['weight'], 'evidence.weight', 0, 100),
      count: _intIn(m['count'], 'evidence.count', 1, 10000),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.wire,
        'polarity': polarity.name,
        'code': code,
        'source': source,
        'weight': weight,
        'count': count,
      };
}

class ScamVerdict {
  final int schemaVersion;
  final RiskLevel riskLevel;
  final int? riskScore;
  final List<Reason> reasons;
  final List<Evidence> evidence;
  final SourceType sourceType;
  final double? confidence;
  final List<String> limitations;
  final List<VerdictAction> recommendedActions;
  final String engineVersion;

  const ScamVerdict._({
    required this.schemaVersion,
    required this.riskLevel,
    required this.riskScore,
    required this.reasons,
    required this.evidence,
    required this.sourceType,
    required this.confidence,
    required this.limitations,
    required this.recommendedActions,
    required this.engineVersion,
  });

  /// Builds a verdict and enforces every invariant (used by the adapters and by parsing).
  factory ScamVerdict.create({
    required RiskLevel riskLevel,
    int? riskScore,
    List<Reason> reasons = const [],
    List<Evidence> evidence = const [],
    required SourceType sourceType,
    required List<String> limitations,
    List<VerdictAction> recommendedActions = const [],
    required String engineVersion,
  }) {
    if (riskScore != null && (riskScore < 0 || riskScore > 100)) throw const FormatException('risk_score must be 0..100');
    final unknown = riskLevel == RiskLevel.unknown;
    if (unknown && riskScore != null) throw const FormatException('an unknown verdict must not carry a score');
    if (!unknown && riskScore == null && !sourceType.isRuleBased) {
      throw const FormatException('risk_score may be null only for unknown (or rule-based detectors without a score)');
    }
    if (limitations.isEmpty || limitations.length > 10) throw const FormatException('limitations must have 1-10 items');
    for (final l in limitations) {
      if (l.trim().isEmpty || l.length > 200) throw const FormatException('each limitation must be 1-200 characters');
    }
    if (reasons.length > 20 || evidence.length > 20 || recommendedActions.length > 10) throw const FormatException('too many items');
    if (reasons.map((r) => r.code).toSet().length != reasons.length) throw const FormatException('duplicate reason codes');
    if (recommendedActions.map((a) => a.code).toSet().length != recommendedActions.length) throw const FormatException('duplicate action codes');
    if (!_engineRe.hasMatch(engineVersion)) throw const FormatException('engine_version must look like "qr-rules/1"');
    final adverse = evidence.any((e) => e.polarity == Polarity.adverse);
    final positive = evidence.any((e) => e.polarity == Polarity.positive);
    if ((riskLevel == RiskLevel.medium || riskLevel == RiskLevel.high || riskLevel == RiskLevel.critical) && (!adverse || reasons.isEmpty)) {
      throw const FormatException('medium, high and critical need adverse evidence and a reason');
    }
    if (riskLevel == RiskLevel.safe && (!positive || adverse)) {
      throw const FormatException('"safe" needs positive evidence and no adverse evidence');
    }
    if (riskLevel == RiskLevel.low && !adverse && !reasons.any((r) => r.code == 'no_signals_found')) {
      throw const FormatException('"low" without adverse evidence needs the reason no_signals_found');
    }
    return ScamVerdict._(
      schemaVersion: scamVerdictSchemaVersion,
      riskLevel: riskLevel,
      riskScore: riskScore,
      reasons: List.unmodifiable(reasons),
      evidence: List.unmodifiable(evidence),
      sourceType: sourceType,
      confidence: null,
      limitations: List.unmodifiable(limitations),
      recommendedActions: List.unmodifiable(recommendedActions),
      engineVersion: engineVersion,
    );
  }

  /// Nothing could be assessed. Never `safe`, never a score.
  factory ScamVerdict.unknown({
    required SourceType sourceType,
    required String engineVersion,
    String limitation = 'The analysis could not be completed, so no judgement is made.',
  }) =>
      ScamVerdict.create(
        riskLevel: RiskLevel.unknown,
        reasons: const [Reason(code: 'analysis_unavailable', text: 'The analysis could not be completed.')],
        sourceType: sourceType,
        limitations: [limitation],
        recommendedActions: const [Reason(code: 'verify_independently', text: 'If you did not expect this, check it another way before acting.')],
        engineVersion: engineVersion,
      );

  /// Strict parse of a server (or stored) verdict. Throws [FormatException] on anything malformed or unsupported.
  factory ScamVerdict.fromJson(Object? raw) {
    final m = _map(raw, 'verdict');
    const known = {
      'schema_version', 'risk_level', 'risk_score', 'reasons', 'evidence', 'source_type', 'confidence', 'limitations',
      'recommended_actions', 'engine_version',
    };
    final extra = m.keys.where((k) => !known.contains(k));
    if (extra.isNotEmpty) throw FormatException('unexpected verdict fields: ${extra.join(', ')}');
    if (m['schema_version'] != scamVerdictSchemaVersion) throw FormatException('unsupported schema_version: ${m['schema_version']}');
    if (m['confidence'] != null) throw const FormatException('confidence must be null in scam_verdict/1');
    final engine = m['engine_version'];
    if (engine is! String) throw const FormatException('engine_version must be a string');
    return ScamVerdict.create(
      riskLevel: RiskLevel.parse(m['risk_level']),
      riskScore: _intIn(m['risk_score'], 'risk_score', 0, 100),
      reasons: _list(m['reasons'], 'reasons').map(Reason.fromJson).toList(),
      evidence: _list(m['evidence'], 'evidence').map(Evidence.fromJson).toList(),
      sourceType: SourceType.parse(m['source_type']),
      limitations: _list(m['limitations'], 'limitations', max: 10, min: 1).map((e) => _text(e, 'limitation')).toList(),
      recommendedActions: _list(m['recommended_actions'], 'recommended_actions', max: 10).map(Reason.fromJson).toList(),
      engineVersion: engine,
    );
  }

  /// Like [fromJson] but returns null for a missing or malformed verdict, so the caller keeps using the legacy fields.
  /// A bad verdict is never turned into a `safe` one.
  static ScamVerdict? tryParse(Object? raw) {
    if (raw == null) return null;
    try {
      return ScamVerdict.fromJson(raw);
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'risk_level': riskLevel.name,
        'risk_score': riskScore,
        'reasons': reasons.map((r) => r.toJson()).toList(),
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'source_type': sourceType.wire,
        'confidence': confidence,
        'limitations': limitations,
        'recommended_actions': recommendedActions.map((a) => a.toJson()).toList(),
        'engine_version': engineVersion,
      };

  /// True only for an explicit `safe` verdict (never for unknown, missing or low).
  bool get isSafeClaim => riskLevel == RiskLevel.safe;

  /// True when the detector could not assess the item (distinct from a clean result).
  bool get isUnknown => riskLevel == RiskLevel.unknown;
}

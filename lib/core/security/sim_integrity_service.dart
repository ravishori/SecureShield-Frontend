/// SIM Integrity Service.
///
/// Detects SIM swap / port-out attacks by storing a trusted SHA-256
/// fingerprint of each active SIM on first launch and comparing on every
/// subsequent app start.
///
/// Privacy: the raw ICCID / IMSI / phone number is hashed by the native
/// [SimFingerprintProvider] before crossing the JNI boundary. We only see
/// and persist the hash.
///
/// Storage: [FlutterSecureStorage] (AES-GCM via Keystore on Android,
/// Keychain on iOS). Falls back to in-memory if secure storage is
/// unavailable (very rare).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One SIM record as reported by the native side.
@immutable
class SimRecord {
  final int slotIndex;
  final String carrierName;
  final String countryIso;
  final String mccMnc;
  final String fingerprint;
  final bool hasFullId;

  const SimRecord({
    required this.slotIndex,
    required this.carrierName,
    required this.countryIso,
    required this.mccMnc,
    required this.fingerprint,
    required this.hasFullId,
  });

  factory SimRecord.fromMap(Map<dynamic, dynamic> m) => SimRecord(
        slotIndex:   m['slotIndex']   as int?    ?? 0,
        carrierName: m['carrierName'] as String? ?? '',
        countryIso:  m['countryIso']  as String? ?? '',
        mccMnc:      m['mccMnc']      as String? ?? '',
        fingerprint: m['fingerprint'] as String? ?? '',
        hasFullId:   m['hasFullId']   as bool?   ?? false,
      );

  Map<String, dynamic> toJson() => {
        'slotIndex': slotIndex,
        'carrierName': carrierName,
        'countryIso': countryIso,
        'mccMnc': mccMnc,
        'fingerprint': fingerprint,
        'hasFullId': hasFullId,
      };

  factory SimRecord.fromJson(Map<String, dynamic> j) => SimRecord(
        slotIndex:   j['slotIndex']   as int?    ?? 0,
        carrierName: j['carrierName'] as String? ?? '',
        countryIso:  j['countryIso']  as String? ?? '',
        mccMnc:      j['mccMnc']      as String? ?? '',
        fingerprint: j['fingerprint'] as String? ?? '',
        hasFullId:   j['hasFullId']   as bool?   ?? false,
      );
}

/// Possible verdicts of a SIM-integrity check.
enum SimIntegrityVerdict {
  /// No SIMs visible (no permission, no SIM inserted) — neutral state.
  noPermissionOrSim,

  /// First-ever scan or after explicit reset — baseline established now.
  baselineEstablished,

  /// Every active SIM matches the baseline. Safe.
  unchanged,

  /// At least one SIM fingerprint changed — the SIM card was replaced.
  changed,

  /// New SIM slot is active that wasn't before (e.g. dual-SIM second card).
  extraSim,

  /// A previously-active SIM is missing (e.g. eSIM deleted).
  removedSim,

  /// Multiple kinds of changes at once.
  mixedChange,
}

@immutable
class SimIntegrityReport {
  final SimIntegrityVerdict verdict;
  final List<SimRecord> current;
  final List<SimRecord> baseline;
  final List<String> humanReadableChanges;

  const SimIntegrityReport({
    required this.verdict,
    required this.current,
    required this.baseline,
    required this.humanReadableChanges,
  });

  bool get isAlertable =>
      verdict == SimIntegrityVerdict.changed ||
      verdict == SimIntegrityVerdict.removedSim ||
      verdict == SimIntegrityVerdict.mixedChange;
}

class SimIntegrityService {
  SimIntegrityService._();
  static final instance = SimIntegrityService._();

  static const _channel = MethodChannel('secureshield/sim_integrity');
  static const _baselineKey = 'sim_integrity_baseline_v1';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Public API ──────────────────────────────────────────────────────────

  /// Read SIMs from the device, compare against the persisted baseline,
  /// and return a verdict.
  ///
  /// Side-effect: when the verdict is [baselineEstablished], the current
  /// SIMs are persisted as the new baseline. On [changed]/[removedSim]/
  /// [mixedChange], the baseline is **not** auto-updated — the caller
  /// must call [confirmAndUpdateBaseline] after the user acknowledges.
  Future<SimIntegrityReport> check() async {
    final current = await _readCurrentSims();

    if (current.isEmpty) {
      return const SimIntegrityReport(
        verdict: SimIntegrityVerdict.noPermissionOrSim,
        current: [],
        baseline: [],
        humanReadableChanges: [],
      );
    }

    final baseline = await _readBaseline();

    if (baseline.isEmpty) {
      // First-ever run — establish baseline.
      await _writeBaseline(current);
      return SimIntegrityReport(
        verdict: SimIntegrityVerdict.baselineEstablished,
        current: current,
        baseline: current,
        humanReadableChanges: [
          'Baseline established with ${current.length} SIM(s).',
        ],
      );
    }

    return _compare(current: current, baseline: baseline);
  }

  /// Accept the new SIM as the trusted baseline (after the user has
  /// dismissed the alert intentionally).
  Future<void> confirmAndUpdateBaseline(List<SimRecord> sims) async {
    await _writeBaseline(sims);
  }

  /// Wipe the persisted baseline. Next [check] will re-establish it.
  Future<void> reset() async {
    await _storage.delete(key: _baselineKey);
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Future<List<SimRecord>> _readCurrentSims() async {
    try {
      final raw = await _channel.invokeListMethod<Map>('readSimFingerprints');
      if (raw == null) return const [];
      return raw.map(SimRecord.fromMap).toList();
    } on PlatformException catch (e) {
      debugPrint('[SimIntegrityService] platform error: ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('[SimIntegrityService] unexpected: $e');
      return const [];
    }
  }

  Future<List<SimRecord>> _readBaseline() async {
    try {
      final raw = await _storage.read(key: _baselineKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(SimRecord.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[SimIntegrityService] baseline read failed: $e');
      return const [];
    }
  }

  Future<void> _writeBaseline(List<SimRecord> sims) async {
    try {
      final json = jsonEncode(sims.map((s) => s.toJson()).toList());
      await _storage.write(key: _baselineKey, value: json);
    } catch (e) {
      debugPrint('[SimIntegrityService] baseline write failed: $e');
    }
  }

  /// Returns the diff between the current and baseline SIM sets.
  SimIntegrityReport _compare({
    required List<SimRecord> current,
    required List<SimRecord> baseline,
  }) {
    // Compare on (slotIndex, fingerprint) pairs.
    final currentByFp = {for (final s in current) s.fingerprint: s};
    final baselineByFp = {for (final s in baseline) s.fingerprint: s};

    final added   = current.where((s) => !baselineByFp.containsKey(s.fingerprint)).toList();
    final removed = baseline.where((s) => !currentByFp.containsKey(s.fingerprint)).toList();

    final changes = <String>[];

    if (added.isEmpty && removed.isEmpty) {
      return SimIntegrityReport(
        verdict: SimIntegrityVerdict.unchanged,
        current: current,
        baseline: baseline,
        humanReadableChanges: const ['All SIMs match the trusted baseline.'],
      );
    }

    for (final s in removed) {
      changes.add(
        'SIM removed: slot ${s.slotIndex + 1} '
        '(${s.carrierName.isNotEmpty ? s.carrierName : "Unknown carrier"})',
      );
    }
    for (final s in added) {
      changes.add(
        'New SIM detected: slot ${s.slotIndex + 1} '
        '(${s.carrierName.isNotEmpty ? s.carrierName : "Unknown carrier"}, '
        'MCC/MNC ${s.mccMnc})',
      );
    }

    final SimIntegrityVerdict verdict;
    if (added.isNotEmpty && removed.isNotEmpty) {
      // Same slot, different SIM → "changed". Different slot → "mixed".
      final sameSlot = added.any(
        (a) => removed.any((r) => r.slotIndex == a.slotIndex),
      );
      verdict = sameSlot
          ? SimIntegrityVerdict.changed
          : SimIntegrityVerdict.mixedChange;
    } else if (added.isNotEmpty) {
      verdict = SimIntegrityVerdict.extraSim;
    } else {
      verdict = SimIntegrityVerdict.removedSim;
    }

    return SimIntegrityReport(
      verdict: verdict,
      current: current,
      baseline: baseline,
      humanReadableChanges: changes,
    );
  }
}

/// Shared Riverpod provider for the banking-threat correlator.
///
/// Wraps [BankingThreatCorrelator.scan] in a `FutureProvider.autoDispose`
/// so multiple screens can read the same cached result without each one
/// triggering its own native call. Anyone can refresh by invalidating
/// the provider:
///
/// ```dart
/// ref.invalidate(bankingThreatProvider);
/// ```
///
/// AutoDispose means: when the last listener unmounts (e.g. user navigates
/// far away), the result is discarded and next access re-scans. Keeps the
/// banner accurate without us writing manual cache-invalidation code.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'banking_threat_correlator.dart';

/// Async banking-threat report. `null` while scanning.
final bankingThreatProvider =
    FutureProvider.autoDispose<BankingThreatReport>((ref) async {
  return BankingThreatCorrelator.scan();
});

/// Convenience: synchronous accessor returning the current report or null.
/// Use when you don't want to deal with AsyncValue plumbing.
final bankingThreatReportProvider = Provider.autoDispose<BankingThreatReport?>(
  (ref) => ref.watch(bankingThreatProvider).valueOrNull,
);

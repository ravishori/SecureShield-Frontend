import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, TlsException;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/network/dio_client.dart';
import '../auth/auth_provider.dart';

const _channel = MethodChannel('secureshield/app_monitor');

/// The pre-Stage-2B in-memory/SharedPreferences upload queue. It was filled from the live event stream with no owner and no
/// event id, so it can neither be attributed to an account nor deduplicated. It is deleted once, never uploaded.
const legacyQueueKey = 'install_event_queue_v1';

enum SyncStatus {
  /// Nothing was waiting.
  idle,

  /// Everything that was waiting got a final answer from the server (per-event results may still include rejected).
  synced,

  /// Stopped early: the network failed, or the server answered 5xx. Events are untouched; the next run retries them.
  offline,

  /// The server said 429. Events are untouched; nothing is sent before [SyncReport.retryAt].
  rateLimited,

  /// The server answered 401 even after a token refresh. Events are kept; sync resumes after the next sign-in.
  authRequired,

  /// No account is signed in (or the native store has not accepted the owner): nothing is read or sent.
  signedOut,

  /// Another sync is already running; this call joined it instead of starting a second upload.
  joined,

  /// The account changed during the run: that response was discarded, not applied to the new account.
  ownerChanged,

  /// Waiting out a back-off after an earlier failure.
  backingOff,

  /// The native store is unavailable (not Android, or a storage error).
  storeUnavailable,

  /// The sync endpoint is permanently unavailable or misconfigured (HTTP 404/405/410/501) or its TLS certificate was
  /// rejected. Events are kept untouched; the next try is at least an hour away. See [SyncReport.diagnostic].
  endpointProblem,

  /// An endpoint restriction is in force but could not be SAVED (a write was refused or failed). It is kept in memory and
  /// ALL sync stays blocked until it has been saved, so a restart cannot forget it. See [SyncReport.diagnostic].
  settingsWriteFailed,

  /// The saved endpoint-restriction state could not be READ (storage error), so it is unknown whether a one-hour wait
  /// applies. Sync stays blocked, the queued events are not touched, and the read is retried on every attempt.
  settingsUnreadable,

  /// The server answered 200 but gave no per-event outcomes (an older server). Nothing was recorded and no attempt was spent.
  serverUpdateNeeded,
}

class SyncReport {
  final SyncStatus status;
  final int uploaded; // events the server answered for (created + duplicate + rejected + retry)
  final int created;
  final int duplicate;
  final int rejected;
  final int retried; // per-event retry results (the server did not give a final answer for them)
  final int guardianAccepted; // the server holds an alert (queued, already queued, pending, leased) - NOT delivered
  final int guardianProviderAccepted; // the SMS/e-mail provider accepted it (`sent`) - still not handset delivery
  final DateTime? retryAt;
  final String? diagnostic; // a short code such as http_404 or tls_certificate when status is endpointProblem
  const SyncReport(
    this.status, {
    this.uploaded = 0,
    this.created = 0,
    this.duplicate = 0,
    this.rejected = 0,
    this.retried = 0,
    this.guardianAccepted = 0,
    this.guardianProviderAccepted = 0,
    this.retryAt,
    this.diagnostic,
  });

  /// Events that now have a final history result.
  int get settled => created + duplicate + rejected;

  @override
  String toString() => 'SyncReport($status uploaded=$uploaded created=$created duplicate=$duplicate rejected=$rejected '
      'retried=$retried guardianAccepted=$guardianAccepted providerAccepted=$guardianProviderAccepted)';
}

/// F19 Stage 2C: the ONE upload pipeline for app-monitor events.
///
/// The native SQLite store (Stage 2B) is the only queue. This class reads it with `drainEvents` (which changes nothing),
/// posts the batch to `/app-monitor/sync` with the native UUID as `client_event_id` and the native `occurred_at`, and then
/// records the server's per-event answers with `markResults`.
///
/// Rules:
///  • One run at a time (a concurrent call joins the run in progress); the server is idempotent per `client_event_id`, so
///    even a crash between the upload and `markResults` only repeats events the server reports as `duplicate`.
///  • A whole-request failure (offline, 5xx, 429, 401) never calls `markResults`: events stay as they were and no attempt
///    is spent, so being offline for a week cannot make events give up. Only a per-event "no final answer" is recorded as
///    a retry (and the native store gives up on an event after its attempt limit).
///  • An account change during a run discards that run's response; ownership is also enforced natively (events of any other
///    account are deleted when the owner changes and ignored by `markResults`).
///  • History and guardian outcomes are independent: a `created` event can have a `skipped` alert and vice versa.
class MonitorSyncCoordinator {
  MonitorSyncCoordinator({
    Dio Function()? dio,
    DateTime Function()? now,
    MethodChannel? channel,
    Future<bool> Function()? hasRefreshToken,
    Future<SharedPreferences> Function()? preferences,
  })  : _dio = dio ?? (() => DioClient().dio),
        _prefs = preferences ?? SharedPreferences.getInstance,
        _hasRefreshToken = hasRefreshToken ?? _defaultHasRefreshToken,
        _now = now ?? DateTime.now,
        _ch = channel ?? _channel;

  final Dio Function() _dio;
  final DateTime Function() _now;
  final MethodChannel _ch;
  final Future<bool> Function() _hasRefreshToken;
  final Future<SharedPreferences> Function() _prefs; // app-private storage; replaceable so tests can make it fail

  /// True while a refresh token is stored. An unreadable store counts as true: keeping the owner is the less destructive answer.
  static Future<bool> _defaultHasRefreshToken() async {
    try {
      return (await const FlutterSecureStorage().read(key: AppConstants.refreshTokenKey)) != null;
    } catch (_) {
      return true;
    }
  }

  /// For the auth binding: does a refresh token remain (so a merely expired access token is not a sign-out)?
  Future<bool> hasRefreshToken() => _hasRefreshToken();

  static const maxBatchesPerRun = 10;
  static const _baseBackoff = Duration(seconds: 30);
  static const _maxBackoff = Duration(minutes: 15);
  static const _defaultRetryAfter = Duration(seconds: 60);
  static const _maxRetryAfter = Duration(hours: 1);
  static const endpointRetryInterval = Duration(hours: 1); // the minimum wait after a permanent endpoint problem
  static const _permanentEndpointCodes = {404, 405, 410, 501};
  // App-private (SharedPreferences) so the wait survives a restart. Both are removed only by a successful response.
  /// ONE value holding the problem code and the deadline together (JSON), so a single write either stores both or neither.
  static const endpointRestrictionKey = 'monitor_endpoint_restriction_v2';

  /// The earlier two-value layout. Still READ (a half-written pair must never let a restart skip a wait), never written;
  /// it is removed when the single value is saved or the restriction is cleared.
  static const endpointProblemKey = 'monitor_endpoint_problem_v1';
  static const endpointBlockedUntilKey = 'monitor_endpoint_blocked_until_v1';
  static final _problemCode = RegExp(r'^(http_[0-9]{3}|tls_certificate|endpoint_unknown)$');

  String? _owner; // the account the native store has accepted, or null
  bool _ownerSynced = false; // true once THIS process has told the native store its owner (the store persists across processes)
  int _epoch = 0; // bumped on every owner change; a run holds the epoch it started in
  Future<SyncReport>? _inFlight;
  Future<void> _ownerQueue = Future<void>.value(); // owner changes run strictly one after another
  DateTime? _retryAt;
  DateTime? _rateLimitedUntil;
  int _failures = 0;
  bool _authBlocked = false;
  String? _endpointProblem; // http_404, tls_certificate ... until a request gets through again
  DateTime? _endpointBlockedUntil;
  bool _reconciled = false;
  bool _endpointStateLoaded = false; // true once the saved state has been READ successfully (an absent value counts)
  Future<void>? _restoring;
  int _storageFailures = 0; // consecutive failed reads; reset by a successful one
  bool _endpointPersisted = true; // true only when the restriction in memory is CONFIRMED written (or was read) on disk
  bool _clearPending = false; // recovery happened but removing the saved restriction was not confirmed
  int _writeFailures = 0; // consecutive failed writes; reset by a confirmed one
  Future<void>? _settling;
  bool _legacyCleared = false;

  /// The account whose events this coordinator may read and send (null = signed out).
  String? get owner => _owner;

  /// The code of the permanent endpoint/configuration problem currently blocking sync, or null.
  String? get endpointProblem => _endpointProblem;

  /// When the next attempt is allowed after an endpoint problem.
  DateTime? get endpointRetryAt => _endpointBlockedUntil;

  /// True while the saved restriction state cannot be read: sync is blocked until the storage works again.
  bool get endpointStateUnreadable => !_endpointStateLoaded && _storageFailures > 0;

  /// How many reads in a row have failed (shown as a diagnostic when the problem persists).
  int get storageFailures => _storageFailures;

  /// True while a restriction is held in memory that has NOT been confirmed saved: sync stays blocked until it is.
  bool get endpointWriteFailed => _endpointProblem != null && !_endpointPersisted;

  /// How many writes in a row have failed (shown as a diagnostic when the problem persists).
  int get writeFailures => _writeFailures;

  // ------------------------------------------------------------------------------------------------ owner lifecycle
  /// Tells the native store which account is signed in (null = signed out). Must succeed before monitoring is enabled.
  /// Returns false (and leaves the coordinator signed out) if the native side did not accept it.
  Future<bool> setOwner(String? ownerId) => _serial(() => _setOwnerNow(ownerId));

  /// Owner changes (and purges) run one at a time, in call order, so two quick auth changes can never interleave.
  Future<T> _serial<T>(Future<T> Function() job) {
    final run = _ownerQueue.then((_) => job());
    _ownerQueue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<bool> _setOwnerNow(String? ownerId) async {
    final clean = ownerId?.trim();
    final wanted = (clean == null || clean.isEmpty) ? null : clean;
    if (wanted == _owner && _ownerSynced) {
      _authBlocked = false; // a fresh sign-in of the same account clears an auth block
      return true;
    }
    _epoch++;
    _owner = null; // nothing may run while the native owner is being changed
    _retryAt = _rateLimitedUntil = null;
    _failures = 0;
    _authBlocked = false;
    try {
      final ok = await _ch.invokeMethod<bool>('setOwner', {'ownerId': wanted}) ?? false;
      if (ok) _owner = wanted;
      _ownerSynced = ok;
      return ok;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Startup reconciliation of a native owner this process never set (F2). Runs once per process, and only when the Dart
  /// side has no owner but the native store still names one:
  ///  • no refresh token left -> authentication is confirmed absent -> the stale native owner is cleared;
  ///  • a refresh token remains -> one authenticated request validates it: a 401 that leaves no refresh token behind (the
  ///    refresh was rejected for good) clears the owner; success, a network error or anything else keeps it.
  /// It only ever CLEARS: it never sets an owner, so it cannot attribute events to the wrong account. Returns true if it
  /// cleared the owner.
  Future<bool> reconcileStaleOwner() => _serial(() async {
        if (_reconciled || _ownerSynced || _owner != null) return false;
        _reconciled = true;
        final st = await stats();
        if (st['hasOwner'] != true) return false;
        if (!await _hasRefreshToken()) return _setOwnerNow(null);
        try {
          await _dio().get<dynamic>('/app-monitor/summary');
          return false; // the session is valid: keep the owner
        } on DioException catch (e) {
          if (e.response?.statusCode == 401 && !await _hasRefreshToken()) return _setOwnerNow(null);
          return false; // offline or inconclusive: never clear on a guess
        } catch (_) {
          return false;
        }
      });

  /// Account deletion: removes every stored event of every account, then signs the store out. Returns true ONLY if the
  /// native purge reported success and the store accepted the sign-out; the caller must not claim the device data is gone
  /// otherwise. A failed purge is retried once. On a platform without the native store there is nothing to purge (true).
  Future<bool> purgeAll() => _serial(() async {
        _epoch++;
        _owner = null;
        var purged = await _purgeOnce();
        if (!purged) purged = await _purgeOnce();
        var signedOut = false;
        try {
          signedOut = await _ch.invokeMethod<bool>('setOwner', {'ownerId': null}) ?? false;
        } on MissingPluginException {
          signedOut = true;
        } catch (_) {}
        return purged && signedOut;
      });

  Future<bool> _purgeOnce() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('purge', {'ownerId': null});
      return m != null && m['ok'] == true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> stats() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('stats');
      return m ?? const {'available': false};
    } catch (_) {
      return const {'available': false};
    }
  }

  Timer? _debounce;

  /// A new event arrived: upload shortly (coalesces a burst of events into one run).
  void requestSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(sync()));
  }

  // ------------------------------------------------------------------------------------------------ endpoint problem (persisted)
  /// Loads a persisted endpoint problem once per process. Safe against anything found on disk:
  ///  • a missing or malformed problem code: both values are discarded;
  ///  • a missing or malformed deadline: treated as a fresh full wait from now (the safe side: never bypassed);
  ///  • a deadline further away than the interval (corrupt, or the clock moved back): clamped to the interval;
  ///  • a deadline in the past: the retry is allowed, but the problem stays recorded until a request succeeds.
  ///
  /// A storage READ ERROR is different from an absent value: absent means "no restriction", an error means "unknown", and
  /// unknown fails CLOSED. [_endpointStateLoaded] stays false, sync is blocked ([SyncStatus.settingsUnreadable]), nothing is
  /// marked or consumed, and the read is tried again on the next call (every sync attempt and every screen load).
  Future<void> restoreEndpointState() async {
    if (!_endpointStateLoaded) await (_restoring ??= _restoreEndpointState().whenComplete(() => _restoring = null));
    if (_endpointStateLoaded) await (_settling ??= _settleWrites().whenComplete(() => _settling = null));
  }

  /// Finishes writes that were not confirmed earlier. Runs on every sync attempt and every screen load.
  ///  • a restriction that could not be saved is saved again; only a CONFIRMED write lifts the write block;
  ///  • a recovery whose saved restriction could not be removed has its removal retried; the problem stays recorded
  ///    (but no longer blocks anything) until the removal is confirmed.
  Future<void> _settleWrites() async {
    if (_endpointProblem != null && !_endpointPersisted) {
      if (await _persistEndpointState()) {
        _endpointPersisted = true;
        _writeFailures = 0;
      } else {
        _writeFailures++;
      }
    }
    if (_clearPending && _endpointProblem != null) {
      if (await _clearPersistedEndpointState()) {
        _endpointProblem = null;
        _endpointBlockedUntil = null;
        _clearPending = false;
        _endpointPersisted = true;
        _writeFailures = 0;
      } else {
        _writeFailures++;
      }
    }
  }

  Future<void> _restoreEndpointState() async {
    final SharedPreferences p;
    final Object? raw;
    final Object? legacyCode;
    final Object? legacyUntil;
    try {
      p = await _prefs();
      raw = p.get(endpointRestrictionKey);
      legacyCode = p.get(endpointProblemKey);
      legacyUntil = p.get(endpointBlockedUntilKey);
    } catch (_) {
      _storageFailures++; // unreadable: do NOT assume there is no restriction
      return;
    }
    _storageFailures = 0;
    _endpointStateLoaded = true;
    // Nothing saved at all is the only "no restriction". ANY saved value, however damaged, is treated as a restriction:
    // a corrupt or half-written value must never let a restart skip a wait that was in force.
    if (raw == null && legacyCode == null && legacyUntil == null) return;

    String code = 'endpoint_unknown'; // the code is lost if the value is damaged; the wait still applies
    Object? until;
    var clean = false; // true only for a complete, valid single value (nothing to rewrite or clean up)
    if (raw != null) {
      final parsed = _parseRestriction(raw);
      if (parsed != null) {
        code = parsed.code;
        until = parsed.until;
        clean = until != null;
      }
    } else {
      // the earlier two-value layout (possibly half-written: either value may be missing or wrong)
      if (legacyCode is String && _problemCode.hasMatch(legacyCode)) code = legacyCode;
      until = legacyUntil;
    }
    final now = _now();
    final latest = now.add(endpointRetryInterval);
    DateTime deadline;
    if (until is int && until > 0) {
      deadline = DateTime.fromMillisecondsSinceEpoch(until, isUtc: true);
      if (deadline.isAfter(latest)) deadline = latest; // never block longer than the interval
    } else {
      deadline = latest; // unknown or damaged deadline: a fresh full wait, never a bypass
    }
    if (_endpointProblem == null) {
      // nothing newer was learned in this process
      _endpointProblem = code;
      _endpointBlockedUntil = deadline;
      // Only a clean single value is "saved". Anything else is held in memory and re-saved in the single-value format by
      // the same retry that handles failed writes (sync stays blocked until that save is confirmed).
      _endpointPersisted = clean;
    }
  }

  /// A complete single value is `{"v":1,"code":"http_404","until":<epoch ms>}`. A value with a valid code but a bad
  /// deadline still yields its code (until null); anything else is unparseable (null).
  static ({String code, int? until})? _parseRestriction(Object raw) {
    try {
      if (raw is! String) return null;
      final m = json.decode(raw);
      if (m is! Map) return null;
      final code = m['code'];
      if (code is! String || !_problemCode.hasMatch(code)) return null;
      final until = m['until'];
      return (code: code, until: (until is int && until > 0) ? until : null);
    } catch (_) {
      return null;
    }
  }

  /// Saves problem code and deadline in ONE value and returns true only if the write was confirmed: SharedPreferences said
  /// yes AND the value reads back exactly. The deadline written is always the one in memory, so retries and restarts keep
  /// the original. The earlier two-value keys are then removed (best effort: the single value takes precedence).
  Future<bool> _persistEndpointState() async {
    try {
      final p = await _prefs();
      final payload = json.encode({
        'v': 1,
        'code': _endpointProblem!,
        'until': _endpointBlockedUntil!.toUtc().millisecondsSinceEpoch,
      });
      if (!await p.setString(endpointRestrictionKey, payload)) return false;
      if (p.get(endpointRestrictionKey) != payload) return false;
      try {
        await p.remove(endpointProblemKey);
        await p.remove(endpointBlockedUntilKey);
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes everything saved; true only if every removal was confirmed. The earlier keys go first, the single value last,
  /// so a failure part-way can never leave an older, stale restriction behind a removed newer one.
  Future<bool> _clearPersistedEndpointState() async {
    try {
      final p = await _prefs();
      final a = await p.remove(endpointProblemKey);
      final b = await p.remove(endpointBlockedUntilKey);
      final c = await p.remove(endpointRestrictionKey);
      return a && b && c;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------------------------------------ sync
  /// Uploads what is waiting. [manual] (the user pressed Sync) skips the exponential back-off but never a server
  /// `Retry-After`. Concurrent calls share one run.
  Future<SyncReport> sync({bool manual = false}) {
    final running = _inFlight;
    if (running != null) return running.then((r) => SyncReport(SyncStatus.joined, uploaded: r.uploaded, created: r.created, duplicate: r.duplicate, rejected: r.rejected, retried: r.retried, guardianAccepted: r.guardianAccepted, guardianProviderAccepted: r.guardianProviderAccepted, retryAt: r.retryAt));
    final f = _run(manual).whenComplete(() => _inFlight = null);
    _inFlight = f;
    return f;
  }

  Future<SyncReport> _run(bool manual) async {
    await _clearLegacyQueueOnce();
    await restoreEndpointState(); // a deadline persisted before a restart applies to this run too
    final owner = _owner;
    if (owner == null) return const SyncReport(SyncStatus.signedOut);
    // Fail closed: if the saved restriction cannot be read it is unknown, so the one-hour rule cannot be proven absent. A
    // restriction learned in THIS process (kept in memory) still applies below, so only the unknown case is blocked here.
    if (!_endpointStateLoaded && _endpointBlockedUntil == null) {
      return const SyncReport(SyncStatus.settingsUnreadable, diagnostic: 'prefs_unreadable');
    }
    // A restriction that was never confirmed saved blocks EVERYTHING (manual Sync and an expired in-memory deadline
    // included) until the save succeeds: otherwise a restart right now would silently forget it. The save is retried on
    // every attempt (restoreEndpointState above settles pending writes).
    if (endpointWriteFailed) {
      return SyncReport(SyncStatus.settingsWriteFailed, retryAt: _endpointBlockedUntil, diagnostic: 'prefs_write_failed');
    }
    if (_authBlocked) return const SyncReport(SyncStatus.authRequired);
    final now = _now();
    // A permanent endpoint problem holds for at least an hour, manual presses included; the queued events stay untouched.
    if (_endpointBlockedUntil != null && now.isBefore(_endpointBlockedUntil!)) {
      return SyncReport(SyncStatus.endpointProblem, retryAt: _endpointBlockedUntil, diagnostic: _endpointProblem);
    }
    if (_rateLimitedUntil != null && now.isBefore(_rateLimitedUntil!)) {
      return SyncReport(SyncStatus.rateLimited, retryAt: _rateLimitedUntil);
    }
    if (!manual && _retryAt != null && now.isBefore(_retryAt!)) {
      return SyncReport(SyncStatus.backingOff, retryAt: _retryAt);
    }
    final epoch = _epoch;
    var total = const SyncReport(SyncStatus.idle);
    for (var i = 0; i < maxBatchesPerRun; i++) {
      final List<Map<String, dynamic>> batch;
      try {
        batch = await _drain();
      } catch (_) {
        return SyncReport(SyncStatus.storeUnavailable, uploaded: total.uploaded, created: total.created, duplicate: total.duplicate, rejected: total.rejected, retried: total.retried, guardianAccepted: total.guardianAccepted, guardianProviderAccepted: total.guardianProviderAccepted);
      }
      if (epoch != _epoch) return _with(total, SyncStatus.ownerChanged);
      if (batch.isEmpty) return _with(total, i == 0 ? SyncStatus.idle : SyncStatus.synced);

      final Response<dynamic> resp;
      try {
        resp = await _dio().post<dynamic>('/app-monitor/sync', data: {'events': batch});
      } on DioException catch (e) {
        if (epoch != _epoch) return _with(total, SyncStatus.ownerChanged);
        return await _failure(e, total, batch);
      } catch (_) {
        return await _failure(null, total, batch);
      }
      if (epoch != _epoch) return _with(total, SyncStatus.ownerChanged); // another account: never apply this response

      if (_endpointProblem != null || _endpointBlockedUntil != null) {
        // a successful response establishes recovery: only now is the problem (and its persisted deadline) removed
        _endpointBlockedUntil = null; // it no longer blocks anything
        if (await _clearPersistedEndpointState()) {
          _endpointProblem = null;
          _clearPending = false;
          _writeFailures = 0;
        } else {
          // the saved restriction could not be removed: the problem stays recorded and the removal is retried later
          _clearPending = true;
          _writeFailures++;
        }
      }
      if (!_hasOutcomes(resp.data)) {
        // A 200 without per-event outcomes is a server that predates Stage 2A: nothing can be matched, so nothing is
        // recorded and no attempt is spent. The events stay pending until the server is updated.
        _failures++;
        _retryAt = _now().add(_backoff());
        return _with(total, SyncStatus.serverUpdateNeeded);
      }
      final results = _mapOutcomes(batch, resp.data);
      final applied = await _mark(results.map((r) => r.toNative()).toList());
      if (epoch != _epoch) return _with(total, SyncStatus.ownerChanged);
      if (!applied) return _with(total, SyncStatus.storeUnavailable);

      total = SyncReport(
        SyncStatus.synced,
        uploaded: total.uploaded + batch.length,
        created: total.created + results.where((r) => r.history == 'created').length,
        duplicate: total.duplicate + results.where((r) => r.history == 'duplicate').length,
        rejected: total.rejected + results.where((r) => r.history == 'rejected').length,
        retried: total.retried + results.where((r) => r.history == 'retry').length,
        guardianAccepted: total.guardianAccepted + results.where((r) => r.guardianAccepted).length,
        guardianProviderAccepted: total.guardianProviderAccepted + results.where((r) => r.guardianProviderAccepted).length,
      );
      _failures = 0;
      _retryAt = null;
      // Nothing settled in this batch (every event got "retry"): stop instead of resending the same events in a loop.
      if (results.every((r) => r.history == 'retry')) return total;
      if (batch.length < 50) return total;
    }
    return total;
  }

  SyncReport _with(SyncReport t, SyncStatus s, {DateTime? retryAt, String? diagnostic}) => SyncReport(s,
      uploaded: t.uploaded, created: t.created, duplicate: t.duplicate, rejected: t.rejected, retried: t.retried,
      guardianAccepted: t.guardianAccepted, guardianProviderAccepted: t.guardianProviderAccepted, retryAt: retryAt, diagnostic: diagnostic);

  /// Whole-request failures. Only 400, 413 and 422 mean "this request can never succeed" and spend one attempt per event
  /// (so a poison batch cannot loop forever). 401 and 429 keep their own handling. Everything else (403, 408, 409, 423,
  /// 425, other 4xx, 5xx, network errors) is retried with back-off and spends NO attempt.
  Future<SyncReport> _failure(DioException? e, SyncReport total, List<Map<String, dynamic>> batch) async {
    final code = e?.response?.statusCode;
    final now = _now();
    if (code == 401) {
      _authBlocked = true; // events are kept; a new sign-in (setOwner) clears this
      // The Dio client already tried a refresh. If no refresh token is left it was rejected for good: that is a confirmed
      // end of the session, and only then is the native owner cleared (events stay stored, but unattributed).
      if (!await _hasRefreshToken()) unawaited(setOwner(null));
      return _with(total, SyncStatus.authRequired);
    }
    final tls = e != null && (e.type == DioExceptionType.badCertificate || e.error is TlsException);
    if (tls || (code != null && _permanentEndpointCodes.contains(code))) {
      // The URL, route or certificate is wrong. More retries cannot fix it and no event is at fault, so no attempt is
      // spent and nothing is discarded: the events wait, the problem is recorded, and the next try is an hour away.
      _endpointProblem = tls ? 'tls_certificate' : 'http_$code';
      _endpointBlockedUntil = now.add(endpointRetryInterval);
      _clearPending = false;
      _endpointPersisted = await _persistEndpointState(); // never claimed saved unless the write was confirmed
      if (!_endpointPersisted) {
        _writeFailures++;
        return _with(total, SyncStatus.settingsWriteFailed, retryAt: _endpointBlockedUntil, diagnostic: 'prefs_write_failed');
      }
      _writeFailures = 0;
      return _with(total, SyncStatus.endpointProblem, retryAt: _endpointBlockedUntil, diagnostic: _endpointProblem);
    }
    if (code == 429) {
      final wait = _parseRetryAfter(e!.response!.headers.value('retry-after'), now);
      _rateLimitedUntil = now.add(wait);
      return _with(total, SyncStatus.rateLimited, retryAt: _rateLimitedUntil);
    }
    if (code == 400 || code == 413 || code == 422) {
      await _mark([for (final b in batch) _EventResult(b['client_event_id'] as String?, 'retry', null, reason: 'http_$code').toNative()]);
    }
    _failures++;
    _retryAt = now.add(_backoff());
    return _with(total, SyncStatus.offline, retryAt: _retryAt);
  }

  Duration _backoff() {
    final ms = _baseBackoff.inMilliseconds * (1 << (_failures - 1).clamp(0, 10));
    return Duration(milliseconds: ms > _maxBackoff.inMilliseconds ? _maxBackoff.inMilliseconds : ms);
  }

  static Duration _parseRetryAfter(String? v, DateTime now) {
    if (v == null) return _defaultRetryAfter;
    final secs = int.tryParse(v.trim());
    Duration d;
    if (secs != null) {
      d = Duration(seconds: secs);
    } else {
      try {
        d = HttpDate.parse(v.trim()).difference(now.toUtc());
      } catch (_) {
        d = _defaultRetryAfter;
      }
    }
    if (d < const Duration(seconds: 1)) d = const Duration(seconds: 1);
    return d > _maxRetryAfter ? _maxRetryAfter : d;
  }

  // ------------------------------------------------------------------------------------------------ response mapping
  static bool _hasOutcomes(dynamic data) => data is Map && data['outcomes'] is List && (data['outcomes'] as List).isNotEmpty;

  /// One result per uploaded event, matched BY INDEX and confirmed by `client_event_id` (never by position alone).
  /// created/duplicate -> synced; rejected -> permanent; anything else, a missing outcome or an id mismatch -> retry.
  List<_EventResult> _mapOutcomes(List<Map<String, dynamic>> batch, dynamic data) {
    final outcomes = <int, Map<String, dynamic>>{};
    if (data is Map && data['outcomes'] is List) {
      for (final o in data['outcomes'] as List) {
        if (o is Map && o['index'] is int) outcomes[o['index'] as int] = Map<String, dynamic>.from(o);
      }
    }
    final out = <_EventResult>[];
    for (var i = 0; i < batch.length; i++) {
      final id = batch[i]['client_event_id'] as String?;
      final o = outcomes[i];
      if (o == null) {
        out.add(_EventResult(id, 'retry', null, reason: 'no_outcome'));
        continue;
      }
      if (o['client_event_id'] != null && o['client_event_id'] != id) {
        out.add(_EventResult(id, 'retry', null, reason: 'id_mismatch'));
        continue;
      }
      final status = o['status'];
      if (status != 'created' && status != 'duplicate' && status != 'rejected') {
        out.add(_EventResult(id, 'retry', null, reason: 'unknown_status'));
        continue;
      }
      final g = o['guardian'];
      final guardian = (g is Map && g['status'] is String) ? g['status'] as String : null;
      final guardianReason = (g is Map && g['reason'] is String) ? g['reason'] as String : null;
      out.add(_EventResult(id, status as String, status == 'rejected' ? null : guardian,
          guardianReason: status == 'rejected' ? null : guardianReason, reason: status == 'rejected' ? o['reason'] as String? : null));
    }
    return out;
  }

  // ------------------------------------------------------------------------------------------------ native calls
  Future<List<Map<String, dynamic>>> _drain() async {
    final raw = await _ch.invokeListMethod<dynamic>('drainEvents', {'limit': 50});
    return (raw ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<bool> _mark(List<Map<String, Object?>> results) async {
    try {
      await _ch.invokeMapMethod<String, dynamic>('markResults', {'results': results});
      return true;
    } catch (_) {
      return false; // not recorded: the next run re-uploads these events and the server answers "duplicate"
    }
  }

  Future<void> _clearLegacyQueueOnce() async {
    if (_legacyCleared) return;
    _legacyCleared = true;
    try {
      final p = await SharedPreferences.getInstance();
      if (p.containsKey(legacyQueueKey)) await p.remove(legacyQueueKey);
    } catch (_) {}
  }
}

class _EventResult {
  final String? id;
  final String history; // created | duplicate | rejected | retry
  final String? guardian; // the server's raw guardian status, or null
  final String? guardianReason; // the server's reason code for it (for example not_authorised)
  final String? reason; // rejection reason, or the error code of a retry
  _EventResult(this.id, this.history, this.guardian, {this.guardianReason, this.reason});

  /// The server holds an alert for this event: it is NOT delivered and may still fail or be skipped.
  bool get guardianAccepted => guardian == 'queued' || guardian == 'already' || guardian == 'pending' || guardian == 'leased';

  /// The provider accepted the alert. This is as far as the system can know: handset delivery is never confirmed.
  bool get guardianProviderAccepted => guardian == 'sent';

  Map<String, Object?> toNative() =>
      {'id': id, 'history': history, 'guardian': guardian, 'guardianReason': guardianReason, 'reason': reason};
}

/// The coordinator, bound to the authentication lifecycle: the native owner follows the signed-in account (set at app
/// start once the session is restored, on login, on account switch; cleared on sign-out).
final monitorSyncProvider = Provider<MonitorSyncCoordinator>((ref) {
  final c = MonitorSyncCoordinator();
  unawaited(c.restoreEndpointState());
  Future<void> follow(AuthState s) async {
    if (s.isLoading) return; // the session is still being restored: do not guess
    final id = (s.isAuthenticated && (s.userId?.isNotEmpty ?? false)) ? s.userId : null;
    // An expired access token is not a sign-out: while a refresh token remains, the last known native owner is kept so
    // events that arrive in the background are still stored. Logout and a rejected refresh delete the tokens, which ends it.
    if (id == null && await c.hasRefreshToken()) {
      await c.reconcileStaleOwner(); // validates once at startup; keeps the owner unless the session is confirmed gone
      return;
    }
    final ok = await c.setOwner(id);
    if (ok && id != null) unawaited(c.sync());
  }

  // Auth changes are handled strictly in order: a slow earlier change can never land after a later one.
  var chain = Future<void>.value();
  ref.listen<AuthState>(authProvider, (_, next) {
    chain = chain.then((_) => follow(next)).catchError((Object _) {});
  }, fireImmediately: true);
  return c;
});


/// The one-line message the screen shows for a sync result.
String syncMessage(SyncReport r) {
  switch (r.status) {
    case SyncStatus.idle:
      return 'Nothing to sync';
    case SyncStatus.synced:
    case SyncStatus.joined:
      return 'Synced ${r.settled} events';
    case SyncStatus.offline:
      return 'Could not reach the server. Your events are saved and will be sent later.';
    case SyncStatus.rateLimited:
      return 'The server asked us to wait. Your events are saved and will be sent later.';
    case SyncStatus.authRequired:
      return 'Sign in again to sync. Your events are saved.';
    case SyncStatus.signedOut:
      return 'Sign in to sync.';
    case SyncStatus.backingOff:
      return 'Will retry shortly. Your events are saved.';
    case SyncStatus.ownerChanged:
      return 'The account changed. Nothing was synced.';
    case SyncStatus.storeUnavailable:
      return 'Event storage is not available on this device.';
    case SyncStatus.serverUpdateNeeded:
      return 'Server update needed';
    case SyncStatus.endpointProblem:
      return endpointProblemMessage(r.diagnostic);
    case SyncStatus.settingsUnreadable:
      return storageProblemMessage();
    case SyncStatus.settingsWriteFailed:
      return writeProblemMessage();
  }
}

/// The sentence shown for a permanent endpoint problem (HTTP 404/405/410/501 or a rejected TLS certificate).
String endpointProblemMessage(String? code) {
  if (code == 'tls_certificate') {
    return "The server's security certificate was rejected, so SecureShield cannot sync. Your events are saved on this "
        'device. It will try again in about an hour.';
  }
  final c = (code != null && code.startsWith('http_')) ? ' (${code.replaceFirst('http_', 'HTTP ')})' : '';
  return 'The sync service cannot be reached at its address$c. The app or the server may need an update. Your events are '
      'saved on this device. It will try again in about an hour.';
}

/// Shown while the saved sync-restriction state cannot be read: sync is paused, nothing is lost, and it retries by itself.
String storageProblemMessage() =>
    "SecureShield cannot read its saved sync settings on this device, so sync is paused to be safe. Your events are saved "
    'and nothing was discarded. It will try again automatically; if this keeps happening, free up storage space or restart '
    'the phone.';

/// Shown while a sync restriction is held but could not be saved: sync stays paused so a restart cannot forget it.
String writeProblemMessage() =>
    'SecureShield could not save a sync restriction on this device. Until it can be saved, sync stays paused so that '
    'restarting the app cannot make it forget the restriction. Your events are saved and nothing was discarded. It will '
    'try to save it again automatically; if this keeps happening, free up storage space or restart the phone.';

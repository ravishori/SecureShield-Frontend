import 'dart:async';

import 'dart:io' show HandshakeException;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/features/app_monitor/monitor_sync_coordinator.dart';
import 'package:secureshield_app/features/auth/auth_provider.dart';

import '../auth/fake_http.dart';
import 'flaky_prefs.dart';

const _channel = MethodChannel('secureshield/app_monitor');

/// A Dart model of the native store's contract (Stage 2B): owner-scoped, read-only drain, results applied only to the
/// current owner's pending events, owner switch deletes everyone else's events.
class _Native {
  String? owner;
  bool acceptOwner = true;
  final rows = <Map<String, dynamic>>[]; // {id, owner, history, guardian, attempts, payload}
  final calls = <String>[];
  final marked = <Map<String, Object?>>[];
  void Function()? onDrain; // hook to simulate something happening mid-run
  final failOwners = <String?>{}; // setOwner answers false for these
  bool purgeFails = false; // purge answers ok:false
  bool purgeThrows = false; // purge raises a platform error
  final ownerCalls = <String?>[]; // every setOwner argument, in arrival order
  final ownerDelay = <String?, Duration>{}; // makes a particular setOwner slow

  void add(String id, String ownerId, {int at = 1000}) => rows.add({
        'id': id,
        'owner': ownerId,
        'history': 'pending',
        'guardian': 'pending',
        'attempts': 0,
        'payload': {
          'client_event_id': id,
          'occurred_at': at,
          'client_timestamp': at,
          'package_name': 'com.example.$id',
          'app_name': 'App $id',
          'event_type': 'installed',
        },
      });

  Iterable<Map<String, dynamic>> get mine => rows.where((r) => r['owner'] == owner);
  Map<String, dynamic> row(String id) => rows.firstWhere((r) => r['id'] == id);

  Future<Object?> handle(MethodCall c) async {
    calls.add(c.method);
    final a = (c.arguments as Map?) ?? {};
    switch (c.method) {
      case 'setOwner':
        final o = a['ownerId'] as String?;
        ownerCalls.add(o);
        if (ownerDelay[o] != null) await Future<void>.delayed(ownerDelay[o]!);
        if (!acceptOwner || failOwners.contains(o)) return false;
        if (o != null) rows.removeWhere((r) => r['owner'] != o);
        owner = o;
        return true;
      case 'drainEvents':
        onDrain?.call();
        if (owner == null) return <Object?>[];
        return mine.where((r) => r['history'] == 'pending').take((a['limit'] as int?) ?? 50).map((r) => r['payload']).toList();
      case 'markResults':
        var updated = 0, ignored = 0;
        for (final r in (a['results'] as List).cast<Map>()) {
          marked.add(Map<String, Object?>.from(r));
          final row = mine.where((x) => x['id'] == r['id']).toList();
          if (owner == null || row.isEmpty || row.first['history'] != 'pending') {
            row.isEmpty ? ignored++ : updated++;
            continue;
          }
          final h = r['history'] as String;
          final g = r['guardian'] as String?;
          if (h == 'created' || h == 'duplicate') {
            row.first['history'] = 'synced';
            row.first['guardian'] = const {'queued', 'already', 'pending', 'leased'}.contains(g)
                ? 'accepted'
                : g == 'sent'
                    ? 'provider_accepted'
                    : const {'skipped', 'expired', 'none'}.contains(g)
                        ? 'not_sent'
                        : g == 'failed'
                            ? 'failed'
                            : 'pending';
            row.first['guardianReason'] = r['guardianReason'];
          } else if (h == 'rejected') {
            row.first['history'] = 'rejected';
            row.first['guardian'] = 'not_sent';
            row.first['lastError'] = r['reason'];
          } else {
            row.first['attempts'] = (row.first['attempts'] as int) + 1;
            row.first['lastError'] = r['reason'];
          }
          updated++;
        }
        return {'updated': updated, 'ignored': ignored};
      case 'stats':
        return {'available': true, 'hasOwner': owner != null};
      case 'purge':
        if (purgeThrows) throw PlatformException(code: 'PURGE_FAILED');
        if (purgeFails) return {'ok': false, 'deleted': 0};
        final o = a['ownerId'] as String?;
        final n = rows.length;
        rows.removeWhere((r) => o == null || r['owner'] == o);
        return {'ok': true, 'deleted': n - rows.length};
    }
    return null;
  }
}

String _fakeSession(String id) => fakeJwt({'sub': id, 'identifier': 'x@example.com', 'exp': 4102444800});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Native native;
  late FakeAdapter adapter;
  late ResponseBody Function(RequestOptions) server;
  late DateTime clock;
  late MonitorSyncCoordinator coord;
  var refreshTokenPresent = true;

  /// Answers every uploaded event with [status] (guardian [guardian]).
  ResponseBody Function(RequestOptions) answerAll(String status, {String? guardian, String? reason}) => (o) {
        final events = (o.data as Map)['events'] as List;
        return jsonBody(200, {
          'synced': status == 'created' ? events.length : 0,
          'results': [],
          'outcomes': [
            for (var i = 0; i < events.length; i++)
              {
                'index': i,
                'client_event_id': (events[i] as Map)['client_event_id'],
                'status': status,
                if (reason != null) 'reason': reason,
                if (guardian != null) 'guardian': {'status': guardian},
              }
          ],
        });
      };

  setUp(() {
    native = _Native();
    clock = DateTime.utc(2026, 11, 14, 12);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, native.handle);
    server = answerAll('created');
    adapter = FakeAdapter((o) => server(o));
    DioClient().dio.httpClientAdapter = adapter; // provider-level tests use the shared client: never the real network
    refreshTokenPresent = true;
    coord = MonitorSyncCoordinator(
        dio: () => dioWith(adapter), now: () => clock, hasRefreshToken: () async => refreshTokenPresent);
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));

  Future<void> signedInWith(List<String> ids, {String owner = 'user-a'}) async {
    for (final id in ids) {
      native.add(id, owner);
    }
    expect(await coord.setOwner(owner), isTrue);
  }

  group('authentication lifecycle and account isolation', () {
    test('nothing is read or sent while signed out', () async {
      native.add('e1', 'user-a');
      final r = await coord.sync();
      expect(r.status, SyncStatus.signedOut);
      expect(adapter.requests, isEmpty);
      expect(native.calls, isNot(contains('drainEvents')));
    });

    test('the owner is established natively before anything is uploaded', () async {
      await signedInWith(['e1']);
      expect(native.calls.first, 'setOwner');
      expect(coord.owner, 'user-a');
      await coord.sync();
      expect(native.calls.indexOf('setOwner'), lessThan(native.calls.indexOf('drainEvents')));
    });

    test('if the native side refuses the owner, the coordinator stays signed out', () async {
      native.acceptOwner = false;
      expect(await coord.setOwner('user-a'), isFalse);
      expect(coord.owner, isNull);
      expect((await coord.sync()).status, SyncStatus.signedOut);
    });

    test('logout (owner null) stops all syncing', () async {
      await signedInWith(['e1']);
      await coord.setOwner(null);
      expect((await coord.sync()).status, SyncStatus.signedOut);
      expect(adapter.requests, isEmpty);
    });

    test('switching accounts: the first account\'s events are gone and never sent for the second', () async {
      await signedInWith(['a1', 'a2']);
      expect(await coord.setOwner('user-b'), isTrue);
      native.add('b1', 'user-b');
      await coord.sync();
      final sent = adapter.requests.expand((o) => ((o.data as Map)['events'] as List).map((e) => (e as Map)['client_event_id'])).toList();
      expect(sent, ['b1']);
      expect(native.rows.where((r) => r['owner'] == 'user-a'), isEmpty);
    });

    test('an account change DURING a request discards that response and applies nothing to the new account', () async {
      await signedInWith(['a1']);
      final gate = Completer<void>();
      server = (o) => answerAll('created')(o);
      adapter = FakeAdapter((o) => server(o));
      var first = true;
      coord = MonitorSyncCoordinator(
        dio: () {
          final d = Dio(BaseOptions(baseUrl: 'http://test'));
          d.httpClientAdapter = _GatedAdapter(adapter, () async {
            if (first) {
              first = false;
              await gate.future;
            }
          });
          return d;
        },
        now: () => clock,
      );
      expect(await coord.setOwner('user-a'), isTrue);
      final run = coord.sync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await coord.setOwner('user-b'); // the user switched accounts mid-flight
      gate.complete();
      final r = await run;
      expect(r.status, SyncStatus.ownerChanged);
      expect(native.marked, isEmpty); // nothing from the old response was applied
    });

    test('account deletion purges every stored event and signs the store out', () async {
      await signedInWith(['a1', 'a2']);
      native.add('other', 'user-z');
      expect(await coord.purgeAll(), isTrue);
      expect(native.rows, isEmpty);
      expect(native.owner, isNull);
      expect(coord.owner, isNull);
      expect((await coord.sync()).status, SyncStatus.signedOut);
    });

    test('setting the same owner again changes nothing and keeps the events', () async {
      await signedInWith(['a1']);
      expect(await coord.setOwner('user-a'), isTrue);
      expect(native.rows.length, 1);
    });
  });

  group('batch upload and response mapping', () {
    test('sends the native UUID as client_event_id and preserves occurred_at', () async {
      native.add('11111111-1111-4111-8111-111111111111', 'user-a', at: 1763121600000);
      expect(await coord.setOwner('user-a'), isTrue);
      await coord.sync();
      final e = ((adapter.requests.single.data as Map)['events'] as List).single as Map;
      expect(e['client_event_id'], '11111111-1111-4111-8111-111111111111');
      expect(e['occurred_at'], 1763121600000);
      expect(adapter.requests.single.path, '/app-monitor/sync');
    });

    test('created events become synced and are not sent again', () async {
      await signedInWith(['e1', 'e2', 'e3']);
      final r = await coord.sync();
      expect((r.status, r.created, r.settled), (SyncStatus.synced, 3, 3));
      expect(native.rows.every((x) => x['history'] == 'synced'), isTrue);
      adapter.requests.clear();
      expect((await coord.sync()).status, SyncStatus.idle);
      expect(adapter.requests, isEmpty);
    });

    test('duplicate responses are final success (a re-sent event after a crash)', () async {
      await signedInWith(['e1']);
      server = answerAll('duplicate');
      final r = await coord.sync();
      expect((r.duplicate, r.created), (1, 0));
      expect(native.row('e1')['history'], 'synced');
    });

    test('rejected is permanent: recorded, never re-sent', () async {
      await signedInWith(['e1']);
      server = answerAll('rejected', reason: 'invalid_payload');
      final r = await coord.sync();
      expect(r.rejected, 1);
      expect(native.row('e1')['history'], 'rejected');
      expect(native.row('e1')['guardian'], 'not_sent');
      adapter.requests.clear();
      await coord.sync();
      expect(adapter.requests, isEmpty);
    });

    test('a mixed batch maps each event by index and id', () async {
      await signedInWith(['e1', 'e2', 'e3']);
      server = (o) {
        final ev = ((o.data as Map)['events'] as List).cast<Map>();
        return jsonBody(200, {
          'outcomes': [
            {'index': 0, 'client_event_id': ev[0]['client_event_id'], 'status': 'created', 'guardian': {'status': 'queued'}},
            {'index': 1, 'client_event_id': ev[1]['client_event_id'], 'status': 'rejected', 'reason': 'bad_timestamp'},
            {'index': 2, 'client_event_id': ev[2]['client_event_id'], 'status': 'duplicate', 'guardian': {'status': 'none'}},
          ]
        });
      };
      final r = await coord.sync();
      expect((r.created, r.rejected, r.duplicate), (1, 1, 1));
      expect(native.row('e1')['history'], 'synced');
      expect(native.row('e2')['history'], 'rejected');
      expect(native.row('e3')['history'], 'synced');
    });

    test('a missing outcome or a mismatched id is a per-event retry, not success', () async {
      await signedInWith(['e1', 'e2']);
      server = (o) {
        return jsonBody(200, {
          'outcomes': [
            {'index': 0, 'client_event_id': 'someone-elses-id', 'status': 'created'},
            // index 1 missing
          ]
        });
      };
      final r = await coord.sync();
      expect((r.retried, r.created), (2, 0));
      expect(native.row('e1')['history'], 'pending');
      expect(native.row('e1')['attempts'], 1);
      expect(native.row('e2')['attempts'], 1);
    });

    test('a 200 without outcomes is a server compatibility error: nothing is recorded and no attempt is spent', () async {
      await signedInWith(['e1', 'e2']);
      server = (o) => jsonBody(200, {'synced': 2, 'results': []});
      final r = await coord.sync();
      expect(r.status, SyncStatus.serverUpdateNeeded);
      expect(native.marked, isEmpty);
      expect(native.rows.every((x) => x['history'] == 'pending' && x['attempts'] == 0), isTrue);
      expect(syncMessage(r), 'Server update needed');
      server = (o) => jsonBody(200, {'synced': 0, 'results': [], 'outcomes': []}); // an empty list is the same thing
      expect((await coord.sync(manual: true)).status, SyncStatus.serverUpdateNeeded);
      expect(native.marked, isEmpty);
    });

    test('more than one batch is drained in one run, 50 at a time', () async {
      await signedInWith([for (var i = 0; i < 120; i++) 'e$i']);
      final r = await coord.sync();
      expect(r.created, 120);
      expect(adapter.requests.map((o) => ((o.data as Map)['events'] as List).length).toList(), [50, 50, 20]);
    });
  });

  group('history and guardian states are independent', () {
    test('every server guardian status maps to what it really means (never "delivered")', () async {
      const expected = {
        'queued': 'accepted', 'already': 'accepted', 'pending': 'accepted', 'leased': 'accepted',
        'sent': 'provider_accepted',
        'skipped': 'not_sent', 'expired': 'not_sent', 'none': 'not_sent',
        'failed': 'failed',
      };
      final ids = {for (final k in expected.keys) k: 'g-$k'};
      await signedInWith([...ids.values, 'g-null']);
      server = (o) {
        final ev = ((o.data as Map)['events'] as List).cast<Map>();
        return jsonBody(200, {
          'outcomes': [
            for (var i = 0; i < ev.length; i++)
              {
                'index': i,
                'client_event_id': ev[i]['client_event_id'],
                'status': 'created',
                if (ev[i]['client_event_id'] != 'g-null')
                  'guardian': {
                    'status': ids.entries.firstWhere((e) => e.value == ev[i]['client_event_id']).key,
                    if (ev[i]['client_event_id'] == 'g-skipped') 'reason': 'not_authorised',
                  },
              }
          ]
        });
      };
      final r = await coord.sync();
      expect(r.guardianAccepted, 4); // queued, already, pending, leased
      expect(r.guardianProviderAccepted, 1); // sent
      expected.forEach((status, state) {
        final row = native.row('g-$status');
        expect((row['history'], row['guardian']), ('synced', state), reason: status);
      });
      expect(native.row('g-null')['guardian'], 'pending');
      expect(native.row('g-skipped')['guardianReason'], 'not_authorised'); // the reason code is passed through
    });

    test('a queued alert is never stored as delivered or provider-accepted', () async {
      await signedInWith(['q']);
      server = answerAll('created', guardian: 'queued');
      await coord.sync();
      expect(native.row('q')['guardian'], 'accepted');
      expect(native.row('q')['guardian'], isNot(anyOf('delivered', 'provider_accepted')));
    });

    test('a retried event reports no guardian outcome (history is not final yet)', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(200, {
            'outcomes': [
              {'index': 0, 'client_event_id': 'e1', 'status': 'mystery', 'guardian': {'status': 'sent'}}
            ]
          });
      await coord.sync();
      expect(native.marked.single['guardian'], isNull);
    });
  });

  group('failures: offline, 5xx, 429, 401 (events are never lost)', () {
    test('offline: nothing is marked, no attempt is spent, and the next run succeeds', () async {
      await signedInWith(['e1']);
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      final r = await coord.sync();
      expect(r.status, SyncStatus.offline);
      expect(native.marked, isEmpty);
      expect(native.row('e1')['attempts'], 0);
      expect((await coord.sync()).status, SyncStatus.backingOff); // not hammering
      clock = clock.add(const Duration(seconds: 31));
      server = answerAll('created');
      expect((await coord.sync()).created, 1);
      expect(native.row('e1')['history'], 'synced');
    });

    test('back-off grows with repeated failures, is capped, and a manual sync skips it', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(503, {'detail': 'down'});
      var r = await coord.sync();
      expect(r.retryAt, clock.add(const Duration(seconds: 30)));
      r = await coord.sync(manual: true);
      expect(r.retryAt, clock.add(const Duration(seconds: 60)));
      r = await coord.sync(manual: true);
      expect(r.retryAt, clock.add(const Duration(seconds: 120)));
      for (var i = 0; i < 12; i++) {
        r = await coord.sync(manual: true);
      }
      expect(r.retryAt, clock.add(const Duration(minutes: 15)));
      expect(native.marked, isEmpty);
    });

    test('HTTP 5xx keeps the events untouched', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(500, {'detail': 'boom'});
      expect((await coord.sync()).status, SyncStatus.offline);
      expect(native.row('e1')['history'], 'pending');
      expect(native.marked, isEmpty);
    });

    test('429 honours Retry-After, even for a manual sync, and then resumes', () async {
      await signedInWith(['e1']);
      server = (o) => ResponseBody.fromString('{"detail":"slow down"}', 429, headers: {
            'retry-after': ['90'],
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
      var r = await coord.sync();
      expect(r.status, SyncStatus.rateLimited);
      expect(r.retryAt, clock.add(const Duration(seconds: 90)));
      expect(native.marked, isEmpty);
      adapter.requests.clear();
      expect((await coord.sync(manual: true)).status, SyncStatus.rateLimited);
      expect(adapter.requests, isEmpty); // not even a manual press goes around the server's wait
      clock = clock.add(const Duration(seconds: 91));
      server = answerAll('created');
      r = await coord.sync();
      expect(r.created, 1);
    });

    test('429 without a usable Retry-After waits a sane default; a huge one is capped', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(429, {'detail': 'x'});
      expect((await coord.sync()).retryAt, clock.add(const Duration(seconds: 60)));
      clock = clock.add(const Duration(seconds: 61));
      server = (o) => ResponseBody.fromString('{}', 429, headers: {
            'retry-after': ['999999'],
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
      expect((await coord.sync()).retryAt, clock.add(const Duration(hours: 1)));
    });

    test('401 with a refresh token still stored keeps every event and the owner, and waits for the next sign-in', () async {
      await signedInWith(['e1', 'e2']);
      server = (o) => jsonBody(401, {'detail': 'expired'});
      expect((await coord.sync()).status, SyncStatus.authRequired);
      expect(native.owner, 'user-a'); // the session may still be refreshed: the owner is NOT cleared
      expect(native.rows.length, 2);
      expect(native.rows.every((r) => r['history'] == 'pending' && r['attempts'] == 0), isTrue);
      adapter.requests.clear();
      expect((await coord.sync()).status, SyncStatus.authRequired);
      expect(adapter.requests, isEmpty); // no pointless retries with a dead session
      server = answerAll('created');
      await coord.setOwner('user-a'); // signing in again (same account) clears the block
      expect((await coord.sync()).created, 2);
    });

    test('401 after a CONFIRMED refresh rejection (no refresh token left) clears the owner but keeps the events', () async {
      await signedInWith(['e1']);
      refreshTokenPresent = false; // the Dio client deleted the tokens when the refresh was rejected
      server = (o) => jsonBody(401, {'detail': 'expired'});
      expect((await coord.sync()).status, SyncStatus.authRequired);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(native.owner, isNull);
      expect(native.rows.length, 1); // kept, unattributable until the same account signs in again
      expect(native.row('e1')['history'], 'pending');
    });

    for (final code in [400, 413, 422]) {
      test('HTTP $code spends one attempt per event and records http_$code', () async {
        await signedInWith(['e1', 'e2']);
        server = (o) => jsonBody(code, {'detail': 'bad'});
        expect((await coord.sync()).status, SyncStatus.offline);
        expect(native.rows.map((r) => r['attempts']), [1, 1]);
        expect(native.rows.map((r) => r['lastError']), ['http_$code', 'http_$code']);
      });
    }

    for (final code in [403, 408, 409, 423, 425, 500, 502, 503]) {
      test('HTTP $code is retried with back-off and spends NO attempt', () async {
        await signedInWith(['e1']);
        server = (o) => jsonBody(code, {'detail': 'x'});
        for (var i = 0; i < 12; i++) {
          clock = clock.add(const Duration(minutes: 20));
          expect((await coord.sync()).status, SyncStatus.offline);
        }
        expect(native.marked, isEmpty);
        expect(native.row('e1')['attempts'], 0);
        expect(native.row('e1')['history'], 'pending'); // twelve failures later it is still waiting, not failed
      });
    }

    test('a missing outcome records no_outcome; a wrong id records id_mismatch; an unknown status records unknown_status', () async {
      await signedInWith(['a', 'b', 'c']);
      server = (o) {
        final ev = ((o.data as Map)['events'] as List).cast<Map>();
        return jsonBody(200, {
          'outcomes': [
            {'index': 0, 'client_event_id': 'wrong', 'status': 'created'},
            {'index': 1, 'client_event_id': ev[1]['client_event_id'], 'status': 'mystery'},
          ]
        });
      };
      await coord.sync();
      expect([native.row('a')['lastError'], native.row('b')['lastError'], native.row('c')['lastError']],
          ['id_mismatch', 'unknown_status', 'no_outcome']);
    });

    test('a rejected event keeps the server\'s reason code', () async {
      await signedInWith(['e1']);
      server = answerAll('rejected', reason: 'bad_timestamp');
      await coord.sync();
      expect(native.row('e1')['lastError'], 'bad_timestamp');
    });

    test('offline recovery re-sends the same ids and the server\'s "duplicate" settles them without double counting', () async {
      await signedInWith(['e1']);
      // the upload reached the server but the response was lost
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
      await coord.sync();
      clock = clock.add(const Duration(minutes: 1));
      server = answerAll('duplicate');
      final r = await coord.sync();
      expect((r.duplicate, r.created), (1, 0));
      final ids = adapter.requests.map((o) => (((o.data as Map)['events'] as List).single as Map)['client_event_id']).toList();
      expect(ids, ['e1', 'e1']);
    });

    test('a failure to record results is safe: the events are re-sent next time', () async {
      await signedInWith(['e1']);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (c) async {
        if (c.method == 'markResults') throw PlatformException(code: 'x');
        return native.handle(c);
      });
      expect((await coord.sync()).status, SyncStatus.storeUnavailable);
      expect(native.row('e1')['history'], 'pending');
    });

    test('a missing native plugin (not Android) is reported, not thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
      expect(await coord.setOwner('user-a'), isFalse);
      expect((await coord.sync()).status, SyncStatus.signedOut);
    });
  });

  group('one upload pipeline, no concurrent runs', () {
    test('two simultaneous syncs make one upload; the second joins', () async {
      await signedInWith(['e1']);
      final gate = Completer<void>();
      coord = MonitorSyncCoordinator(
        dio: () {
          final d = Dio(BaseOptions(baseUrl: 'http://test'));
          d.httpClientAdapter = _GatedAdapter(adapter, () => gate.future);
          return d;
        },
        now: () => clock,
      );
      await coord.setOwner('user-a');
      final a = coord.sync();
      final b = coord.sync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      final ra = await a, rb = await b;
      expect(adapter.requests.length, 1);
      expect(ra.status, SyncStatus.synced);
      expect(rb.status, SyncStatus.joined);
    });

    test('a sync after a run has finished starts a new run', () async {
      await signedInWith(['e1']);
      await coord.sync();
      native.add('e2', 'user-a');
      expect((await coord.sync()).created, 1);
      expect(adapter.requests.length, 2);
    });

    test('the retired pre-Stage-2B queue is deleted, never uploaded', () async {
      SharedPreferences.setMockInitialValues({legacyQueueKey: ['{"package_name":"old.app","app_name":"Old"}']});
      await signedInWith([]);
      await coord.sync();
      expect((await SharedPreferences.getInstance()).containsKey(legacyQueueKey), isFalse);
      expect(adapter.requests, isEmpty);
    });
  });

  group('F1: permanent endpoint problems', () {
    for (final code in [404, 405, 410, 501]) {
      test('HTTP $code is a permanent endpoint problem: events kept, no attempts, a diagnostic, one hour minimum', () async {
        await signedInWith(['e1', 'e2']);
        server = (o) => jsonBody(code, {'detail': 'gone'});
        final r = await coord.sync();
        expect(r.status, SyncStatus.endpointProblem);
        expect(r.diagnostic, 'http_$code');
        expect(coord.endpointProblem, 'http_$code');
        expect(r.retryAt, clock.add(const Duration(hours: 1)));
        expect(native.marked, isEmpty); // nothing was marked, so nothing was spent or discarded
        expect(native.rows.every((x) => x['history'] == 'pending' && x['attempts'] == 0), isTrue);
        expect(syncMessage(r), contains('HTTP $code'));
        expect(syncMessage(r), contains('saved on this device'));
      });
    }

    test('nothing is sent for an hour, not even by a manual sync; then it tries again', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(404, {'detail': 'x'});
      await coord.sync();
      adapter.requests.clear();
      clock = clock.add(const Duration(minutes: 59));
      expect((await coord.sync(manual: true)).status, SyncStatus.endpointProblem);
      expect((await coord.sync()).status, SyncStatus.endpointProblem);
      expect(adapter.requests, isEmpty);
      clock = clock.add(const Duration(minutes: 2)); // 61 minutes in total
      await coord.sync();
      expect(adapter.requests.length, 1); // it did try again
    });

    test('a repeated failure keeps the events and waits another hour (never a tight loop, never a silent drop)', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(404, {'detail': 'x'});
      await coord.sync();
      for (var i = 0; i < 5; i++) {
        clock = clock.add(const Duration(hours: 1, minutes: 1));
        expect((await coord.sync()).status, SyncStatus.endpointProblem);
      }
      expect(adapter.requests.length, 6);
      expect(native.row('e1')['history'], 'pending');
      expect(native.row('e1')['attempts'], 0);
      expect(native.rows.length, 1);
    });

    test('the problem clears as soon as the endpoint answers, and the queued events upload', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(404, {'detail': 'x'});
      await coord.sync();
      clock = clock.add(const Duration(hours: 2));
      server = answerAll('created');
      final r = await coord.sync();
      expect(r.created, 1);
      expect(coord.endpointProblem, isNull);
      expect(native.row('e1')['history'], 'synced');
    });

    test('a rejected TLS certificate is its own diagnostic, not "offline"', () async {
      await signedInWith(['e1']);
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.badCertificate);
      var r = await coord.sync();
      expect((r.status, r.diagnostic), (SyncStatus.endpointProblem, 'tls_certificate'));
      expect(r.retryAt, clock.add(const Duration(hours: 1)));
      expect(syncMessage(r), contains('certificate'));
      expect(native.marked, isEmpty);
      // a handshake failure surfaced as a plain error is recognised too
      clock = clock.add(const Duration(hours: 2));
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.unknown, error: const HandshakeException('bad cert'));
      r = await coord.sync();
      expect(r.diagnostic, 'tls_certificate');
    });

    test('ordinary outages are NOT permanent: 503 and connection errors keep the normal back-off', () async {
      await signedInWith(['e1']);
      server = (o) => jsonBody(503, {'detail': 'x'});
      var r = await coord.sync();
      expect(r.status, SyncStatus.offline);
      expect(coord.endpointProblem, isNull);
      clock = clock.add(const Duration(minutes: 1));
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      r = await coord.sync();
      expect(r.status, SyncStatus.offline);
      expect(coord.endpointProblem, isNull);
    });
  });

  group('F1: the endpoint retry deadline survives a restart', () {

    /// A new process: a fresh coordinator over the same app-private storage and the same native store.
    Future<MonitorSyncCoordinator> restarted() async {
      final c = MonitorSyncCoordinator(dio: () => dioWith(adapter), now: () => clock, hasRefreshToken: () async => true);
      expect(await c.setOwner('user-a'), isTrue);
      return c;
    }

    Future<void> fail(Object failure) async {
      await signedInWith(['e1', 'e2']);
      server = (o) => failure is int ? jsonBody(failure, {'detail': 'x'}) : throw DioException(requestOptions: o, type: DioExceptionType.badCertificate);
      final r = await coord.sync();
      expect(r.status, SyncStatus.endpointProblem);
    }

    void expectNothingConsumed() {
      expect(native.marked, isEmpty);
      expect(native.rows.length, 2);
      expect(native.rows.every((x) => x['history'] == 'pending' && x['attempts'] == 0), isTrue);
    }

    test('the problem code and the deadline are written to app-private storage', () async {
      await fail(404);
      final prefs = await SharedPreferences.getInstance();
      expect(storedCode(prefs), 'http_404');
      expect(storedUntil(prefs), clock.add(const Duration(hours: 1)).millisecondsSinceEpoch);
    });

    for (final failure in <Object>[404, 405, 410, 501, 'tls']) {
      test('after a restart the one-hour wait still holds for $failure, manual Sync included', () async {
        await fail(failure);
        final retryAt = coord.endpointRetryAt;
        adapter.requests.clear();

        final c = await restarted(); // the process died and came back
        clock = clock.add(const Duration(minutes: 30));
        var r = await c.sync(manual: true);
        expect(r.status, SyncStatus.endpointProblem);
        expect(r.retryAt, retryAt);
        expect(r.diagnostic, failure is int ? 'http_$failure' : 'tls_certificate');
        r = await c.sync();
        expect(r.status, SyncStatus.endpointProblem);
        expect(adapter.requests, isEmpty); // neither a restart nor the Sync button bypassed it
        expect(c.endpointProblem, r.diagnostic);
        expectNothingConsumed();

        clock = clock.add(const Duration(minutes: 31)); // past the deadline: one try is allowed
        await c.sync(manual: true);
        expect(adapter.requests.length, 1);
      });
    }

    test('restoring on its own (as the screen does) shows the persisted problem before any sync', () async {
      await fail(404);
      final c = MonitorSyncCoordinator(dio: () => dioWith(adapter), now: () => clock);
      expect(c.endpointProblem, isNull); // nothing is loaded until asked
      await c.restoreEndpointState();
      expect(c.endpointProblem, 'http_404');
      expect(c.endpointRetryAt, clock.add(const Duration(hours: 1)));
    });

    test('an expired persisted deadline allows the retry but the problem stays recorded until a request succeeds', () async {
      await fail(404);
      clock = clock.add(const Duration(hours: 3));
      final c = await restarted();
      server = (o) => jsonBody(503, {'detail': 'down'}); // the retry reaches a still-unhealthy server
      expect((await c.sync()).status, SyncStatus.offline);
      expect(c.endpointProblem, 'http_404'); // not a success: the marker stays
      expect(storedCode((await SharedPreferences.getInstance())), 'http_404');
      expectNothingConsumed();
    });

    test('a retry after expiry that fails the same way starts a new full hour and persists it', () async {
      await fail(404);
      clock = clock.add(const Duration(hours: 2));
      final c = await restarted();
      expect((await c.sync()).status, SyncStatus.endpointProblem); // 404 again
      expect(c.endpointRetryAt, clock.add(const Duration(hours: 1)));
      expect(storedUntil((await SharedPreferences.getInstance())), clock.add(const Duration(hours: 1)).millisecondsSinceEpoch);
      adapter.requests.clear();
      expect((await (await restarted()).sync(manual: true)).status, SyncStatus.endpointProblem);
      expect(adapter.requests, isEmpty);
      expectNothingConsumed();
    });

    test('only a successful endpoint response clears the persisted problem and the queued events then upload', () async {
      await fail(404);
      clock = clock.add(const Duration(hours: 2));
      final c = await restarted();
      server = answerAll('created');
      final r = await c.sync();
      expect(r.created, 2);
      expect(c.endpointProblem, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(anyStored(prefs), isFalse);
      expect(anyStored(prefs), isFalse);
      expect((await (await restarted()).sync()).status, SyncStatus.idle); // and a later restart finds nothing to wait for
    });

    test('401, 429 and 400-class answers are not recovery: the persisted problem remains', () async {
      await fail(404);
      for (final code in [401, 429, 422]) {
        clock = clock.add(const Duration(hours: 2));
        final c = await restarted();
        server = (o) => jsonBody(code, {'detail': 'x'});
        await c.sync(manual: true);
        expect(c.endpointProblem, 'http_404', reason: '$code');
        expect(storedCode((await SharedPreferences.getInstance())), 'http_404', reason: '$code');
      }
    });

    test('a signed-out or switched account does not clear the problem (it is about the server, not the account)', () async {
      await fail(404);
      final c = await restarted();
      await c.setOwner(null);
      await c.setOwner('user-b');
      expect(storedCode((await SharedPreferences.getInstance())), 'http_404');
    });

    group('damaged or old-layout persisted values are handled safely (a damaged value is a RESTRICTION, never a bypass)', () {
      Future<void> persist(Map<String, Object> values) async {
        SharedPreferences.setMockInitialValues(values);
        await signedInWith(['e1', 'e2']);
        adapter.requests.clear();
      }

      Future<void> expectFullFreshWait(Map<String, Object> values, {String code = 'endpoint_unknown'}) async {
        await persist(values);
        final c = await restarted();
        final r = await c.sync(manual: true);
        expect((r.status, r.diagnostic), (SyncStatus.endpointProblem, code));
        expect(r.retryAt, clock.add(const Duration(hours: 1))); // a fresh full wait, never skipped
        expect(adapter.requests, isEmpty);
        expectNothingConsumed();
      }

      const until = 1763121600000; // content is irrelevant for damaged values (and `clock` is not set up yet here)
      final damaged = <String, Object>{
        'not JSON': 'DROP TABLE',
        'JSON but not a map': '[1,2,3]',
        'a map without a code': '{"v":1,"until":$until}',
        'an invalid code': '{"v":1,"code":"rm -rf","until":$until}',
        'a wrong-typed value': 404,
      };
      for (final e in damaged.entries) {
        test('a damaged single value (${e.key}) is treated as a restriction with a fresh full wait', () async {
          await expectFullFreshWait({restrictionKey: e.value});
        });
      }

      test('a damaged value is re-saved in the clean format once saving works, and then survives another restart', () async {
        await persist({restrictionKey: 'garbage'});
        final c = await restarted();
        expect((await c.sync()).status, SyncStatus.endpointProblem);
        final prefs = await SharedPreferences.getInstance();
        expect((storedCode(prefs), storedUntil(prefs)), ('endpoint_unknown', clock.add(const Duration(hours: 1)).millisecondsSinceEpoch));
        adapter.requests.clear();
        expect((await (await restarted()).sync(manual: true)).status, SyncStatus.endpointProblem);
        expect(adapter.requests, isEmpty);
      });

      for (final entry in <String, Object?>{'missing': null, 'malformed text': 'tomorrow', 'negative': -5, 'zero': 0}.entries) {
        test('a valid code with a ${entry.key} deadline means a fresh full wait (never a bypass)', () async {
          final blob = entry.value == null
              ? '{"v":1,"code":"http_404"}'
              : '{"v":1,"code":"http_404","until":${entry.value is String ? '"${entry.value}"' : entry.value}}';
          await expectFullFreshWait({restrictionKey: blob}, code: 'http_404');
        });
      }

      test('a deadline absurdly far in the future (corrupt, or the clock moved back) is clamped to one hour', () async {
        await persist({restrictionKey: restrictionBlob('http_410', clock.add(const Duration(days: 400)).millisecondsSinceEpoch)});
        final c = await restarted();
        final r = await c.sync();
        expect(r.retryAt, clock.add(const Duration(hours: 1)));
        clock = clock.add(const Duration(minutes: 61));
        server = answerAll('created');
        expect((await c.sync()).created, 2); // it is not blocked for a year
      });

      test('an already-expired deadline lets the retry through immediately', () async {
        await persist({restrictionKey: restrictionBlob('http_405', clock.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch)});
        final c = await restarted();
        expect((await c.sync()).created, 2);
        expect(adapter.requests.length, 1);
        expect(c.endpointProblem, isNull);
      });

      test('a TLS problem code is accepted from storage', () async {
        await persist({restrictionKey: restrictionBlob('tls_certificate', clock.add(const Duration(minutes: 20)).millisecondsSinceEpoch)});
        final c = await restarted();
        final r = await c.sync(manual: true);
        expect((r.status, r.diagnostic, r.retryAt), (SyncStatus.endpointProblem, 'tls_certificate', clock.add(const Duration(minutes: 20))));
        expect(adapter.requests, isEmpty);
      });

      group('the earlier two-value layout (a half-written pair from an older build) still cannot bypass a wait', () {
        test('BOTH values present: adopted with the ORIGINAL deadline, then migrated to the single value', () async {
          final d = clock.add(const Duration(minutes: 20));
          await persist({legacyCodeKey: 'http_404', legacyUntilKey: d.millisecondsSinceEpoch});
          final c = await restarted();
          final r = await c.sync(manual: true);
          expect((r.status, r.diagnostic, r.retryAt), (SyncStatus.endpointProblem, 'http_404', d));
          final prefs = await SharedPreferences.getInstance();
          expect((storedCode(prefs), storedUntil(prefs)), ('http_404', d.millisecondsSinceEpoch));
          expect(prefs.containsKey(legacyCodeKey) || prefs.containsKey(legacyUntilKey), isFalse); // old keys cleaned up
          expect(adapter.requests, isEmpty);
        });

        test('direction 1: CODE only (the deadline write never happened) is a fresh full wait', () async {
          await expectFullFreshWait({legacyCodeKey: 'http_404'}, code: 'http_404');
        });

        test('direction 2: DEADLINE only (the code write never happened) still holds until that deadline', () async {
          final d = clock.add(const Duration(minutes: 25));
          await persist({legacyUntilKey: d.millisecondsSinceEpoch});
          final c = await restarted();
          final r = await c.sync(manual: true);
          expect((r.status, r.diagnostic, r.retryAt), (SyncStatus.endpointProblem, 'endpoint_unknown', d)); // not discarded
          expect(adapter.requests, isEmpty);
          expect(syncMessage(r), isNot(contains('(endpoint_unknown)'))); // no raw code in the sentence
          expectNothingConsumed();
        });

        test('direction 2 after its deadline: the retry is allowed, and success clears every trace', () async {
          await persist({legacyUntilKey: clock.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch});
          final c = await restarted();
          expect((await c.sync()).created, 2);
          expect(anyStored(await SharedPreferences.getInstance()), isFalse);
        });

        test('garbage in the old keys is a fresh full wait too', () async {
          await expectFullFreshWait({legacyCodeKey: 404, legacyUntilKey: 'soon'});
        });

        test('the single value takes precedence over leftover old keys', () async {
          final d = clock.add(const Duration(minutes: 40));
          await persist({
            restrictionKey: restrictionBlob('http_410', d.millisecondsSinceEpoch),
            legacyCodeKey: 'tls_certificate',
            legacyUntilKey: clock.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
          });
          final c = await restarted();
          final r = await c.sync(manual: true);
          expect((r.diagnostic, r.retryAt), ('http_410', d));
        });
      });
    });
  });

  group('F1: fail closed when the saved restriction cannot be read', () {
    var storageDown = false;
    var reads = 0;

    /// Storage that works until [storageDown] is set (a read error, as distinct from an absent value).
    Future<SharedPreferences> flaky() async {
      reads++;
      if (storageDown) throw PlatformException(code: 'prefs_read_failed');
      return SharedPreferences.getInstance();
    }

    Future<MonitorSyncCoordinator> process() async {
      final c = MonitorSyncCoordinator(
          dio: () => dioWith(adapter), now: () => clock, hasRefreshToken: () async => true, preferences: flaky);
      expect(await c.setOwner('user-a'), isTrue);
      return c;
    }

    void expectUntouched() {
      expect(native.marked, isEmpty);
      expect(native.rows.length, 2);
      expect(native.rows.every((x) => x['history'] == 'pending' && x['attempts'] == 0), isTrue);
    }

    setUp(() {
      storageDown = false;
      reads = 0;
    });

    test('an ABSENT saved restriction is not an error: sync proceeds normally', () async {
      await signedInWith(['e1', 'e2']);
      final c = await process();
      final r = await c.sync();
      expect(r.created, 2);
      expect(c.endpointStateUnreadable, isFalse);
      expect(c.storageFailures, 0);
    });

    test('a read ERROR blocks sync, manual Sync included, and touches nothing', () async {
      await signedInWith(['e1', 'e2']);
      storageDown = true;
      final c = await process();
      adapter.requests.clear();
      for (final manual in [false, true, true]) {
        final r = await c.sync(manual: manual);
        expect(r.status, SyncStatus.settingsUnreadable);
        expect(r.diagnostic, 'prefs_unreadable');
      }
      expect(adapter.requests, isEmpty);
      expect(c.endpointStateUnreadable, isTrue);
      expectUntouched();
      expect(syncMessage(const SyncReport(SyncStatus.settingsUnreadable)), contains('paused'));
    });

    test('time does not unblock it: hours later, with the storage still failing, nothing is sent', () async {
      await signedInWith(['e1', 'e2']);
      storageDown = true;
      final c = await process();
      adapter.requests.clear();
      clock = clock.add(const Duration(hours: 5));
      expect((await c.sync(manual: true)).status, SyncStatus.settingsUnreadable);
      expect(adapter.requests, isEmpty);
      expectUntouched();
    });

    test('every attempt retries the read, and the failure count grows while the problem persists', () async {
      await signedInWith(['e1', 'e2']);
      storageDown = true;
      final c = await process();
      final before = reads;
      await c.sync();
      await c.sync(manual: true);
      await c.restoreEndpointState(); // what the screen does on load
      expect(reads - before, greaterThanOrEqualTo(3)); // it kept trying, it did not give up after the first error
      expect(c.storageFailures, greaterThanOrEqualTo(3));
    });

    test('when the storage works again with NO saved restriction, the next sync proceeds and uploads', () async {
      await signedInWith(['e1', 'e2']);
      storageDown = true;
      final c = await process();
      expect((await c.sync()).status, SyncStatus.settingsUnreadable);
      storageDown = false; // recovered
      final r = await c.sync();
      expect(r.created, 2);
      expect(c.endpointStateUnreadable, isFalse);
      expect(c.storageFailures, 0);
    });

    test('a SAVED restriction is enforced after recovery: blocked while unreadable, then its original deadline applies', () async {
      await signedInWith(['e1', 'e2']);
      server = (o) => jsonBody(404, {'detail': 'x'});
      final first = await coord.sync(); // records http_404 and persists it
      final deadline = first.retryAt!;

      // the app restarts, and now the storage cannot be read
      storageDown = true;
      clock = clock.add(const Duration(minutes: 20));
      final c = await process();
      adapter.requests.clear();
      expect((await c.sync(manual: true)).status, SyncStatus.settingsUnreadable);
      expect(adapter.requests, isEmpty); // the one-hour rule was NOT bypassed by the read failure

      // storage recovers while the saved deadline is still in the future: it is enforced, not forgotten
      storageDown = false;
      final r = await c.sync(manual: true);
      expect((r.status, r.diagnostic, r.retryAt), (SyncStatus.endpointProblem, 'http_404', deadline));
      expect(adapter.requests, isEmpty);
      expectUntouched();

      // and only after the deadline is one try allowed again
      clock = deadline.add(const Duration(minutes: 1));
      server = answerAll('created');
      expect((await c.sync()).created, 2);
    });

    test('a saved restriction that expired while the storage was down allows the retry once it can be read', () async {
      await signedInWith(['e1', 'e2']);
      server = (o) => jsonBody(410, {'detail': 'x'});
      await coord.sync();
      storageDown = true;
      clock = clock.add(const Duration(hours: 3));
      final c = await process();
      expect((await c.sync()).status, SyncStatus.settingsUnreadable);
      storageDown = false;
      server = answerAll('created');
      expect((await c.sync()).created, 2);
      expect(c.endpointProblem, isNull);
    });

    test('a restriction learned in THIS process still holds if the storage fails afterwards', () async {
      await signedInWith(['e1', 'e2']);
      final c = await process();
      server = (o) => jsonBody(404, {'detail': 'x'});
      expect((await c.sync()).status, SyncStatus.endpointProblem);
      storageDown = true;
      adapter.requests.clear();
      final r = await c.sync(manual: true);
      expect(r.status, SyncStatus.endpointProblem); // the in-memory deadline is still enforced
      expect(adapter.requests, isEmpty);
      expectUntouched();
    });

    test('an application restart during the outage is still blocked, and another restart after recovery proceeds', () async {
      await signedInWith(['e1', 'e2']);
      storageDown = true;
      var c = await process();
      expect((await c.sync()).status, SyncStatus.settingsUnreadable);
      c = await process(); // process death and restart, storage still down
      expect((await c.sync(manual: true)).status, SyncStatus.settingsUnreadable);
      expect(adapter.requests, isEmpty);
      storageDown = false;
      c = await process();
      expect((await c.sync()).created, 2);
    });

    test('a storage error never counts against the events: attempts stay at zero across many failed runs', () async {
      await signedInWith(['e1', 'e2']);
      storageDown = true;
      final c = await process();
      for (var i = 0; i < 25; i++) {
        clock = clock.add(const Duration(minutes: 10));
        await c.sync(manual: i.isEven);
      }
      expectUntouched();
    });

    test('a damaged saved value is a restriction (not an outage and not a bypass)', () async {
      SharedPreferences.setMockInitialValues({MonitorSyncCoordinator.endpointRestrictionKey: 'garbage'});
      await signedInWith(['e1', 'e2']);
      final c = await process();
      final r = await c.sync();
      expect((r.status, r.diagnostic), (SyncStatus.endpointProblem, 'endpoint_unknown'));
      expect(c.endpointStateUnreadable, isFalse);
      expect(adapter.requests, isEmpty);
    });
  });

  group('F1: persistence WRITE failures', () {
    late FlakyPrefs fp;

    setUp(() async => fp = FlakyPrefs(await SharedPreferences.getInstance()));

    /// A process whose app-private storage is [fp]; calling it again is an application restart.
    Future<MonitorSyncCoordinator> proc() async {
      final c = MonitorSyncCoordinator(
          dio: () => dioWith(adapter), now: () => clock, hasRefreshToken: () async => true, preferences: () async => fp);
      expect(await c.setOwner('user-a'), isTrue);
      return c;
    }

    void expectUntouched() {
      expect(native.marked, isEmpty);
      expect(native.rows.length, 2);
      expect(native.rows.every((x) => x['history'] == 'pending' && x['attempts'] == 0), isTrue);
    }

    Future<SyncReport> hit(MonitorSyncCoordinator c, int code) {
      server = (o) => jsonBody(code, {'detail': 'x'});
      return c.sync();
    }

    test('a refused write keeps the restriction in memory, reports settingsWriteFailed and saves nothing', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      final r = await hit(c, 404);
      expect((r.status, r.diagnostic), (SyncStatus.settingsWriteFailed, 'prefs_write_failed'));
      expect(c.endpointProblem, 'http_404'); // still held
      expect(c.endpointWriteFailed, isTrue);
      expect(c.writeFailures, 1);
      expect(anyStored(fp.real) || anyStored(fp.real), isFalse); // and nothing claims to be saved
      expect(syncMessage(r), contains('could not save'));
      expectUntouched();
    });

    test('a write that throws is handled the same way', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.throwOnWrite = true;
      final r = await hit(c, 410);
      expect(r.status, SyncStatus.settingsWriteFailed);
      expect(c.endpointProblem, 'http_410');
      expectUntouched();
    });

    test('while it cannot be saved ALL sync is blocked: manual Sync, repeats, and an expired in-memory deadline', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      await hit(c, 404);
      adapter.requests.clear();
      for (final step in [
        (const Duration(minutes: 10), false),
        (const Duration(minutes: 10), true),
        (const Duration(hours: 3), true), // well past the original one-hour deadline
        (const Duration(hours: 1), false),
      ]) {
        clock = clock.add(step.$1);
        expect((await c.sync(manual: step.$2)).status, SyncStatus.settingsWriteFailed);
      }
      expect(adapter.requests, isEmpty);
      expect(c.writeFailures, greaterThanOrEqualTo(5)); // every trigger retried the save and failed again
      expectUntouched();
    });

    test('when saving works again before the deadline, the ORIGINAL deadline is saved and enforced', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      final first = await hit(c, 404);
      final deadline = first.retryAt!;
      adapter.requests.clear();
      fp.refuseWrites = false;
      clock = clock.add(const Duration(minutes: 20));
      final r = await c.sync(manual: true);
      expect((r.status, r.retryAt, r.diagnostic), (SyncStatus.endpointProblem, deadline, 'http_404'));
      expect(c.endpointWriteFailed, isFalse);
      expect(c.writeFailures, 0);
      expect(storedCode(fp.real), 'http_404'); // now it IS saved
      expect(storedUntil(fp.real), deadline.millisecondsSinceEpoch);
      expect(adapter.requests, isEmpty);
      clock = deadline.add(const Duration(minutes: 1));
      server = answerAll('created');
      expect((await c.sync()).created, 2);
    });

    test('when saving recovers only after the deadline, the restriction is saved first and then one retry is allowed', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      await hit(c, 404);
      fp.refuseWrites = false;
      clock = clock.add(const Duration(hours: 3));
      server = answerAll('created');
      adapter.requests.clear();
      final r = await c.sync();
      expect(r.created, 2); // the endpoint is back
      expect(adapter.requests.length, 1);
      expect(c.endpointProblem, isNull);
      expect(anyStored(fp.real) || anyStored(fp.real), isFalse); // and recovery removed what was saved
    });

    test('RESTART after a failed save: nothing was saved, so nothing is claimed; the restarted app tries again', () async {
      await signedInWith(['e1', 'e2']);
      var c = await proc();
      fp.refuseWrites = true;
      final r = await hit(c, 404);
      expect(r.status, SyncStatus.settingsWriteFailed); // it said so: the wait was NOT saved
      expect(c.endpointWriteFailed, isTrue);

      fp.refuseWrites = false;
      c = await proc(); // the process died and restarted before any save succeeded
      await c.restoreEndpointState();
      expect(c.endpointProblem, isNull); // honest: the restriction did not survive, and the app never claimed it would
      expect(c.endpointWriteFailed, isFalse);
      adapter.requests.clear();
      expect((await hit(c, 404)).status, SyncStatus.endpointProblem); // it re-learns it, and this time it IS saved
      expect(storedCode(fp.real), 'http_404');
      expect(adapter.requests.length, 1);
    });

    test('a partial write is impossible: ONE value, so an integer-write failure cannot leave half a restriction', () async {
      await signedInWith(['e1', 'e2']);
      var c = await proc();
      fp.refuseSetInt = true; // would have left the old two-value layout half-written
      final r = await hit(c, 404);
      expect(r.status, SyncStatus.endpointProblem); // the single write went through
      expect((storedCode(fp.real), storedUntil(fp.real)), ('http_404', r.retryAt!.millisecondsSinceEpoch));
      c = await proc();
      adapter.requests.clear();
      expect((await c.sync(manual: true)).status, SyncStatus.endpointProblem); // the restart still enforces it
      expect(adapter.requests, isEmpty);
    });

    test('a write that is REFUSED stores nothing at all (never half), and the restriction stays in memory', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      expect((await hit(c, 404)).status, SyncStatus.settingsWriteFailed);
      expect(anyStored(fp.real), isFalse);
      expect(c.endpointProblem, 'http_404');
    });

    test('a store that says yes but kept nothing is caught by the read-back: not treated as saved', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.dropSilently = true;
      final r = await hit(c, 404);
      expect(r.status, SyncStatus.settingsWriteFailed);
      expect(c.endpointWriteFailed, isTrue);
      expect(anyStored(fp.real), isFalse);
      fp.dropSilently = false;
      expect((await c.sync(manual: true)).status, SyncStatus.endpointProblem); // saved for real on the retry
      expect(storedCode(fp.real), 'http_404');
    });

    test('the ORIGINAL deadline is what every retry and every restart sees', () async {
      await signedInWith(['e1', 'e2']);
      var c = await proc();
      fp.refuseWrites = true;
      final deadline = (await hit(c, 404)).retryAt!;
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(minutes: 5));
        await c.sync(manual: true); // each retry fails to save, and none of them extends the deadline
      }
      fp.refuseWrites = false;
      clock = clock.add(const Duration(minutes: 5));
      final r = await c.sync(manual: true);
      expect(r.retryAt, deadline);
      expect(storedUntil(fp.real), deadline.millisecondsSinceEpoch);
      c = await proc();
      expect((await c.sync(manual: true)).retryAt, deadline); // and after a restart
    });

    test('repeated failures keep counting, and one confirmed save resets everything', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      await hit(c, 404);
      for (var i = 0; i < 4; i++) {
        await c.sync(manual: true);
      }
      expect(c.writeFailures, 5);
      fp.refuseWrites = false;
      await c.sync(manual: true);
      expect((c.writeFailures, c.endpointWriteFailed), (0, false));
      expectUntouched();
    });

    test('recovery whose saved restriction cannot be REMOVED: not blocked, problem stays recorded, removal is retried', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      await hit(c, 404); // saved fine
      clock = clock.add(const Duration(hours: 2));
      fp.refuseRemove = true;
      server = answerAll('created');
      final r = await c.sync();
      expect(r.created, 2); // the endpoint answered: uploads are not held back
      expect(c.endpointProblem, 'http_404'); // not claimed cleared: the saved restriction is still on disk
      expect(c.endpointRetryAt, isNull); // but it no longer blocks anything
      expect(storedCode(fp.real), 'http_404');
      native.add('e3', 'user-a');
      expect((await c.sync()).created, 1); // still uploads while the removal is pending
      fp.refuseRemove = false;
      expect((await c.sync()).status, SyncStatus.idle); // the retry happens on the next trigger
      expect(c.endpointProblem, isNull);
      expect(anyStored(fp.real) || anyStored(fp.real), isFalse);
    });

    test('a failed write never touches queued events or attempts, across many triggers', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      await hit(c, 405);
      for (var i = 0; i < 30; i++) {
        clock = clock.add(const Duration(minutes: 7));
        await c.sync(manual: i.isOdd);
        await c.restoreEndpointState(); // what the screen does
      }
      expectUntouched();
      expect(adapter.requests.length, 1);
    });

    for (final entry in <String, void Function(FlakyPrefs)>{
      'every removal refused': (f) => f.refuseRemove = true,
      'only the single value refused': (f) => f.refuseRemoveKeys.add(restrictionKey),
      'only the old keys refused': (f) => f.refuseRemoveKeys.addAll([legacyCodeKey, legacyUntilKey]),
      'removal throws': (f) => f.throwOnWrite = true,
    }.entries) {
      test('removal failure (${entry.key}) after recovery: uploads continue, the marker is not claimed cleared, then it is retried', () async {
        await signedInWith(['e1', 'e2']);
        final c = await proc();
        await hit(c, 404); // saved as the single value
        clock = clock.add(const Duration(hours: 2));
        // an old-layout pair is also on disk, so BOTH layouts' removals are exercised
        await fp.real.setString(legacyCodeKey, 'http_404');
        await fp.real.setInt(legacyUntilKey, clock.millisecondsSinceEpoch);
        entry.value(fp);
        server = answerAll('created');
        final r = await c.sync();
        expect(r.created, 2); // the endpoint answered: nothing is held back
        expect(c.endpointProblem, isNotNull); // not claimed recovered while something is still saved
        expect(c.endpointRetryAt, isNull); // but it blocks nothing
        native.add('e3', 'user-a');
        expect((await c.sync()).created, 1);
        fp.refuseRemove = false;
        fp.refuseRemoveKeys.clear();
        fp.throwOnWrite = false;
        await c.sync();
        expect(c.endpointProblem, isNull); // retried on the next trigger
        expect(anyStored(fp.real), isFalse);
      });
    }

    test('a restart after a failed removal cannot be blocked by a stale restriction beyond its original deadline', () async {
      await signedInWith(['e1', 'e2']);
      var c = await proc();
      await hit(c, 404);
      clock = clock.add(const Duration(hours: 2));
      fp.refuseRemove = true;
      server = answerAll('created');
      await c.sync();
      expect(storedCode(fp.real), 'http_404'); // still on disk
      c = await proc(); // restart with the stale value present
      fp.refuseRemove = false;
      native.add('e3', 'user-a');
      expect((await c.sync()).created, 1); // its deadline is long past: the retry is allowed
      expect(anyStored(fp.real), isFalse);
    });

    test('TLS failures follow the same rule', () async {
      await signedInWith(['e1', 'e2']);
      final c = await proc();
      fp.refuseWrites = true;
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.badCertificate);
      final r = await c.sync();
      expect((r.status, c.endpointProblem), (SyncStatus.settingsWriteFailed, 'tls_certificate'));
      fp.refuseWrites = false;
      expect((await c.sync(manual: true)).diagnostic, 'tls_certificate');
      expect(storedCode(fp.real), 'tls_certificate');
    });
  });

  group('F2: stale native owner at startup', () {
    test('no refresh token and a leftover native owner: the stale owner is cleared', () async {
      native.owner = 'user-gone';
      native.add('old', 'user-gone');
      refreshTokenPresent = false;
      expect(await coord.reconcileStaleOwner(), isTrue);
      expect(native.owner, isNull);
      expect(adapter.requests, isEmpty); // no network is needed to know the session is gone
    });

    test('a valid refresh token keeps the owner (one request confirms the session)', () async {
      native.owner = 'user-7';
      native.add('bg', 'user-7');
      server = (o) => jsonBody(200, {'ok': true});
      expect(await coord.reconcileStaleOwner(), isFalse);
      expect(native.owner, 'user-7');
      expect(adapter.requests.single.path, '/app-monitor/summary');
      expect(native.rows.length, 1);
    });

    test('a refresh rejected for good (401 and the tokens are gone) clears the owner', () async {
      native.owner = 'user-7';
      var calls = 0;
      server = (o) {
        calls++;
        refreshTokenPresent = false; // what the Dio client does when the refresh is rejected
        return jsonBody(401, {'detail': 'expired'});
      };
      expect(await coord.reconcileStaleOwner(), isTrue);
      expect(native.owner, isNull);
      expect(calls, 1);
    });

    test('a 401 that leaves the refresh token in place is inconclusive: the owner is kept', () async {
      native.owner = 'user-7';
      server = (o) => jsonBody(401, {'detail': 'expired'});
      expect(await coord.reconcileStaleOwner(), isFalse);
      expect(native.owner, 'user-7');
    });

    test('offline or any other error never clears the owner on a guess', () async {
      native.owner = 'user-7';
      server = (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      expect(await coord.reconcileStaleOwner(), isFalse);
      expect(native.owner, 'user-7');
    });

    test('nothing to reconcile when the native store has no owner, and it runs only once', () async {
      expect(await coord.reconcileStaleOwner(), isFalse);
      expect(adapter.requests, isEmpty);
      native.owner = 'user-7';
      expect(await coord.reconcileStaleOwner(), isFalse); // already reconciled in this process
      expect(native.owner, 'user-7');
    });

    test('it never sets an owner and never touches an owner this process established', () async {
      await signedInWith(['e1']);
      expect(await coord.reconcileStaleOwner(), isFalse);
      expect(native.ownerCalls, ['user-a']); // only the sign-in
      expect(native.owner, 'user-a');
    });

    test('account isolation holds after reconciliation: the next account sees none of the stale owner\'s events', () async {
      native.owner = 'user-gone';
      native.add('old', 'user-gone');
      refreshTokenPresent = false;
      await coord.reconcileStaleOwner();
      expect(await coord.setOwner('user-b'), isTrue);
      expect(native.rows, isEmpty);
      expect((await coord.sync()).status, SyncStatus.idle);
    });
  });

  group('owner changes are serialised', () {
    test('overlapping owner changes reach the native store in call order and the last one wins', () async {
      native.ownerDelay['user-a'] = const Duration(milliseconds: 60); // the FIRST change is slow
      final a = coord.setOwner('user-a');
      final b = coord.setOwner('user-b');
      final c = coord.setOwner(null);
      await Future.wait([a, b, c]);
      expect(native.ownerCalls, ['user-a', 'user-b', null]);
      expect(native.owner, isNull);
      expect(coord.owner, isNull);
    });

    test('a slow earlier change can never overwrite a later one', () async {
      native.ownerDelay['user-a'] = const Duration(milliseconds: 80);
      final a = coord.setOwner('user-a');
      final b = coord.setOwner('user-b');
      await Future.wait([a, b]);
      expect(native.owner, 'user-b');
      expect(coord.owner, 'user-b');
    });

    test('a failing change does not block the ones queued behind it', () async {
      native.failOwners.add('user-a');
      final a = coord.setOwner('user-a');
      final b = coord.setOwner('user-b');
      expect(await a, isFalse);
      expect(await b, isTrue);
      expect(coord.owner, 'user-b');
    });
  });

  group('purge results (account deletion)', () {
    test('success is reported only when the native purge confirmed it and the store signed out', () async {
      await signedInWith(['e1']);
      expect(await coord.purgeAll(), isTrue);
      expect(native.rows, isEmpty);
    });

    test('a purge that answers ok:false is retried once and then reported as FAILED', () async {
      await signedInWith(['e1']);
      native.purgeFails = true;
      expect(await coord.purgeAll(), isFalse);
      expect(native.calls.where((c) => c == 'purge').length, 2);
      expect(native.rows.length, 1);
      expect(coord.owner, isNull); // never left able to upload or read events
      expect(native.owner, isNull); // and signed out natively, so the next account cannot see them
    });

    test('a purge that throws is reported as FAILED too, not swallowed', () async {
      await signedInWith(['e1']);
      native.purgeThrows = true;
      expect(await coord.purgeAll(), isFalse);
    });

    test('a transient purge failure that succeeds on the retry is a success', () async {
      await signedInWith(['e1']);
      var first = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (c) async {
        if (c.method == 'purge' && first) {
          first = false;
          return {'ok': false, 'deleted': 0};
        }
        return native.handle(c);
      });
      expect(await coord.purgeAll(), isTrue);
      expect(native.rows, isEmpty);
    });

    test('a purge never leaves another account able to see the events: the next sign-in deletes them', () async {
      await signedInWith(['e1']);
      native.purgeFails = true;
      await coord.purgeAll();
      native.purgeFails = false;
      expect(await coord.setOwner('user-b'), isTrue);
      expect(native.rows, isEmpty);
    });
  });

  group('bound to the authentication lifecycle (Riverpod)', () {
    Future<ProviderContainer> app({String? token}) async {
      FlutterSecureStorage.setMockInitialValues({if (token != null) 'access_token': token});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(monitorSyncProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80)); // session restore
      return c;
    }

    test('app restart with a saved session sets the native owner', () async {
      await app(token: _fakeSession('user-7'));
      expect(native.owner, 'user-7');
    });

    test('app start with no session leaves the store signed out', () async {
      final c = await app();
      expect(native.owner, isNull);
      expect(c.read(monitorSyncProvider).owner, isNull);
    });

    test('an EXPIRED access token with a valid refresh token keeps the last known native owner', () async {
      native.owner = 'user-7'; // set by the previous session; the store persists it
      native.add('bg', 'user-7');
      FlutterSecureStorage.setMockInitialValues({
        'access_token': fakeJwt({'sub': 'user-7', 'exp': 1000}), // long expired
        'refresh_token': 'still-valid',
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(monitorSyncProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.read(authProvider).isAuthenticated, isFalse); // the UI still treats it as signed out ...
      expect(native.ownerCalls, isEmpty); // ... but the native owner was never touched
      expect(native.owner, 'user-7');
      expect(native.rows.length, 1); // and the background event is still there
    });

    test('with no refresh token left, an expired session clears the owner', () async {
      native.owner = 'user-7';
      FlutterSecureStorage.setMockInitialValues({'access_token': fakeJwt({'sub': 'user-7', 'exp': 1000})});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(monitorSyncProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(native.owner, isNull);
    });

    test('logout clears the native owner and keeps nothing attributable', () async {
      final c = await app(token: _fakeSession('user-7'));
      await c.read(authProvider.notifier).logout();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(native.owner, isNull);
      expect(c.read(monitorSyncProvider).owner, isNull);
    });

    test('a different user signing in on the same device replaces the owner and removes the previous user\'s events', () async {
      final c = await app(token: _fakeSession('user-7'));
      native.add('old', 'user-7');
      await c.read(authProvider.notifier).logout();
      FlutterSecureStorage.setMockInitialValues({'access_token': _fakeSession('user-8')});
      c.read(authProvider.notifier).state = const AuthState(isAuthenticated: true, isLoading: false, userId: 'user-8');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(native.owner, 'user-8');
      expect(native.rows.where((r) => r['owner'] == 'user-7'), isEmpty);
    });
  });
}

/// Delays the request until [wait] completes, then delegates.
class _GatedAdapter implements HttpClientAdapter {
  final FakeAdapter inner;
  final Future<void> Function() wait;
  _GatedAdapter(this.inner, this.wait);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    await wait();
    return inner.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) {}
}

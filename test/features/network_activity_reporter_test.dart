import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/vpn_monitor/network_activity_reporter.dart';

void main() {
  NetworkActivityReporter make(List<Map<String, dynamic>> sent,
      {String? id = 'dev-1', bool fail = false, int batch = 3, int cap = 5}) {
    return NetworkActivityReporter(
      deviceId: () async => id,
      post: (body) async {
        if (fail) throw StateError('offline');
        sent.add(body);
      },
      batchSize: batch,
      maxBuffered: cap,
      flushEvery: const Duration(hours: 1),
    );
  }

  test('batches events and sends the device id with only destination fields',
      () async {
    final sent = <Map<String, dynamic>>[];
    final r = make(sent);
    r.add(destIp: '1.2.3.4', destDomain: 'example.com');
    r.add(destIp: '5.6.7.8', destDomain: '');
    expect(r.pending, 2);
    expect(await r.flush(), isTrue);
    expect(r.pending, 0);
    expect(sent.single['device_id'], 'dev-1');
    final acts = sent.single['activities'] as List;
    expect(acts[0],
        {'destination_ip': '1.2.3.4', 'destination_domain': 'example.com'});
    expect(acts[1], {'destination_ip': '5.6.7.8'});
    r.dispose();
  });

  test('flushes automatically when the batch size is reached', () async {
    final sent = <Map<String, dynamic>>[];
    final r = make(sent);
    for (var i = 0; i < 3; i++) {
      r.add(destIp: '10.0.0.$i', destDomain: 'h$i.test');
    }
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(sent.length, 1);
    r.dispose();
  });

  test('a failed upload keeps the events and never throws', () async {
    final sent = <Map<String, dynamic>>[];
    final r = make(sent, fail: true);
    r.add(destIp: '1.1.1.1', destDomain: 'a.test');
    expect(await r.flush(), isFalse);
    expect(r.pending, 1);
    r.dispose();
  });

  test('without a registered device nothing is sent and events are kept',
      () async {
    final sent = <Map<String, dynamic>>[];
    final r = make(sent, id: null);
    r.add(destIp: '1.1.1.1', destDomain: 'a.test');
    expect(await r.flush(), isFalse);
    expect(sent, isEmpty);
    expect(r.pending, 1);
    r.dispose();
  });

  test('the buffer is bounded and drops the oldest, empty events are ignored',
      () {
    final r = make([], cap: 5, batch: 100);
    r.add(destIp: '', destDomain: '');
    for (var i = 0; i < 9; i++) {
      r.add(destIp: '10.0.0.$i', destDomain: '');
    }
    expect(r.pending, 5);
    r.dispose();
  });

  test('overlong values are truncated to the server limits', () async {
    final sent = <Map<String, dynamic>>[];
    final r = make(sent);
    r.add(destIp: 'x' * 100, destDomain: 'd' * 400);
    await r.flush();
    final a = (sent.single['activities'] as List).single as Map;
    expect((a['destination_ip'] as String).length, 64);
    expect((a['destination_domain'] as String).length, 255);
    r.dispose();
  });
}

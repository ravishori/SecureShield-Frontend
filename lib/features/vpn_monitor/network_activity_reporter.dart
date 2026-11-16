import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';

/// Batches the destination IP/domain events the local VPN monitor already shows the user and uploads
/// them to `POST /network/activity` so the backend can flag known-bad destinations.
///
/// Privacy: only the destination address/domain is sent (the VPN service never reads payloads). Nothing
/// is sent unless the user has started the VPN monitor, because that is the only producer of events.
///
/// Reliability: the buffer is bounded; a failed upload keeps the batch for the next attempt (up to the
/// cap) and never throws into the UI.
class NetworkActivityReporter {
  NetworkActivityReporter({
    Future<String?> Function()? deviceId,
    Future<void> Function(Map<String, dynamic> body)? post,
    this.batchSize = 25,
    this.maxBuffered = 500,
    this.flushEvery = const Duration(seconds: 30),
  })  : _deviceId = deviceId ?? _lookupDeviceId,
        _post = post ?? _defaultPost;

  final Future<String?> Function() _deviceId;
  final Future<void> Function(Map<String, dynamic> body) _post;
  final int batchSize;
  final int maxBuffered;
  final Duration flushEvery;

  final List<Map<String, dynamic>> _buffer = [];
  Timer? _timer;
  bool _flushing = false;

  int get pending => _buffer.length;

  void add({required String destIp, required String destDomain}) {
    if (destIp.isEmpty && destDomain.isEmpty) return;
    if (_buffer.length >= maxBuffered) _buffer.removeAt(0); // drop the oldest
    _buffer.add({
      if (destIp.isNotEmpty)
        'destination_ip': destIp.length > 64 ? destIp.substring(0, 64) : destIp,
      if (destDomain.isNotEmpty)
        'destination_domain':
            destDomain.length > 255 ? destDomain.substring(0, 255) : destDomain,
    });
    _timer ??= Timer.periodic(flushEvery, (_) => flush());
    if (_buffer.length >= batchSize) unawaited(flush());
  }

  /// Uploads up to [batchSize] buffered events. Returns true if something was sent.
  Future<bool> flush() async {
    if (_flushing || _buffer.isEmpty) return false;
    _flushing = true;
    final batch = _buffer.take(batchSize).toList();
    try {
      final id = await _deviceId();
      if (id == null) return false; // not registered yet: keep the events
      await _post({'device_id': id, 'activities': batch});
      _buffer.removeRange(0, batch.length);
      return true;
    } catch (e) {
      debugPrint('[NetworkActivityReporter] upload failed: ${e.runtimeType}');
      return false;
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  static String? _cachedId;

  static Future<String?> _lookupDeviceId() async {
    if (_cachedId != null) return _cachedId;
    if (!Platform.isAndroid) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    // Same fingerprint the login flow registers (otp_screen.dart), so this is THIS phone even when the
    // account has several devices.
    final token = sha256
        .convert(utf8
            .encode('${info.id}|${info.model}|${info.brand}|${info.hardware}'))
        .toString();
    final response = await DioClient().dio.get('/devices');
    for (final d in response.data as List<dynamic>) {
      final m = d as Map<String, dynamic>;
      if (m['device_token'] == token) {
        _cachedId = m['id'] as String?;
        return _cachedId;
      }
    }
    return null;
  }

  static Future<void> _defaultPost(Map<String, dynamic> body) async {
    await DioClient().dio.post('/network/activity', data: body);
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the backend base URL at runtime by probing multiple candidate
/// hosts in parallel and picking whichever answers first.
///
/// **Why this exists**
/// In dev we routinely flip between three transports:
///   • Android emulator → `10.0.2.2`
///   • iOS simulator    → `localhost`
///   • Physical device  → the dev PC's LAN IP (changes with network/DHCP)
///
/// A hard-coded URL gets out of sync every time:
///   - the dev's IP changes (new wifi, DHCP renew, hotspot, VPN…)
///   - the user moves from emulator to phone or vice-versa
///   - the backend is restarted on `127.0.0.1` instead of `0.0.0.0`
///
/// This class probes a candidate list (TCP-connect + `/health` check) and
/// uses the first one that responds. Result is cached for fast subsequent
/// startups; on connection failure the [DioClient] interceptor calls
/// [redetect] to recover automatically.
///
/// **Build-time override**
/// You can pin a host without code edits:
///   `flutter run --dart-define=BACKEND_HOST=192.168.1.50`
///
/// **Manual override**
/// The Settings screen calls [setCustomUrl] to pin a URL persistently.
class AppConfig {
  // ── Configuration ────────────────────────────────────────────────────────
  static const int port = 8000;
  static const String _apiPrefix = '/api/v1';
  static const String _prefKeyManual = 'custom_server_url';
  static const String _prefKeyAuto   = 'auto_detected_server_url';

  /// Build-time override: `--dart-define=BACKEND_HOST=192.168.x.x`.
  static const String _buildTimeHost = String.fromEnvironment(
    'BACKEND_HOST', defaultValue: '',
  );

  /// Fixed production/staging API root, e.g.
  /// `--dart-define=API_BASE_URL=https://secureshield-staging.up.railway.app/api/v1`.
  /// When set the app NEVER probes LAN hosts (no startup delay, no cleartext HTTP): release builds
  /// must be built with this define.
  static const String _fixedApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: '',
  );

  /// True when the backend URL is pinned at build time (release/staging builds).
  static bool get isFixedBackend => _fixedApiBaseUrl.isNotEmpty;

  /// Probe timeouts — generous enough for slow networks, fast enough to
  /// keep startup under ~2 seconds even if everything fails.
  static const Duration _tcpTimeout    = Duration(milliseconds: 700);
  static const Duration _httpTimeout   = Duration(seconds: 1);
  static const Duration _overallBudget = Duration(seconds: 3);

  /// Hosts to always include in the candidate list (covers common dev setups).
  static const List<String> _fallbackHosts = [
    '10.0.2.2',           // Android emulator → host machine
    'localhost',
    '127.0.0.1',
    '192.168.1.11',       // common dev IP (this dev machine)
    '192.168.1.10',
    '192.168.1.100',
    '192.168.0.10',
    '192.168.0.11',
    '192.168.0.100',
    '192.168.29.1',       // Jio default router (some users)
    '10.0.0.10',          // some corporate setups
  ];

  // ── State ────────────────────────────────────────────────────────────────
  static String _baseUrl = 'http://10.0.2.2:$port$_apiPrefix';
  static bool _initialized = false;
  static bool _probing = false;
  static final List<String> _lastProbedHosts = <String>[];
  static String? _lastProbeWinner;

  /// The resolved base URL for the current runtime environment.
  static String get baseUrl => _baseUrl;

  /// Whether [initialize] has resolved a URL.
  static bool get isInitialized => _initialized;

  /// Diagnostic helpers (used by Settings screen).
  static List<String> get lastProbedHosts => List.unmodifiable(_lastProbedHosts);
  static String? get lastProbeWinner => _lastProbeWinner;

  /// Suggested LAN host for the Settings UI's "LAN" preset chip.
  ///
  /// Picks, in order:
  ///   1. The host of the most-recent successful probe (most accurate).
  ///   2. The build-time `BACKEND_HOST` override (if set).
  ///   3. The first non-emulator fallback host.
  ///
  /// Kept as a getter so the chip stays accurate even when the dev IP
  /// changes between sessions.
  static String get deviceLanIp {
    // 1. Whatever the probe most recently picked, if it's a real LAN IP.
    final winner = _lastProbeWinner;
    if (winner != null) {
      final host = Uri.tryParse(winner)?.host;
      if (host != null && _isValidIPv4(host) && !_isLoopbackOrEmulator(host)) {
        return host;
      }
    }
    // 2. Build-time override.
    if (_buildTimeHost.isNotEmpty && _isValidIPv4(_buildTimeHost)) {
      return _buildTimeHost;
    }
    // 3. First non-emulator fallback.
    return _fallbackHosts.firstWhere(
      (h) => _isValidIPv4(h) && !_isLoopbackOrEmulator(h),
      orElse: () => '192.168.1.11',
    );
  }

  static bool _isLoopbackOrEmulator(String host) =>
      host == '10.0.2.2' || host == '127.0.0.1' || host == 'localhost';

  // ── Public API ───────────────────────────────────────────────────────────

  /// Call once from `main()` before `runApp()`.
  static Future<void> initialize() async {
    if (_initialized) return;

    // 0. Pinned build: use it directly. No probing, no network I/O before the first frame.
    if (isFixedBackend) {
      _baseUrl = _fixedApiBaseUrl.endsWith('/')
          ? _fixedApiBaseUrl.substring(0, _fixedApiBaseUrl.length - 1)
          : _fixedApiBaseUrl;
      _initialized = true;
      debugPrint('[AppConfig] Using fixed backend: $_baseUrl');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Highest priority: user-pinned override.
    final manual = prefs.getString(_prefKeyManual);
    if (manual != null && manual.isNotEmpty) {
      if (await _isReachable(manual)) {
        _baseUrl = manual;
        _initialized = true;
        debugPrint('[AppConfig] Using manual override: $manual');
        return;
      }
      debugPrint('[AppConfig] Manual override $manual unreachable, falling through');
    }

    // 2. Cached auto-detected URL — fast path.
    final cached = prefs.getString(_prefKeyAuto);
    if (cached != null && cached.isNotEmpty) {
      if (await _isReachable(cached)) {
        _baseUrl = cached;
        _initialized = true;
        _lastProbeWinner = cached;
        debugPrint('[AppConfig] Reusing cached URL: $cached');
        return;
      }
      debugPrint('[AppConfig] Cached URL $cached unreachable, re-probing');
    }

    // 3. Probe candidates in parallel.
    final found = await _probeAll();
    if (found != null) {
      _baseUrl = found;
      await prefs.setString(_prefKeyAuto, found);
      _lastProbeWinner = found;
      debugPrint('[AppConfig] Probe winner: $found');
    } else {
      _baseUrl = await _defaultFallback();
      debugPrint('[AppConfig] No host responded, using default: $_baseUrl');
    }
    _initialized = true;
  }

  /// Re-run detection — used by [DioClient] when a connection error indicates
  /// the network/IP topology may have changed. Returns true if the URL
  /// changed and callers should retry their request.
  static Future<bool> redetect() async {
    if (isFixedBackend) return false; // nothing to rediscover
    if (_probing) return false;
    _probing = true;
    try {
      final found = await _probeAll();
      if (found != null && found != _baseUrl) {
        debugPrint('[AppConfig] Re-detection swapped $_baseUrl → $found');
        _baseUrl = found;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyAuto, found);
        _lastProbeWinner = found;
        return true;
      }
      return false;
    } finally {
      _probing = false;
    }
  }

  /// Manually pin a backend URL (Settings screen).
  static Future<void> setCustomUrl(String url) async {
    if (isFixedBackend) return; // pinned builds ignore overrides (prevents pointing a release app at http://)
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyManual, url);
  }

  /// Clear the manual override and re-auto-detect.
  static Future<void> clearCustomUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyManual);
    await prefs.remove(_prefKeyAuto);
    _initialized = false;
    _lastProbeWinner = null;
    await initialize();
  }

  // ── Probe machinery ──────────────────────────────────────────────────────

  /// Returns the first reachable candidate URL, or null if all fail within
  /// [_overallBudget].
  static Future<String?> _probeAll() async {
    final hosts = await _buildCandidateHosts();
    _lastProbedHosts
      ..clear()
      ..addAll(hosts);
    debugPrint('[AppConfig] Probing ${hosts.length} hosts: ${hosts.join(", ")}');

    final completer = Completer<String?>();
    int remaining = hosts.length;

    for (final host in hosts) {
      // ignore: discarded_futures
      _isReachable('http://$host:$port$_apiPrefix').then((ok) {
        if (ok && !completer.isCompleted) {
          completer.complete('http://$host:$port$_apiPrefix');
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    // Hard cap: don't block startup forever even if a probe hangs.
    return completer.future.timeout(
      _overallBudget,
      onTimeout: () => null,
    );
  }

  /// Build the host candidate list:
  ///   1. dart-define `BACKEND_HOST` (if set)
  ///   2. Emulator + localhost (cheap, always probe)
  ///   3. WiFi-derived neighbours of the device's own IP (most likely match)
  ///   4. Hard-coded fallback dev IPs
  static Future<List<String>> _buildCandidateHosts() async {
    final candidates = <String>{};

    // 1. Build-time override (highest priority)
    if (_buildTimeHost.isNotEmpty) candidates.add(_buildTimeHost);

    // 2. Platform-appropriate localhost variants
    if (Platform.isAndroid) candidates.add('10.0.2.2');
    candidates.add('localhost');
    candidates.add('127.0.0.1');

    // 3. Smart: derive same-subnet candidates from WiFi info
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && _isValidIPv4(wifiIp)) {
        final lastDot = wifiIp.lastIndexOf('.');
        final subnet = wifiIp.substring(0, lastDot + 1);
        // Common dev-machine indices within the same subnet.
        for (final idx in [1, 2, 5, 10, 11, 50, 100, 101, 150, 200]) {
          candidates.add('$subnet$idx');
        }
      }
      final gateway = await NetworkInfo().getWifiGatewayIP();
      if (gateway != null && _isValidIPv4(gateway)) {
        candidates.add(gateway);
      }
    } catch (e) {
      debugPrint('[AppConfig] WiFi info unavailable: $e');
    }

    // 4. Hard-coded fallback dev IPs
    candidates.addAll(_fallbackHosts);

    return candidates.toList();
  }

  /// Check if [url] is reachable. Two-step probe:
  ///   1. Fast TCP-connect to the host:port (fails in milliseconds on bad hosts)
  ///   2. Light HTTP GET /health to confirm it's actually our backend
  static Future<bool> _isReachable(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final probePort = uri.port == 0 ? port : uri.port;

      // ── Step 1: TCP connect ────────────────────────────────────────────
      Socket socket;
      try {
        socket = await Socket.connect(
          host, probePort,
          timeout: _tcpTimeout,
        );
      } on SocketException {
        return false;
      } on TimeoutException {
        return false;
      }
      try { socket.destroy(); } catch (_) {}

      // ── Step 2: HTTP /health validation ─────────────────────────────────
      try {
        final client = HttpClient()..connectionTimeout = _httpTimeout;
        try {
          final req = await client
              .getUrl(Uri.parse('${uri.scheme}://$host:$probePort/health'))
              .timeout(_httpTimeout);
          final res = await req.close().timeout(_httpTimeout);
          await res.drain<void>();
          return res.statusCode == 200;
        } finally {
          client.close(force: true);
        }
      } catch (_) {
        // TCP worked but /health failed - could be a different service on port.
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Best-effort default when no candidate responds.
  static Future<String> _defaultFallback() async {
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        return info.isPhysicalDevice
            ? 'http://192.168.1.11:$port$_apiPrefix'
            : 'http://10.0.2.2:$port$_apiPrefix';
      } catch (_) {}
      return 'http://10.0.2.2:$port$_apiPrefix';
    }
    return 'http://localhost:$port$_apiPrefix';
  }

  static bool _isValidIPv4(String s) {
    final parts = s.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }
}

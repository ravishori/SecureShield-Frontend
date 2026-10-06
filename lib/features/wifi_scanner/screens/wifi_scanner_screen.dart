import 'package:secureshield_app/l10n/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../../core/theme.dart';
import '../wifi_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Security type helpers
// ─────────────────────────────────────────────────────────────────────────────
enum _Security { open, wep, wpa, wpa2, wpa3 }

extension _SecurityX on _Security {
  String get label {
    switch (this) {
      case _Security.open:  return 'OPEN';
      case _Security.wep:   return 'WEP';
      case _Security.wpa:   return 'WPA';
      case _Security.wpa2:  return 'WPA2';
      case _Security.wpa3:  return 'WPA3';
    }
  }

  Color get color {
    switch (this) {
      case _Security.open:  return AppTheme.errorColor;
      case _Security.wep:   return AppTheme.warning;
      case _Security.wpa:   return AppTheme.warning;
      case _Security.wpa2:  return AppTheme.success;
      case _Security.wpa3:  return AppTheme.success;
    }
  }

  String get encryptionType {
    switch (this) {
      case _Security.open:  return 'OPEN';
      case _Security.wep:   return 'WEP';
      case _Security.wpa:   return 'WPA';
      case _Security.wpa2:  return 'WPA2';
      case _Security.wpa3:  return 'WPA3';
    }
  }

  bool get isRisky => this == _Security.open || this == _Security.wep;
}

_Security _parseSecurity(String capabilities) {
  final c = capabilities.toUpperCase();
  if (c.contains('WPA3')) return _Security.wpa3;
  if (c.contains('WPA2')) return _Security.wpa2;
  if (c.contains('WPA'))  return _Security.wpa;
  if (c.contains('WEP'))  return _Security.wep;
  return _Security.open;
}

int _signalBars(int rssi) {
  if (rssi >= -50) return 4;
  if (rssi >= -65) return 3;
  if (rssi >= -75) return 2;
  return 1;
}

IconData _signalIcon(int rssi) {
  switch (_signalBars(rssi)) {
    case 4: return Icons.signal_wifi_4_bar;
    case 3: return Icons.network_wifi_3_bar;
    case 2: return Icons.network_wifi_2_bar;
    default: return Icons.network_wifi_1_bar;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location state
// ─────────────────────────────────────────────────────────────────────────────
enum _LocationState { unknown, permissionDenied, servicesDisabled, ready }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class WifiScannerScreen extends StatefulWidget {
  const WifiScannerScreen({super.key});

  @override
  State<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen> {
  final _api         = WifiApi();
  final _networkInfo = NetworkInfo();

  // Location gate
  _LocationState _locationState = _LocationState.unknown;

  // Connected network
  String? _connectedSsid;
  String? _connectedBssid;
  // Capabilities string resolved from the nearby scan (e.g. "[WPA2-PSK-CCMP][ESS]")
  String? _connectedCapabilities;

  // Nearby networks
  List<WiFiAccessPoint> _nearbyNetworks = [];
  bool _scanning = false;

  // Per-network backend check results keyed by bssid (or ssid)
  final Map<String, Map<String, dynamic>> _checkResults = {};
  final Map<String, bool>                 _checking     = {};

  // Scan history
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ── Bootstrap: check permission → load connected → scan nearby ────────────

  Future<void> _bootstrap() async {
    final state = await _resolveLocationState(request: false);
    setState(() => _locationState = state);
    if (state == _LocationState.ready) {
      await Future.wait([_loadConnected(), _scanNearby(), _loadHistory()]);
    } else {
      _loadHistory(); // history can load without location
    }
  }

  /// Returns the effective location state. If [request] is true it asks for
  /// permission first (used when the user taps "Grant Permission").
  Future<_LocationState> _resolveLocationState({required bool request}) async {
    var status = await Permission.location.status;

    if (!status.isGranted) {
      if (request) status = await Permission.location.request();
      if (!status.isGranted) {
        return status.isPermanentlyDenied
            ? _LocationState.permissionDenied
            : _LocationState.permissionDenied;
      }
    }

    // Permission granted — check if the GPS/Location Services toggle is on
    final serviceStatus = await Permission.location.serviceStatus;
    if (!serviceStatus.isEnabled) return _LocationState.servicesDisabled;

    return _LocationState.ready;
  }

  // ── Connected network ──────────────────────────────────────────────────────

  Future<void> _loadConnected() async {
    try {
      String? ssid  = await _networkInfo.getWifiName();
      String? bssid = await _networkInfo.getWifiBSSID();
      // Android wraps SSID in double-quotes on some devices
      if (ssid != null && ssid.startsWith('"') && ssid.endsWith('"')) {
        ssid = ssid.substring(1, ssid.length - 1);
      }
      if (mounted) setState(() { _connectedSsid = ssid; _connectedBssid = bssid; });
    } catch (_) {}
  }

  // ── Nearby scan ───────────────────────────────────────────────────────────

  Future<void> _scanNearby() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      // Trigger a fresh hardware scan
      final canStart = await WiFiScan.instance.canStartScan(askPermissions: false);
      if (canStart == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future.delayed(const Duration(seconds: 2));
      }

      final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: false);

      if (canGet == CanGetScannedResults.yes) {
        final results = await WiFiScan.instance.getScannedResults();
        results.sort((a, b) => b.level.compareTo(a.level));

        // Match the connected AP by BSSID (most reliable) or SSID fallback
        // and capture its capabilities so we know the real security type.
        String? connCaps;
        if (_connectedBssid != null || _connectedSsid != null) {
          WiFiAccessPoint? match;
          // Prefer BSSID match (exact hardware address)
          if (_connectedBssid != null) {
            match = results.where((ap) =>
                ap.bssid.toLowerCase() == _connectedBssid!.toLowerCase())
                .firstOrNull;
          }
          // Fall back to SSID match with highest signal
          match ??= results.where((ap) =>
              ap.ssid == _connectedSsid && ap.ssid.isNotEmpty)
              .firstOrNull;
          connCaps = match?.capabilities;
        }

        if (mounted) {
          setState(() {
            _nearbyNetworks = results;
            if (connCaps != null) _connectedCapabilities = connCaps;
          });
        }
      } else if (canGet == CanGetScannedResults.noLocationServiceDisabled) {
        // Location Services toggled off mid-session
        if (mounted) setState(() => _locationState = _LocationState.servicesDisabled);
      } else if (canGet == CanGetScannedResults.noLocationPermissionDenied ||
                 canGet == CanGetScannedResults.noLocationPermissionRequired) {
        if (mounted) setState(() => _locationState = _LocationState.permissionDenied);
      }
      // other failures (noNetworkInterfacesAvailable etc.) → silently skip
    } catch (_) {
      // Ignore hardware failures
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _refreshAll() async {
    final state = await _resolveLocationState(request: false);
    if (mounted) setState(() => _locationState = state);
    if (state == _LocationState.ready) {
      await Future.wait([_loadConnected(), _scanNearby()]);
    }
  }

  // ── Permission / services helpers ─────────────────────────────────────────

  Future<void> _requestLocationPermission() async {
    final state = await _resolveLocationState(request: true);
    if (mounted) setState(() => _locationState = state);
    if (state == _LocationState.servicesDisabled) {
      _showLocationServicesDialog();
    } else if (state == _LocationState.ready) {
      await Future.wait([_loadConnected(), _scanNearby()]);
    } else {
      // Permanently denied — open app settings
      await openAppSettings();
    }
  }

  void _showLocationServicesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.location_off, color: AppTheme.warning, size: 22),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context).wifiLocOff, style: const TextStyle(fontSize: 16)),
        ]),
        content: const Text(
          'Android requires Location Services (GPS) to be enabled for Wi-Fi scanning '
          'and to detect which network you are connected to.\n\n'
          'Please turn on Location / GPS in your device settings, then come back and tap Refresh.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel,
              style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings, size: 16),
            label: Text(AppLocalizations.of(context).gOpenSettings),
            onPressed: () async {
              Navigator.pop(ctx);
              // Open Android Location Settings
              try {
                await const MethodChannel('secureshield/system')
                    .invokeMethod('openLocationSettings');
              } catch (_) {
                await openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
            ),
          ),
        ],
      ),
    );
  }

  // ── Backend safety check ───────────────────────────────────────────────────

  String _apKey(WiFiAccessPoint ap) =>
      ap.bssid.isNotEmpty ? ap.bssid : ap.ssid;

  Future<void> _checkSafety(WiFiAccessPoint ap) async {
    final key = _apKey(ap);
    if (_checking[key] == true) return;
    setState(() => _checking[key] = true);
    try {
      final security = _parseSecurity(ap.capabilities);
      final result = await _api.scanWifi(
        ssid:           ap.ssid.isNotEmpty ? ap.ssid : null,
        bssid:          ap.bssid.isNotEmpty ? ap.bssid : null,
        signalStrength: ap.level,
        encryptionType: security.encryptionType,
      );
      if (mounted) {
        setState(() => _checkResults[key] = result);
        _showResultDialog(ap.ssid.isNotEmpty ? ap.ssid : 'Hidden Network',
            ap.capabilities, result);
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check failed: $e'),
            backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _checking[key] = false);
    }
  }

  Future<void> _checkConnectedSafety() async {
    if (_connectedSsid == null) return;
    setState(() => _checking['connected'] = true);
    try {
      // Derive encryption type from capabilities captured during nearby scan.
      // If we haven't scanned yet, omit it so the backend can still respond.
      final encType = _connectedCapabilities != null
          ? _parseSecurity(_connectedCapabilities!).encryptionType
          : null;

      final result = await _api.scanWifi(
        ssid:           _connectedSsid,
        bssid:          _connectedBssid,
        encryptionType: encType,
      );
      if (mounted) {
        setState(() => _checkResults['connected'] = result);
        _showResultDialog(_connectedSsid!, '', result);
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check failed: $e'),
            backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _checking['connected'] = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _api.getHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {}
  }

  // ── Result dialog ──────────────────────────────────────────────────────────

  void _showResultDialog(
      String ssid, String capabilities, Map<String, dynamic> result) {
    final riskLevel    = result['risk_level'] as String? ?? 'safe';
    final isSuspicious = result['is_suspicious'] as bool? ?? false;
    final reasons      = (result['risk_reasons'] as List?)?.cast<String>() ?? [];
    final color        = AppTheme.riskColor(riskLevel);
    final security     = capabilities.isNotEmpty ? _parseSecurity(capabilities) : null;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(isSuspicious ? Icons.wifi_off : Icons.wifi, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(ssid,
              style: TextStyle(color: color, fontSize: 16),
              overflow: TextOverflow.ellipsis),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text('Risk: ${riskLevel.toUpperCase()}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            if (security != null && security.isRisky) ...[
              _warningBanner(
                security == _Security.open
                    ? '⚠ Open Network — No Password Protection'
                    : '⚠ WEP Encryption is obsolete and easily cracked',
                color: security.color,
              ),
              const SizedBox(height: 8),
            ],
            if (reasons.isNotEmpty) ...[
              Text(AppLocalizations.of(context).wifiRiskFactors,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, size: 13, color: color),
                    const SizedBox(width: 5),
                    Expanded(child: Text(r,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.9), fontSize: 12))),
                  ],
                ),
              )),
            ] else
              Text(AppLocalizations.of(context).wifiNoRiskFactors,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).gClose, style: const TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).wifiSafety),
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent))
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : _refreshAll,
            tooltip: AppLocalizations.of(context).wifiRescan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Location gate ──────────────────────────────────────────────
            if (_locationState == _LocationState.permissionDenied)
              _locationGateCard(
                icon:    Icons.location_disabled,
                color:   AppTheme.errorColor,
                title:   AppLocalizations.of(context).wifiLocPermReq,
                message: 'Android requires Location permission to scan nearby '
                         'Wi-Fi networks and detect your connected network. '
                         'Your data is never shared.',
                buttonLabel: 'Grant Permission',
                onTap: _requestLocationPermission,
              )
            else if (_locationState == _LocationState.servicesDisabled)
              _locationGateCard(
                icon:    Icons.location_off,
                color:   AppTheme.warning,
                title:   AppLocalizations.of(context).wifiLocDisabled,
                message: 'Enable GPS / Location Services in your device settings. '
                         'Android needs it to scan Wi-Fi networks.',
                buttonLabel: 'Open Settings',
                onTap: _showLocationServicesDialog,
              ),

            if (_locationState == _LocationState.permissionDenied ||
                _locationState == _LocationState.servicesDisabled)
              const SizedBox(height: 16),

            // ── Currently Connected ────────────────────────────────────────
            _sectionTitle('Currently Connected', Icons.wifi),
            const SizedBox(height: 8),
            _connectedCard(),
            const SizedBox(height: 20),

            // ── Nearby Networks ────────────────────────────────────────────
            Row(
              children: [
                _sectionTitle('Nearby Networks', Icons.radar),
                const Spacer(),
                if (_nearbyNetworks.isNotEmpty)
                  Text('${_nearbyNetworks.length} found',
                    style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            if (_scanning && _nearbyNetworks.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppTheme.accent),
              ))
            else if (_locationState != _LocationState.ready &&
                     _nearbyNetworks.isEmpty)
              _noPermissionNearbyCard()
            else if (_nearbyNetworks.isEmpty)
              _emptyNearbyCard()
            else
              ..._nearbyNetworks.map((ap) => _nearbyCard(ap)),

            const SizedBox(height: 20),

            // ── Scan History ───────────────────────────────────────────────
            if (_history.isNotEmpty) ...[
              _sectionTitle('Recent Checks', Icons.history),
              const SizedBox(height: 8),
              ..._history.take(5).map(
                  (h) => _historyTile(h as Map<String, dynamic>)),
              const SizedBox(height: 20),
            ],

            // ── Tips ──────────────────────────────────────────────────────
            _tipsCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text, IconData icon) => Row(
    children: [
      Icon(icon, color: AppTheme.accent, size: 16),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(
        color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
    ],
  );

  /// Gate card shown when location permission / services are missing.
  Widget _locationGateCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message,
            style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(
                icon == Icons.location_disabled
                    ? Icons.security : Icons.settings,
                size: 16),
              label: Text(buttonLabel, style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard() {
    // Show hint card when we can't read the connected network
    if (_locationState == _LocationState.permissionDenied ||
        _locationState == _LocationState.servicesDisabled) {
      final isServices = _locationState == _LocationState.servicesDisabled;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isServices ? Icons.location_off : Icons.location_disabled,
              color: AppTheme.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isServices
                    ? 'Enable Location Services to detect connected network'
                    : 'Grant Location permission to detect connected network',
                style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    // Still loading
    if (_locationState == _LocationState.unknown) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent)),
            SizedBox(width: 12),
            Text('Detecting connected network…',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Ready but no WiFi
    if (_connectedSsid == null || _connectedSsid!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                AppLocalizations.of(context).wifiNotConnected,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // Connected — show SSID + optional risk
    final connResult = _checkResults['connected'];
    final isChecking = _checking['connected'] == true;
    // Security derived from nearby scan capabilities (the authoritative source)
    final connSecurity = _connectedCapabilities != null
        ? _parseSecurity(_connectedCapabilities!)
        : null;

    // If backend returned HIGH/MEDIUM but we know encryption is WPA2/WPA3
    // (the backend didn't have encryptionType at check time), trust the local data.
    String? riskLevel = connResult?['risk_level'] as String?;
    if (riskLevel != null && connSecurity != null && !connSecurity.isRisky) {
      // Re-evaluate: only keep a high/medium risk if the check used correct encryption.
      // A simple heuristic: if the ONLY risk reasons were "open network" related,
      // we suppress the risk entirely since the network IS encrypted.
      final reasons = (connResult!['risk_reasons'] as List?)?.cast<String>() ?? [];
      final realReasons = reasons.where((r) {
        final lower = r.toLowerCase();
        return !(lower.contains('open') || lower.contains('no encrypt') ||
                 lower.contains('no password') || lower.contains('unencrypted'));
      }).toList();
      if (realReasons.isEmpty && (riskLevel == 'high' || riskLevel == 'medium')) {
        riskLevel = null; // Hide stale risk — user should re-check
      }
    }
    final riskColor  = riskLevel != null
        ? AppTheme.riskColor(riskLevel) : AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: riskLevel != null
              ? riskColor.withValues(alpha: 0.4)
              : AppTheme.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wifi,
                  color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _connectedSsid!,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_connectedBssid != null && _connectedBssid!.isNotEmpty)
                      Text(_connectedBssid!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                    if (connSecurity != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: connSecurity.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(connSecurity.label,
                          style: TextStyle(
                            color: connSecurity.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              if (riskLevel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: riskColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(riskLevel.toUpperCase(),
                    style: TextStyle(color: riskColor,
                      fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),

          // Risk reasons — filter out "open network" reasons when we know
          // the actual security type is not open (backend may lack encryption info).
          if (connResult != null) ...[
            const SizedBox(height: 10),
            ...((connResult['risk_reasons'] as List?)
                ?.cast<String>() ?? [])
                .where((r) {
                  // Suppress false-positive "open/no encryption" warnings when
                  // we confirmed the network is WPA/WPA2/WPA3 from nearby scan.
                  if (connSecurity != null && !connSecurity.isRisky) {
                    final lower = r.toLowerCase();
                    if (lower.contains('open') || lower.contains('no encrypt') ||
                        lower.contains('no password') || lower.contains('unencrypted')) {
                      return false;
                    }
                  }
                  return true;
                })
                .map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, size: 13, color: riskColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r,
                    style: TextStyle(
                      color: riskColor.withValues(alpha: 0.9),
                      fontSize: 12))),
                ],
              ),
            )),
          ],

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isChecking ? null : _checkConnectedSafety,
              icon: isChecking
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.security, size: 16),
              label: Text(isChecking ? 'Checking…' : 'Check Safety',
                style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nearbyCard(WiFiAccessPoint ap) {
    final displaySsid = ap.ssid.isNotEmpty ? ap.ssid : 'Hidden Network';
    final security    = _parseSecurity(ap.capabilities);
    final rssi        = ap.level;
    final key         = _apKey(ap);
    final isChecking  = _checking[key] == true;
    final result      = _checkResults[key];
    final riskLevel   = result?['risk_level'] as String?;
    final riskColor   = riskLevel != null
        ? AppTheme.riskColor(riskLevel) : null;
    final isConnected = _connectedSsid != null &&
        (_connectedSsid == ap.ssid || _connectedBssid == ap.bssid);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: security.isRisky
              ? security.color.withValues(alpha: 0.4)
              : riskColor != null
                  ? riskColor.withValues(alpha: 0.3)
                  : AppTheme.cardColor,
        ),
      ),
      child: Column(
        children: [
          // Warning banner
          if (security == _Security.open)
            _topBanner(
              icon: Icons.no_encryption,
              text: '⚠ Open Network — No Password. Avoid sensitive activity.',
              color: AppTheme.errorColor,
            )
          else if (security == _Security.wep)
            _topBanner(
              icon: Icons.lock_open,
              text: '⚠ WEP Encryption — Easily hacked.',
              color: AppTheme.warning,
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Signal
                Column(
                  children: [
                    Icon(_signalIcon(rssi),
                      color: security.isRisky
                          ? security.color : AppTheme.accent,
                      size: 22),
                    Text('${_signalBars(rssi)}/4',
                      style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 9)),
                  ],
                ),
                const SizedBox(width: 10),

                // SSID + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(displaySsid,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          ),
                          if (isConnected) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(AppLocalizations.of(context).wifiConnected,
                                style: const TextStyle(color: AppTheme.success,
                                  fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: security.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(security.label,
                              style: TextStyle(color: security.color,
                                fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Text('$rssi dBm',
                            style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(ap.frequency >= 5000 ? '5 GHz' : '2.4 GHz',
                            style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Check button / risk badge
                if (riskLevel != null && !isChecking)
                  GestureDetector(
                    onTap: () => _checkSafety(ap),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor!.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: riskColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(riskLevel.toUpperCase(),
                        style: TextStyle(color: riskColor, fontSize: 9,
                          fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  TextButton(
                    onPressed: isChecking ? null : () => _checkSafety(ap),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: isChecking
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.accent))
                        : Text(AppLocalizations.of(context).wifiCheck,
                            style: const TextStyle(color: AppTheme.accent,
                              fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBanner({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
              style: TextStyle(color: color,
                fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _noPermissionNearbyCard() {
    final isServices =
        _locationState == _LocationState.servicesDisabled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            isServices ? Icons.location_off : Icons.wifi_find,
            size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            isServices
                ? 'Location Services are disabled'
                : 'Location permission not granted',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isServices
                ? 'Please enable GPS / Location Services and tap Refresh'
                : 'Tap below to grant Location permission for Wi-Fi scanning',
            style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isServices
                ? _showLocationServicesDialog
                : _requestLocationPermission,
            icon: Icon(
              isServices ? Icons.settings : Icons.security,
              size: 16),
            label: Text(isServices ? 'Open Settings' : 'Grant Permission'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyNearbyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_find, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).wifiNoNearby,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Make sure Wi-Fi is on and tap Refresh',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _scanning ? null : _scanNearby,
            icon: const Icon(Icons.radar, size: 16),
            label: Text(AppLocalizations.of(context).wifiScanNearby),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> item) {
    final riskLevel = item['risk_level'] as String? ?? 'safe';
    final color     = AppTheme.riskColor(riskLevel);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['ssid'] as String? ?? 'Unknown',
                  style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['encryption_type'] != null)
                  Text(item['encryption_type'] as String,
                    style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(riskLevel.toUpperCase(),
              style: TextStyle(color: color,
                fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _warningBanner(String text, {required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
        style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _tipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates, color: AppTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context).wifiTips, style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            'Never use open (no-password) Wi-Fi for banking, UPI, or logins.',
            'Attackers on public Wi-Fi can intercept your data (MITM attacks).',
            'Watch out for fake "Free WiFi" hotspots at malls, cafes, and stations.',
            'WPA3 networks offer the strongest protection — prefer them.',
            'Use a VPN when connecting to unknown or public networks.',
            'Disable auto-connect to open networks in your phone settings.',
          ].map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_right,
                  color: AppTheme.accent, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(tip,
                  style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

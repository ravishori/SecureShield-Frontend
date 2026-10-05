import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme.dart';

/// Specially-handled permissions that need native bridges or Settings flows.
enum SpecialType { normal, usageStats, storage, notification }

class PermissionItem {
  /// Primary [Permission] handled by `permission_handler`. May be null for
  /// `SpecialType.usageStats` which has no runtime permission.
  final Permission? permission;
  /// Extra permissions that should be requested together (e.g. on Android
  /// 13+ "Storage" means `Permission.photos` + `.videos` + `.audio`).
  final List<Permission> extraPermissions;
  final SpecialType specialType;
  final String title;
  final String reason;
  final IconData icon;
  final bool critical;

  const PermissionItem({
    this.permission,
    this.extraPermissions = const [],
    this.specialType = SpecialType.normal,
    required this.title,
    required this.reason,
    required this.icon,
    this.critical = false,
  });
}

class ConsentManagerScreen extends StatefulWidget {
  const ConsentManagerScreen({super.key});

  @override
  State<ConsentManagerScreen> createState() => _ConsentManagerScreenState();
}

class _ConsentManagerScreenState extends State<ConsentManagerScreen> {
  // MethodChannel to the existing remote_detector channel for usage-stats checks
  static const _channel = MethodChannel('secureshield/remote_detector');

  /// Android SDK level cached on first load. Drives the Android-13+ media
  /// permission split.
  int _androidSdk = 0;

  /// Permission catalogue — built dynamically in [initState] because the
  /// "Storage" entry differs between Android <=12 (use Permission.storage)
  /// and Android 13+ (use the media-type splits).
  late final List<PermissionItem> _permissions;

  Map<int, PermissionStatus> _statuses = {};   // keyed by index
  Map<int, bool> _specialGranted = {};          // for special-type items
  bool _loading = true;
  bool _batchInFlight = false;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _androidSdk = info.version.sdkInt;
      } catch (_) {
        _androidSdk = 0;
      }
    }
    _permissions = _buildCatalog();
    await _loadStatuses();
  }

  /// Build the right permission set for this OS version.
  ///
  /// **Storage rule of thumb (the actual Android story)**:
  ///   • SDK ≤ 28 (Android 9-): need WRITE_EXTERNAL_STORAGE → use Permission.storage
  ///   • SDK 29-32 (Android 10-12): scoped storage; app-private dirs need
  ///     no permission. We still expose Permission.storage so old shared
  ///     files (legacy MediaStore) work — the system will mark it granted
  ///     without showing a dialog on 11/12 because of scoped storage.
  ///   • SDK ≥ 33 (Android 13+): READ_MEDIA_IMAGES / VIDEO / AUDIO replaced
  ///     the old storage perms. Request all three so any evidence file
  ///     (photo / video / audio recording) works.
  List<PermissionItem> _buildCatalog() {
    final isAndroid13Plus = Platform.isAndroid && _androidSdk >= 33;

    return [
      const PermissionItem(
        permission: Permission.sms,
        title: 'SMS Access',
        reason: 'Read SMS to detect OTPs and alert you about bank messages.',
        icon: Icons.sms,
        critical: true,
      ),
      const PermissionItem(
        permission: Permission.camera,
        title: 'Camera',
        reason: 'Capture photo evidence for fraud reporting.',
        icon: Icons.camera_alt,
      ),
      const PermissionItem(
        permission: Permission.microphone,
        title: 'Microphone',
        reason: 'Record audio during scam calls as evidence.',
        icon: Icons.mic,
      ),
      const PermissionItem(
        permission: Permission.location,
        title: 'Location',
        reason: 'Attach location to evidence and find nearby cyber cells.',
        icon: Icons.location_on,
      ),
      const PermissionItem(
        permission: Permission.phone,
        title: 'Phone State',
        reason: 'Detect incoming calls for scam call protection.',
        icon: Icons.phone,
      ),
      // ── Storage: version-aware ─────────────────────────────────────────
      if (isAndroid13Plus)
        const PermissionItem(
          // Android 13+: ask for photos as the primary; videos + audio as extras.
          permission: Permission.photos,
          extraPermissions: [Permission.videos, Permission.audio],
          specialType: SpecialType.storage,
          title: 'Storage (Media)',
          reason: 'Save evidence files, screenshots, and recordings.',
          icon: Icons.folder,
        )
      else
        const PermissionItem(
          // Android 12-: classic storage permission.
          permission: Permission.storage,
          specialType: SpecialType.storage,
          title: 'Storage',
          reason: 'Save evidence files, recordings, and reports.',
          icon: Icons.folder,
        ),
      const PermissionItem(
        permission: Permission.notification,
        specialType: SpecialType.notification,
        title: 'Notifications',
        reason: 'Show security alerts and OTP warnings.',
        icon: Icons.notifications,
        critical: true,
      ),
      const PermissionItem(
        // Android: PACKAGE_USAGE_STATS — not a runtime permission; opened via Settings
        specialType: SpecialType.usageStats,
        title: 'Usage Stats',
        reason: 'Analyze installed apps for security risks.',
        icon: Icons.bar_chart,
      ),
    ];
  }

  Future<void> _loadStatuses() async {
    setState(() => _loading = true);
    final statuses = <int, PermissionStatus>{};
    final special  = <int, bool>{};

    for (int i = 0; i < _permissions.length; i++) {
      final item = _permissions[i];
      if (item.specialType == SpecialType.usageStats) {
        try {
          final granted = await _channel.invokeMethod<bool>(
            'checkUsageStatsPermission',
          ) ?? false;
          special[i] = granted;
        } catch (_) {
          special[i] = false;
        }
      } else if (item.permission != null) {
        // For grouped permissions (e.g. Android 13 storage = photos+videos+audio),
        // we require ALL of them to be granted before showing the green tick.
        var status = await item.permission!.status;
        for (final extra in item.extraPermissions) {
          final extraStatus = await extra.status;
          if (!extraStatus.isGranted) {
            status = extraStatus;
            break;
          }
        }
        statuses[i] = status;
      }
    }

    if (mounted) {
      setState(() {
        _statuses = statuses;
        _specialGranted = special;
        _loading = false;
      });
    }
  }

  /// Request a single permission item. Returns true if granted after the request.
  Future<bool> _requestPermission(int index, {bool silentForBatch = false}) async {
    final item = _permissions[index];

    if (item.specialType == SpecialType.usageStats) {
      if (silentForBatch) return false;  // skip Settings flow in batch mode
      _showUsageStatsDialog();
      return false;
    }

    if (item.permission == null) return false;

    // Build the set of permissions to request: primary + extras.
    final all = [item.permission!, ...item.extraPermissions];

    // requestMultiple() shows a SINGLE Android dialog containing all listed
    // permissions, instead of N dialogs back-to-back.
    final results = await all.request();

    final allGranted = results.values.every((s) => s.isGranted);
    final anyPermanentlyDenied =
        results.values.any((s) => s.isPermanentlyDenied);

    // If anything was permanently denied AND the user clicked the button
    // directly (not via batch), bounce them to App Settings so they can fix it.
    if (!allGranted && anyPermanentlyDenied && !silentForBatch) {
      await openAppSettings();
    }

    if (!silentForBatch) await _loadStatuses();
    return allGranted;
  }

  Future<void> _grantAllPermissions() async {
    if (_batchInFlight) return;
    setState(() => _batchInFlight = true);

    // 1. Collect every runtime permission across all non-special items.
    //    requestMultiple() will show a single grouped dialog.
    final runtimePerms = <Permission>{};
    for (final item in _permissions) {
      // Skip Usage Stats (not a runtime permission)
      if (item.specialType == SpecialType.usageStats) continue;
      if (item.permission != null) runtimePerms.add(item.permission!);
      runtimePerms.addAll(item.extraPermissions);
    }

    int grantedThisRound = 0;
    int permanentlyDenied = 0;
    try {
      // Filter out any already-granted to avoid Android re-asking for them.
      final toRequest = <Permission>[];
      for (final p in runtimePerms) {
        final s = await p.status;
        if (!s.isGranted) toRequest.add(p);
      }
      if (toRequest.isNotEmpty) {
        // ONE system dialog (or sequential per permission group on older
        // Android versions — the OS decides batching, not us).
        final results = await toRequest.request();
        for (final entry in results.entries) {
          if (entry.value.isGranted) {
            grantedThisRound++;
          } else if (entry.value.isPermanentlyDenied) {
            permanentlyDenied++;
          }
        }
      }
    } catch (e) {
      debugPrint('[ConsentManager] batch request failed: $e');
    }

    // 2. Refresh on-screen status before triggering special-permission flows.
    await _loadStatuses();

    // 3. Show a result snackbar
    if (mounted) {
      final allGranted = _permissions.every((_) => true) &&
          _permissions
              .asMap()
              .entries
              .every((e) => _isGranted(e.key) ||
                  e.value.specialType == SpecialType.usageStats);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: allGranted
              ? AppTheme.success
              : (permanentlyDenied > 0
                  ? AppTheme.errorColor
                  : AppTheme.warning),
          content: Text(
            permanentlyDenied > 0
                ? 'Some permissions were permanently denied. Tap "Settings" '
                    'on each to grant manually.'
                : grantedThisRound > 0
                    ? '$grantedThisRound permission${grantedThisRound == 1 ? "" : "s"} granted.'
                    : 'No new permissions granted.',
            style: const TextStyle(color: Colors.white),
          ),
          action: permanentlyDenied > 0
              ? SnackBarAction(
                  label: 'Open Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                )
              : null,
        ),
      );
    }

    // 4. Offer Usage Stats next (it requires a separate Settings page).
    if (mounted) {
      final usageIdx = _permissions
          .indexWhere((p) => p.specialType == SpecialType.usageStats);
      if (usageIdx >= 0 && !_isGranted(usageIdx)) {
        // Tiny delay so the snackbar above is visible before the dialog
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _showUsageStatsDialog();
      }
    }

    if (mounted) setState(() => _batchInFlight = false);
  }

  void _showUsageStatsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.bar_chart, color: AppTheme.accent, size: 20),
          SizedBox(width: 8),
          Text('Usage Stats Access', style: TextStyle(fontSize: 16)),
        ]),
        content: const Text(
          'Usage Stats permission allows SecureShield to analyze '
          'installed apps for risks.\n\n'
          'You\'ll be taken to the system "Usage Access" settings page. '
          'Find "SecureShield AI" in the list and enable it.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _channel.invokeMethod('openUsageAccessSettings');
              } catch (_) {
                await openAppSettings();
              }
              // Reload after returning from settings
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) await _loadStatuses();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Open Settings', style: TextStyle(color: AppTheme.background)),
          ),
        ],
      ),
    );
  }

  bool _isGranted(int index) {
    final item = _permissions[index];
    if (item.specialType == SpecialType.usageStats) {
      return _specialGranted[index] ?? false;
    }
    return _statuses[index]?.isGranted ?? false;
  }

  bool _isPermanentlyDenied(int index) {
    return _statuses[index]?.isPermanentlyDenied ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // While the initial OS-version detect is still in flight, _permissions
    // isn't initialised yet. Render the spinner against the same Scaffold
    // so we don't crash on `late final` access.
    if (_loading && _statuses.isEmpty && _specialGranted.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permission Manager')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final granted = List.generate(_permissions.length, (i) => _isGranted(i))
        .where((g) => g).length;
    final total     = _permissions.length;
    final criticals = _permissions
        .asMap()
        .entries
        .where((e) => e.value.critical)
        .toList();
    final allCriticalGranted = criticals.every((e) => _isGranted(e.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _batchInFlight ? null : _loadStatuses,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primary,
                  allCriticalGranted
                      ? AppTheme.success.withValues(alpha: 0.5)
                      : AppTheme.warning.withValues(alpha: 0.5),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    value: total > 0 ? granted / total : 0,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allCriticalGranted ? AppTheme.success : AppTheme.warning),
                    strokeWidth: 6,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$granted / $total permissions granted',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allCriticalGranted
                              ? 'All critical permissions granted'
                              : 'Some critical permissions are missing',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('App Permissions', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )),
            const SizedBox(height: 12),

            ...List.generate(_permissions.length, (i) => _permissionCard(i)),

            const SizedBox(height: 16),

            // Grant all button — only enabled when there's at least one not granted
            if (granted < total)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _batchInFlight ? null : _grantAllPermissions,
                  icon: _batchInFlight
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.security),
                  label: Text(
                    _batchInFlight ? 'Requesting…' : 'Grant All Permissions',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard(int index) {
    final item    = _permissions[index];
    final granted = _isGranted(index);
    final denied  = _isPermanentlyDenied(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted
              ? AppTheme.success.withValues(alpha: 0.3)
              : item.critical
                  ? AppTheme.errorColor.withValues(alpha: 0.3)
                  : AppTheme.cardColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (granted ? AppTheme.success : item.critical
                  ? AppTheme.errorColor : AppTheme.accent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon,
              color: granted ? AppTheme.success : item.critical
                  ? AppTheme.errorColor : AppTheme.accent,
              size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(item.title, style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
                  ),
                  if (item.critical) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('CRITICAL',
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (item.specialType == SpecialType.usageStats) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SETTINGS',
                        style: TextStyle(color: AppTheme.accent, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(item.reason, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            const Icon(Icons.check_circle, color: AppTheme.success, size: 22)
          else
            TextButton(
              onPressed: _batchInFlight
                  ? null
                  : () => _requestPermission(index),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: Text(
                item.specialType == SpecialType.usageStats
                    ? 'Open'
                    : denied ? 'Settings' : 'Grant',
                style: TextStyle(
                  color: item.critical ? AppTheme.errorColor : AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permissions that need special native handling on Android
// ─────────────────────────────────────────────────────────────────────────────
enum _SpecialType { normal, usageStats, storage }

class PermissionItem {
  final Permission? permission;     // null for special-handled items
  final _SpecialType specialType;
  final String title;
  final String reason;
  final IconData icon;
  final bool critical;

  const PermissionItem({
    this.permission,
    this.specialType = _SpecialType.normal,
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
  // MethodChannel to the existing remote_detector channel for special actions
  static const _channel = MethodChannel('secureshield/remote_detector');

  final _permissions = const [
    PermissionItem(
      permission: Permission.sms,
      title: 'SMS Access',
      reason: 'Read SMS to detect OTPs and alert you about bank messages.',
      icon: Icons.sms,
      critical: true,
    ),
    PermissionItem(
      permission: Permission.camera,
      title: 'Camera',
      reason: 'Capture photo evidence for fraud reporting.',
      icon: Icons.camera_alt,
    ),
    PermissionItem(
      permission: Permission.microphone,
      title: 'Microphone',
      reason: 'Record audio during scam calls as evidence.',
      icon: Icons.mic,
    ),
    PermissionItem(
      permission: Permission.location,
      title: 'Location',
      reason: 'Attach location to evidence and find nearby cyber cells.',
      icon: Icons.location_on,
    ),
    PermissionItem(
      permission: Permission.phone,
      title: 'Phone State',
      reason: 'Detect incoming calls for scam call protection.',
      icon: Icons.phone,
    ),
    PermissionItem(
      // Use manageExternalStorage for Android 11+ broad file access
      // Falls back gracefully for older versions via openAppSettings()
      permission: Permission.manageExternalStorage,
      specialType: _SpecialType.storage,
      title: 'Storage',
      reason: 'Save evidence files, recordings, and reports.',
      icon: Icons.folder,
    ),
    PermissionItem(
      permission: Permission.notification,
      title: 'Notifications',
      reason: 'Show security alerts and OTP warnings.',
      icon: Icons.notifications,
      critical: true,
    ),
    PermissionItem(
      // Android: PACKAGE_USAGE_STATS — not a runtime permission; opened via Settings
      // iOS: not applicable
      specialType: _SpecialType.usageStats,
      title: 'Usage Stats',
      reason: 'Analyze installed apps for security risks.',
      icon: Icons.bar_chart,
    ),
  ];

  Map<int, PermissionStatus> _statuses = {};   // keyed by index
  Map<int, bool> _specialGranted = {};          // for special-type items
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _loading = true);
    final statuses = <int, PermissionStatus>{};
    final special  = <int, bool>{};

    for (int i = 0; i < _permissions.length; i++) {
      final item = _permissions[i];
      if (item.specialType == _SpecialType.usageStats) {
        // Check via native MethodChannel
        try {
          final granted = await _channel.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
          special[i] = granted;
        } catch (_) {
          special[i] = false;
        }
      } else if (item.permission != null) {
        statuses[i] = await item.permission!.status;
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

  Future<void> _requestPermission(int index) async {
    final item = _permissions[index];

    if (item.specialType == _SpecialType.usageStats) {
      // Usage Stats is a special access, not a runtime permission — open settings
      _showUsageStatsDialog();
      return;
    }

    if (item.specialType == _SpecialType.storage) {
      // On Android, MANAGE_EXTERNAL_STORAGE opens "All files access" Settings page
      // On iOS or if unavailable, fall through to normal request
      if (Platform.isAndroid) {
        final status = await item.permission!.request();
        if (status.isPermanentlyDenied || status == PermissionStatus.restricted) {
          await openAppSettings();
        }
        await _loadStatuses();
        return;
      }
    }

    if (item.permission == null) return;

    final status = await item.permission!.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else if (status == PermissionStatus.denied) {
      // On some Android 13+ devices, request silently fails; force app settings
      await openAppSettings();
    }
    await _loadStatuses();
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
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
    if (item.specialType == _SpecialType.usageStats) {
      return _specialGranted[index] ?? false;
    }
    return _statuses[index]?.isGranted ?? false;
  }

  bool _isPermanentlyDenied(int index) {
    return _statuses[index]?.isPermanentlyDenied ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _loadStatuses,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : SingleChildScrollView(
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
                            ? AppTheme.success.withOpacity(0.5)
                            : AppTheme.warning.withOpacity(0.5),
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

                  // Grant all button
                  if (granted < total)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          for (int i = 0; i < _permissions.length; i++) {
                            if (!_isGranted(i)) {
                              await _requestPermission(i);
                            }
                          }
                        },
                        icon: const Icon(Icons.security),
                        label: const Text('Grant All Permissions'),
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
              ? AppTheme.success.withOpacity(0.3)
              : item.critical
                  ? AppTheme.errorColor.withOpacity(0.3)
                  : AppTheme.cardColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (granted ? AppTheme.success : item.critical
                  ? AppTheme.errorColor : AppTheme.accent).withOpacity(0.1),
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
                        color: AppTheme.errorColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('CRITICAL',
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (item.specialType == _SpecialType.usageStats) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
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
              onPressed: () => _requestPermission(index),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: Text(
                item.specialType == _SpecialType.usageStats
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

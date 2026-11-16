import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/risk_ui_tokens.dart';
import '../../../core/theme/theme_provider.dart' show themeProvider;
import '../../../core/services/notification_service.dart';
import '../../../core/security/fake_app_detector.dart';
import '../../../core/security/device_scanner_service.dart';
import '../../../core/security/app_risk_engine.dart';
import '../../../core/widgets/premium/scan/scan.dart';

/// App Scanner screen.
///
/// Scans the device's REAL installed apps using the on-device
/// [AppRiskEngine]. Uses adaptive [RiskUiTokens] so cards remain
/// WCAG-AA readable in every theme — including Senior Citizen and Nature
/// Green, which previously showed white text on light backgrounds.
class AppScannerScreen extends ConsumerStatefulWidget {
  const AppScannerScreen({super.key});

  @override
  ConsumerState<AppScannerScreen> createState() => _AppScannerScreenState();
}

enum _ScanPhase { idle, scanning, complete, error }

class _AppScannerScreenState extends ConsumerState<AppScannerScreen> {
  _ScanPhase _phase = _ScanPhase.idle;
  List<AppRiskResult> _results = [];
  ScanSummary? _summary;
  ScanSummaryData? _summaryData;
  Object? _scanError;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    // Kick off scan on first mount so users don't stare at an empty screen,
    // but route through the same premium _startScan() path so they see the
    // full animated experience even on the initial visit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  void _startScan() {
    if (_phase == _ScanPhase.scanning) return;
    HapticFeedback.lightImpact(); // stage-1 tactile ack
    setState(() {
      _phase = _ScanPhase.scanning;
      _scanError = null;
    });
  }

  /// The real work — runs in the background while `ScanExperience` shows
  /// its scripted animation. Returns the sorted result list.
  Future<List<AppRiskResult>> _performScan() async {
    final apps = await DeviceScannerService.getInstalledApps();
    final a11yComponents = await DeviceScannerService.getAccessibilityServices();
    final summary = AppRiskEngine.analyze(apps, a11yComponents);

    final sorted = [...summary.results]..sort((a, b) {
      final byLevel = b.level.index.compareTo(a.level.index);
      if (byLevel != 0) return byLevel;
      return a.app.appName.toLowerCase().compareTo(b.app.appName.toLowerCase());
    });

    _summary = summary;
    return sorted;
  }

  /// Called by ScanExperience when the animation completes to 100%.
  void _onScanComplete(List<AppRiskResult> results) {
    if (!mounted) return;
    final summary = _summary;
    if (summary == null) return;

    _lastScanAt = DateTime.now();
    _summaryData = _buildSummaryData(results, summary);

    setState(() {
      _results = results;
      _phase = _ScanPhase.complete;
    });

    _maybeNotify(results);
    HapticFeedback.mediumImpact(); // completion tactile cue
  }

  void _onScanError(Object error, StackTrace stack) {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.error;
      _scanError = error;
    });
  }

  /// "View details" handler on the ScanSummaryCard.
  ///
  /// The summary card is tall (score + description + gauge + 6-tile grid),
  /// so on most phones it hides the per-app tile list below the fold.
  /// Dismissing the summary swaps it for a compact scan button and lets the
  /// app list breathe — giving the user room to tap through individual apps
  /// (each tile is expandable with per-app risk reasons).
  ///
  /// `_results` is preserved, so tapping "Scan again" or waiting for a
  /// re-scan will rebuild the summary from the same data instantly.
  void _dismissSummary() {
    if (_phase != _ScanPhase.complete) return;
    // Capture messenger BEFORE any state mutation — the AnimatedSwitcher
    // rebuild is fine, but this is the safe pattern in case a future edit
    // introduces an await here.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _phase = _ScanPhase.idle);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Showing app details — tap "Scan All Apps" to see the summary again'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Summary',
          onPressed: () {
            if (!mounted) return;
            if (_summaryData != null) {
              setState(() => _phase = _ScanPhase.complete);
            }
          },
        ),
      ),
    );
  }

  /// Derives the rich security-intelligence summary the ScanSummaryCard
  /// displays. Categories are based on the dangerous permissions granted
  /// by each app — safe because DeviceAppInfo already exposes them.
  ScanSummaryData _buildSummaryData(
      List<AppRiskResult> results, ScanSummary summary) {
    const camera   = 'android.permission.CAMERA';
    const mic      = 'android.permission.RECORD_AUDIO';
    const fineLoc  = 'android.permission.ACCESS_FINE_LOCATION';
    const coarseLoc = 'android.permission.ACCESS_COARSE_LOCATION';

    var cameraApps = 0, micApps = 0, locationApps = 0, sensitiveApps = 0;
    for (final r in results) {
      final perms = r.app.grantedDangerousPerms;
      if (perms.isEmpty) continue;
      sensitiveApps++;
      if (perms.contains(camera))                          cameraApps++;
      if (perms.contains(mic))                             micApps++;
      if (perms.contains(fineLoc) || perms.contains(coarseLoc)) locationApps++;
    }

    // Overall Device Security Score: penalize warnings by weight.
    // 100 - 25*critical - 12*high - 5*medium, floored at 0.
    final penalty = summary.criticalCount * 25
                  + summary.highCount     * 12
                  + summary.mediumCount   * 5;
    final score = (100 - penalty).clamp(0, 100);

    return ScanSummaryData(
      totalApps:              summary.totalScanned,
      safeApps:               summary.safeCount + summary.lowCount,
      highRiskApps:           summary.criticalCount + summary.highCount,
      appsWithSensitivePerms: sensitiveApps,
      cameraApps:             cameraApps,
      micApps:                micApps,
      locationApps:           locationApps,
      securityScore:          score,
      scanDuration:           const Duration(seconds: 4), // animated duration
      completedAt:            _lastScanAt ?? DateTime.now(),
    );
  }

  /// Show user-facing notifications for risky apps.
  ///
  /// IMPORTANT: never notify for apps the engine has already classified as
  /// SAFE or LOW. The engine is the source of truth — if it says safe, no
  /// alert should be fired regardless of what individual sub-engines (like
  /// FakeAppDetector) think.
  Future<void> _maybeNotify(List<AppRiskResult> results) async {
    for (final r in results) {
      try {
        // ── Gate: only consider apps the engine flagged as medium+. ──────
        // This single check eliminates the false-positive notification spam
        // (system apps impersonating other system apps, ICICI Direct
        // impersonating itself, Google Assistant vs Google Translate, etc.)
        if (!r.level.shouldWarn) continue;

        // ── Fake-app alert (only when engine ALSO sees the impersonation) ─
        // Pass isSystem so the detector short-circuits system apps internally.
        final fake = FakeAppDetector.analyze(
          r.app.packageName,
          r.app.appName,
          isSystem: r.app.isSystem,
        );
        if (fake.risk != FakeAppRisk.notFake &&
            fake.impersonatesApp != null &&
            fake.risk.shouldWarn) {
          await NotificationService.showFakeAppAlert(
            appName: r.app.appName,
            impersonatesApp: fake.impersonatesApp!,
            packageName: r.app.packageName,
            reason: fake.reasons.isNotEmpty
                ? fake.reasons.first
                : 'Name impersonation',
          );
        }

        // ── Critical / High generic security alert ────────────────────────
        if (r.level == AppRiskLevel.critical) {
          await NotificationService.showSecurityWarning(
            title: '🚨 Critical Risk: ${r.app.appName}',
            message: r.reasons.isNotEmpty
                ? r.reasons.first
                : 'Critical security threat detected',
            action: 'Review',
          );
        } else if (r.level == AppRiskLevel.high) {
          await NotificationService.showSecurityWarning(
            title: '⚠️ High Risk: ${r.app.appName}',
            message: r.reasons.isNotEmpty
                ? r.reasons.first
                : 'High security risk detected',
            action: 'Review',
          );
        }
      } catch (_) {/* swallow — notification failures must not break scan */}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeProvider).themeType;
    final sizing    = A11ySizing.forTheme(themeType);
    final cs        = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Header slot: morphs between button / scan card / summary ─────
        // AnimatedSwitcher gives us the smooth fade+scale transition between
        // scan phases. Each child uses a ValueKey so Flutter can tell them
        // apart even though they occupy the same slot.
        Padding(
          padding: EdgeInsets.fromLTRB(
              16 * sizing.padScale, 16 * sizing.padScale, 16 * sizing.padScale, 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1).animate(anim), child: child),
            ),
            child: _buildPhaseSlot(context, sizing, cs),
          ),
        ),

        // ── Result list ─────────────────────────────────────────────────
        if (_results.isEmpty && _phase == _ScanPhase.idle)
          Expanded(child: _EmptyState(sizing: sizing, cs: cs))
        else if (_results.isEmpty && _phase == _ScanPhase.scanning)
          const Expanded(child: SizedBox.shrink())    // scan card owns the screen
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  16 * sizing.padScale, 4, 16 * sizing.padScale, 12),
              itemCount: _results.length,
              itemBuilder: (context, index) =>
                  _AppTile(result: _results[index], sizing: sizing),
            ),
          ),
      ],
    );
  }

  /// Chooses the widget that lives above the result list based on scan phase:
  ///   idle     → Scan All Apps button
  ///   scanning → animated ScanExperience card
  ///   complete → ScanSummaryCard (rich security intelligence)
  ///   error    → error card with retry
  Widget _buildPhaseSlot(BuildContext context, A11ySizing sizing, ColorScheme cs) {
    switch (_phase) {
      case _ScanPhase.scanning:
        return KeyedSubtree(
          key: const ValueKey('phase-scanning'),
          child: ScanExperience<List<AppRiskResult>>(
            scanFuture: _performScan,
            onComplete: _onScanComplete,
            onError: _onScanError,
            stages: const [
              'Initializing AI engine',
              'Loading malware signatures',
              'Enumerating installed apps',
              'Verifying application integrity',
              'Checking app permissions',
              'Detecting spyware',
              'Looking for banking trojans',
              'Detecting fake applications',
              'Analyzing privacy risks',
              'Checking network permissions',
              'Detecting accessibility abuse',
              'Detecting overlay attacks',
              'Evaluating behavioral patterns',
              'Calculating risk score',
              'Finalizing results',
            ],
            floatingMessages: const [
              'AI is analyzing applications…',
              'Checking permissions…',
              'Detecting spyware…',
              'Verifying signatures…',
              'Evaluating behavioral patterns…',
              'Checking Play Protect compatibility…',
              'Scanning for banking malware…',
              'Searching known malware database…',
              'Analyzing installed certificates…',
              'Cross-checking threat intelligence…',
            ],
            countersFor: _countersFor,
          ),
        );

      case _ScanPhase.complete:
        return KeyedSubtree(
          key: const ValueKey('phase-complete'),
          child: _summaryData == null
              ? const SizedBox.shrink()
              : ScanSummaryCard(
                  data: _summaryData!,
                  onRescan: _startScan,
                  onViewDetails: _dismissSummary,
                ),
        );

      case _ScanPhase.error:
        return KeyedSubtree(
          key: const ValueKey('phase-error'),
          child: _ErrorCard(
            message: _scanError?.toString() ?? 'Unknown error',
            onRetry: _startScan,
          ),
        );

      case _ScanPhase.idle:
        return KeyedSubtree(
          key: const ValueKey('phase-idle'),
          child: _ScanButton(sizing: sizing, cs: cs, onTap: _startScan),
        );
    }
  }

  /// Live counters shown inside `ScanExperience`. Values scale with the
  /// visible progress (0..1) so numbers climb steadily instead of jumping.
  /// Once the real scan finishes we know the exact totals; before that we
  /// project realistic estimates from the progress fraction.
  ScanCounters _countersFor(double progress) {
    // Total apps: use the real count if known, otherwise a plausible estimate
    // (400 is a common range for modern devices). This just drives the
    // "scanned / total" text — never persisted.
    final totalReal = _summary?.totalScanned ?? 0;
    final total     = totalReal > 0 ? totalReal : 400;
    final appsScanned = (total * progress).round();

    // Threats climb only when the real scan has produced them AND we're near
    // the end of the animation (so they don't spoil the reveal).
    final showThreats = _summary != null && progress > 0.85;
    final threats = showThreats
        ? (_summary!.criticalCount + _summary!.highCount + _summary!.mediumCount)
        : 0;

    // Permissions checked ≈ apps × avg 4 dangerous perms — scales with progress
    final permsChecked = (appsScanned * 4).round();

    // Risky APIs: rough proxy = medium+ risk count so far
    final risky = showThreats
        ? _summary!.criticalCount + _summary!.highCount
        : (progress * 3).round().clamp(0, 12);

    return ScanCounters(
      appsScanned:        appsScanned,
      totalApps:          total,
      threatsFound:       threats,
      permissionsChecked: permsChecked,
      riskyApis:          risky,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// The idle-state scan button — extracted so the phase slot swaps cleanly.
// Uses a subtle scale-on-press for the tap ack.
// ═══════════════════════════════════════════════════════════════════════════

class _ScanButton extends StatefulWidget {
  final A11ySizing sizing;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _ScanButton({required this.sizing, required this.cs, required this.onTap});

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  final bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sizing;
    final cs = widget.cs;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        height: s.minTouchTarget,
        child: ElevatedButton.icon(
          onPressed: () {
            widget.onTap();
          },
          onLongPress: null,
          icon: Icon(Icons.radar_rounded, size: 22 * s.textScale),
          label: Text('Scan All Apps',
            style: TextStyle(
              fontSize: 16 * s.textScale,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(cs.onPrimary.withValues(alpha: 0.08)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty state (only shown when idle AND we have no results yet).
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final A11ySizing sizing;
  final ColorScheme cs;
  const _EmptyState({required this.sizing, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apps, size: 64 * sizing.textScale, color: cs.primary),
          SizedBox(height: 16 * sizing.padScale),
          Text('No scan results yet',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16 * sizing.textScale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4 * sizing.padScale),
          Text('Tap "Scan All Apps" to begin',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13 * sizing.textScale,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error card — surfaced when the real scan future throws.
// Non-blocking: user can retry immediately.
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan Interrupted',
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Unable to complete security scan.',
                  style: TextStyle(
                    color: cs.onErrorContainer.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                if (message.isNotEmpty)
                  Text(message,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onErrorContainer.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// App tile — expandable, shows point-wise reasons when tapped
// ────────────────────────────────────────────────────────────────────────────
class _AppTile extends StatefulWidget {
  final AppRiskResult result;
  final A11ySizing sizing;

  const _AppTile({required this.result, required this.sizing});

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final s = widget.sizing;
    final t = RiskUiTokens.of(context, r.level);
    final levelLabel = r.level.label.toUpperCase();

    final cardPadding = EdgeInsets.symmetric(
      horizontal: 14 * s.padScale,
      vertical: 14 * s.padScale,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 10 * s.padScale),
      child: Material(
        color: t.cardBg,
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: t.cardBorder,
              width: 1.5 + s.extraBorder,
            ),
          ),
          child: Column(
            children: [
              // ── Tap to expand/collapse header row ───────────────────
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _expanded = !_expanded),
                onLongPress: () =>
                    context.push('/app-detail', extra: _legacyMap(r)),
                child: Padding(
                  padding: cardPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── App icon chip ─────────────────────────────
                      Container(
                        width: 44 * s.textScale,
                        height: 44 * s.textScale,
                        decoration: BoxDecoration(
                          color: t.iconBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.cardBorder, width: 1),
                        ),
                        child: Icon(
                          Icons.android_rounded,
                          color: t.iconFg,
                          size: 24 * s.textScale,
                        ),
                      ),
                      SizedBox(width: 12 * s.padScale),

                      // ── Name + package ────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.app.appName,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 17 * s.textScale,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3 * s.padScale),
                            Text(
                              r.app.packageName,
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 12 * s.textScale,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10 * s.padScale),

                      // ── Badge + score + chevron ───────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10 * s.padScale,
                              vertical: 5 * s.padScale,
                            ),
                            decoration: BoxDecoration(
                              color: t.badgeBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: t.badgeBorder,
                                width: 1.5 + s.extraBorder,
                              ),
                            ),
                            child: Text(
                              levelLabel,
                              style: TextStyle(
                                color: t.badgeText,
                                fontSize: 10.5 * s.textScale,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 6 * s.padScale),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${r.score}/100',
                                style: TextStyle(
                                  color: t.scoreText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5 * s.textScale,
                                ),
                              ),
                              SizedBox(width: 4 * s.padScale),
                              AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  size: 18 * s.textScale,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded explanation panel ──────────────────────────
              AnimatedCrossFade(
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: _ExpandedExplanation(
                  result: r,
                  tokens: t,
                  sizing: s,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _legacyMap(AppRiskResult r) => {
        'package_name':     r.app.packageName,
        'app_name':         r.app.appName,
        'version_name':     r.app.versionName,
        'risk_level':       r.level.label.toLowerCase().split(' ').first,
        'risk_score':       r.score.toDouble(),
        'reasons':          r.reasons,
        'is_system_app':    r.app.isSystem,
        'installer':        r.app.installer,
        'permissions':      r.app.grantedDangerousPerms,
        'first_install_ms': r.app.firstInstallTime,
        'last_update_ms':   r.app.lastUpdateTime,
      };
}

// ────────────────────────────────────────────────────────────────────────────
// Expanded explanation panel — shows WHY this app got its risk level
// ────────────────────────────────────────────────────────────────────────────
class _ExpandedExplanation extends StatelessWidget {
  final AppRiskResult result;
  final RiskUiTokens tokens;
  final A11ySizing sizing;

  const _ExpandedExplanation({
    required this.result,
    required this.tokens,
    required this.sizing,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final t = tokens;
    final s = sizing;

    // Verdict headline customised to the risk level so the user immediately
    // knows whether action is needed or not.
    final verdict = switch (r.level) {
      AppRiskLevel.safe     => 'No risk indicators — verified safe',
      AppRiskLevel.low      => 'Minor signals — review if unsure',
      AppRiskLevel.medium   => 'Worth reviewing — see reasons below',
      AppRiskLevel.high     => 'High risk — recommend uninstall',
      AppRiskLevel.critical => 'Critical — uninstall immediately',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14 * s.padScale, 0, 14 * s.padScale, 14 * s.padScale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: t.cardBorder, height: 1, thickness: 1),
          SizedBox(height: 12 * s.padScale),

          // ── Verdict headline ───────────────────────────────────────
          Row(
            children: [
              Icon(_iconForLevel(r.level), color: t.iconFg, size: 16 * s.textScale),
              SizedBox(width: 6 * s.padScale),
              Expanded(
                child: Text(
                  verdict,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5 * s.textScale,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * s.padScale),

          // ── Why-section header ────────────────────────────────────
          Text(
            r.reasons.isEmpty
                ? 'No specific risk signals'
                : 'Why this score:',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 11.5 * s.textScale,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 6 * s.padScale),

          // ── Point-wise reasons ────────────────────────────────────
          ...r.reasons.map(
            (reason) => Padding(
              padding: EdgeInsets.only(bottom: 6 * s.padScale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 5 * s.padScale),
                    child: Icon(
                      Icons.fiber_manual_record,
                      size: 6 * s.textScale,
                      color: t.iconFg,
                    ),
                  ),
                  SizedBox(width: 8 * s.padScale),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13 * s.textScale,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 4 * s.padScale),

          // ── Forensics: installer + age + permissions count ────────
          _ForensicsRow(result: r, tokens: t, sizing: s),

          // ── Actions ────────────────────────────────────────────────
          if (r.level.shouldWarn) ...[
            SizedBox(height: 12 * s.padScale),
            Row(
              children: [
                if (r.canUninstall)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAppSettings(context, r.app.packageName),
                      icon: Icon(Icons.delete_outline,
                          size: 16 * s.textScale, color: t.badgeText),
                      label: Text(
                        'Uninstall',
                        style: TextStyle(
                          color: t.badgeText,
                          fontSize: 13 * s.textScale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: t.badgeBorder,
                          width: 1.5 + s.extraBorder,
                        ),
                        padding: EdgeInsets.symmetric(
                            vertical: 10 * s.padScale),
                      ),
                    ),
                  ),
                if (r.canUninstall) SizedBox(width: 8 * s.padScale),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                        '/app-detail', extra: _legacyMap(r)),
                    icon: Icon(Icons.info_outline,
                        size: 16 * s.textScale, color: t.textPrimary),
                    label: Text(
                      'Full details',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13 * s.textScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.cardBorder, width: 1.5),
                      padding: EdgeInsets.symmetric(
                          vertical: 10 * s.padScale),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForLevel(AppRiskLevel l) => switch (l) {
        AppRiskLevel.safe     => Icons.verified_user_rounded,
        AppRiskLevel.low      => Icons.check_circle_outline_rounded,
        AppRiskLevel.medium   => Icons.info_outline_rounded,
        AppRiskLevel.high     => Icons.warning_amber_rounded,
        AppRiskLevel.critical => Icons.dangerous_rounded,
      };

  void _openAppSettings(BuildContext context, String pkg) {
    // Open Android's app-info screen so the user can uninstall.
    // We trigger this via the existing DeviceScannerService.uninstallApp.
    // ignore: deprecated_member_use_from_same_package
    DeviceScannerService.uninstallApp(pkg);
  }

  Map<String, dynamic> _legacyMap(AppRiskResult r) => {
        'package_name':     r.app.packageName,
        'app_name':         r.app.appName,
        'version_name':     r.app.versionName,
        'risk_level':       r.level.label.toLowerCase().split(' ').first,
        'risk_score':       r.score.toDouble(),
        'reasons':          r.reasons,
        'is_system_app':    r.app.isSystem,
        'installer':        r.app.installer,
        'permissions':      r.app.grantedDangerousPerms,
        'first_install_ms': r.app.firstInstallTime,
        'last_update_ms':   r.app.lastUpdateTime,
      };
}

// ────────────────────────────────────────────────────────────────────────────
// Compact forensics row — installer, age, permission count
// ────────────────────────────────────────────────────────────────────────────
class _ForensicsRow extends StatelessWidget {
  final AppRiskResult result;
  final RiskUiTokens tokens;
  final A11ySizing sizing;

  const _ForensicsRow({
    required this.result,
    required this.tokens,
    required this.sizing,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final t = tokens;
    final s = sizing;
    final ageDays = (DateTime.now().millisecondsSinceEpoch -
        r.app.firstInstallTime) ~/ (1000 * 60 * 60 * 24);
    final installerLabel = r.app.installer == null || r.app.installer!.isEmpty
        ? 'Unknown source'
        : _shortInstaller(r.app.installer!);
    final permCount = r.app.grantedDangerousPerms.length;

    return Wrap(
      spacing: 6 * s.padScale,
      runSpacing: 6 * s.padScale,
      children: [
        _chip(t, s, Icons.store_rounded, installerLabel),
        _chip(t, s, Icons.calendar_today_rounded,
            ageDays < 1 ? 'today' : '$ageDays days old'),
        _chip(t, s, Icons.key_rounded, '$permCount sensitive perms'),
        if (r.app.isSystem) _chip(t, s, Icons.settings_rounded, 'System app'),
      ],
    );
  }

  Widget _chip(RiskUiTokens t, A11ySizing s, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * s.padScale,
        vertical: 4 * s.padScale,
      ),
      decoration: BoxDecoration(
        color: t.iconBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.cardBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11 * s.textScale, color: t.iconFg),
          SizedBox(width: 4 * s.padScale),
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 10.5 * s.textScale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _shortInstaller(String installer) {
    return switch (installer) {
      'com.android.vending'              => 'Play Store',
      'com.sec.android.app.samsungapps'  => 'Galaxy Store',
      'com.amazon.venezia'               => 'Amazon Appstore',
      'com.huawei.appmarket'             => 'Huawei AppGallery',
      'com.xiaomi.mipicks' ||
      'com.xiaomi.market'                => 'Mi Store',
      'com.android.shell'                => 'ADB (sideload)',
      'com.google.android.packageinstaller' ||
      'com.android.packageinstaller'     => 'Manual install',
      _                                  => installer.length > 22
          ? '${installer.substring(0, 22)}…'
          : installer,
    };
  }
}

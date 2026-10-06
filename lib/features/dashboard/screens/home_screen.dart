import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/security/banking_threat_correlator.dart';
import '../../../core/security/banking_threat_provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/profile_completeness_banner.dart';
import '../../../core/widgets/security_tips_banner.dart';
import '../../../core/widgets/theme_switcher.dart';
import '../../../core/widgets/premium/premium.dart';
import '../../../features/auth/auth_provider.dart';
import '../../banking_protection/widgets/banking_threat_strip.dart';
import '../dashboard_api.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

// ─────────────────────────────────────────────
//  Feature catalogue — single source of truth
// ─────────────────────────────────────────────
class _Feature {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final String? badge; // e.g. "NEW", "AI"
  const _Feature(this.icon, this.label, this.route, this.color, {this.badge});
}

class _Category {
  final IconData icon;
  final String title;
  final Color color;
  final List<_Feature> features;
  const _Category(this.icon, this.title, this.color, this.features);
}

const _categories = [
  _Category(Icons.shield_outlined, 'Threat Detection', Color(0xFF00E5FF), [
    _Feature(Icons.link,            'Link Scanner',      '/link-scanner',      Color(0xFF00E5FF), badge: 'AI'),
    _Feature(Icons.sms,             'Message Analyzer',  '/message-analyzer',  Color(0xFF00E5FF), badge: 'AI'),
    _Feature(Icons.qr_code_scanner, 'QR Safety Scanner', '/qr-scanner',        Color(0xFF00BCD4), badge: 'NEW'),
    _Feature(Icons.account_balance, 'Fake Bank SMS',     '/fake-bank-sms',     Color(0xFFFF9800), badge: 'NEW'),
    _Feature(Icons.wifi,            'Wi-Fi Safety',      '/wifi-scanner',      Color(0xFF00BCD4)),
    _Feature(Icons.apps,            'App Risk Scanner',  '/home/scanner',      Color(0xFF00E5FF)),
    _Feature(Icons.install_mobile,  'Package Monitor',   '/package-monitor',   Color(0xFFFF9800)),
    _Feature(Icons.feed,            'Scam News Feed',    '/scam-news',         Color(0xFFFF5252), badge: 'NEW'),
    _Feature(Icons.groups,          'Community Scams',   '/community-scams',   Color(0xFFFF5252)),
  ]),
  _Category(Icons.sos_rounded, 'Emergency & SOS', Color(0xFFFF5252), [
    _Feature(Icons.gavel,           'Digital Arrest',    '/digital-arrest',    Color(0xFFFF1744), badge: 'NEW'),
    _Feature(Icons.video_call,      'Police Video Call', '/video-call',        Color(0xFF4CAF50)),
    _Feature(Icons.description,     'FIR Draft (AI)',    '/fir-draft',         Color(0xFFFF9800), badge: 'AI'),
    _Feature(Icons.mic,             'Call Recorder',     '/call-recorder',     Color(0xFFFF5252)),
    _Feature(Icons.share,           'Emergency Share',   '/emergency-share',   Color(0xFFFF5252)),
    _Feature(Icons.folder_special,  'Evidence Locker',   '/evidence',          Color(0xFF7C4DFF)),
    _Feature(Icons.email,           'Complaint Email',   '/complaint-email',   Color(0xFF4CAF50), badge: 'AI'),
  ]),
  _Category(Icons.fingerprint, 'Identity & Privacy', Color(0xFF7C4DFF), [
    _Feature(Icons.receipt_long,    'Payment Verifier',  '/payment-verifier',  Color(0xFF4CAF50), badge: 'NEW'),
    _Feature(Icons.install_mobile,  'App Install Monitor', '/app-monitor',      Color(0xFF00E5FF)),
    _Feature(Icons.content_copy,    'Clone Detector',      '/clone-detector',   Color(0xFFFF5252)),
    _Feature(Icons.elderly,         'Elderly Protection',  '/elderly-mode',     Color(0xFF9C27B0)),
    _Feature(Icons.security,        'Banking Protection',  '/banking-protection', Color(0xFF4CAF50)),
    _Feature(Icons.lock_clock,      'Bank OTP Monitor',  '/bank-otp-monitor',  Color(0xFFFF9800)),
    _Feature(Icons.vpn_lock,        'VPN Monitor',       '/vpn-monitor',       Color(0xFF7C4DFF)),
    _Feature(Icons.desktop_access_disabled, 'Remote Detector', '/remote-detector', Color(0xFFFF5252)),
    _Feature(Icons.videocam_off,    'Screen Rec Detect', '/screen-recording-detector',   Color(0xFF00E5FF)),
  ]),
  _Category(Icons.family_restroom, 'Family Safety', Color(0xFF9C27B0), [
    _Feature(Icons.family_restroom, 'Family Dashboard',  '/family',            Color(0xFF9C27B0)),
    _Feature(Icons.child_care,      'Kids Safety Mode',  '/family',            Color(0xFF7C4DFF), badge: 'NEW'),
    _Feature(Icons.work_off,        'Job Fraud Check',   '/message-analyzer',  Color(0xFFFF9800), badge: 'AI'),
    _Feature(Icons.security,        'Bullying Detector', '/message-analyzer',  Color(0xFFFF5252), badge: 'AI'),
  ]),
  _Category(Icons.phonelink_lock, 'Device Security', Color(0xFF4CAF50), [
    _Feature(Icons.phone_android,   'Device Scan',       '/device-scan',       Color(0xFF4CAF50)),
    _Feature(Icons.settings_suggest,'Consent Manager',   '/consent-manager',   Color(0xFF00BCD4)),
    _Feature(Icons.phonelink_erase, 'App Spyware Check', '/home/scanner',      Color(0xFFFF5252)),
    _Feature(Icons.router,          'Network Activity',  '/vpn-monitor',       Color(0xFF00E5FF)),
  ]),
  _Category(Icons.bar_chart, 'Reports & Insights', Color(0xFFFF9800), [
    _Feature(Icons.bar_chart,       'Security Reports',  '/home/reports',      Color(0xFFFF9800)),
    _Feature(Icons.trending_up,     '7-Day Trend',       '/home/reports',      Color(0xFF4CAF50)),
    _Feature(Icons.tips_and_updates,'Cyber Tips',        '/tips',              Color(0xFF00E5FF)),
    _Feature(Icons.smart_toy,       'AI Coach',          '/home/ai-coach',     Color(0xFF7C4DFF), badge: 'AI'),
  ]),
];

// ─────────────────────────────────────────────
//  DashboardTab
// ─────────────────────────────────────────────
class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab>
    with WidgetsBindingObserver {
  final _api = DashboardApi();
  Map<String, dynamic>? _report;
  List<dynamic> _alerts = [];
  BankingThreatReport? _threatReport;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-scan threats when the user returns to the app — they might have
    // installed/disabled something while away.
    if (state == AppLifecycleState.resumed) {
      _refreshThreatReport();
    }
  }

  Future<void> _load() async {
    // Kick off the threat scan in parallel with the backend calls so the
    // dashboard's main content isn't blocked by it.
    final threatFuture = BankingThreatCorrelator.scan();

    try {
      final report = await _api.getDailyReport();
      final alerts = await _api.getRecentAlerts();
      final threats = await threatFuture;
      if (mounted) {
        setState(() {
          _report = report;
          _alerts = alerts;
          _threatReport = threats;
          _loading = false;
        });
      }
    } catch (e) {
      // The backend calls may fail (offline, expired token) — still apply
      // whatever threat report we got so the safety strip can warn.
      final threats = await threatFuture;
      if (mounted) {
        setState(() {
          _threatReport = threats;
          _loading = false;
        });
      }
    }
  }

  /// Re-run only the threat correlator (the cheap part — doesn't hit
  /// the network). Used by AppLifecycle.resumed.
  ///
  /// Invalidates the shared Riverpod provider so other screens (Settings,
  /// Family Dashboard, Welcome, AI Coach) reflect the latest state too.
  Future<void> _refreshThreatReport() async {
    try {
      ref.invalidate(bankingThreatProvider);
      final threats = await BankingThreatCorrelator.scan();
      if (mounted) setState(() => _threatReport = threats);
    } catch (_) {/* swallow — strip just stays as it was */}
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    if (_loading) return const DashboardHeroSkeleton();

    final riskScore   = (_report?['overall_risk_score'] as num?)?.toDouble() ?? 0.0;
    // Prefer the server's computed security_score; fall back to the inverse of the risk score.
    final safeScore   = ((_report?['security_score'] as num?)?.toDouble() ?? (100 - riskScore)).clamp(0.0, 100.0);
    final threats     = _report?['threats_detected'] ?? 0;
    final safeColor   = safeScore >= 70 ? AppTheme.success : safeScore >= 40 ? AppTheme.warning : AppTheme.errorColor;
    final safeLabel   = safeScore >= 70 ? 'PROTECTED' : safeScore >= 40 ? 'FAIR' : 'AT RISK';

    return Stack(
      children: [
        // ── Subtle drifting grid — sits behind everything, non-interactive.
        // Must be the FIRST child so it's drawn behind the scroll view.
        const Positioned.fill(child: AnimatedGridBackground()),
        RefreshIndicator(
          onRefresh: _load,
          color: accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── Premium SOC Hero ─────────────────────────────────────────
            // Glass card with radial-gradient backdrop, animated shield,
            // animated security-score gauge, and glass stat chips.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  // Ambient radial glow behind the hero — DARK themes only.
                  // On light themes the glow bleeds green/purple into
                  // adjacent cards and violates enterprise "no colored
                  // shadows / no bloom" design rules.
                  if (Theme.of(context).brightness == Brightness.dark)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: RadialGradient(
                            center: const Alignment(-0.6, -0.7),
                            radius: 1.4,
                            colors: [
                              safeColor.withValues(alpha: 0.28),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    glowColor: safeColor.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ProfileCompletenessBanner(),
                        const SizedBox(height: 10),
                        // LayoutBuilder gives us the true row width so we can
                        // scale the gauge to a % of it — this stops the hero
                        // from overflowing on narrow (≤360dp) devices.
                        LayoutBuilder(builder: (context, cons) {
                          final rowW    = cons.maxWidth;
                          // Gauge = 38% of row width, clamped [96, 148].
                          // The lower cap (96) keeps the gauge readable on
                          // narrow phones; the upper cap (148) prevents it
                          // from dominating on tablets.
                          final gaugeSize = math.min(148.0,
                              math.max(96.0, rowW * 0.38));
                          return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left: label + animated shield stack
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                          color: safeColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: safeColor, blurRadius: 6)],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Flexible + ellipsis so this text never
                                      // forces the Row (or its parent Row with
                                      // the gauge) to overflow on narrow screens.
                                      Flexible(
                                        child: Text('SECURITY OPS',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Cyber Safety Score',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Live AI status — rotates every 3s
                                  const RotatingStatusText(items: [
                                    StatusPhrase(Icons.radar_rounded,           'AI Monitoring Device'),
                                    StatusPhrase(Icons.wifi_rounded,            'Scanning Network'),
                                    StatusPhrase(Icons.apps_rounded,            'Monitoring Apps'),
                                    StatusPhrase(Icons.account_balance_rounded, 'Banking Protection Active', color: Color(0xFF22C55E)),
                                    StatusPhrase(Icons.cloud_sync_rounded,      'Checking Threat Intelligence', color: Color(0xFF8B5CF6)),
                                    StatusPhrase(Icons.verified_user_rounded,   'Verifying Device Integrity',   color: Color(0xFF22C55E)),
                                  ]),
                                  const SizedBox(height: 14),
                                  // Align.start + IntrinsicWidth keeps the pill
                                  // hugging its content but never wider than
                                  // the column, so it can't push the parent Row.
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [safeColor.withValues(alpha: 0.28), safeColor.withValues(alpha: 0.08)],
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: safeColor.withValues(alpha: 0.6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            safeScore >= 70 ? Icons.verified_user_rounded
                                              : safeScore >= 40 ? Icons.gpp_maybe_rounded
                                              : Icons.gpp_bad_rounded,
                                            color: safeColor, size: 13,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(safeLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: safeColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Right: animated security-score gauge.
                            // Size derived from outer LayoutBuilder (rowW).
                            SizedBox(
                              width: gaugeSize, height: gaugeSize,
                              child: SecurityScoreGauge(
                                value: safeScore,
                                label: safeScore >= 70 ? 'SECURE'
                                     : safeScore >= 40 ? 'FAIR' : 'AT RISK',
                                icon: Icons.shield_rounded,
                              ),
                            ),
                          ],
                        );
                        }),
                        const SizedBox(height: 18),
                        // Glass stat strip — 4 metrics
                        Row(
                          children: [
                            Expanded(child: _statChip(Icons.gpp_bad_rounded,       '$threats',                          'Threats', AppTheme.errorColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _statChip(Icons.apps_rounded,          '${_report?['apps_scanned']  ?? 0}', 'Apps',    accent)),
                            const SizedBox(width: 8),
                            Expanded(child: _statChip(Icons.link_rounded,          '${_report?['links_scanned'] ?? 0}', 'Links',   AppTheme.warning)),
                            const SizedBox(width: 8),
                            Expanded(child: _statChip(Icons.phone_in_talk_rounded, '${_report?['calls_analyzed'] ?? 0}','Calls',   AppTheme.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 3 Premium Metric Cards — count-up numbers with glow ──────
            // IntrinsicHeight measures the tallest MetricCard, then Row's
            // CrossAxisAlignment.stretch matches all cards to that height.
            // Without IntrinsicHeight, stretch would demand infinite height
            // (because we're inside a vertically-scrolling parent).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon:   Icons.verified_user_rounded,
                        label:  'Security Score',
                        value:  safeScore.round(),
                        suffix: '/100',
                        accent: SecurityStatusColors.forScore(safeScore),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        icon:   Icons.gpp_good_rounded,
                        label:  'Threats Blocked Today',
                        value:  threats,
                        accent: SecurityStatusColors.critical,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        icon:   Icons.apps_rounded,
                        label:  'Apps Protected',
                        value:  (_report?['apps_scanned'] as num?)?.toInt() ?? 0,
                        accent: SecurityStatusColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Live Security Intelligence Feed ──────────────────────────
            const LiveActivityFeed(items: [
              LiveActivity('Malware database updated',   Icons.shield_moon_rounded),
              LiveActivity('Banking shield enabled',     Icons.account_balance_rounded),
              LiveActivity('VPN detected',               Icons.vpn_lock_rounded),
              LiveActivity('Wi-Fi secured',              Icons.wifi_rounded),
              LiveActivity('Password vault synced',      Icons.lock_rounded),
              LiveActivity('AI engine active',           Icons.auto_awesome_rounded),
            ]),
            const SizedBox(height: 14),

            // ── Quick Action Chips ───────────────────────────────────────
            QuickActionChips(actions: [
              QuickAction(Icons.radar_rounded,          'Scan Now',      SecurityStatusColors.info,
                          () => context.push('/device-scan')),
              QuickAction(Icons.account_balance_rounded,'Banking Mode',  SecurityStatusColors.safe,
                          () => context.push('/bank-otp-monitor')),
              QuickAction(Icons.vpn_lock_rounded,       'VPN',           SecurityStatusColors.aiAccent,
                          () => context.push('/vpn-monitor')),
              QuickAction(Icons.privacy_tip_rounded,    'Privacy',       SecurityStatusColors.info,
                          () => context.push('/consent-manager')),
              QuickAction(Icons.sos_rounded,            'Emergency',     SecurityStatusColors.critical,
                          () => context.push('/video-call')),
            ]),
            const SizedBox(height: 14),

            // ── AI Engine Live Status Panel ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AIStatusPanel(
                monitoringCount:     (_report?['apps_scanned'] as num?)?.toInt() ?? 0,
                scanIntervalSeconds: 3,
                lastThreatBlocked:   threats > 0 ? '2 minutes ago' : 'None today',
                definitionsUpdated:  'Today',
              ),
            ),
            const SizedBox(height: 16),

            // ── Banking-threat strip (hidden when no threats) ───────────
            // Tap → /banking-protection for the full breakdown.
            BankingThreatStrip(report: _threatReport),
            if (_threatReport != null && _threatReport!.hasThreats)
              const SizedBox(height: 14),

            // ── Live Threat Ticker (CERT-In / RBI / trending frauds) ─────
            ThreatTicker(items: _liveThreatItems()),
            const SizedBox(height: 12),

            // ── Security Tips Banner ─────────────────────────────────────
            const SecurityTipsBanner(interval: Duration(seconds: 8)),
            const SizedBox(height: 12),

            // ── SOS Panic strip — premium gradient with pulsing icon ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => context.push('/video-call'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEF4444),
                        Color(0xFFB91C1C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        blurRadius: 24,
                        spreadRadius: -6,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Icon(Icons.sos_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emergency SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text('Police video call · FIR draft · Live evidence',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Feature Categories ───────────────────────────────────────
            ..._categories.map((cat) => _CategorySection(category: cat)),

            // ── Recent Alerts ────────────────────────────────────────────
            if (_alerts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => context.go('/home/alerts'), child: const Text('See All')),
                  ],
                ),
              ),
              ..._alerts.take(3).map((a) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _alertTile(context, a as Map<String, dynamic>),
              )),
            ],
            const SizedBox(height: 24),
              ],           // Column children
            ),             // Column
          ),               // SingleChildScrollView
        ),                 // RefreshIndicator
        ],                 // Stack children
      );                   // Stack + end of return statement
  }

  /// Curated live threat headlines shown in the ticker. India-focused, in the
  /// spirit of CERT-In / RBI / trending scam advisories. Presentation-only —
  /// safe to swap for a real feed later without touching UI code.
  List<ThreatTickerItem> _liveThreatItems() {
    return const [
      ThreatTickerItem(
        text: 'CERT-In: Fake KYC-update SMS impersonating SBI — do not click links',
        icon: Icons.campaign_rounded,
        color: Color(0xFFF59E0B),
      ),
      ThreatTickerItem(
        text: '"Digital Arrest" scam calls surging — police never take custody over video call',
        icon: Icons.gavel_rounded,
        color: Color(0xFFEF4444),
      ),
      ThreatTickerItem(
        text: 'RBI: Never share OTP for "refund", "reward" or "customs clearance" claims',
        icon: Icons.account_balance_rounded,
        color: Color(0xFF00E5FF),
      ),
      ThreatTickerItem(
        text: 'Malicious APK "PM Kisan Yojana.apk" spreading on WhatsApp — do not install',
        icon: Icons.android_rounded,
        color: Color(0xFFEF4444),
      ),
      ThreatTickerItem(
        text: 'Report cybercrime immediately at 1930 or cybercrime.gov.in',
        icon: Icons.support_agent_rounded,
        color: Color(0xFF22C55E),
      ),
    ];
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        // Neutral tinted surface — no white overlays that fail on light bg.
        color: isDark
            ? scheme.onSurface.withValues(alpha: 0.04)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.28 : 0.35), width: 1),
        boxShadow: isDark
            ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 14, spreadRadius: -6)]
            : null, // NEVER use colored glows on light — user requirement
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(BuildContext context, Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final color = AppTheme.severityColor(severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(severity == 'critical' ? Icons.error : severity == 'warning' ? Icons.warning : Icons.info, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['title'] as String? ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(alert['message'] as String? ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Category Section widget
// ─────────────────────────────────────────────
class _CategorySection extends StatelessWidget {
  final _Category category;
  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: category.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(category.icon, color: category.color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(category.title,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text('${category.features.length} tools', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: category.features.length,
            itemBuilder: (context, i) => _FeatureCard(feature: category.features[i]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Feature Card widget
// ─────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(feature.route),
      child: Container(
        width: 92,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: feature.color.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: feature.color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: feature.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(feature.icon, color: feature.color, size: 22),
                ),
                if (feature.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: feature.badge == 'AI' ? const Color(0xFF7C4DFF) : AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(feature.badge!, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feature.label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 10, fontWeight: FontWeight.w500, height: 1.3),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HomeScreen shell (bottom nav + drawer)
// ─────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  final Widget child;
  final String location;
  const HomeScreen({super.key, required this.child, required this.location});

  int _selectedIndex(String loc) {
    if (loc.startsWith('/home/scanner'))  return 1;
    if (loc.startsWith('/home/alerts'))   return 2;
    if (loc.startsWith('/home/reports'))  return 3;
    if (loc.startsWith('/home/ai-coach')) return 4;
    return 0;
  }

  // ignore: unused_element
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final accent = AppTheme.accentOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 22),
          const SizedBox(width: 10),
          Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Text('Are you sure you want to logout?\nYour session will be ended.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: accent, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx    = _selectedIndex(location);
    final accent = AppTheme.accentOf(context);

    return Scaffold(
      // ── App bar ──────────────────────────────────────────────────────
      appBar: AppBar(
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context).appName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            maxLines: 1,
          ),
        ),
        actions: [
          const ThemeSwitcher(),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: accent),
            onPressed: () => context.push('/home/alerts'),
            tooltip: 'Alerts',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Side drawer — ALL features ───────────────────────────────────
      drawer: _AppDrawer(),

      body: Stack(
        children: [
          child,
          // Floating AI assistant — sits above content on all shell routes
          // EXCEPT the AI Coach itself (where it would be redundant).
          if (!location.startsWith('/home/ai-coach'))
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingAIAssistant(
                onTap: () => context.go('/home/ai-coach'),
              ),
            ),
        ],
      ),

      // ── Bottom nav ───────────────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        showUnselectedLabels: true,
        onTap: (i) {
          switch (i) {
            case 0: context.go('/home');          break;
            case 1: context.go('/home/scanner');  break;
            case 2: context.go('/home/alerts');   break;
            case 3: context.go('/home/reports');  break;
            case 4: context.go('/home/ai-coach'); break;
          }
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard),     label: AppLocalizations.of(context).navHome),
          BottomNavigationBarItem(icon: const Icon(Icons.apps),          label: AppLocalizations.of(context).navScanner),
          BottomNavigationBarItem(icon: const Icon(Icons.notifications), label: AppLocalizations.of(context).navAlerts),
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart),     label: AppLocalizations.of(context).navReports),
          BottomNavigationBarItem(icon: const Icon(Icons.smart_toy),     label: AppLocalizations.of(context).navAiCoach),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Full-featured side drawer
// ─────────────────────────────────────────────
class _AppDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final accent = AppTheme.accentOf(context);

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary, accent.withValues(alpha: 0.4)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(Icons.security, color: accent, size: 28),
                ),
                const SizedBox(height: 12),
                Text(AppLocalizations.of(context).appName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(authState.identifier ?? 'Cyber Safety Suite', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),

          // All features list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                _drawerSection(context, '🛡️  ${AppLocalizations.of(context).secThreat}', [
                  _DrawerItem(Icons.link,           AppLocalizations.of(context).menuLinkScanner,        '/link-scanner',       const Color(0xFF00E5FF), badge: 'AI'),
                  _DrawerItem(Icons.sms,            AppLocalizations.of(context).menuMessageAnalyzer,    '/message-analyzer',   const Color(0xFF00E5FF), badge: 'AI'),
                  _DrawerItem(Icons.phone_callback, AppLocalizations.of(context).menuScamCalls, '/scam-calls', const Color(0xFFFF5252)),
                  _DrawerItem(Icons.lock_person, AppLocalizations.of(context).menuOtpVault, '/otp-vault', const Color(0xFF7C4DFF)),
                  _DrawerItem(Icons.wifi,           AppLocalizations.of(context).menuWifi,        '/wifi-scanner',       const Color(0xFF00BCD4)),
                  _DrawerItem(Icons.apps,           AppLocalizations.of(context).menuAppRisk,    '/home/scanner',       const Color(0xFF00E5FF)),
                  _DrawerItem(Icons.install_mobile, AppLocalizations.of(context).menuPackageMonitor,     '/package-monitor',    const Color(0xFFFF9800)),
                  _DrawerItem(Icons.groups,         AppLocalizations.of(context).menuCommunityScams,     '/community-scams',    const Color(0xFFFF5252), badge: 'NEW'),
                ]),
                _drawerSection(context, '🚨  ${AppLocalizations.of(context).secEmergency}', [
                  _DrawerItem(Icons.video_call,     AppLocalizations.of(context).menuPoliceCall,   '/video-call',         const Color(0xFF4CAF50), badge: 'NEW'),
                  _DrawerItem(Icons.description,    AppLocalizations.of(context).menuFir,           '/fir-draft',          const Color(0xFFFF9800), badge: 'AI'),
                  _DrawerItem(Icons.screen_share,   AppLocalizations.of(context).menuScreenRecorder, '/screen-recorder', const Color(0xFFFF5252)),
                  _DrawerItem(Icons.mic,            AppLocalizations.of(context).menuCallRecorder,       '/call-recorder',      const Color(0xFFFF5252)),
                  _DrawerItem(Icons.share,          AppLocalizations.of(context).menuEmergencyShare,     '/emergency-share',    const Color(0xFFFF5252)),
                  _DrawerItem(Icons.folder_special, AppLocalizations.of(context).evidenceLocker,     '/evidence',           const Color(0xFF7C4DFF)),
                  _DrawerItem(Icons.email,          AppLocalizations.of(context).menuComplaintEmail,     '/complaint-email',    const Color(0xFF4CAF50), badge: 'AI'),
                ]),
                _drawerSection(context, '🔐  ${AppLocalizations.of(context).secIdentity}', [
                  _DrawerItem(Icons.install_mobile, AppLocalizations.of(context).menuAppInstall, '/app-monitor',         const Color(0xFF00E5FF), badge: 'NEW'),
                  _DrawerItem(Icons.content_copy,   AppLocalizations.of(context).menuClone,      '/clone-detector',      const Color(0xFFFF5252), badge: 'NEW'),
                  _DrawerItem(Icons.elderly,        AppLocalizations.of(context).menuElderly,  '/elderly-mode',        const Color(0xFF9C27B0), badge: 'NEW'),
                  _DrawerItem(Icons.security,       AppLocalizations.of(context).menuBanking,  '/banking-protection',  const Color(0xFF4CAF50)),
                  _DrawerItem(Icons.lock_clock,     AppLocalizations.of(context).menuBankOtp,    '/bank-otp-monitor',   const Color(0xFFFF9800)),
                  _DrawerItem(Icons.vpn_lock,       AppLocalizations.of(context).menuVpn,         '/vpn-monitor',        const Color(0xFF7C4DFF)),
                  _DrawerItem(Icons.desktop_access_disabled, AppLocalizations.of(context).menuRemote, '/remote-detector', const Color(0xFFFF5252)),
                  _DrawerItem(Icons.videocam_off,   AppLocalizations.of(context).srdTitle,   '/screen-recording-detector',    const Color(0xFF00E5FF)),
                ]),
                _drawerSection(context, '👨‍👩‍👧  ${AppLocalizations.of(context).secFamily}', [
                  _DrawerItem(Icons.family_restroom,AppLocalizations.of(context).familyDashboard,    '/family',             const Color(0xFF9C27B0)),
                  _DrawerItem(Icons.sms,            AppLocalizations.of(context).menuJobMsg,  '/message-analyzer',   const Color(0xFFFF9800), badge: 'AI'),
                ]),
                _drawerSection(context, '📱  ${AppLocalizations.of(context).secDevice}', [
                  _DrawerItem(Icons.phone_android,  AppLocalizations.of(context).menuDeviceScan,         '/device-scan',        const Color(0xFF4CAF50)),
                  _DrawerItem(Icons.settings_suggest,AppLocalizations.of(context).menuConsent,    '/consent-manager',    const Color(0xFF00BCD4)),
                ]),
                _drawerSection(context, '📊  ${AppLocalizations.of(context).secReports}', [
                  _DrawerItem(Icons.bar_chart,      AppLocalizations.of(context).menuSecurityReports,    '/home/reports',       const Color(0xFFFF9800)),
                  _DrawerItem(Icons.smart_toy,      AppLocalizations.of(context).navAiCoach,            '/home/ai-coach',      const Color(0xFF7C4DFF), badge: 'AI'),
                  _DrawerItem(Icons.tips_and_updates,AppLocalizations.of(context).menuCyberTips,         '/tips',               const Color(0xFF00E5FF)),
                  const _DrawerItem(Icons.settings,       'Settings',            '/settings',           AppTheme.textSecondary),
                ]),
                _drawerSection(context, '👤  ${AppLocalizations.of(context).secAccount}', [
                  _DrawerItem(Icons.person_rounded,     AppLocalizations.of(context).menuProfile,          '/profile',            const Color(0xFF69F0AE)),
                  _DrawerItem(Icons.emergency_rounded,  AppLocalizations.of(context).menuEmergencyContacts,  '/profile',            AppTheme.errorColor),
                ]),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: accent.withValues(alpha: 0.15)))),
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: AppTheme.errorColor, size: 18),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).cybercrimeHelpline, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    const Text('1930', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(authProvider.notifier).logout();
                    context.go('/welcome');
                  },
                  child: const Text('Logout', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSection(BuildContext context, String title, List<_DrawerItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        ...items.map((item) => ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: item.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          title: Row(
            children: [
              // Label takes whatever space remains, ellipsizes if needed.
              Flexible(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: item.badge == 'AI' ? const Color(0xFF7C4DFF) : AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          onTap: () {
            Navigator.pop(context); // close drawer
            context.push(item.route);
          },
        )),
        Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
      ],
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final String? badge;
  const _DrawerItem(this.icon, this.label, this.route, this.color, {this.badge});
}

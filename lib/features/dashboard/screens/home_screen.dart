import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/profile_completeness_banner.dart';
import '../../../core/widgets/security_tips_banner.dart';
import '../../../core/widgets/theme_switcher.dart';
import '../../../features/auth/auth_provider.dart';
import '../dashboard_api.dart';

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
    _Feature(Icons.wifi,            'Wi-Fi Safety',      '/wifi-scanner',      Color(0xFF00BCD4)),
    _Feature(Icons.apps,            'App Risk Scanner',  '/home/scanner',      Color(0xFF00E5FF)),
    _Feature(Icons.install_mobile,  'Package Monitor',   '/package-monitor',   Color(0xFFFF9800)),
    _Feature(Icons.groups,          'Community Scams',   '/community-scams',   Color(0xFFFF5252), badge: 'NEW'),
  ]),
  _Category(Icons.sos_rounded, 'Emergency & SOS', Color(0xFFFF5252), [
    _Feature(Icons.video_call,      'Police Video Call', '/video-call',        Color(0xFF4CAF50), badge: 'NEW'),
    _Feature(Icons.description,     'FIR Draft (AI)',    '/fir-draft',         Color(0xFFFF9800), badge: 'AI'),
    _Feature(Icons.mic,             'Call Recorder',     '/call-recorder',     Color(0xFFFF5252)),
    _Feature(Icons.share,           'Emergency Share',   '/emergency-share',   Color(0xFFFF5252)),
    _Feature(Icons.folder_special,  'Evidence Locker',   '/evidence',          Color(0xFF7C4DFF)),
    _Feature(Icons.email,           'Complaint Email',   '/complaint-email',   Color(0xFF4CAF50), badge: 'AI'),
  ]),
  _Category(Icons.fingerprint, 'Identity & Privacy', Color(0xFF7C4DFF), [
    _Feature(Icons.install_mobile,  'App Install Monitor', '/app-monitor',      Color(0xFF00E5FF), badge: 'NEW'),
    _Feature(Icons.content_copy,    'Clone Detector',      '/clone-detector',   Color(0xFFFF5252), badge: 'NEW'),
    _Feature(Icons.elderly,         'Elderly Protection',  '/elderly-mode',     Color(0xFF9C27B0), badge: 'NEW'),
    _Feature(Icons.security,        'Banking Protection',  '/banking-protection', Color(0xFF4CAF50)),
    _Feature(Icons.lock_clock,      'Bank OTP Monitor',  '/bank-otp-monitor',  Color(0xFFFF9800)),
    _Feature(Icons.vpn_lock,        'VPN Monitor',       '/vpn-monitor',       Color(0xFF7C4DFF)),
    _Feature(Icons.desktop_access_disabled, 'Remote Detector', '/remote-detector', Color(0xFFFF5252)),
    _Feature(Icons.videocam_off,    'Screen Rec Detect', '/screen-recorder',   Color(0xFF00E5FF)),
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

class _DashboardTabState extends ConsumerState<DashboardTab> {
  final _api = DashboardApi();
  Map<String, dynamic>? _report;
  List<dynamic> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await _api.getDailyReport();
      final alerts = await _api.getRecentAlerts();
      if (mounted) {
        setState(() { _report = report; _alerts = alerts; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentOf(context);
    if (_loading) return Center(child: CircularProgressIndicator(color: accent));

    final riskScore   = (_report?['overall_risk_score'] as num?)?.toDouble() ?? 0.0;
    final safeScore   = (100 - riskScore).clamp(0.0, 100.0);
    final threats     = _report?['threats_detected'] ?? 0;
    final safeColor   = safeScore >= 70 ? AppTheme.success : safeScore >= 40 ? AppTheme.warning : AppTheme.errorColor;
    final safeLabel   = safeScore >= 70 ? 'PROTECTED' : safeScore >= 40 ? 'FAIR' : 'AT RISK';

    return RefreshIndicator(
      onRefresh: _load,
      color: accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Security Score Hero ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, safeColor.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: safeColor.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  const ProfileCompletenessBanner(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cyber Safety Score',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${safeScore.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '/100',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: safeColor.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                safeLabel,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        safeScore >= 70 ? Icons.shield : safeScore >= 40 ? Icons.shield_outlined : Icons.warning_amber_rounded,
                        size: 70, color: safeColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: safeScore / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(safeColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _statChip(Icons.warning,   '$threats',                          'Threats',  AppTheme.errorColor)),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip(Icons.apps,      '${_report?['apps_scanned']  ?? 0}', 'Apps',     accent)),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip(Icons.link,      '${_report?['links_scanned'] ?? 0}', 'Links',    AppTheme.warning)),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip(Icons.phone,     '${_report?['calls_analyzed'] ?? 0}','Calls',    AppTheme.success)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Security Tips Banner ─────────────────────────────────────
            const SecurityTipsBanner(interval: Duration(seconds: 8)),
            const SizedBox(height: 12),

            // ── SOS Panic strip ──────────────────────────────────────────
            GestureDetector(
              onTap: () => context.push('/video-call'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.errorColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sos_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Emergency SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Police video call · FIR draft · Evidence', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white70),
                  ],
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
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),  // Darker background for better contrast
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,  // Pure white on dark background
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),  // High contrast gray
              fontSize: 10,
              fontWeight: FontWeight.w500,
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
                Text(alert['message'] as String? ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                decoration: BoxDecoration(color: category.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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
          border: Border.all(color: feature.color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: feature.color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: feature.color.withOpacity(0.12), shape: BoxShape.circle),
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final accent = AppTheme.accentOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 22),
          const SizedBox(width: 10),
          Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Text('Are you sure you want to logout?\nYour session will be ended.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13)),
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
        title: const Text('SecureShield AI'),
        actions: [
          const ThemeSwitcher(),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: accent),
            onPressed: () => context.push('/home/alerts'),
            tooltip: 'Alerts',
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Side drawer — ALL features ───────────────────────────────────
      drawer: _AppDrawer(),

      body: child,

      // ── Bottom nav ───────────────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          switch (i) {
            case 0: context.go('/home');          break;
            case 1: context.go('/home/scanner');  break;
            case 2: context.go('/home/alerts');   break;
            case 3: context.go('/home/reports');  break;
            case 4: context.go('/home/ai-coach'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard),     label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.apps),          label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart),     label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy),     label: 'AI Coach'),
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
              gradient: LinearGradient(colors: [AppTheme.primary, accent.withOpacity(0.4)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: accent.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(Icons.security, color: accent, size: 28),
                ),
                const SizedBox(height: 12),
                Text('SecureShield AI', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(authState.identifier ?? 'Cyber Safety Suite', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),

          // All features list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                _drawerSection(context, '🛡️  Threat Detection', [
                  _DrawerItem(Icons.link,           'Link Scanner',        '/link-scanner',       const Color(0xFF00E5FF), badge: 'AI'),
                  _DrawerItem(Icons.sms,            'Message Analyzer',    '/message-analyzer',   const Color(0xFF00E5FF), badge: 'AI'),
                  _DrawerItem(Icons.wifi,           'Wi-Fi Safety',        '/wifi-scanner',       const Color(0xFF00BCD4)),
                  _DrawerItem(Icons.apps,           'App Risk Scanner',    '/home/scanner',       const Color(0xFF00E5FF)),
                  _DrawerItem(Icons.install_mobile, 'Package Monitor',     '/package-monitor',    const Color(0xFFFF9800)),
                  _DrawerItem(Icons.groups,         'Community Scams',     '/community-scams',    const Color(0xFFFF5252), badge: 'NEW'),
                ]),
                _drawerSection(context, '🚨  Emergency & SOS', [
                  _DrawerItem(Icons.video_call,     'Police Video Call',   '/video-call',         const Color(0xFF4CAF50), badge: 'NEW'),
                  _DrawerItem(Icons.description,    'FIR Draft',           '/fir-draft',          const Color(0xFFFF9800), badge: 'AI'),
                  _DrawerItem(Icons.mic,            'Call Recorder',       '/call-recorder',      const Color(0xFFFF5252)),
                  _DrawerItem(Icons.share,          'Emergency Share',     '/emergency-share',    const Color(0xFFFF5252)),
                  _DrawerItem(Icons.folder_special, 'Evidence Locker',     '/evidence',           const Color(0xFF7C4DFF)),
                  _DrawerItem(Icons.email,          'Complaint Email',     '/complaint-email',    const Color(0xFF4CAF50), badge: 'AI'),
                ]),
                _drawerSection(context, '🔐  Identity & Privacy', [
                  _DrawerItem(Icons.install_mobile, 'App Install Monitor', '/app-monitor',         const Color(0xFF00E5FF), badge: 'NEW'),
                  _DrawerItem(Icons.content_copy,   'Clone Detector',      '/clone-detector',      const Color(0xFFFF5252), badge: 'NEW'),
                  _DrawerItem(Icons.elderly,        'Elderly Protection',  '/elderly-mode',        const Color(0xFF9C27B0), badge: 'NEW'),
                  _DrawerItem(Icons.security,       'Banking Protection',  '/banking-protection',  const Color(0xFF4CAF50)),
                  _DrawerItem(Icons.lock_clock,     'Bank OTP Monitor',    '/bank-otp-monitor',   const Color(0xFFFF9800)),
                  _DrawerItem(Icons.vpn_lock,       'VPN Monitor',         '/vpn-monitor',        const Color(0xFF7C4DFF)),
                  _DrawerItem(Icons.desktop_access_disabled, 'Remote Detector', '/remote-detector', const Color(0xFFFF5252)),
                  _DrawerItem(Icons.videocam_off,   'Screen Rec Detect',   '/screen-recorder',    const Color(0xFF00E5FF)),
                ]),
                _drawerSection(context, '👨‍👩‍👧  Family Safety', [
                  _DrawerItem(Icons.family_restroom,'Family Dashboard',    '/family',             const Color(0xFF9C27B0)),
                  _DrawerItem(Icons.sms,            'Job / Msg Analyzer',  '/message-analyzer',   const Color(0xFFFF9800), badge: 'AI'),
                ]),
                _drawerSection(context, '📱  Device Security', [
                  _DrawerItem(Icons.phone_android,  'Device Scan',         '/device-scan',        const Color(0xFF4CAF50)),
                  _DrawerItem(Icons.settings_suggest,'Consent Manager',    '/consent-manager',    const Color(0xFF00BCD4)),
                ]),
                _drawerSection(context, '📊  Reports & Insights', [
                  _DrawerItem(Icons.bar_chart,      'Security Reports',    '/home/reports',       const Color(0xFFFF9800)),
                  _DrawerItem(Icons.smart_toy,      'AI Coach',            '/home/ai-coach',      const Color(0xFF7C4DFF), badge: 'AI'),
                  _DrawerItem(Icons.tips_and_updates,'Cyber Tips',         '/tips',               const Color(0xFF00E5FF)),
                  _DrawerItem(Icons.settings,       'Settings',            '/settings',           AppTheme.textSecondary),
                ]),
                _drawerSection(context, '👤  Account', [
                  _DrawerItem(Icons.person_rounded,     'My Profile',          '/profile',            const Color(0xFF69F0AE)),
                  _DrawerItem(Icons.emergency_rounded,  'Emergency Contacts',  '/profile',            AppTheme.errorColor),
                ]),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: accent.withOpacity(0.15)))),
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: AppTheme.errorColor, size: 18),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cybercrime Helpline', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    Text('1930', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 20)),
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
            decoration: BoxDecoration(color: item.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          title: Row(
            children: [
              Text(item.label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
              if (item.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: item.badge == 'AI' ? const Color(0xFF7C4DFF) : AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item.badge!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          onTap: () {
            Navigator.pop(context); // close drawer
            context.push(item.route);
          },
        )),
        Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06)),
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

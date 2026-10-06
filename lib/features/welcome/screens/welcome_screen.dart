import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/security/banking_threat_provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/premium/premium.dart';
import '../../../core/widgets/security_tips_banner.dart';
import '../../../features/auth/auth_provider.dart';
import '../../banking_protection/widgets/banking_threat_strip.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────────────────────
// Feature card model
// ────────────────────────────────────────────────────────────────────────────
class _CardData {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final String?  badge;
  final bool     fullWidth;
  final VoidCallback? action;

  const _CardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    this.fullWidth = false,
    this.action,
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Welcome Screen — auth-aware, dynamic login/logout/register
// ────────────────────────────────────────────────────────────────────────────
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
    final cards = _buildCards(context, ref, isLoggedIn);

    // Banking-threat correlator result (shared across screens). Renders
    // nothing when the device is clean OR while the scan is in flight.
    final threatReport = ref.watch(bankingThreatReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App header ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header(isLoggedIn: isLoggedIn)),

            // ── Banking-threat alert (post device-security check) ─────────
            // Sits at the very top of the scroll content so users see any
            // active threat the moment they open SecureShield.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: BankingThreatStrip(report: threatReport),
              ),
            ),

            // ── Animated security tips banner ─────────────────────────────
            const SliverToBoxAdapter(
              child: SecurityTipsBanner(interval: Duration(seconds: 7)),
            ),

            // ── Section: Get Started / Account ────────────────────────────
            _sectionLabel(isLoggedIn ? 'Your Account' : 'Get Started'),
            _CardGrid(cards: cards['getStarted']!),

            // ── Section: Safety Tools ─────────────────────────────────────
            _sectionLabel('Safety Tools'),
            _CardGrid(cards: cards['safetyTools']!),

            // ── Section: Support & Help ───────────────────────────────────
            _sectionLabel('Support & Help'),
            _CardGrid(cards: cards['support']!),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Map<String, List<_CardData>> _buildCards(
      BuildContext context, WidgetRef ref, bool isLoggedIn) {
    final getStartedCards = <_CardData>[];

    if (isLoggedIn) {
      // ── Authenticated user cards ────────────────────────────────────────
      getStartedCards.addAll([
        _CardData(
          icon:     Icons.dashboard_rounded,
          title:    'Dashboard',
          subtitle: 'View your security reports',
          color:    AppTheme.accent,
          action:   () => context.go('/home'),
        ),
        _CardData(
          icon:     Icons.person_rounded,
          title:    AppLocalizations.of(context).profMy,
          subtitle: 'Edit details & emergency contacts',
          color:    const Color(0xFF69F0AE),
          action:   () => context.push('/profile'),
        ),
        _CardData(
          icon:      Icons.logout_rounded,
          title:     AppLocalizations.of(context).logout,
          subtitle:  'Sign out of your account',
          color:     AppTheme.errorColor,
          fullWidth: true,
          action:    () => _confirmLogout(context, ref),
        ),
      ]);
    } else {
      // ── Unauthenticated user cards ──────────────────────────────────────
      getStartedCards.addAll([
        _CardData(
          icon:     Icons.lock_open_rounded,
          title:    AppLocalizations.of(context).welLogin,
          subtitle: 'Access your security reports',
          color:    AppTheme.accent,
          action:   () => context.push('/login'),
        ),
        _CardData(
          icon:     Icons.person_add_rounded,
          title:    AppLocalizations.of(context).welRegister,
          subtitle: 'Create your free account',
          color:    const Color(0xFF69F0AE),
          action:   () => context.push('/register'),
        ),
        _CardData(
          icon:      Icons.radar_rounded,
          title:     AppLocalizations.of(context).welcomeScanTitle,
          subtitle:  'Check your phone for threats in 30 seconds',
          color:     AppTheme.success,
          badge:     'RECOMMENDED',
          fullWidth: true,
          action:    () => context.push('/device-scan'),
        ),
      ]);
    }

    return {
      'getStarted': getStartedCards,
      'safetyTools': [
        _CardData(
          icon:     Icons.tips_and_updates_rounded,
          title:    AppLocalizations.of(context).welcomeTipsTitle,
          subtitle: 'Daily fraud prevention guides',
          color:    const Color(0xFFCE93D8),
          action:   () => context.push('/tips'),
        ),
        _CardData(
          icon:     Icons.sos_rounded,
          title:    AppLocalizations.of(context).welcomeSosTitle,
          subtitle: 'Report cyber crime instantly',
          color:    AppTheme.errorColor,
          action:   () => _showSosDialog(context),
        ),
        _CardData(
          icon:     Icons.video_call_rounded,
          title:    AppLocalizations.of(context).welShareEvidence,
          subtitle: 'Send fraud video via WhatsApp',
          color:    const Color(0xFF25D366),
          action:   () => _shareOnWhatsApp(context),
        ),
        _CardData(
          icon:     Icons.contacts_rounded,
          title:    AppLocalizations.of(context).welCyberContacts,
          subtitle: 'Helplines & reporting portals',
          color:    const Color(0xFF7986CB),
          action:   () => context.push('/contacts'),
        ),
      ],
      'support': [
        _CardData(
          icon:      Icons.email_rounded,
          title:     AppLocalizations.of(context).welSendEmailReport,
          subtitle:  'Email the cyber crime cell directly',
          color:     const Color(0xFF4FC3F7),
          fullWidth: true,
          action:    () => _sendEmail(context),
        ),
      ],
    };
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  static Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 22),
          const SizedBox(width: 10),
          Text(AppLocalizations.of(context).logout, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Are you sure you want to logout?\nYour session will be ended.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel, style: const TextStyle(color: AppTheme.accent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocalizations.of(context).logout, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  static Future<void> _showSosDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SosSheet(),
    );
  }

  static Future<void> _shareOnWhatsApp(BuildContext context) async {
    const message =
        'I want to report a cyber fraud. Evidence attached. '
        'Please help me get justice. '
        '\n\nNational Helpline: 1930'
        '\nPortal: cybercrime.gov.in';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).welWhatsappMissing)),
      );
    }
  }

  static Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'cybercrime@gov.in',
      queryParameters: {
        'subject': 'Cyber Crime Report — SecureShield AI User',
        'body': 'Dear Cyber Crime Cell,\n\n'
            'I am reporting a cyber fraud incident.\n\n'
            'Details:\n'
            '• Date of incident:\n'
            '• Type of fraud:\n'
            '• Amount lost (if any):\n'
            '• Description:\n\n'
            'Please investigate and take necessary action.\n\n'
            'Regards,\n[Your Name]',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).welNoEmailApp)),
      );
    }
  }

  SliverToBoxAdapter _sectionLabel(String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// App header — shows logged-in indicator when authenticated
// ────────────────────────────────────────────────────────────────────────────
/// Premium welcome header — animated AI shield on the left, brand + tagline
/// stacked on the right. Sits on a radial-glow gradient for the SOC feel.
class _Header extends StatelessWidget {
  final bool isLoggedIn;
  const _Header({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.6),
          radius: 1.4,
          colors: [
            const Color(0xFF00C2FF).withValues(alpha: 0.22),
            const Color(0xFF8B5CF6).withValues(alpha: 0.10),
            AppTheme.background,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row: top-of-app "Active" pill or nothing when signed out
          if (isLoggedIn)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).welProtected,
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Hero row: animated shield + brand
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 128,
                height: 128,
                child: AnimatedShield(size: 74, icon: Icons.shield_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C2FF), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(AppLocalizations.of(context).welAiPowered,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('SecureShield',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(AppLocalizations.of(context).welEnterprise,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB8C2D1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _trustRow(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trustRow() {
    return const Row(
      children: [
        _TrustPill(icon: Icons.lock_rounded,       label: 'Encrypted'),
        SizedBox(width: 6),
        _TrustPill(icon: Icons.cloud_off_rounded,  label: 'Offline-first'),
      ],
    );
  }
}

class _TrustPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 4),
          Text(label,
            style: const TextStyle(
              color: Color(0xFFB8C2D1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Card grid
// ────────────────────────────────────────────────────────────────────────────
class _CardGrid extends StatelessWidget {
  final List<_CardData> cards;
  const _CardGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;
          return _buildGrid(isWide);
        },
      ),
    );
  }

  Widget _buildGrid(bool isWide) {
    final rows = <Widget>[];
    int i = 0;
    while (i < cards.length) {
      final card = cards[i];
      if (card.fullWidth) {
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _FeatureCard(data: card),
        ));
        i++;
      } else {
        final group = <_CardData>[];
        while (i < cards.length && !cards[i].fullWidth) {
          group.add(cards[i]);
          i++;
        }
        final cols = isWide ? 3 : 2;
        for (int j = 0; j < group.length; j += cols) {
          final rowCards = group.skip(j).take(cols).toList();
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int k = 0; k < cols; k++) ...[
                    if (k > 0) const SizedBox(width: 8),
                    Expanded(
                      child: k < rowCards.length
                          ? _FeatureCard(data: rowCards[k])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
      }
    }
    return Column(children: rows);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Individual feature card
// ────────────────────────────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final _CardData data;
  const _FeatureCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.action,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(data.fullWidth ? 18 : 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: data.color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: data.fullWidth
            ? _FullWidthContent(data: data)
            : _HalfWidthContent(data: data),
      ),
    );
  }
}

class _HalfWidthContent extends StatelessWidget {
  final _CardData data;
  const _HalfWidthContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(data.icon, color: data.color, size: 26),
        ),
        const SizedBox(height: 12),
        Text(data.title,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 3),
        Text(data.subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _FullWidthContent extends StatelessWidget {
  final _CardData data;
  const _FullWidthContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(data.icon, color: data.color, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(data.title,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (data.badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: data.color.withValues(alpha: 0.5)),
                      ),
                      child: Text(data.badge!,
                        style: TextStyle(color: data.color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(data.subtitle,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: data.color.withValues(alpha: 0.6)),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// SOS bottom sheet
// ────────────────────────────────────────────────────────────────────────────
class _SosSheet extends StatelessWidget {
  const _SosSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          const Icon(Icons.sos_rounded, color: AppTheme.errorColor, size: 44),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).menuEmergencyContacts, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _sosTile('1930', 'National Cyber Crime Helpline', Icons.phone_rounded, AppTheme.errorColor),
          _sosTile('100',  'Police Emergency',              Icons.local_police_rounded, AppTheme.accent),
          _sosTile('112',  'All Emergency Services',        Icons.sos_rounded, AppTheme.warning),
          const SizedBox(height: 12),
          const Text('cybercrime.gov.in', style: TextStyle(color: AppTheme.accent, fontSize: 13, decoration: TextDecoration.underline)),
        ],
      ),
    );
  }

  Widget _sosTile(String number, String label, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      trailing: Text(number, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';

// ────────────────────────────────────────────────────────────────────────────
// Feature card model
// ────────────────────────────────────────────────────────────────────────────
class _CardData {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final String?  badge;       // e.g. "RECOMMENDED"
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
// Welcome Screen — first screen the user sees (no auth required)
// ────────────────────────────────────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App header ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header()),

            // ── Smart tip banner ───────────────────────────────────────────
            SliverToBoxAdapter(child: _SmartBanner()),

            // ── Section: Get Started ───────────────────────────────────────
            _sectionLabel('Get Started'),
            _CardGrid(cards: cards['getStarted']!),

            // ── Section: Safety Tools ──────────────────────────────────────
            _sectionLabel('Safety Tools'),
            _CardGrid(cards: cards['safetyTools']!),

            // ── Section: Support & Help ────────────────────────────────────
            _sectionLabel('Support & Help'),
            _CardGrid(cards: cards['support']!),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Map<String, List<_CardData>> _buildCards(BuildContext context) {
    return {
      'getStarted': [
        _CardData(
          icon:     Icons.lock_open_rounded,
          title:    'Login',
          subtitle: 'Access your security reports',
          color:    AppTheme.accent,
          action:   () => context.push('/login'),
        ),
        _CardData(
          icon:     Icons.person_add_rounded,
          title:    'Register',
          subtitle: 'Create your free account',
          color:    const Color(0xFF69F0AE),
          action:   () => context.push('/login'),
        ),
        _CardData(
          icon:      Icons.radar_rounded,
          title:     'Scan My Mobile',
          subtitle:  'Check your phone for threats in 30 seconds',
          color:     AppTheme.success,
          badge:     'RECOMMENDED',
          fullWidth: true,
          action:    () => context.push('/device-scan'),
        ),
      ],
      'safetyTools': [
        _CardData(
          icon:     Icons.tips_and_updates_rounded,
          title:    'Cyber Safety Tips',
          subtitle: 'Daily fraud prevention guides',
          color:    const Color(0xFFCE93D8),
          action:   () => context.push('/tips'),
        ),
        _CardData(
          icon:     Icons.sos_rounded,
          title:    'SOS Emergency',
          subtitle: 'Report cyber crime instantly',
          color:    AppTheme.errorColor,
          action:   () => _showSosDialog(context),
        ),
        _CardData(
          icon:     Icons.video_call_rounded,
          title:    'Share Evidence',
          subtitle: 'Send fraud video via WhatsApp',
          color:    const Color(0xFF25D366), // WhatsApp green
          action:   () => _shareOnWhatsApp(context),
        ),
        _CardData(
          icon:     Icons.contacts_rounded,
          title:    'Cyber Contacts',
          subtitle: 'Helplines & reporting portals',
          color:    const Color(0xFF7986CB),
          action:   () => context.push('/contacts'),
        ),
      ],
      'support': [
        _CardData(
          icon:      Icons.email_rounded,
          title:     'Send Email Report',
          subtitle:  'Email the cyber crime cell directly',
          color:     const Color(0xFF4FC3F7),
          fullWidth: true,
          action:    () => _sendEmail(context),
        ),
      ],
    };
  }

  // ── Actions ────────────────────────────────────────────────────────────────
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

    final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp is not installed')),
        );
      }
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
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email app found on this device')),
        );
      }
    }
  }

  // Helper: section label sliver
  SliverToBoxAdapter _sectionLabel(String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Container(width: 3, height: 16, color: AppTheme.accent,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(2))),
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
// App header widget
// ────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1547), Color(0xFF0A0E27)],
        ),
      ),
      child: Row(
        children: [
          // Shield logo
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.3),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.security_rounded,
                size: 30, color: AppTheme.accent),
          ),
          const SizedBox(width: 14),
          // Title + tagline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SecureShield AI',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Your Personal Cyber Safety Assistant',
                  style: TextStyle(
                    color: AppTheme.accent.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Smart tip banner — rotates through awareness messages
// ────────────────────────────────────────────────────────────────────────────
class _SmartBanner extends StatelessWidget {
  static const _tips = [
    ('🛡️', 'Never share your OTP — not even with bank officials'),
    ('🔍', 'Scan your mobile first to check for hidden threats'),
    ('📞', 'Dial 1930 immediately if you fall victim to cyber fraud'),
    ('⚠️', 'Verify any link before clicking — fake sites steal data'),
    ('🔐', 'Use strong, unique passwords for every account'),
  ];

  @override
  Widget build(BuildContext context) {
    // Pick a tip based on current minute (rotates every minute)
    final tip = _tips[DateTime.now().minute % _tips.length];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(tip.$1, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip.$2,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Card grid — renders 2-column grid, full-width cards span both columns
// ────────────────────────────────────────────────────────────────────────────
class _CardGrid extends StatelessWidget {
  final List<_CardData> cards;
  const _CardGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    // Split cards into rows manually to support full-width items
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
        // Pair with next card if available and not full-width
        final next = (i + 1 < cards.length && !cards[i + 1].fullWidth)
            ? cards[i + 1]
            : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(child: _FeatureCard(data: card)),
                const SizedBox(width: 8),
                Expanded(
                    child: next != null
                        ? _FeatureCard(data: next)
                        : const SizedBox()),
              ],
            ),
          ),
        );
        i += next != null ? 2 : 1;
      }
    }

    return SliverToBoxAdapter(child: Column(children: rows));
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
          border: Border.all(color: data.color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(0.08),
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

// ── Half-width card (vertical layout) ────────────────────────────────────────
class _HalfWidthContent extends StatelessWidget {
  final _CardData data;
  const _HalfWidthContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon circle
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: data.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(data.icon, color: data.color, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          data.title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          data.subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Full-width card (horizontal layout) ──────────────────────────────────────
class _FullWidthContent extends StatelessWidget {
  final _CardData data;
  const _FullWidthContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon circle
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: data.color.withOpacity(0.12),
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
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (data.badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: data.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: data.color.withOpacity(0.5)),
                      ),
                      child: Text(
                        data.badge!,
                        style: TextStyle(
                          color: data.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: data.color.withOpacity(0.6)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // SOS icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sos_rounded,
                size: 34, color: AppTheme.errorColor),
          ),
          const SizedBox(height: 12),
          const Text(
            'Emergency — Cyber Crime SOS',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose an action below',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Action buttons
          _SosAction(
            icon:    Icons.phone_rounded,
            label:   'Call 1930',
            sub:     'National Cyber Crime Helpline (India)',
            color:   AppTheme.errorColor,
            onTap:   () => _call('1930', context),
          ),
          const SizedBox(height: 10),
          _SosAction(
            icon:    Icons.emergency_rounded,
            label:   'Call 112',
            sub:     'Police Emergency',
            color:   AppTheme.warning,
            onTap:   () => _call('112', context),
          ),
          const SizedBox(height: 10),
          _SosAction(
            icon:    Icons.language_rounded,
            label:   'Report Online',
            sub:     'cybercrime.gov.in — National Portal',
            color:   AppTheme.accent,
            onTap:   () => _openUrl('https://cybercrime.gov.in', context),
          ),
          const SizedBox(height: 10),
          _SosAction(
            icon:    Icons.contact_phone_rounded,
            label:   'View All Contacts',
            sub:     'State cyber cells & helplines',
            color:   const Color(0xFF7986CB),
            onTap:   () {
              Navigator.pop(context);
              context.push('/contacts');
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _call(String number, BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
    if (context.mounted) Navigator.pop(context);
  }

  static Future<void> _openUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }
}

class _SosAction extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sub;
  final Color    color;
  final VoidCallback onTap;

  const _SosAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(sub,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

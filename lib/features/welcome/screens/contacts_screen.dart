import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';

// ────────────────────────────────────────────────────────────────────────────
// Data models
// ────────────────────────────────────────────────────────────────────────────
enum _ActionType { call, email, web }

class _Contact {
  final String   name;
  final String   detail;     // number / email / URL
  final String   description;
  final IconData icon;
  final Color    color;
  final _ActionType type;
  final String?  badge;

  const _Contact({
    required this.name,
    required this.detail,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
    this.badge,
  });
}

class _Section {
  final String         title;
  final String         subtitle;
  final IconData       icon;
  final List<_Contact> contacts;
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.contacts,
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Contact data
// ────────────────────────────────────────────────────────────────────────────
const _sections = [
  _Section(
    title:    'Emergency Helplines',
    subtitle: 'Call these immediately if you are under attack',
    icon:     Icons.emergency_rounded,
    contacts: [
      _Contact(
        name:        '1930 — National Cyber Crime Helpline',
        detail:      '1930',
        description: '24×7 helpline for reporting online financial fraud. '
                     'Call within the golden hour to freeze fraudulent transactions.',
        icon:  Icons.phone_rounded,
        color: AppTheme.errorColor,
        type:  _ActionType.call,
        badge: '24×7',
      ),
      _Contact(
        name:        '112 — Police Emergency',
        detail:      '112',
        description: 'For immediate physical threats or emergencies related to cyber crime.',
        icon:  Icons.local_police_rounded,
        color: AppTheme.warning,
        type:  _ActionType.call,
      ),
      _Contact(
        name:        '155260 — RBI Financial Fraud',
        detail:      '155260',
        description: 'RBI-designated helpline for banking and UPI fraud. '
                     'Also escalate through your bank\'s official customer care.',
        icon:  Icons.account_balance_rounded,
        color: Color(0xFF4FC3F7),
        type:  _ActionType.call,
      ),
    ],
  ),
  _Section(
    title:    'Government Security Tools',
    subtitle: 'Sanchar Saathi — Fraud prevention & device verification',
    icon:     Icons.verified_user_rounded,
    contacts: [
      _Contact(
        name:        'CHAKSHU — Fraud Reporting',
        detail:      'https://sancharsaathi.gov.in/sfc/',
        description: 'Official fraud reporting portal by Department of Telecom. '
                     'Report financial fraud, UPI scams, and telecom fraud instantly.',
        icon:  Icons.report_problem_rounded,
        color: AppTheme.errorColor,
        type:  _ActionType.web,
        badge: 'OFFICIAL',
      ),
      _Contact(
        name:        'CEIR — Block Lost Devices',
        detail:      'https://ceir.sancharsaathi.gov.in/',
        description: 'Central Equipment Identity Register. Block lost/stolen phones immediately. '
                     'Prevents unauthorized use and protects your data.',
        icon:  Icons.phone_locked_rounded,
        color: Color(0xFF4FC3F7),
        type:  _ActionType.web,
        badge: 'OFFICIAL',
      ),
      _Contact(
        name:        'TAFCOP — Track Active SIMs',
        detail:      'https://tafcop.sancharsaathi.gov.in/telecomUser/',
        description: 'Track All Telecom Frequencies on Personal mobile number. '
                     'Verify active SIM cards on your number instantly.',
        icon:  Icons.sim_card_rounded,
        color: Color(0xFF69F0AE),
        type:  _ActionType.web,
        badge: 'OFFICIAL',
      ),
      _Contact(
        name:        'KYM — Check IMEI Status',
        detail:      'https://ceir.sancharsaathi.gov.in/Device/SancharSaathiKym.jsp',
        description: 'Know Your Mobile — Verify device IMEI and check if phone is stolen/blacklisted. '
                     'Ensure your device is legitimate.',
        icon:  Icons.phonelink_setup_rounded,
        color: Color(0xFF7986CB),
        type:  _ActionType.web,
        badge: 'OFFICIAL',
      ),
      _Contact(
        name:        'Sanchar Saathi Portal',
        detail:      'https://sancharsaathi.gov.in/',
        description: 'Main Sanchar Saathi portal — Gateway to all government security tools. '
                     'Access all fraud prevention resources in one place.',
        icon:  Icons.shield_rounded,
        color: AppTheme.accent,
        type:  _ActionType.web,
        badge: 'MAIN PORTAL',
      ),
      _Contact(
        name:        'Sanchar Saathi — Android App',
        detail:      'https://play.google.com/store/apps/details?id=com.dot.app.sancharsaathi',
        description: 'Download the official Sanchar Saathi mobile app. '
                     'Instant access to fraud prevention and device security tools on the go.',
        icon:  Icons.android_rounded,
        color: Color(0xFF69F0AE),
        type:  _ActionType.web,
      ),
      _Contact(
        name:        'Sanchar Saathi — iOS App',
        detail:      'https://apps.apple.com/in/app/sanchar-saathi/id6739700695',
        description: 'Download Sanchar Saathi from Apple App Store. '
                     'Mobile-first access to security tools and fraud alerts.',
        icon:  Icons.apple_rounded,
        color: Color(0xFFFF6D00),
        type:  _ActionType.web,
      ),
    ],
  ),
  _Section(
    title:    'Online Reporting Portals',
    subtitle: 'File a formal complaint online',
    icon:     Icons.language_rounded,
    contacts: [
      _Contact(
        name:        'cybercrime.gov.in',
        detail:      'https://cybercrime.gov.in',
        description: 'National Cyber Crime Reporting Portal by MHA, India. '
                     'Report all types of cyber crime including financial fraud, social media abuse.',
        icon:  Icons.web_rounded,
        color: AppTheme.accent,
        type:  _ActionType.web,
        badge: 'OFFICIAL',
      ),
      _Contact(
        name:        'sachet.rbi.org.in',
        detail:      'https://sachet.rbi.org.in',
        description: 'RBI\'s portal to lodge complaints against unauthorized financial schemes '
                     'and fraudulent lending apps.',
        icon:  Icons.gavel_rounded,
        color: Color(0xFF7986CB),
        type:  _ActionType.web,
      ),
      _Contact(
        name:        'pgportal.gov.in',
        detail:      'https://pgportal.gov.in',
        description: 'Public Grievance Portal for escalating unresolved cyber crime complaints '
                     'to ministry level.',
        icon:  Icons.assignment_rounded,
        color: Color(0xFF69F0AE),
        type:  _ActionType.web,
      ),
    ],
  ),
  _Section(
    title:    'Email Cyber Cells',
    subtitle: 'Write a detailed complaint by email',
    icon:     Icons.email_rounded,
    contacts: [
      _Contact(
        name:        'cybercrime@gov.in',
        detail:      'cybercrime@gov.in',
        description: 'Email the Ministry of Home Affairs Cyber Crime Cell. '
                     'Include date, time, transaction ID, screenshots, and description.',
        icon:  Icons.email_rounded,
        color: Color(0xFFFF6D00),
        type:  _ActionType.email,
        badge: 'MHA INDIA',
      ),
      _Contact(
        name:        'cybercell@cbi.gov.in',
        detail:      'cybercell@cbi.gov.in',
        description: 'Central Bureau of Investigation Cyber Crime Cell. '
                     'For serious cyber crime involving organized networks.',
        icon:  Icons.email_rounded,
        color: Color(0xFF4FC3F7),
        type:  _ActionType.email,
      ),
    ],
  ),
  _Section(
    title:    'State Cyber Cells',
    subtitle: 'Contact your state cybercrime unit directly',
    icon:     Icons.location_city_rounded,
    contacts: [
      _Contact(
        name:        'Mumbai Cyber Cell',
        detail:      'cybercell.mumbai@mahapolice.gov.in',
        description: 'Mumbai Police Cyber Crime Unit — Maharashtra.',
        icon:  Icons.email_rounded,
        color: Color(0xFFCE93D8),
        type:  _ActionType.email,
      ),
      _Contact(
        name:        'Bengaluru Cyber Cell',
        detail:      'https://cybercrime.karnataka.gov.in',
        description: 'Karnataka Cyber Crime Police Station, Bengaluru.',
        icon:  Icons.web_rounded,
        color: Color(0xFF7986CB),
        type:  _ActionType.web,
      ),
      _Contact(
        name:        'Delhi Cyber Cell',
        detail:      'https://cybercrime.delhi.gov.in',
        description: 'Delhi Police Cyber Crime Branch — report online fraud in Delhi NCR.',
        icon:  Icons.web_rounded,
        color: Color(0xFF25D366),
        type:  _ActionType.web,
      ),
    ],
  ),
];

// ────────────────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────────────────
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cyber Crime Contacts'),
        backgroundColor: AppTheme.surface,
        leading: const BackButton(color: AppTheme.accent),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Top banner ───────────────────────────────────────────────────
          _TopBanner(),

          // ── Sections ─────────────────────────────────────────────────────
          ..._sections.map((s) => _SectionWidget(section: s)),

          // ── Advice footer ────────────────────────────────────────────────
          _Footer(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Top banner
// ────────────────────────────────────────────────────────────────────────────
class _TopBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  color: AppTheme.warning, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text('If you\'re under attack right now:',
                    style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '1. Call 1930 IMMEDIATELY\n'
            '2. Note the transaction ID / reference number\n'
            '3. Do NOT transfer more money to "recover" losses\n'
            '4. Block your card/UPI via your banking app',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Section widget
// ────────────────────────────────────────────────────────────────────────────
class _SectionWidget extends StatelessWidget {
  final _Section section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              Icon(section.icon, size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    section.subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Contacts
        ...section.contacts
            .map((c) => _ContactCard(contact: c))
            ,
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Contact card
// ────────────────────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final _Contact contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: contact.color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: contact.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(contact.icon, color: contact.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (contact.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: contact.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                contact.badge!,
                                style: TextStyle(
                                  color: contact.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Tap-to-copy detail
                      GestureDetector(
                        onTap: () => _copy(contact.detail, context),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.detail,
                                style: TextStyle(
                                  color: contact.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.copy_rounded,
                                size: 11,
                                color: contact.color.withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Description
            const SizedBox(height: 10),
            Text(
              contact.description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),

            // Action button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launch(contact, context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: contact.color,
                  side: BorderSide(color: contact.color.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_actionIcon(contact.type), size: 16),
                label: Text(_actionLabel(contact.type),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(_ActionType t) => switch (t) {
        _ActionType.call  => Icons.phone_rounded,
        _ActionType.email => Icons.send_rounded,
        _ActionType.web   => Icons.open_in_browser_rounded,
      };

  String _actionLabel(_ActionType t) => switch (t) {
        _ActionType.call  => 'Call Now',
        _ActionType.email => 'Send Email',
        _ActionType.web   => 'Open Portal',
      };

  Future<void> _launch(_Contact c, BuildContext context) async {
    final Uri uri;
    switch (c.type) {
      case _ActionType.call:
        uri = Uri(scheme: 'tel', path: c.detail);
      case _ActionType.email:
        uri = Uri(
          scheme: 'mailto',
          path: c.detail,
          queryParameters: {
            'subject': 'Cyber Crime Report — SecureShield AI User',
            'body':    'Dear Cyber Crime Cell,\n\n'
                       'I am reporting a cyber crime incident.\n\n'
                       'Date of incident:\nType of fraud:\nAmount lost:\nDescription:\n\n'
                       'Please investigate and take necessary action.\n\nRegards,\n[Your Name]',
          },
        );
      case _ActionType.web:
        uri = Uri.parse(c.detail);
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: c.type == _ActionType.web
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: ${c.detail}')),
      );
    }
  }

  void _copy(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Footer advice
// ────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3560)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.warning, size: 16),
              SizedBox(width: 8),
              Text('Pro Tips',
                  style: TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Report within 24 hours — banks can recover funds more easily\n'
            '• Save all transaction IDs, screenshots, and call recordings\n'
            '• Tap any contact detail above to copy it\n'
            '• Your complaint is free — no lawyer or fee needed',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}

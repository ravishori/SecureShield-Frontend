import 'package:flutter/material.dart';
import '../../../core/theme.dart';

// ────────────────────────────────────────────────────────────────────────────
// Data model
// ────────────────────────────────────────────────────────────────────────────
class _TipCategory {
  final IconData icon;
  final String   name;
  final Color    color;
  final List<_Tip> tips;
  const _TipCategory({
    required this.icon,
    required this.name,
    required this.color,
    required this.tips,
  });
}

class _Tip {
  final String title;
  final String body;
  final String emoji;
  const _Tip(this.emoji, this.title, this.body);
}

// ────────────────────────────────────────────────────────────────────────────
// Content
// ────────────────────────────────────────────────────────────────────────────
const _categories = [
  _TipCategory(
    icon:  Icons.sms_failed_rounded,
    name:  'OTP & SMS Scams',
    color: Color(0xFFFF6D00),
    tips: [
      _Tip('🚫', 'Never share your OTP',
          'No bank, government, or tech company will ever ask for your OTP over a call or message. '
          'OTP is your digital signature — treat it like your ATM PIN.'),
      _Tip('📩', 'Fake SMS with links',
          'Fraudsters send SMS like "Your account is blocked, click here to verify." '
          'Legitimate banks never send clickable links in SMS alerts.'),
      _Tip('☎️', 'Impersonation calls',
          'Callers claiming to be RBI/TRAI/Police saying your SIM/account will be blocked. '
          'Hang up immediately. These agencies never call asking for OTP or money.'),
      _Tip('🔁', 'OTP forwarding apps',
          'Apps asking to forward SMS or granting accessibility can steal OTPs silently. '
          'Only install apps from the Play Store and review permissions carefully.'),
    ],
  ),
  _TipCategory(
    icon:  Icons.chat_rounded,
    name:  'WhatsApp & Social Fraud',
    color: Color(0xFF25D366),
    tips: [
      _Tip('👥', 'Fake relative scam',
          '"Hi uncle, this is my new number. I\'m in trouble and need money urgently." '
          'Always call the person\'s original number to verify before sending money.'),
      _Tip('📸', 'Screen share scams',
          'Fraudsters ask you to share your screen to "help" you, then steal banking logins '
          'and OTPs in real-time. Never share your screen with unknown people.'),
      _Tip('🎁', 'Lottery / prize messages',
          '"You\'ve won ₹50 lakh! Pay ₹500 processing fee to claim." '
          'Legitimate prizes never require upfront payment — always a scam.'),
      _Tip('💼', 'Job offer fraud',
          'Fake job offers asking for registration fees or documents. '
          'Research the company, call their official number, and never pay to get a job.'),
    ],
  ),
  _TipCategory(
    icon:  Icons.account_balance_rounded,
    name:  'Banking & UPI Safety',
    color: Color(0xFF4FC3F7),
    tips: [
      _Tip('📱', 'Use official banking apps only',
          'Download your bank\'s app from the Play Store by searching the bank name. '
          'Avoid apps from third-party links or QR codes.'),
      _Tip('💸', 'UPI request scam',
          'In UPI, you RECEIVE money by entering your PIN — but scammers say "enter PIN to receive." '
          'You only need PIN to SEND money. Never enter PIN for incoming requests.'),
      _Tip('🔒', 'Set transaction limits',
          'Keep your daily UPI and netbanking transfer limits low (e.g., ₹10,000/day). '
          'Increase it only when doing large transactions, then lower it again.'),
      _Tip('📊', 'Check statements weekly',
          'Review your bank and UPI statements every week. Report unknown transactions '
          'within 3 days for maximum chargeback protection (RBI guidelines).'),
    ],
  ),
  _TipCategory(
    icon:  Icons.link_rounded,
    name:  'Fake Websites & Phishing',
    color: Color(0xFFCE93D8),
    tips: [
      _Tip('🔍', 'Check the URL carefully',
          'Fake sites use URLs like "sbi-bank-login.com" or "amazon-offer.net". '
          'Always type the official address directly or use bookmarks.'),
      _Tip('🔐', 'Look for HTTPS',
          'Real banking sites use HTTPS (padlock icon). But note: scam sites '
          'can also use HTTPS. Check the full domain name, not just the padlock.'),
      _Tip('📧', 'Email phishing',
          'Emails with "Urgent: Your account will be suspended" links. '
          'Log into your account by typing the URL directly, never through email links.'),
      _Tip('🤳', 'QR code scams',
          'Fraudsters put fake QR stickers on legitimate payment QR codes. '
          'Always verify the payee name before completing a UPI transaction.'),
    ],
  ),
  _TipCategory(
    icon:  Icons.wifi_rounded,
    name:  'Wi-Fi & Network Safety',
    color: Color(0xFF69F0AE),
    tips: [
      _Tip('📶', 'Avoid public Wi-Fi for banking',
          'Free airport/café Wi-Fi can be monitored. Use mobile data for any '
          'financial transactions. If you must use Wi-Fi, enable a VPN.'),
      _Tip('📡', 'Fake hotspot attack',
          'Fraudsters create hotspots named "Free_Airport_WiFi" to intercept traffic. '
          'Always confirm the official Wi-Fi name with staff before connecting.'),
      _Tip('🔑', 'Secure your home router',
          'Change your router\'s default password. Use WPA3 or WPA2 encryption. '
          'Disable WPS (Wi-Fi Protected Setup) as it has known vulnerabilities.'),
    ],
  ),
  _TipCategory(
    icon:  Icons.phone_android_rounded,
    name:  'App & Device Safety',
    color: Color(0xFF7986CB),
    tips: [
      _Tip('🛡️', 'Review app permissions',
          'A flashlight app should not need SMS, camera, or contacts access. '
          'Revoke unnecessary permissions in Settings > Apps > [App] > Permissions.'),
      _Tip('🔄', 'Keep your phone updated',
          'Install security updates promptly. Patches fix vulnerabilities that hackers '
          'actively exploit. Enable auto-updates for the OS and apps.'),
      _Tip('🕵️', 'Detect hidden spy apps',
          'Signs of a compromised phone: battery drains fast, phone gets warm, '
          'unknown apps installed, high data usage in background. Run a scan!'),
      _Tip('💾', 'Backup your data',
          'Regular backups protect you from ransomware (hackers locking your files). '
          'Use Google Drive or an offline backup on a trusted device.'),
    ],
  ),
];

// ────────────────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────────────────
class CyberTipsScreen extends StatefulWidget {
  const CyberTipsScreen({super.key});

  @override
  State<CyberTipsScreen> createState() => _CyberTipsScreenState();
}

class _CyberTipsScreenState extends State<CyberTipsScreen> {
  int _selectedCategory = 0;
  int? _expandedTip;

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_selectedCategory];
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cyber Safety Tips'),
        backgroundColor: AppTheme.surface,
        leading: const BackButton(color: AppTheme.accent),
      ),
      body: Column(
        children: [
          // ── Category selector ──────────────────────────────────────────
          _buildCategoryRow(),

          // ── Category header ────────────────────────────────────────────
          _buildCategoryHeader(cat),

          // ── Tips list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: cat.tips.length,
              itemBuilder: (_, i) => _TipCard(
                tip:      cat.tips[i],
                color:    cat.color,
                expanded: _expandedTip == i,
                onTap: () => setState(() {
                  _expandedTip = _expandedTip == i ? null : i;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat      = _categories[i];
          final selected = i == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedCategory = i;
              _expandedTip = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? cat.color.withValues(alpha: 0.15)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? cat.color : const Color(0xFF2A3560),
                ),
              ),
              child: Row(
                children: [
                  Icon(cat.icon,
                      size: 15,
                      color: selected ? cat.color : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      color: selected ? cat.color : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryHeader(_TipCategory cat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cat.icon, color: cat.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name,
                    style: TextStyle(
                        color: cat.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('${cat.tips.length} tips — tap each to read more',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tip card with expand/collapse
// ────────────────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final _Tip       tip;
  final Color      color;
  final bool       expanded;
  final VoidCallback onTap;

  const _TipCard({
    required this.tip,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expanded ? color.withValues(alpha: 0.5) : const Color(0xFF2A3560),
          ),
        ),
        child: Column(
          children: [
            // Header row (always visible)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(tip.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip.title,
                      style: TextStyle(
                        color: expanded ? color : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: color,
                    size: 22,
                  ),
                ],
              ),
            ),
            // Expanded body
            if (expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: color.withValues(alpha: 0.2)),
                    const SizedBox(height: 8),
                    Text(
                      tip.body,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

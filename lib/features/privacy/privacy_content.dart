/// Versions and text of the privacy notice and terms shown in the app.
///
/// The server rejects a consent that quotes a different version (see backend `app/services/consent.py`), so change the
/// version string here AND there whenever the text changes in a way that needs a new decision.
///
/// IMPORTANT: this is a DRAFT written from what the application actually does (code review, 2026-11-14). It has NOT been
/// reviewed by counsel and makes no statement about legal compliance. Items marked "to be completed" are owner decisions
/// that have not been made yet (contact details, retention periods) and must be filled in before any release.
library;

const String kTermsVersion = '2026-11-14';
const String kPrivacyVersion = '2026-11-14';
const String kAiProcessingVersion = '2026-11-14';

const String kPurposeTerms = 'terms';
const String kPurposePrivacy = 'privacy_notice';
const String kPurposeAi = 'ai_processing';

class NoticeSection {
  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
  const NoticeSection(this.heading, {this.paragraphs = const [], this.bullets = const []});
}

const String kNoticeTitle = 'Privacy notice';
const String kNoticeStatus =
    'Draft - not yet reviewed by a lawyer. Version $kPrivacyVersion.';

const List<NoticeSection> kPrivacyNotice = [
  NoticeSection(
    'Who we are',
    paragraphs: [
      'SecureShield AI is a personal cyber-safety app. The operator\'s legal name and contact address are to be completed '
          'before release.',
    ],
  ),
  NoticeSection(
    'What we collect and why',
    bullets: [
      'Account and identity: your name, email address (verified with a code), and optionally a phone number (verified '
          'separately) and your address. Used to create and secure your account and to sign you in. If you use Google '
          'Sign-In we also receive your Google account identifier and email.',
      'Device: a device identifier, device name, platform, operating-system and app version, and the network address '
          'you connect from. Used to protect your account (for example a new-device alert). Device security checks '
          '(for example whether the phone is rooted) run on your phone.',
      'Apps on your phone: when you run an app scan, the names and permissions of installed apps are sent to our '
          'server to be scored. The app can also tell you when a new app is installed.',
      'Links, QR codes and scan results: a link you scan is sent to our server and may be checked against third-party '
          'threat lists. QR codes are read on your phone; the link inside is only checked if you choose to.',
      'Messages you submit: text you paste into the message analyser is sent to our server and checked with '
          'built-in rules. External AI processing is currently DISABLED, so it is not sent to any AI provider.',
      'Notifications and SMS: the bank-OTP alert feature, if you switch it on, reads notifications on your phone to '
          'warn you about fraud. The app does not read your SMS inbox and does not ask for SMS or call-log permission.',
      'Evidence and files: photos, recordings and files you add to the evidence locker are stored encrypted on our '
          'server and are visible only to you unless you share them.',
      'Location: only when you use a feature that needs it (for example the panic button or a Wi-Fi check), and only '
          'after you allow it in Android.',
      'Family and emergency contacts: names, phone numbers and emails of other people that you enter. A family '
          'invitation gives the other person a request to accept; nothing is shared with you until they accept.',
      'Wi-Fi and network activity: Wi-Fi scan results and the destinations of connections seen by the optional local '
          'VPN monitor are stored to show you alerts and reports.',
      'Technical logs: error logs help us fix faults. They are detached from your account when you delete it.',
      'Your consent choices: what you agreed to, which version of this notice, and when.',
    ],
  ),
  NoticeSection(
    'What stays on your phone',
    paragraphs: [
      'The OTP vault, the device security checks, the QR reader, and several detectors (digital-arrest, payment '
          'verifier, fake-bank SMS, SIM check) work on your phone without sending their content to our server.',
    ],
  ),
  NoticeSection(
    'Who else receives data',
    paragraphs: [
      'We do not sell your data and the app contains no advertising or analytics software. We do use these providers, '
          'and some of your data goes to them:',
    ],
    bullets: [
      'Email delivery provider (Resend): your email address and the code or notice being sent.',
      'Hosting provider (Railway): all data we store, including the database and uploaded files.',
      'Google: Google Sign-In (if you use it) and, when enabled, Google Safe Browsing checks of links you scan.',
      'abuse.ch URLhaus: links you scan, when enabled.',
      'AI provider (Anthropic): external AI processing is currently DISABLED, so nothing is sent. If it is ever '
          'switched on we will update this notice and ask for your consent before using your content.',
      'Video-call room (Jitsi public server): audio and video of a room you start, if you use that feature.',
      'SMS provider: none is in use at the moment.',
    ],
  ),
  NoticeSection(
    'How long we keep it',
    paragraphs: [
      'We keep your data until you delete your account. Specific retention periods for logs and backups are to be '
          'completed before release.',
    ],
  ),
  NoticeSection(
    'Your choices',
    bullets: [
      'Permissions: each Android permission is requested when you use the feature that needs it and can be withdrawn '
          'in Android settings at any time.',
      'AI processing: external AI is currently disabled. The optional choice in Privacy and data is only recorded '
          'for a future version; it does not turn anything on, and you can change it any time.',
      'Terms and this notice are needed to provide the service; if you do not accept them you cannot create an '
          'account. You cannot withdraw them while keeping the account; you can delete the account instead.',
    ],
  ),
  NoticeSection(
    'Deleting your account',
    paragraphs: [
      'You can delete your account in the app (Settings > Privacy and data > Delete account). We send a code to your '
          'verified email or phone to confirm it is you. Deletion removes the data you created: evidence and '
          'recordings (including files), devices and alerts, scans, AI conversations, family links, emergency '
          'contacts, reports, and your consent records.',
      'What we keep: an empty account record (an internal id and creation date only; every personal detail removed) '
          'and an audit trail of moderation actions, which may include reviewer notes. Backups made before deletion '
          'may hold your data until they expire; the backup schedule is to be completed.',
    ],
  ),
  NoticeSection(
    'Children',
    paragraphs: [
      'Family features may involve minors. Rules for parental consent are still being defined; do not add a child '
          'until they are published.',
    ],
  ),
  NoticeSection(
    'Changes',
    paragraphs: [
      'If this notice changes in a way that matters we will ask you to review and accept the new version.',
    ],
  ),
];

const String kTermsSummary =
    'Terms of service (draft): SecureShield AI gives general cyber-safety guidance and automated risk indicators. It is '
    'not a guarantee of protection, legal advice or a replacement for reporting fraud to your bank or the police '
    '(cybercrime.gov.in, 1930). Full terms are to be completed before release.';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'security/screenshot_prevention.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/screens/phone_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/phone_verify_screen.dart';
import '../features/privacy/screens/consent_screen.dart';
import '../features/privacy/screens/delete_account_screen.dart';
import '../features/privacy/screens/privacy_notice_screen.dart';
import '../features/privacy/screens/privacy_settings_screen.dart';
import '../features/auth/screens/profile_details_screen.dart';
import '../features/dashboard/screens/home_screen.dart';
import '../features/app_scanner/screens/app_scanner_screen.dart';
import '../features/app_scanner/screens/app_detail_screen.dart';
import '../features/alerts/screens/alerts_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/ai_coach/screens/ai_coach_screen.dart';
import '../features/link_scanner/screens/link_scanner_screen.dart';
import '../features/scam_hub/screens/scam_hub_screen.dart';
import '../features/evidence/screens/evidence_screen.dart';
import '../features/family/screens/family_screen.dart';
import '../features/scam_calls/screens/scam_calls_screen.dart';
import '../features/screen_recorder/screens/screen_recording_detector_screen.dart';
import '../features/otp_vault/screens/otp_vault_screen.dart';
import '../features/wifi_scanner/screens/wifi_scanner_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/call_recording/screens/recording_screen.dart';
import '../features/call_recording/screens/recording_preview_screen.dart';
import '../features/call_recording/screens/emergency_share_screen.dart';
import '../features/device_scan/screens/device_scan_screen.dart';
import '../features/device_scan/screens/scan_result_screen.dart';
import '../features/welcome/screens/welcome_screen.dart';
import '../features/welcome/screens/cyber_tips_screen.dart';
import '../features/welcome/screens/contacts_screen.dart';
import '../core/security/app_risk_engine.dart';
import '../features/bank_otp/screens/bank_otp_screen.dart';
import '../features/remote_detector/screens/remote_detector_screen.dart';
import '../features/complaint_email/screens/complaint_email_screen.dart';
import '../features/screen_recorder/screens/screen_recorder_screen.dart';
import '../features/consent_manager/screens/consent_manager_screen.dart';
import '../features/vpn_monitor/screens/vpn_monitor_screen.dart';
import '../features/package_monitor/screens/package_monitor_screen.dart';
import '../features/message_analyzer/screens/message_analyzer_screen.dart';
import '../features/community_scam/screens/community_scam_screen.dart';
import '../features/video_call/screens/video_call_screen.dart';
import '../features/app_monitor/screens/app_monitor_screen.dart';
import '../features/clone_detector/screens/clone_detector_screen.dart';
import '../features/elderly_protection/screens/elderly_mode_screen.dart';
import '../features/video_call/screens/fir_draft_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/banking_protection/screens/banking_protection_screen.dart';
import '../features/digital_arrest/screens/digital_arrest_screen.dart';
import '../features/fake_bank_sms/screens/fake_bank_sms_screen.dart';
import '../features/qr_scanner/screens/qr_scanner_screen.dart';
import '../features/payment_verifier/screens/payment_verifier_screen.dart';
import '../features/scam_news/screens/scam_news_screen.dart';

// Screens that show evidence, codes, personal data or private conversations hold FLAG_SECURE while mounted.
Widget _secure(Widget child) => ScreenshotPrevention.protect(child: child);

final _rootNavigatorKey  = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routes that never require auth — always accessible.
///
/// Banking Protection and the new threat-detection utilities run purely
/// on-device (no backend calls), so they're safe to expose pre-login.
/// This also makes the welcome-screen "Banking risk detected" strip
/// tappable for unauthenticated users.
const _publicRoutes = {
  '/welcome',
  '/device-scan',
  '/scan-result',
  '/tips',
  '/contacts',
  '/login',
  '/register',
  '/privacy',
  '/consent',
  '/otp',
  '/profile-details',
  '/banking-protection',
  '/digital-arrest',
  '/fake-bank-sms',
  '/qr-scanner',
  '/payment-verifier',
};

final routerProvider = Provider<GoRouter>((ref) {
  // ── IMPORTANT: only watch `isAuthenticated`, NOT the full AuthState. ──────
  // Watching the full state recreates GoRouter on every sendOtp / verifyOtp
  // call (which toggles isLoading), resetting the navigation stack to
  // initialLocation before context.push('/otp') fires.
  final isAuthenticated = ref.watch(
    authProvider.select((s) => s.isAuthenticated),
  );

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    redirect: (context, state) {
      final loc      = state.matchedLocation;
      final isPublic = _publicRoutes.any((r) => loc.startsWith(r));

      if (isPublic) {
        // Authenticated users are sent home from login / register.
        // Do NOT redirect from /otp — the OTP screen navigates to /home
        // itself (and shows a success dialog) after verifyOtp succeeds.
        // Redirecting here would destroy the success dialog before it shows.
        if (isAuthenticated &&
            (loc.startsWith('/login') || loc.startsWith('/register'))) {
          return '/home';
        }
        return null;
      }

      if (!isAuthenticated) return '/welcome';
      return null;
    },
    routes: [
      // ── Landing / Welcome ──────────────────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ── Public info ────────────────────────────────────────────────────
      GoRoute(path: '/tips',     builder: (_, __) => const CyberTipsScreen()),
      GoRoute(path: '/contacts', builder: (_, __) => const ContactsScreen()),

      // ── Device scan ────────────────────────────────────────────────────
      GoRoute(
        path: '/device-scan',
        builder: (_, __) => const DeviceScanScreen(),
      ),
      GoRoute(
        path: '/scan-result',
        builder: (context, state) {
          final summary = state.extra as ScanSummary?;
          return summary == null
              ? const DeviceScanScreen()
              : ScanResultScreen(summary: summary);
        },
      ),

      // ── Auth ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, state) {
          // Allow callers to pre-fill the identifier — e.g. when the register
          // screen sees a 409 "account already exists" and offers
          // "Sign in instead", it passes the email/phone via `extra`.
          final extra = state.extra;
          String? identifier;
          if (extra is Map) {
            identifier = (extra['identifier'] as String?)
                      ?? (extra['email']      as String?)
                      ?? (extra['phone']      as String?);
          } else if (extra is String) {
            identifier = extra;
          }
          return PhoneScreen(initialIdentifier: identifier);
        },
      ),
      GoRoute(
        path: '/register',
        // The consent screen comes first; the form appears once the mandatory acknowledgements are accepted.
        builder: (_, __) => const ConsentGate(child: RegisterScreen()),
      ),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyNoticeScreen()),
      GoRoute(
        path: '/consent',
        // Used when a sign-in would CREATE an account (Google): returns the choices to the caller.
        builder: (context, __) => ConsentScreen(
          onAccepted: (c) => context.pop(c),
        ),
      ),
      GoRoute(path: '/privacy-settings', builder: (_, __) => _secure(const PrivacySettingsScreen())),
      GoRoute(path: '/delete-account', builder: (_, __) => _secure(const DeleteAccountScreen())),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra;

          // New unified map format:
          // { identifier, isRegister, maskedEmail?, maskedPhone? }
          if (extra is Map) {
            final identifier  = extra['identifier']  as String?
                             ?? extra['phone']        as String? // legacy
                             ?? '';
            final isRegister  = extra['isRegister']  as bool?  ?? false;
            final maskedEmail = extra['maskedEmail']  as String?;
            final maskedPhone = extra['maskedPhone']  as String?;
            return _secure(OtpScreen(
              identifier:  identifier,
              isRegister:  isRegister,
              maskedEmail: maskedEmail,
              maskedPhone: maskedPhone,
            ));
          }

          // Legacy: extra was a plain String (phone number)
          return _secure(OtpScreen(
            identifier: extra as String? ?? '',
          ));
        },
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (_, __) => _secure(const PhoneVerifyScreen()),
      ),
      GoRoute(
        path: '/profile-details',
        builder: (_, __) => _secure(const ProfileDetailsScreen()),
      ),

      // ── Standalone authenticated screens ──────────────────────────────
      GoRoute(path: '/link-scanner',  builder: (_, __) => const LinkScannerScreen()),
      GoRoute(path: '/scam-hub',      builder: (_, __) => const ScamHubScreen()),
      GoRoute(path: '/evidence',      builder: (_, __) => _secure(const EvidenceScreen())),
      GoRoute(path: '/family',        builder: (_, __) => _secure(const FamilyScreen())),
      GoRoute(path: '/otp-vault',     builder: (_, __) => _secure(const OtpVaultScreen())),
      GoRoute(path: '/scam-calls',    builder: (_, __) => const ScamCallsScreen()),
      GoRoute(path: '/wifi-scanner',  builder: (_, __) => const WifiScannerScreen()),
      GoRoute(path: '/settings',      builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/call-recorder',
        builder: (context, state) {
          final autoStart = state.extra as bool? ?? false;
          return RecordingScreen(autoStart: autoStart);
        },
      ),
      GoRoute(path: '/recording-preview', builder: (_, __) => _secure(const RecordingPreviewScreen())),
      GoRoute(path: '/emergency-share',   builder: (_, __) => _secure(const EmergencyShareScreen())),
      GoRoute(path: '/bank-otp-monitor',  builder: (_, __) => _secure(const BankOtpScreen())),
      GoRoute(path: '/remote-detector',   builder: (_, __) => const RemoteDetectorScreen()),
      GoRoute(path: '/complaint-email',   builder: (_, __) => _secure(const ComplaintEmailScreen())),
      GoRoute(path: '/screen-recording-detector', builder: (_, __) => const ScreenRecordingDetectorScreen()),
      GoRoute(path: '/screen-recorder',   builder: (_, __) => const ScreenRecorderScreen()),
      GoRoute(path: '/consent-manager',   builder: (_, __) => const ConsentManagerScreen()),
      GoRoute(path: '/vpn-monitor',          builder: (_, __) => const VpnMonitorScreen()),
      GoRoute(path: '/package-monitor',      builder: (_, __) => const PackageMonitorScreen()),
      GoRoute(path: '/message-analyzer',     builder: (_, __) => const MessageAnalyzerScreen()),
      GoRoute(path: '/community-scams',      builder: (_, __) => const CommunityScamScreen()),
      GoRoute(path: '/video-call',            builder: (_, __) => const VideoCallScreen()),
      GoRoute(path: '/app-monitor',           builder: (_, __) => const AppMonitorScreen()),
      GoRoute(path: '/clone-detector',        builder: (_, __) => const CloneDetectorScreen()),
      GoRoute(path: '/elderly-mode',          builder: (_, __) => const ElderlyModeScreen()),
      GoRoute(path: '/fir-draft',            builder: (_, __) => _secure(const FirDraftScreen())),
      GoRoute(path: '/profile',              builder: (_, __) => _secure(const ProfileScreen())),
      GoRoute(path: '/banking-protection',   builder: (_, __) => const BankingProtectionScreen()),
      GoRoute(path: '/digital-arrest',       builder: (_, __) => const DigitalArrestScreen()),
      GoRoute(path: '/fake-bank-sms',        builder: (_, __) => const FakeBankSmsScreen()),
      GoRoute(path: '/qr-scanner',           builder: (_, __) => const QrScannerScreen()),
      GoRoute(path: '/payment-verifier',     builder: (_, __) => const PaymentVerifierScreen()),
      GoRoute(path: '/scam-news',            builder: (_, __) => const ScamNewsScreen()),
      GoRoute(
        path: '/app-detail',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return AppDetailScreen(scanResult: data);
        },
      ),

      // ── Shell (bottom nav) ─────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            HomeScreen(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: DashboardTab()),
          ),
          GoRoute(
            path: '/home/scanner',
            pageBuilder: (_, __) => const NoTransitionPage(child: AppScannerScreen()),
          ),
          GoRoute(
            path: '/home/alerts',
            pageBuilder: (_, __) => const NoTransitionPage(child: AlertsScreen()),
          ),
          GoRoute(
            path: '/home/reports',
            pageBuilder: (_, __) => const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/home/ai-coach',
            pageBuilder: (_, __) => NoTransitionPage(child: _secure(const AiCoachScreen())),
          ),
        ],
      ),
    ],
  );
});

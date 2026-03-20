import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/screens/phone_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/dashboard/screens/home_screen.dart';
import '../features/app_scanner/screens/app_scanner_screen.dart';
import '../features/app_scanner/screens/app_detail_screen.dart';
import '../features/alerts/screens/alerts_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/ai_coach/screens/ai_coach_screen.dart';
import '../features/otp_vault/screens/otp_vault_screen.dart';
import '../features/link_scanner/screens/link_scanner_screen.dart';
import '../features/evidence/screens/evidence_screen.dart';
import '../features/family/screens/family_screen.dart';
import '../features/wifi_scanner/screens/wifi_scanner_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/device_scan/scan_provider.dart';
import '../features/device_scan/screens/device_scan_screen.dart';
import '../features/device_scan/screens/scan_result_screen.dart';
import '../features/welcome/screens/welcome_screen.dart';
import '../features/welcome/screens/cyber_tips_screen.dart';
import '../features/welcome/screens/contacts_screen.dart';
import '../core/security/app_risk_engine.dart';

final _rootNavigatorKey  = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routes that never require auth or scan — always accessible
const _publicRoutes = {
  '/welcome',
  '/device-scan',
  '/scan-result',
  '/tips',
  '/contacts',
  '/login',
  '/otp',
};

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final scanDone  = ref.watch(deviceScanDoneProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',   // ← User lands here first
    redirect: (context, state) {
      final loc       = state.matchedLocation;
      final isPublic  = _publicRoutes.any((r) => loc.startsWith(r));
      final isLoggedIn = authState.isAuthenticated;

      // Public routes — never redirect
      if (isPublic) {
        // If already logged in and trying to hit /login or /otp → send home
        if (isLoggedIn &&
            (loc.startsWith('/login') || loc.startsWith('/otp'))) {
          return '/home';
        }
        return null;
      }

      // Protected routes — require login
      if (!isLoggedIn) return '/welcome';
      return null;
    },
    routes: [
      // ── Landing / Welcome ────────────────────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ── Public info screens ──────────────────────────────────────────────
      GoRoute(
        path: '/tips',
        builder: (context, state) => const CyberTipsScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),

      // ── Device scan (user-initiated from Welcome) ────────────────────────
      GoRoute(
        path: '/device-scan',
        builder: (context, state) => const DeviceScanScreen(),
      ),
      GoRoute(
        path: '/scan-result',
        builder: (context, state) {
          final summary = state.extra as ScanSummary?;
          if (summary == null) return const DeviceScanScreen();
          return ScanResultScreen(summary: summary);
        },
      ),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),

      // ── Standalone authenticated screens ─────────────────────────────────
      GoRoute(
        path: '/otp-vault',
        builder: (context, state) => const OtpVaultScreen(),
      ),
      GoRoute(
        path: '/link-scanner',
        builder: (context, state) => const LinkScannerScreen(),
      ),
      GoRoute(
        path: '/evidence',
        builder: (context, state) => const EvidenceScreen(),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyScreen(),
      ),
      GoRoute(
        path: '/wifi-scanner',
        builder: (context, state) => const WifiScannerScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/app-detail',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return AppDetailScreen(scanResult: data);
        },
      ),

      // ── Shell (bottom-nav) ────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return HomeScreen(child: child, location: state.matchedLocation);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardTab()),
          ),
          GoRoute(
            path: '/home/scanner',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AppScannerScreen()),
          ),
          GoRoute(
            path: '/home/alerts',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AlertsScreen()),
          ),
          GoRoute(
            path: '/home/reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/home/ai-coach',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AiCoachScreen()),
          ),
        ],
      ),
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_config.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/security/security_service.dart';
import 'core/security/encryption_service.dart';
import 'core/security/biometric_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Resolve backend URL (emulator vs real device)
  await AppConfig.initialize();

  // 2. Initialize AES-256 encryption (generates/loads key from Keystore)
  await EncryptionService.initialize();

  // 3. Run device security checks (root, emulator, screen recording)
  final secReport = await SecurityService.runChecks();
  if (secReport.riskLevel == 'danger') {
    // Rooted device — show blocking warning
    runApp(SecurityBlockApp(reasons: secReport.riskReasons));
    return;
  }

  runApp(ProviderScope(
    child: SecureShieldApp(securityReport: secReport),
  ));
}

class SecureShieldApp extends ConsumerWidget {
  final SecurityReport securityReport;
  const SecureShieldApp({super.key, required this.securityReport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SecureShield AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

/// Shown when device fails critical security check (e.g. rooted)
class SecurityBlockApp extends StatelessWidget {
  final List<String> reasons;
  const SecurityBlockApp({super.key, required this.reasons});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gpp_bad, size: 80, color: Color(0xFFFF1744)),
                  const SizedBox(height: 24),
                  const Text(
                    'Security Risk Detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SecureShield AI cannot run on a compromised device.\nThis protects your sensitive security data.',
                    style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ...reasons.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber, color: Color(0xFFFF9100), size: 16),
                        const SizedBox(width: 8),
                        Text(r, style: const TextStyle(color: Color(0xFFFF9100), fontSize: 13)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

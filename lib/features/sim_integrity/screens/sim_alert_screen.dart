import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/security/sim_integrity_service.dart';

/// Full-screen alert shown when [SimIntegrityService.check] returns an
/// alertable verdict (changed / removedSim / mixedChange).
///
/// Two primary actions:
///   • "This was me" — accepts the new SIM as baseline and dismisses
///   • "Not me — secure accounts" — opens the cybercrime portal +
///     keeps the baseline unchanged so the alert returns next launch
class SimAlertScreen extends StatelessWidget {
  final SimIntegrityReport report;
  final VoidCallback? onDismiss;

  const SimAlertScreen({super.key, required this.report, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB00020),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.sim_card_alert, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                '⚠ SIM Change Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your SIM card configuration changed since the last app launch. '
                'If you did NOT swap or replace your SIM, your phone number may '
                'have been ported out by a fraudster.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Details box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What changed:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 8),
                    for (final c in report.humanReadableChanges)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(color: Colors.white, fontSize: 14)),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4,
                                  )),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Primary action — report fraud
              ElevatedButton.icon(
                onPressed: () async {
                  await _openFraudReport();
                },
                icon: const Icon(Icons.gpp_bad_rounded),
                label: const Text("Not me — report fraud (1930)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB00020),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary — accept change
              OutlinedButton.icon(
                onPressed: () async {
                  await SimIntegrityService.instance
                      .confirmAndUpdateBaseline(report.current);
                  if (context.mounted) {
                    onDismiss?.call();
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('This was me — accept change',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const Spacer(),
              const Text(
                'Cybercrime helpline: 1930',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFraudReport() async {
    // Tries phone call first; falls back to web portal.
    final tel = Uri.parse('tel:1930');
    if (await canLaunchUrl(tel)) {
      await launchUrl(tel);
      return;
    }
    final web = Uri.parse('https://cybercrime.gov.in/');
    if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'privacy_api.dart';
import 'screens/consent_screen.dart';

/// Whether the signed-in account has an up-to-date acceptance on record, as the SERVER reports it.
/// null = unknown (signed out, or the server could not be reached): the app does not block on an unknown state.
final consentGateProvider = FutureProvider<bool?>((ref) async {
  final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
  if (!signedIn) return null;
  try {
    return (await ref.read(privacyApiProvider).getConsents()).requiredUpToDate;
  } catch (_) {
    return null;
  }
});

/// Wraps the whole app: a signed-in account whose server record says the terms / privacy notice were never accepted at the
/// current version (existing users, or after a notice update) sees the consent screen before anything else.
class ConsentGateOverlay extends ConsumerWidget {
  final Widget child;
  const ConsentGateOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(consentGateProvider).valueOrNull == false;
    if (!blocked) return child;
    // Its own Navigator: this widget sits above the router's, and the screen needs dialogs and pushes.
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const ConsentUpdateScreen()),
    );
  }
}

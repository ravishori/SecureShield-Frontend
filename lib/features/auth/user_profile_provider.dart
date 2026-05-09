import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'user_api.dart';

/// Fetches the current user's profile from the API.
/// Invalidated by [authProvider] state changes via [profileProvider].
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Only fetch if logged in
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return {};
  return UserApi().getMe();
});

/// Computes profile completeness as an integer percentage (0–100).
///
/// Required fields (7 total — each worth ~14 points):
///   full_name, phone/email, flat_no, city, state, pin_code, email
/// Bonus: alt_phone pushes to 100.
final profileCompletenessProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile.isEmpty) return 0;

  bool filled(String key) {
    final v = profile[key];
    return v != null && v.toString().trim().isNotEmpty;
  }

  final required = [
    filled('full_name') || (filled('first_name') && filled('last_name')),
    filled('phone') || filled('email'),
    filled('flat_no'),
    filled('city'),
    filled('state'),
    filled('pin_code'),
    filled('email'),
  ];

  final filledCount = required.where((v) => v).length;
  int pct = ((filledCount / required.length) * 100).round();

  // Bonus: alt_phone pushes to 100%
  if (pct >= 86 && filled('alt_phone')) pct = 100;

  return pct.clamp(0, 100);
});

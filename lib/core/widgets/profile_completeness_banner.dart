import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../../features/auth/user_profile_provider.dart';

/// Dismissible banner shown when profile completeness < 80%.
/// Place at the top of authenticated screens.
class ProfileCompletenessBanner extends ConsumerStatefulWidget {
  const ProfileCompletenessBanner({super.key});

  @override
  ConsumerState<ProfileCompletenessBanner> createState() =>
      _ProfileCompletenessBannerState();
}

class _ProfileCompletenessBannerState
    extends ConsumerState<ProfileCompletenessBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final completeness = ref.watch(profileCompletenessProvider);
    return completeness.when(
      data: (percent) {
        if (percent >= 80) return const SizedBox.shrink();
        final accent = AppTheme.accentOf(context);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_circle_outlined, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Profile $percent% complete — complete it for full protection',
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: Icon(Icons.close, size: 16, color: accent.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/profile-details'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: accent,
                  ),
                  child: const Text('Complete Profile →',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

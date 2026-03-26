import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/models/profile.dart';
import '../../core/models/user_hobby.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/theme_provider.dart';

/// Calculates how complete a profile is (0.0 – 1.0).
/// Fields checked: avatar, bio, gender, date_of_birth, location, hobbies.
double profileCompletion(Profile profile, List<UserHobby> hobbies) {
  int filled = 0;
  if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) filled++;
  if (profile.bio != null && profile.bio!.isNotEmpty) filled++;
  if (profile.gender != null && profile.gender!.isNotEmpty) filled++;
  if (profile.dateOfBirth != null) filled++;
  if (profile.location != null && profile.location!.isNotEmpty) filled++;
  if (hobbies.isNotEmpty) filled++;
  return filled / 6;
}

/// List of human-readable labels for the fields that are still empty.
List<String> missingFields(Profile profile, List<UserHobby> hobbies) {
  final missing = <String>[];
  if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
    missing.add('Profile photo');
  }
  if (profile.bio == null || profile.bio!.isEmpty) missing.add('Bio');
  if (profile.gender == null || profile.gender!.isEmpty) missing.add('Gender');
  if (profile.dateOfBirth == null) missing.add('Date of birth');
  if (profile.location == null || profile.location!.isEmpty) {
    missing.add('Location');
  }
  if (hobbies.isEmpty) missing.add('Interests');
  return missing;
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline card — used on the Profile screen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileCompletionCard extends ConsumerWidget {
  const ProfileCompletionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(fullProfileProvider);
    final hobbiesAsync = ref.watch(userHobbiesProvider(userId));

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final hobbies = hobbiesAsync.value ?? [];
        final completion = profileCompletion(profile, hobbies);
        if (completion >= 1.0) return const SizedBox.shrink();

        final colors = ref.watch(appColorSchemeProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final percent = (completion * 100).round();
        final missing = missingFields(profile, hobbies);

        return Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withValues(alpha: 0.2),
                          colors.accent.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_add_rounded,
                        size: 18, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete your profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '$percent% done',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/edit-profile'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.accent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 5,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Missing: ${missing.take(3).join(', ')}${missing.length > 3 ? ' +${missing.length - 3} more' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay banner — used on the Home screen (dismissible)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileCompletionBanner extends ConsumerWidget {
  final VoidCallback onDismiss;

  const ProfileCompletionBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(fullProfileProvider);
    final hobbiesAsync = ref.watch(userHobbiesProvider(userId));

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final hobbies = hobbiesAsync.value ?? [];
        final completion = profileCompletion(profile, hobbies);
        if (completion >= 1.0) return const SizedBox.shrink();

        final colors = ref.watch(appColorSchemeProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final percent = (completion * 100).round();

        return Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Progress ring / icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: completion,
                        strokeWidth: 3.5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.07),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Complete your profile',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add a photo, bio, and more to stand out',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.push('/edit-profile'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.accent],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'Go',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

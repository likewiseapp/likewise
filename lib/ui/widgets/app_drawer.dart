import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/navigation_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/app_theme.dart';
import '../../core/theme_provider.dart';
import '../screens/settings/report_problem_sheet.dart';
import 'app_cached_image.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTab = ref.watch(selectedTabProvider);
    final profile = ref.watch(currentProfileProvider).value;

    final bg = isDark ? AppColors.darkScaffold : Colors.white;

    final name = profile?.fullName ?? 'Guest';
    final username = profile?.username ?? 'guest';
    final avatarUrl = profile?.avatarUrl ?? '';

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // ── Profile header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: AppCachedImage(
                      imageUrl: avatarUrl,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(50),
                      errorWidget: Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── App branding pill ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                      colors.accent.withValues(alpha: isDark ? 0.12 : 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [colors.primary, colors.accent],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'likewise',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v1.0',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Nav items ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _NavItem(
                      icon: Icons.explore_rounded,
                      label: 'Explore',
                      selected: currentTab == 0,
                      colors: colors,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(selectedTabProvider.notifier).setTab(0);
                      },
                    ),
                    _NavItem(
                      icon: Icons.video_library_rounded,
                      label: 'Waves',
                      selected: currentTab == 1,
                      colors: colors,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(selectedTabProvider.notifier).setTab(1);
                      },
                    ),
                    _NavItem(
                      icon: Icons.search_rounded,
                      label: 'Discover',
                      selected: currentTab == 2,
                      colors: colors,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(selectedTabProvider.notifier).setTab(2);
                      },
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: 'My Profile',
                      selected: currentTab == 3,
                      colors: colors,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(selectedTabProvider.notifier).setTab(3);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      colors: colors,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/settings');
                      },
                    ),
                    _NavItem(
                      icon: Icons.flag_outlined,
                      label: 'Report a Problem',
                      colors: colors,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        showReportProblemSheet(context);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Log out ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  await ref.read(authServiceProvider).signOut();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Colors.red.withValues(alpha: isDark ? 0.8 : 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.red.withValues(
                            alpha: isDark ? 0.8 : 0.7,
                          ),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final AppColorScheme colors;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.colors,
    required this.isDark,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: isDark ? 0.18 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? colors.primary
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? colors.primary
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            if (selected) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

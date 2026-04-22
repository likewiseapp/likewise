import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

import '../../../core/app_theme.dart';
import '../../../core/models/hobby.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/avatar_popup.dart';
import '../../widgets/profile_completion_banner.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _retryCount = 0;
  bool _isRetrying = false;

  void _scheduleRetry() {
    if (_isRetrying || _retryCount >= 4) return;
    _isRetrying = true;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _retryCount++;
          _isRetrying = false;
        });
        ref.invalidate(currentProfileProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.darkScaffold
            : AppColors.lightScaffold,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider);
    final hobbiesAsync = ref.watch(userHobbiesProvider(userId));
    final allHobbiesAsync = ref.watch(allHobbiesProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : AppColors.lightScaffold,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          _scheduleRetry();
          return _retryCount >= 4
              ? _RetryWidget(
                  isDark: isDark,
                  onRetry: () {
                    setState(() {
                      _retryCount = 0;
                      _isRetrying = false;
                    });
                    ref.invalidate(currentProfileProvider);
                  },
                )
              : const Center(child: CircularProgressIndicator());
        },
        data: (profile) {
          if (profile == null) {
            _scheduleRetry();
            return _retryCount >= 4
                ? _RetryWidget(
                    isDark: isDark,
                    onRetry: () {
                      setState(() {
                        _retryCount = 0;
                        _isRetrying = false;
                      });
                      ref.invalidate(currentProfileProvider);
                    },
                  )
                : const Center(child: CircularProgressIndicator());
          }
          _retryCount = 0;

          final userHobbies = hobbiesAsync.value ?? [];
          final sortedUserHobbies = [...userHobbies]
            ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
          final hobbyEntries = sortedUserHobbies
              .where((uh) => uh.hobby?.name != null)
              .map((uh) => (name: uh.hobby!.name, isPrimary: uh.isPrimary))
              .toList();
          final allHobbies = allHobbiesAsync.value ?? [];

          return SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Sticky header: "Profile" + Settings shortcut ─────
                SliverAppBar(
                  pinned: true,
                  primary: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 56,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          'Profile',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/settings');
                          },
                          child: Row(
                            children: [
                              Text(
                                'Settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.menu_rounded,
                                size: 26,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      // ── Identity row ───────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAvatar(colors, profile.avatarUrl),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20,
                                              height: 1.1,
                                            ),
                                      ),
                                    ),
                                    if (profile.isVerified) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.verified_rounded,
                                        color: colors.primary,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${profile.username}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (profile.location != null &&
                                    profile.location!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_rounded,
                                          size: 13,
                                          color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          profile.location!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        context.push(
                                          '/follow-list/${profile.id}/0?name=${Uri.encodeComponent(profile.fullName)}',
                                        );
                                      },
                                      child: _buildCompactStat(
                                        context,
                                        _formatCount(profile.followerCount),
                                        'Followers',
                                        isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        context.push(
                                          '/follow-list/${profile.id}/1?name=${Uri.encodeComponent(profile.fullName)}',
                                        );
                                      },
                                      child: _buildCompactStat(
                                        context,
                                        _formatCount(profile.followingCount),
                                        'Following',
                                        isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (profile.bio != null && profile.bio!.isNotEmpty)
                        Text(
                          profile.bio!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 12),

                      // ── Profile completion card ─────────────────────────
                      const ProfileCompletionCard(),

                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Edit Profile',
                              isPrimary: true,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => context.push('/edit-profile'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Share Profile',
                              isPrimary: false,
                              colors: colors,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                    ]),
                  ),
                ),

                if (hobbyEntries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'MY VIBE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: _buildStickerWall(
                          context, colors, isDark, hobbyEntries, allHobbies),
                    ),
                  ),
                ],

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Text(
                      'MY WAVES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),

                _MyWavesSection(userId: userId, isDark: isDark),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100 + MediaQuery.of(context).padding.bottom,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildAvatar(AppColorScheme colors, String? avatarUrl) {
    return GestureDetector(
      onTap: () => showAvatarPopup(context, avatarUrl),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AppCachedImage(
            imageUrl: avatarUrl,
            width: 80,
            height: 80,
            borderRadius: BorderRadius.circular(50),
            errorWidget: Container(
              color: Colors.grey.shade300,
              child: Icon(Icons.person,
                  size: 40, color: Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(
    BuildContext context,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label, {
    required bool isPrimary,
    required AppColorScheme colors,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isPrimary
              ? (isDark ? Colors.white : Colors.black)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white : Colors.black),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerWall(
    BuildContext context,
    AppColorScheme colors,
    bool isDark,
    List<({String name, bool isPrimary})> hobbyEntries,
    List<Hobby> allHobbies,
  ) {
    final random = math.Random(42);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hobbyEntries.map((entry) {
        final hobby =
            allHobbies.where((h) => h.name == entry.name).firstOrNull;
        final color = hobby?.colorValue ?? colors.primary;
        final icon = hobby?.icon ?? '✨';
        final rotation = (random.nextDouble() - 0.5) * 0.1;

        return Transform.rotate(
          angle: entry.isPrimary ? 0 : rotation,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: entry.isPrimary ? 12 : 10,
              vertical: entry.isPrimary ? 8 : 7,
            ),
            decoration: BoxDecoration(
              color: entry.isPrimary
                  ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                  : (isDark ? AppColors.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(
                    alpha: entry.isPrimary ? 0.6 : 0.3),
                width: entry.isPrimary ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(
                      alpha: entry.isPrimary ? 0.22 : 0.12),
                  blurRadius: entry.isPrimary ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon,
                    style:
                        TextStyle(fontSize: entry.isPrimary ? 15 : 14)),
                const SizedBox(width: 6),
                Text(
                  entry.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: entry.isPrimary
                        ? color
                        : (isDark ? Colors.white : Colors.black87),
                    fontSize: entry.isPrimary ? 13 : 12,
                  ),
                ),
                if (entry.isPrimary) ...[
                  const SizedBox(width: 4),
                  const Text('⭐', style: TextStyle(fontSize: 11)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RetryWidget extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _RetryWidget({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'Unable to load profile',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── My Waves section ─────────────────────────────────────────────────────────

class _MyWavesSection extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _MyWavesSection({required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wavesAsync = ref.watch(userWavesProvider(userId));

    return wavesAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Couldn\'t load your waves',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
        ),
      ),
      data: (waves) {
        if (waves.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _MyWavesEmpty(isDark: isDark),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 9 / 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _MyWaveTile(wave: waves[index]),
              childCount: waves.length,
            ),
          ),
        );
      },
    );
  }
}

class _MyWavesEmpty extends StatelessWidget {
  final bool isDark;
  const _MyWavesEmpty({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.videocam_outlined,
              size: 26,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No waves yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share your first video',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyWaveTile extends StatelessWidget {
  final dynamic wave;

  const _MyWaveTile({required this.wave});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppCachedImage(
            imageUrl: wave.thumbnailUrl,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: Colors.grey.shade900,
              child: const Icon(Icons.videocam_outlined,
                  color: Colors.white24),
            ),
          ),
          // Bottom gradient for view count readability
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
                stops: [0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 5,
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded,
                    size: 14, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  _compactCount(wave.viewCount as int),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _compactCount(int n) {
  if (n < 1000) return n.toString();
  final k = n / 1000;
  if (k < 10) return '${k.toStringAsFixed(1)}k';
  if (k < 1000) return '${k.toStringAsFixed(0)}k';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

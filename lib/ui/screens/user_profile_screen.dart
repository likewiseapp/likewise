import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/hobby.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/block_providers.dart';
import '../../core/providers/explore_providers.dart';
import '../../core/providers/follow_providers.dart';
import '../../core/providers/hobby_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/services/block_service.dart';
import '../../core/services/follow_service.dart';
import '../../core/services/message_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/report_service.dart';
import '../../core/app_theme.dart';
import '../../core/theme_provider.dart';
import '../widgets/app_cached_image.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  // Optimistic follow state — null means "use provider value"
  bool? _isFollowingOverride;
  bool _followLoading = false;
  bool _messageLoading = false;
  bool _blockLoading = false;

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_followLoading) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() {
      _followLoading = true;
      _isFollowingOverride = !currentlyFollowing;
    });

    final client = ref.read(supabaseProvider);
    try {
      if (currentlyFollowing) {
        await FollowService(client).unfollow(currentUserId, widget.userId);
        await NotificationService(client).deleteFollowNotification(
          recipientId: widget.userId,
          actorId: currentUserId,
        );
      } else {
        await FollowService(client).follow(currentUserId, widget.userId);
        await NotificationService(client).createFollowNotification(
          recipientId: widget.userId,
          actorId: currentUserId,
        );
      }

      // Refresh follow state + both profiles' counts
      ref.invalidate(isFollowingProvider(widget.userId));
      ref.invalidate(profileStatsProvider(widget.userId));
      ref.invalidate(currentProfileProvider);
      ref.invalidate(followersProvider(widget.userId));
      ref.invalidate(followingProvider(currentUserId));
      ref.invalidate(followingIdsProvider);
      ref.invalidate(notificationsProvider);
    } catch (_) {
      // Revert optimistic update on error
      if (mounted) setState(() => _isFollowingOverride = currentlyFollowing);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _openChat(String otherName, String otherAvatar) async {
    if (_messageLoading) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() => _messageLoading = true);

    try {
      final client = ref.read(supabaseProvider);
      final conversationId = await MessageService(client)
          .getOrCreateConversation(currentUserId, widget.userId);
      if (!mounted) return;
      if (conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This user is not accepting messages'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      final name = Uri.encodeComponent(otherName);
      final avatar = Uri.encodeComponent(otherAvatar);
      final uid = Uri.encodeComponent(widget.userId);
      context.push('/chat/$conversationId?name=$name&avatar=$avatar&userId=$uid');
    } finally {
      if (mounted) setState(() => _messageLoading = false);
    }
  }

  Future<void> _blockUser(String targetName) async {
    if (_blockLoading) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() => _blockLoading = true);

    final client = ref.read(supabaseProvider);
    try {
      final followService = FollowService(client);
      final notificationService = NotificationService(client);

      // Remove A→B follow if exists
      final currentlyFollowing =
          _isFollowingOverride ?? ref.read(isFollowingProvider(widget.userId)).value ?? false;
      if (currentlyFollowing) {
        await followService.unfollow(currentUserId, widget.userId);
        await notificationService.deleteFollowNotification(
          recipientId: widget.userId,
          actorId: currentUserId,
        );
      }

      // Remove B→A follow if exists
      final theyFollowMe = await followService.isFollowing(widget.userId, currentUserId);
      if (theyFollowMe) {
        await followService.unfollow(widget.userId, currentUserId);
        await notificationService.deleteFollowNotification(
          recipientId: currentUserId,
          actorId: widget.userId,
        );
      }

      await BlockService(client).blockUser(currentUserId, widget.userId);

      // Invalidate all cached data so the blocked user disappears everywhere
      ref.invalidate(isFollowingProvider(widget.userId));
      ref.invalidate(profileStatsProvider(widget.userId));
      ref.invalidate(isBlockingProvider(widget.userId));
      ref.invalidate(currentProfileProvider);
      ref.invalidate(followingIdsProvider);
      ref.invalidate(followersProvider(currentUserId));
      ref.invalidate(followersProvider(widget.userId));
      ref.invalidate(followingProvider(currentUserId));
      ref.invalidate(followingProvider(widget.userId));
      ref.invalidate(twinMatchProvider);
      ref.invalidate(nearbyUsersProvider);
      ref.invalidate(topCreatorsProvider);
      ref.invalidate(searchResultsProvider);

      if (mounted) {
        Navigator.of(context).pop(); // leave their profile immediately
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _blockLoading = false);
    }
  }

  void _showBlockDialog(String targetName) {
    HapticFeedback.lightImpact();
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Block $targetName?'),
        content: Text(
          'They won\'t be able to see your profile or find you. '
          'You also won\'t see them in your feed or search.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Block',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _blockUser(targetName);
    });
  }

  void _showReportSheet(String targetName) {
    HapticFeedback.lightImpact();
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    final client = ref.read(supabaseProvider);
    final colors = ref.read(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportBottomSheet(
        targetName: targetName,
        targetId: widget.userId,
        reporterId: currentUserId,
        reportService: ReportService(client),
        colors: colors,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(profileStatsProvider(widget.userId));
    final hobbiesAsync = ref.watch(userHobbiesProvider(widget.userId));
    final allHobbiesAsync = ref.watch(allHobbiesProvider);
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
    final isBlockedByMe =
        ref.watch(isBlockedByProvider(widget.userId)).value ?? false;

    // Resolved follow state: optimistic override beats provider value
    final isFollowing =
        _isFollowingOverride ?? isFollowingAsync.value ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Something went wrong')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }

          final userHobbies = hobbiesAsync.value ?? [];
          final sortedUserHobbies = [...userHobbies]
            ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
          final hobbyNames = sortedUserHobbies
              .map((uh) => uh.hobby?.name)
              .whereType<String>()
              .toList();
          final allHobbies = allHobbiesAsync.value ?? [];

          // Only adjust count while our optimistic override differs from
          // the server state.  Once the provider re-fetches and catches up,
          // the adjustment drops to 0 automatically — no double-counting.
          final serverFollowing = isFollowingAsync.value ?? false;
          final followerAdjust =
              _isFollowingOverride != null && _isFollowingOverride != serverFollowing
                  ? (_isFollowingOverride! ? 1 : -1)
                  : 0;
          final displayFollowerCount = profile.followerCount + followerAdjust;

          final currentUserId = ref.watch(currentUserIdProvider);

          // Profile visibility enforcement
          final visibility = profile.profileVisibility;
          final isProfileRestricted = !isBlockedByMe &&
              ((visibility == 'private') ||
               (visibility == 'followers_only' && !isFollowing));

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ─────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor:
                    isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (currentUserId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        elevation: 8,
                        onSelected: (value) {
                          if (value == 'block') {
                            _showBlockDialog(profile.fullName);
                          } else if (value == 'report') {
                            _showReportSheet(profile.fullName);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Report',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.block_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Block ${profile.fullName}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ── Profile Header ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    children: [
                      // Avatar — blank circle when blocked by this user
                      if (isBlockedByMe)
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Icon(Icons.person_rounded,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.black26),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [colors.primary, colors.accent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppColors.darkScaffold
                                  : AppColors.lightScaffold,
                            ),
                            child: AppCachedImage(
                              imageUrl: profile.avatarUrl,
                              width: 88,
                              height: 88,
                              borderRadius: BorderRadius.circular(50),
                              errorWidget: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade300,
                                ),
                                child: Icon(Icons.person,
                                    size: 44, color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Name + verified badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              profile.fullName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                    height: 1.1,
                                  ),
                            ),
                          ),
                          if (profile.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.verified_rounded,
                                color: colors.primary, size: 20),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '@${profile.username}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),

                      if (profile.location != null && profile.location!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                profile.location!,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Stats row — dashes when blocked/private, non-tappable when blocked/private
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: (isBlockedByMe || isProfileRestricted)
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    context.push(
                                      '/follow-list/${profile.id}/0?name=${Uri.encodeComponent(profile.fullName)}',
                                    );
                                  },
                            child: _buildCompactStat(
                              context,
                              (isBlockedByMe || isProfileRestricted) ? '—' : _formatCount(displayFollowerCount),
                              'Followers',
                              isDark,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                          GestureDetector(
                            onTap: (isBlockedByMe || isProfileRestricted)
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    context.push(
                                      '/follow-list/${profile.id}/1?name=${Uri.encodeComponent(profile.fullName)}',
                                    );
                                  },
                            child: _buildCompactStat(
                              context,
                              (isBlockedByMe || isProfileRestricted) ? '—' : _formatCount(profile.followingCount),
                              'Following',
                              isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Bio — hidden when blocked or private
                      if (!isBlockedByMe && !isProfileRestricted && profile.bio != null && profile.bio!.isNotEmpty)
                        Text(
                          profile.bio!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 16),

                      // Action buttons — disabled when blocked
                      Row(
                        children: [
                          Expanded(
                            child: _buildFollowButton(
                              colors,
                              isDark,
                              isFollowing: isFollowing,
                              loading: _followLoading,
                              disabled: isBlockedByMe,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              _messageLoading ? '...' : 'Message',
                              isPrimary: false,
                              colors: colors,
                              isDark: isDark,
                              onTap: (isBlockedByMe || isProfileRestricted)
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _openChat(
                                        profile.fullName,
                                        profile.avatarUrl ?? '',
                                      );
                                    },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── Private account notice ────────────────────────────────
              if (isProfileRestricted)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 40,
                            color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This account is private',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            visibility == 'private'
                                ? 'This profile is not visible to anyone.'
                                : 'Follow this account to see their profile.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── MY VIBE ──────────────────────────────────────────────────
              if (!isBlockedByMe && !isProfileRestricted && hobbyNames.isNotEmpty) ...[
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
                        context, colors, isDark, hobbyNames, allHobbies),
                  ),
                ),
              ],

              // ── MY REELS ─────────────────────────────────────────────────
              if (!isBlockedByMe && !isProfileRestricted)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Text(
                    'MY REELS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),

              if (!isBlockedByMe && !isProfileRestricted)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 160,
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
                        Icon(
                          Icons.videocam_outlined,
                          size: 30,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No reels yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(
    AppColorScheme colors,
    bool isDark, {
    required bool isFollowing,
    required bool loading,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              _toggleFollow(isFollowing);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 44,
        decoration: BoxDecoration(
          color: disabled
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04))
              : isFollowing
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.8))
                  : (isDark ? Colors.white : Colors.black),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isFollowing
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.black : Colors.white),
                  ),
                )
              : Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: disabled
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : isFollowing
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.black : Colors.white),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
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
    final disabled = onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: disabled
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04))
              : isPrimary
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: disabled
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : isPrimary
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
    List<String> hobbyNames,
    List<Hobby> allHobbies,
  ) {
    final random = math.Random(
      widget.userId.codeUnits.fold<int>(0, (a, b) => a + b),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hobbyNames.map((hobbyName) {
        final hobby =
            allHobbies.where((h) => h.name == hobbyName).firstOrNull;
        final color = hobby?.colorValue ?? colors.primary;
        final icon = hobby?.icon ?? '✨';
        final rotation = (random.nextDouble() - 0.5) * 0.1;

        return Transform.rotate(
          angle: rotation,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  hobbyName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReportBottomSheet extends StatefulWidget {
  final String targetName;
  final String targetId;
  final String reporterId;
  final ReportService reportService;
  final AppColorScheme colors;
  final bool isDark;

  const _ReportBottomSheet({
    required this.targetName,
    required this.targetId,
    required this.reporterId,
    required this.reportService,
    required this.colors,
    required this.isDark,
  });

  @override
  State<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<_ReportBottomSheet> {
  static const _categories = [
    ('spam',                  'Spam'),
    ('harassment',            'Harassment'),
    ('inappropriate_content', 'Inappropriate Content'),
    ('fake_account',          'Fake Account'),
    ('hate_speech',           'Hate Speech'),
    ('violence',              'Violence'),
    ('other',                 'Other'),
  ];

  String? _selectedCategory;
  final _descController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.reportService.submitReport(
        reporterId: widget.reporterId,
        reportedEntityId: widget.targetId,
        reportedEntityType: 'profile',
        category: _selectedCategory!,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
      if (mounted) setState(() => _submitted = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit report. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final colors = widget.colors;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Why are you reporting this account?',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
            ),

            Divider(color: dividerColor, height: 1),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: _submitted
                  ? _buildSuccessState(textPrimary, textSecondary)
                  : ListView(
                      controller: controller,
                      padding: EdgeInsets.zero,
                      children: [
                        // Category rows
                        for (int i = 0; i < _categories.length; i++) ...[
                          _CategoryRow(
                            label: _categories[i].$2,
                            selected: _selectedCategory == _categories[i].$1,
                            isDark: isDark,
                            colors: colors,
                            onTap: () => setState(
                              () => _selectedCategory = _categories[i].$1,
                            ),
                          ),
                          if (i < _categories.length - 1)
                            Divider(
                              color: dividerColor,
                              height: 1,
                              indent: 24,
                            ),
                        ],

                        // Description + submit (after category picked)
                        if (_selectedCategory != null) ...[
                          Divider(color: dividerColor, height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: TextField(
                              controller: _descController,
                              maxLines: 3,
                              maxLength: 300,
                              style: TextStyle(fontSize: 14, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Add details (optional)',
                                hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                                border: InputBorder.none,
                                counterStyle: TextStyle(color: textSecondary, fontSize: 11),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Submit button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          child: AnimatedOpacity(
                            opacity: _selectedCategory != null ? 1.0 : 0.3,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: _selectedCategory != null ? _submit : null,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Report',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Report submitted',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We\'ll review it shortly.',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? colors.primary
        : (isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.check_rounded, size: 18, color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

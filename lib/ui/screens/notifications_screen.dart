
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_notification.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/block_providers.dart';
import '../../core/providers/follow_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/services/follow_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme_provider.dart';
import '../widgets/app_cached_image.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // IDs of unread follow notifications that stay visually "New" until the user
  // interacts with the tile (tap to profile or follow-back button).
  final Set<String> _pendingFollowIds = {};
  bool _initializedPending = false;
  bool _markedReadOnServer = false;

  @override
  void initState() {
    super.initState();
    _autoMarkAllRead();
  }

  @override
  void deactivate() {
    // Invalidate so the bell badge on ExploreScreen reflects the read state.
    // Must happen in deactivate (not dispose) because ref is still safe here.
    if (_markedReadOnServer) {
      ref.invalidate(notificationsProvider);
    }
    super.deactivate();
  }

  /// Silently marks all notifications as read on the backend so the bell badge
  /// clears, but does NOT change the visual "New" section for follow notifs.
  Future<void> _autoMarkAllRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final client = ref.read(supabaseProvider);
    try {
      await NotificationService(client).markAllRead(userId);
      _markedReadOnServer = true;
    } catch (_) {
      // Non-critical — badge may persist until next visit
    }
  }

  void _onTileInteracted(String notifId) {
    if (_pendingFollowIds.remove(notifId)) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _initializedPending = false;
      _pendingFollowIds.clear();
    });
    ref.invalidate(notificationsProvider);
    await ref.read(notificationsProvider.future);
    if (!_markedReadOnServer) _autoMarkAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Sign in to view notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final notificationsAsync = ref.watch(notificationsProvider);
    final blockedIds = ref.watch(blockedByIdsProvider).value ?? <String>{};
    final myBlockedIds = ref.watch(blockedUsersProvider).value
            ?.map((p) => p['id'] as String)
            .toSet() ??
        <String>{};
    final allBlockedIds = {...blockedIds, ...myBlockedIds};

    return Scaffold(
      body: notificationsAsync.when(
        // Keep showing previous data while refreshing instead of a spinner
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Something went wrong')),
        data: (rawNotifications) {
          // Filter out notifications from blocked users
          final notifications = allBlockedIds.isEmpty
              ? rawNotifications
              : rawNotifications
                  .where((n) => !allBlockedIds.contains(n.actorId))
                  .toList();

          // On first load, capture unread follow notification IDs.
          // These stay visually "New" until the user interacts with the tile.
          if (!_initializedPending) {
            _initializedPending = true;
            for (final n in notifications) {
              if (!n.isRead && n.type == 'follow') {
                _pendingFollowIds.add(n.id);
              }
            }
          }

          // "New" = only follow notifications the user hasn't interacted with
          final newItems = notifications
              .where((n) => _pendingFollowIds.contains(n.id))
              .toList();
          // "Earlier" = everything else
          final earlierItems = notifications
              .where((n) => !_pendingFollowIds.contains(n.id))
              .toList();

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                edgeOffset: MediaQuery.of(context).padding.top + 62,
                color: colors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).padding.top + 62,
                      ),
                    ),

                    if (newItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [colors.primary, colors.accent],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _NotifTile(
                            notif: newItems[index],
                            colors: colors,
                            isDark: isDark,
                            isActorBlocked: false,
                            isPending: true,
                            onInteracted: () =>
                                _onTileInteracted(newItems[index].id),
                          ),
                          childCount: newItems.length,
                        ),
                      ),
                    ],

                    if (earlierItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text(
                            'Earlier',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _NotifTile(
                            notif: earlierItems[index],
                            colors: colors,
                            isDark: isDark,
                            isActorBlocked: false,
                          ),
                          childCount: earlierItems.length,
                        ),
                      ),
                    ],

                    if (notifications.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No notifications yet',
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),

              // Glass header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.92),
                        border: Border(
                          bottom: BorderSide(
                            color: colors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.07)
                                        : Colors.black.withValues(
                                            alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (newItems.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.primary,
                                        colors.accent
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${newItems.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Notification tile ──────────────────────────────────────────────────────

class _NotifTile extends ConsumerStatefulWidget {
  final AppNotification notif;
  final AppColorScheme colors;
  final bool isDark;
  final bool isActorBlocked;
  final bool isPending;
  final VoidCallback? onInteracted;

  const _NotifTile({
    required this.notif,
    required this.colors,
    required this.isDark,
    this.isActorBlocked = false,
    this.isPending = false,
    this.onInteracted,
  });

  @override
  ConsumerState<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends ConsumerState<_NotifTile> {
  bool? _followOverride;
  bool _followLoading = false;

  IconData get _typeIcon => switch (widget.notif.type) {
        'follow' => Icons.person_add_rounded,
        'like' => Icons.favorite_rounded,
        'comment' => Icons.chat_bubble_rounded,
        'mention' => Icons.alternate_email_rounded,
        'twin' => Icons.people_rounded,
        _ => Icons.notifications_rounded,
      };

  Color get _typeColor => switch (widget.notif.type) {
        'follow' => widget.colors.primary,
        'like' => const Color(0xFFFF4757),
        'comment' => widget.colors.accent,
        'mention' => const Color(0xFF0095FF),
        'twin' => const Color(0xFF00B894),
        _ => widget.colors.primary,
      };

  String get _typeText => switch (widget.notif.type) {
        'follow' => 'started following you',
        'like' => 'liked your content',
        'comment' => 'commented on your post',
        'mention' => 'mentioned you',
        'twin' => 'is your hobby twin!',
        _ => 'interacted with you',
      };

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_followLoading) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() {
      _followLoading = true;
      _followOverride = !currentlyFollowing;
    });

    final client = ref.read(supabaseProvider);
    try {
      if (currentlyFollowing) {
        await FollowService(client)
            .unfollow(currentUserId, widget.notif.actorId);
        await NotificationService(client).deleteFollowNotification(
          recipientId: widget.notif.actorId,
          actorId: currentUserId,
        );
      } else {
        await FollowService(client)
            .follow(currentUserId, widget.notif.actorId);
        await NotificationService(client).createFollowNotification(
          recipientId: widget.notif.actorId,
          actorId: currentUserId,
        );
      }

      ref.invalidate(isFollowingProvider(widget.notif.actorId));
      ref.invalidate(profileStatsProvider(widget.notif.actorId));
      ref.invalidate(currentProfileProvider);
      ref.invalidate(followersProvider(widget.notif.actorId));
      ref.invalidate(followingProvider(currentUserId));
      ref.invalidate(followingIdsProvider);
    } catch (_) {
      if (mounted) setState(() => _followOverride = currentlyFollowing);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notif;
    final colors = widget.colors;
    final isDark = widget.isDark;

    // For follow notifications, check if we already follow them back
    final isFollowingAsync = notif.type == 'follow'
        ? ref.watch(isFollowingProvider(notif.actorId))
        : const AsyncValue<bool>.data(false);
    final isFollowing = _followOverride ?? isFollowingAsync.value ?? false;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onInteracted?.call();
        context.push('/user/${notif.actorId}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: widget.isPending
            ? (isDark
                ? colors.primary.withValues(alpha: 0.04)
                : colors.primary.withValues(alpha: 0.03))
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppCachedImage(
                  imageUrl: notif.actorAvatarUrl,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(50),
                  errorWidget: Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _typeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      _typeIcon,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: notif.actorFullName ??
                              notif.actorUsername ??
                              'Someone',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: ' $_typeText',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            if (notif.type == 'follow' && !widget.isActorBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onInteracted?.call();
                    _toggleFollow(isFollowing);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isFollowing
                          ? null
                          : LinearGradient(
                              colors: [colors.primary, colors.accent],
                            ),
                      color: isFollowing
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05))
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isFollowing
                          ? Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.1),
                            )
                          : null,
                      boxShadow: isFollowing
                          ? null
                          : [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _followLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: isFollowing
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : Colors.white,
                            ),
                          )
                        : Text(
                            isFollowing ? 'Following' : 'Follow back',
                            style: TextStyle(
                              color: isFollowing
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),

            if (widget.isPending && notif.type != 'follow')
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.accent],
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

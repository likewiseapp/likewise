import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/profile.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/follow_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/services/follow_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme_provider.dart';
import '../widgets/app_cached_image.dart';

class FollowListScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final int initialTab;

  const FollowListScreen({
    super.key,
    required this.userId,
    this.userName = '',
    this.initialTab = 0,
  });

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ProfileStats> _filter(List<ProfileStats> users) {
    if (_query.trim().isEmpty) return users;
    final q = _query.toLowerCase();
    return users
        .where((u) =>
            u.fullName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            (u.bio ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F17) : const Color(0xFFF2F4F8);

    final followersAsync = ref.watch(followersProvider(widget.userId));
    final followingAsync = ref.watch(followingProvider(widget.userId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: bg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            toolbarHeight: 56,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
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
            title: Text(
              widget.userName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(104),
              child: Column(
                children: [
                  // ── Search bar ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.grey.shade500,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // ── Tabs ─────────────────────────────────────────────
                  TabBar(
                    controller: _tabController,
                    indicatorColor: colors.primary,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: colors.primary,
                    unselectedLabelColor: Colors.grey.shade500,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(
                        child: Text(
                          'Followers  ${followersAsync.value?.length ?? ''}',
                        ),
                      ),
                      Tab(
                        child: Text(
                          'Following  ${followingAsync.value?.length ?? ''}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            followersAsync.when(
              data: (users) => _UserList(
                users: _filter(users),
                currentUserId: currentUserId,
                colors: colors,
                isDark: isDark,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Something went wrong')),
            ),
            followingAsync.when(
              data: (users) => _UserList(
                users: _filter(users),
                currentUserId: currentUserId,
                colors: colors,
                isDark: isDark,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Something went wrong')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User list ───────────────────────────────────────────────────────────────────

class _UserList extends StatelessWidget {
  final List<ProfileStats> users;
  final String? currentUserId;
  final AppColorScheme colors;
  final bool isDark;

  const _UserList({
    required this.users,
    required this.currentUserId,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No results found',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _UserRow(
          user: user,
          currentUserId: currentUserId,
          colors: colors,
          isDark: isDark,
          showDivider: index < users.length - 1,
        );
      },
    );
  }
}

// ── Single user row ─────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final ProfileStats user;
  final String? currentUserId;
  final AppColorScheme colors;
  final bool isDark;
  final bool showDivider;

  const _UserRow({
    required this.user,
    required this.currentUserId,
    required this.colors,
    required this.isDark,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = currentUserId == user.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/user/${user.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Avatar
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
                    imageUrl: user.avatarUrl,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(50),
                    errorWidget: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Name / handle / bio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              color: colors.primary,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          user.bio!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Only show follow button for other users
                if (!isSelf && currentUserId != null)
                  _FollowButton(
                    targetUserId: user.id,
                    colors: colors,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
        ),

        if (showDivider)
          Divider(
            indent: 82,
            endIndent: 20,
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
      ],
    );
  }
}

// ── Follow toggle button (wired to backend) ─────────────────────────────────────

class _FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  final AppColorScheme colors;
  final bool isDark;

  const _FollowButton({
    required this.targetUserId,
    required this.colors,
    required this.isDark,
  });

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool? _override; // optimistic state
  bool _loading = false;

  Future<void> _toggle(bool currentlyFollowing) async {
    if (_loading) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() {
      _loading = true;
      _override = !currentlyFollowing;
    });

    final client = ref.read(supabaseProvider);
    try {
      if (currentlyFollowing) {
        await FollowService(client).unfollow(currentUserId, widget.targetUserId);
        await NotificationService(client).deleteFollowNotification(
          recipientId: widget.targetUserId,
          actorId: currentUserId,
        );
      } else {
        await FollowService(client).follow(currentUserId, widget.targetUserId);
        await NotificationService(client).createFollowNotification(
          recipientId: widget.targetUserId,
          actorId: currentUserId,
        );
      }

      ref.invalidate(isFollowingProvider(widget.targetUserId));
      ref.invalidate(profileStatsProvider(widget.targetUserId));
      ref.invalidate(currentProfileProvider);
      ref.invalidate(followersProvider(widget.targetUserId));
      ref.invalidate(followingProvider(currentUserId));
      ref.invalidate(followingIdsProvider);
      ref.invalidate(notificationsProvider);
    } catch (_) {
      if (mounted) setState(() => _override = currentlyFollowing);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUserId));
    final isFollowing = _override ?? isFollowingAsync.value ?? false;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _toggle(isFollowing);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.transparent
              : (widget.isDark ? Colors.white : Colors.black),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFollowing
                ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.15))
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: _loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isFollowing
                      ? (widget.isDark ? Colors.white70 : Colors.black54)
                      : (widget.isDark ? Colors.black : Colors.white),
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: isFollowing
                      ? (widget.isDark ? Colors.white70 : Colors.black54)
                      : (widget.isDark ? Colors.black : Colors.white),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
      ),
    );
  }
}

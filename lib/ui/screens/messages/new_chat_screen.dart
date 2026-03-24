
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/profile.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/follow_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/services/message_service.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';

/// Provider that fetches mutual follows (users you follow who follow you back).
final _mutualFollowsProvider =
    FutureProvider<List<ProfileStats>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final client = ref.watch(supabaseProvider);
  final service = FollowService(client);

  final followers = await service.fetchFollowers(userId);
  final followingIds = await service.fetchFollowingIds(userId);

  // Mutual = people in my followers list whose ID is also in my following set
  return followers.where((f) => followingIds.contains(f.id)).toList();
});

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _navigating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startChat(ProfileStats user) async {
    if (_navigating) return;
    setState(() => _navigating = true);
    HapticFeedback.lightImpact();

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      final client = ref.read(supabaseProvider);
      final conversationId =
          await MessageService(client).getOrCreateConversation(userId, user.id);

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
      final name = Uri.encodeComponent(user.fullName);
      final avatar = Uri.encodeComponent(user.avatarUrl ?? '');
      final otherUserId = Uri.encodeComponent(user.id);
      context.pushReplacement('/chat/$conversationId?name=$name&avatar=$avatar&userId=$otherUserId');
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutualAsync = ref.watch(_mutualFollowsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Space for header
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.top + 124,
                ),
              ),

              // Mutual follows list
              mutualAsync.when(
                data: (users) {
                  final filtered = _searchQuery.isEmpty
                      ? users
                      : users.where((u) {
                          final name = u.fullName.toLowerCase();
                          final username = u.username.toLowerCase();
                          return name.contains(_searchQuery) ||
                              username.contains(_searchQuery);
                        }).toList();

                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                _searchQuery.isEmpty
                                    ? Icons.people_outline_rounded
                                    : Icons.search_off_rounded,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No mutual follows yet'
                                    : 'No results found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Follow people who follow you back\nto start a conversation',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black26,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = filtered[index];
                        return _UserTile(
                          user: user,
                          colors: colors,
                          isDark: isDark,
                          onTap: () => _startChat(user),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Something went wrong',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                },
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 24,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'New Chat',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.trim().toLowerCase()),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search people...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.white30 : Colors.black26,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color:
                                      isDark ? Colors.white30 : Colors.black26,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final ProfileStats user;
  final AppColorScheme colors;
  final bool isDark;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.colors,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            AppCachedImage(
              imageUrl: user.avatarUrl,
              width: 52,
              height: 52,
              borderRadius: BorderRadius.circular(50),
              errorWidget: Container(
                width: 52,
                height: 52,
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: colors.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

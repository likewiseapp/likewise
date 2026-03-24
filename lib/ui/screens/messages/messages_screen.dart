
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/conversation.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/block_providers.dart';
import '../../../core/providers/message_providers.dart';
import '../../../core/services/message_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  bool get _selectMode => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDelete() async {
    final count = _selectedIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${count == 1 ? 'Conversation' : 'Conversations'}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Delete $count ${count == 1 ? 'conversation' : 'conversations'} and all messages within? This cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ids = Set<String>.from(_selectedIds);
    setState(() => _selectedIds.clear());
    HapticFeedback.mediumImpact();
    final client = ref.read(supabaseProvider);
    final service = MessageService(client);
    for (final id in ids) {
      await service.deleteConversation(id);
    }
    ref.invalidate(conversationsProvider);
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
              Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Sign in to view messages',
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

    final conversationsAsync = ref.watch(conversationsProvider);
    final requestsAsync = ref.watch(requestConversationsProvider);
    final onlineAsync = ref.watch(onlineUsersProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final blockedByIds = ref.watch(blockedByIdsProvider).value ?? <String>{};

    // IDs of people the current user has a conversation with
    final conversationPartnerIds = conversationsAsync.value
            ?.map((c) => c.user1Id == currentUserId ? c.user2Id : c.user1Id)
            .toSet() ??
        <String>{};

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.top + 124,
                ),
              ),

              // Online now section
              onlineAsync.when(
                data: (onlineUsers) {
                  // Only show users the current user already has a conversation with
                  final visible = onlineUsers
                      .where((u) => conversationPartnerIds.contains(u.id))
                      .toList();
                  if (visible.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Now',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white54 : Colors.black45,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 76,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final user = visible[index];
                                return _OnlineAvatar(
                                  name: user.fullName.split(' ').first,
                                  imageUrl: user.avatarUrl ?? '',
                                  colors: colors,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Divider
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    height: 1,
                  ),
                ),
              ),

              // Message Requests row
              Builder(builder: (context) {
                final requestCount = requestsAsync.value?.length ?? 0;
                if (requestCount == 0) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/message-requests');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Message Requests',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$requestCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Chat list
              conversationsAsync.when(
                data: (conversations) {
                  // Filter by search query
                  final filtered = _searchQuery.isEmpty
                      ? conversations
                      : conversations.where((c) {
                          final name = (c.otherFullName ?? '').toLowerCase();
                          final username = (c.otherUsername ?? '').toLowerCase();
                          return name.contains(_searchQuery) ||
                              username.contains(_searchQuery);
                        }).toList();

                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No conversations yet'
                                : 'No results found',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  // Build set of online user IDs for dot display on tiles
                  final onlineIds =
                      onlineAsync.value?.map((u) => u.id).toSet() ?? <String>{};
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final conv = filtered[index];
                        final otherId = conv.user1Id == currentUserId
                            ? conv.user2Id
                            : conv.user1Id;
                        final isBlockedByOther = blockedByIds.contains(otherId);
                        return _ConversationTile(
                          conversation: conv,
                          colors: colors,
                          isDark: isDark,
                          currentUserId: currentUserId,
                          isOtherOnline: !isBlockedByOther && onlineIds.contains(otherId),
                          isBlockedByOther: isBlockedByOther,
                          selectMode: _selectMode,
                          isSelected: _selectedIds.contains(conv.id),
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            setState(() => _selectedIds.add(conv.id));
                          },
                          onSelect: () {
                            setState(() {
                              if (_selectedIds.contains(conv.id)) {
                                _selectedIds.remove(conv.id);
                              } else {
                                _selectedIds.add(conv.id);
                              }
                            });
                          },
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final name = Uri.encodeComponent(
                                conv.otherFullName ?? conv.otherUsername ?? '');
                            final avatar = Uri.encodeComponent(
                                conv.otherAvatarUrl ?? '');
                            final userId = Uri.encodeComponent(otherId);
                            context.push(
                              '/chat/${conv.id}?name=$name&avatar=$avatar&userId=$userId',
                            );
                          },
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
                    child: Center(child: Text('Something went wrong')),
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
                          if (_selectMode)
                            Row(
                              children: [
                                // Close / cancel selection
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _selectedIds.clear());
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Count label
                                Text(
                                  '${_selectedIds.length} selected',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                // Select All pill
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final convs = conversationsAsync.value ?? [];
                                    final filtered = _searchQuery.isEmpty
                                        ? convs
                                        : convs.where((c) {
                                            final name = (c.otherFullName ?? '').toLowerCase();
                                            final username = (c.otherUsername ?? '').toLowerCase();
                                            return name.contains(_searchQuery) ||
                                                username.contains(_searchQuery);
                                          }).toList();
                                    setState(() => _selectedIds.addAll(filtered.map((c) => c.id)));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: colors.primary.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'All',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Delete pill
                                GestureDetector(
                                  onTap: _confirmAndDelete,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          size: 15,
                                          color: Colors.red.shade400,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
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
                                  'Messages',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.push('/new-chat');
                                  },
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 22,
                                    color: isDark ? Colors.white70 : Colors.black54,
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
                              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search conversations...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: isDark ? Colors.white30 : Colors.black26,
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
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
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

// ── Online avatar bubble ───────────────────────────────────────────────────

class _OnlineAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;
  final AppColorScheme colors;

  const _OnlineAvatar({
    required this.name,
    required this.imageUrl,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: AppCachedImage(
                imageUrl: imageUrl,
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
            ),
            Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final AppColorScheme colors;
  final bool isDark;
  final String? currentUserId;
  final bool isOtherOnline;
  final bool isBlockedByOther;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;
  final bool selectMode;
  final bool isSelected;

  const _ConversationTile({
    required this.conversation,
    required this.colors,
    required this.isDark,
    this.currentUserId,
    this.isOtherOnline = false,
    this.isBlockedByOther = false,
    this.onTap,
    this.onLongPress,
    this.onSelect,
    this.selectMode = false,
    this.isSelected = false,
  });

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    // Just now (under 1 minute)
    if (diff.inSeconds < 60) return 'Just now';

    // Minutes (1m – 59m)
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m min${m == 1 ? '' : 's'} ago';
    }

    // Hours (1h – 23h)
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hr${h == 1 ? '' : 's'} ago';
    }

    // Yesterday
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    // Days (2d – 6d)
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    // Weeks (1w – 4w)
    if (diff.inDays < 30) {
      final w = diff.inDays ~/ 7;
      return '$w wk${w == 1 ? '' : 's'} ago';
    }

    // Months (1mo – 11mo)
    if (diff.inDays < 365) {
      final mo = diff.inDays ~/ 30;
      return '$mo mo${mo == 1 ? '' : 's'} ago';
    }

    // Years
    final y = diff.inDays ~/ 365;
    return '$y yr${y == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onTap: selectMode ? onSelect : onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isSelected
            ? colors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              child: selectMode
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? colors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : (isDark ? Colors.white38 : Colors.black26),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Stack(
              children: [
                if (isBlockedByOther)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    child: Icon(Icons.person_rounded,
                        size: 26,
                        color: isDark ? Colors.white24 : Colors.black26),
                  )
                else
                  AppCachedImage(
                    imageUrl: conversation.otherAvatarUrl ?? '',
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
                // Online dot — already suppressed via isOtherOnline=false when blocked
                if (isOtherOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2.5,
                        ),
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
                  Text(
                    conversation.otherFullName ?? conversation.otherUsername ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Tick mark for my last message
                      if (conversation.lastMessageSenderId == currentUserId &&
                          conversation.lastMessage != null) ...[
                        if (conversation.lastMessageIsRead)
                          SizedBox(
                            width: 16,
                            height: 13,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 14,
                                  color: Colors.black.withValues(alpha: 0.15),
                                ),
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 13,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          )
                        else
                          Icon(
                            Icons.done_rounded,
                            size: 13,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.25),
                          ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                            color: hasUnread
                                ? (isDark ? Colors.white70 : Colors.black54)
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(conversation.lastMessageAt ?? conversation.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasUnread
                        ? colors.primary
                        : (isDark ? Colors.white30 : Colors.black26),
                  ),
                ),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.accent],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

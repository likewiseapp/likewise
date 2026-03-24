
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/conversation.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/message_providers.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';

class MessageRequestsScreen extends ConsumerWidget {
  const MessageRequestsScreen({super.key});

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    return '${diff.inDays ~/ 30}mo ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final requestsAsync = ref.watch(requestConversationsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      body: Stack(
        children: [
          requestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 56,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No message requests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'When someone new messages you,\nit will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 80,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        'These are messages from people you don\'t follow. '
                        'Replying will move the conversation to your main inbox.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final conv = requests[index];
                        final otherId = conv.user1Id;
                        return _RequestTile(
                          conversation: conv,
                          colors: colors,
                          isDark: isDark,
                          currentUserId: currentUserId,
                          timeAgo: _timeAgo(
                              conv.lastMessageAt ?? conv.createdAt),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final name = Uri.encodeComponent(
                                conv.otherFullName ?? conv.otherUsername ?? '');
                            final avatar =
                                Uri.encodeComponent(conv.otherAvatarUrl ?? '');
                            final userId = Uri.encodeComponent(otherId);
                            context.push(
                              '/chat/${conv.id}?name=$name&avatar=$avatar&userId=$userId&isRequest=true',
                            );
                          },
                        );
                      },
                      childCount: requests.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Something went wrong',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
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
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
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
                            'Message Requests',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black87,
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

class _RequestTile extends StatelessWidget {
  final Conversation conversation;
  final AppColorScheme colors;
  final bool isDark;
  final String? currentUserId;
  final String timeAgo;
  final VoidCallback onTap;

  const _RequestTile({
    required this.conversation,
    required this.colors,
    required this.isDark,
    required this.currentUserId,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            Stack(
              children: [
                AppCachedImage(
                  imageUrl: conversation.otherAvatarUrl,
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
                // Request badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.accent],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkScaffold
                            : AppColors.lightScaffold,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.mail_rounded,
                      size: 9,
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
                  Text(
                    conversation.otherFullName ??
                        conversation.otherUsername ??
                        'Unknown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

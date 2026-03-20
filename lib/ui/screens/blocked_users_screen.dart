import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/block_providers.dart';
import '../../core/providers/explore_providers.dart';
import '../../core/services/block_service.dart';
import '../../core/theme_provider.dart';
import '../widgets/app_cached_image.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockedAsync = ref.watch(blockedUsersProvider);

    final bg = isDark ? const Color(0xFF0F0F17) : const Color(0xFFF2F4F8);
    final tileBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final tileBorder = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Blocked Users',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                        ),
                        blockedAsync.when(
                          data: (list) => Text(
                            list.isEmpty
                                ? 'No one blocked'
                                : '${list.length} ${list.length == 1 ? 'person' : 'people'} blocked',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: blockedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text(
                    'Failed to load',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
                data: (blocked) {
                  if (blocked.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.block_rounded,
                              size: 30,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No blocked users',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'People you block will appear here',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    itemCount: blocked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final u = blocked[i];
                      final name = u['full_name'] as String? ?? 'Unknown';
                      final username = u['username'] as String? ?? '';
                      final avatarUrl = u['avatar_url'] as String? ?? '';
                      final id = u['id'] as String;

                      return Container(
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: tileBorder),
                        ),
                        child: Row(
                          children: [
                            // Avatar + name row — tappable to view profile
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.push('/user/$id');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                                  child: Row(
                                    children: [
                                      AppCachedImage(
                                        imageUrl: avatarUrl,
                                        width: 46,
                                        height: 46,
                                        borderRadius: BorderRadius.circular(50),
                                        errorWidget: _fallback(),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '@$username',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 3-dot menu
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 22,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              color: isDark
                                  ? const Color(0xFF1E1E28)
                                  : Colors.white,
                              elevation: 6,
                              onSelected: (value) {
                                if (value == 'unblock') {
                                  _unblockUser(context, ref, id);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'unblock',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock_open_rounded,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Unblock',
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 46,
      height: 46,
      color: Colors.grey.shade300,
      child: Icon(Icons.person, size: 22, color: Colors.grey.shade600),
    );
  }

  Future<void> _unblockUser(
    BuildContext context,
    WidgetRef ref,
    String targetId,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    final client = ref.read(supabaseProvider);
    try {
      await BlockService(client).unblockUser(currentUserId, targetId);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(twinMatchProvider);
      ref.invalidate(nearbyUsersProvider);
      ref.invalidate(topCreatorsProvider);
      ref.invalidate(searchResultsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }
}

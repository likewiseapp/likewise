import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/matched_user.dart';
import '../../../core/providers/follow_providers.dart';
import '../../../core/theme_provider.dart';
import '../../../core/utils/follow_helper.dart';

class SearchUserListTile extends ConsumerStatefulWidget {
  final MatchedUser user;
  final AppColorScheme colors;
  final bool isDark;

  const SearchUserListTile({
    super.key,
    required this.user,
    required this.colors,
    required this.isDark,
  });

  @override
  ConsumerState<SearchUserListTile> createState() => _SearchUserListTileState();
}

class _SearchUserListTileState extends ConsumerState<SearchUserListTile> {
  bool _followLoading = false;

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      await performToggleFollow(
        ref,
        widget.user.id,
        currentlyFollowing: currentlyFollowing,
      );
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing =
        ref.watch(isFollowingProvider(widget.user.id)).value ?? false;
    final isDark = widget.isDark;
    final colors = widget.colors;
    final user = widget.user;

    final parts = <String>[];
    if (user.primaryHobbyName != null) {
      final icon = user.primaryHobbyIcon ?? '';
      parts.add('$icon ${user.primaryHobbyName}');
    }
    if (user.distanceKm != null) {
      parts.add('${user.distanceKm!.toStringAsFixed(0)} km away');
    } else if (user.location != null && user.location!.isNotEmpty) {
      parts.add(user.location!);
    }
    final subtitle = parts.join('  ·  ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/user/${user.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colors.primary.withValues(alpha: 0.15),
              backgroundImage:
                  user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _followLoading ? null : () => _toggleFollow(isFollowing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.transparent : colors.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFollowing
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : colors.primary,
                    width: 1.5,
                  ),
                ),
                child: _followLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing
                              ? (isDark ? Colors.white54 : Colors.black54)
                              : Colors.white,
                        ),
                      )
                    : Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isFollowing
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : Colors.white,
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

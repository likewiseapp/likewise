import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/matched_user.dart';
import '../../../core/providers/follow_providers.dart';
import '../../../core/theme_provider.dart';
import '../../../core/utils/follow_helper.dart';
import '../app_cached_image.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Asymmetric Grid
// ═════════════════════════════════════════════════════════════════════════════

class SearchAsymmetricGrid extends StatelessWidget {
  final List<MatchedUser> users;
  final int visibleCount;
  final int pageSize;
  final int maxPages;
  final AppColorScheme colors;
  final void Function(String userId) onUserTap;

  const SearchAsymmetricGrid({
    super.key,
    required this.users,
    required this.visibleCount,
    required this.pageSize,
    required this.maxPages,
    required this.colors,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    MatchedUser? u(int i) => i < users.length ? users[i] : null;

    Widget tile(MatchedUser? user, _TileSize size) {
      if (user == null) return ClipRRect(borderRadius: BorderRadius.circular(10), child: const SizedBox.expand());
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onUserTap(user.id);
        },
        child: _GridTile(user: user, size: size, colors: colors),
      );
    }

    /// ┌──────────────┬───────┐
    /// │              │  [1]  │
    /// │     [0]      ├───────┤  256 px
    /// │   (large)    │  [2]  │
    /// └──────────────┴───────┘
    /// ┌────┬────┬────┐
    /// │[3] │[4] │[5] │  128 px
    /// └────┴────┴────┘
    /// ┌───────┬──────────────┐
    /// │  [6]  │              │
    /// ├───────┤     [8]      │  256 px
    /// │  [7]  │   (large)    │
    /// └───────┴──────────────┘
    Widget buildPage(int pageOffset) {
      return Column(
        children: [
          const SizedBox(height: 8),
          // Row A: big left + 2 stacked right
          SizedBox(
            height: 256,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: tile(u(pageOffset + 0), _TileSize.large),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(child: tile(u(pageOffset + 1), _TileSize.small)),
                      const SizedBox(height: 8),
                      Expanded(child: tile(u(pageOffset + 2), _TileSize.small)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row B: 3 equal small tiles
          SizedBox(
            height: 128,
            child: Row(
              children: [
                Expanded(child: tile(u(pageOffset + 3), _TileSize.small)),
                const SizedBox(width: 8),
                Expanded(child: tile(u(pageOffset + 4), _TileSize.small)),
                const SizedBox(width: 8),
                Expanded(child: tile(u(pageOffset + 5), _TileSize.small)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row C: 2 stacked left + big right
          SizedBox(
            height: 256,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(child: tile(u(pageOffset + 6), _TileSize.small)),
                      const SizedBox(height: 8),
                      Expanded(child: tile(u(pageOffset + 7), _TileSize.small)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: tile(u(pageOffset + 8), _TileSize.large),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    final pageCount = (visibleCount / pageSize).ceil().clamp(1, maxPages);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [for (int p = 0; p < pageCount; p++) buildPage(p * pageSize)],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile Size
// ─────────────────────────────────────────────────────────────────────────────

enum _TileSize { large, small }

// ─────────────────────────────────────────────────────────────────────────────
// Grid Tile
// ─────────────────────────────────────────────────────────────────────────────

class _GridTile extends ConsumerStatefulWidget {
  final MatchedUser user;
  final _TileSize size;
  final AppColorScheme colors;

  const _GridTile({
    required this.user,
    required this.size,
    required this.colors,
  });

  @override
  ConsumerState<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends ConsumerState<_GridTile> {
  bool _followLoading = false;

  String get _locationText {
    if (widget.user.distanceKm != null) {
      return '${widget.user.distanceKm!.toStringAsFixed(0)} km';
    }
    return widget.user.location ?? '';
  }

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppCachedImage(
            imageUrl: widget.user.avatarUrl,
            fit: BoxFit.cover,
            errorWidget: Container(color: Colors.grey.shade800),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  widget.size == _TileSize.large
                      ? const Color(0xEE000000)
                      : const Color(0xCC000000),
                ],
                stops: widget.size == _TileSize.large
                    ? const [0.25, 1.0]
                    : const [0.35, 1.0],
              ),
            ),
          ),
          if (widget.user.primaryHobbyIcon != null)
            Positioned(
              top: 8,
              left: 8,
              child: _HobbyBadge(
                icon: widget.user.primaryHobbyIcon!,
                name: widget.size == _TileSize.large
                    ? widget.user.primaryHobbyName
                    : null,
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildContent(isFollowing),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isFollowing) {
    return switch (widget.size) {
      _TileSize.large => _LargeContent(
        user: widget.user,
        colors: widget.colors,
        locationText: _locationText,
        isFollowing: isFollowing,
        isLoading: _followLoading,
        onFollow: () => _toggleFollow(isFollowing),
      ),
      _TileSize.small => _SmallContent(
        user: widget.user,
        locationText: _locationText,
      ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hobby Badge
// ─────────────────────────────────────────────────────────────────────────────

class _HobbyBadge extends StatelessWidget {
  final String icon;
  final String? name;

  const _HobbyBadge({required this.icon, this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: name != null ? 8 : 5,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          if (name != null) ...[
            const SizedBox(width: 4),
            Text(
              name!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Large Tile Content
// ─────────────────────────────────────────────────────────────────────────────

class _LargeContent extends StatelessWidget {
  final MatchedUser user;
  final AppColorScheme colors;
  final String locationText;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onFollow;

  const _LargeContent({
    required this.user,
    required this.colors,
    required this.locationText,
    required this.isFollowing,
    required this.isLoading,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final bio = (user.bio ?? '').length > 44
        ? '${(user.bio ?? '').substring(0, 44)}…'
        : (user.bio ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            bio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (locationText.isNotEmpty) ...[
                Icon(
                  Icons.location_on_rounded,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 3),
                Text(
                  locationText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onFollow();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isFollowing
                        ? Colors.white.withValues(alpha: 0.18)
                        : colors.primary,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: isFollowing
                        ? null
                        : [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: isFollowing ? 0.85 : 1.0,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small Tile Content
// ─────────────────────────────────────────────────────────────────────────────

class _SmallContent extends StatelessWidget {
  final MatchedUser user;
  final String locationText;

  const _SmallContent({required this.user, required this.locationText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 8,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    locationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

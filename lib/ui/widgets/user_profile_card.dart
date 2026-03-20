import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/profile_card_data.dart';
import '../../core/models/hobby.dart';
import '../../core/providers/hobby_providers.dart';
import '../../core/theme_provider.dart';
import 'app_cached_image.dart';

class UserProfileCard extends ConsumerStatefulWidget {
  final ProfileCardData data;
  final VoidCallback onTap;
  final bool compactMode;
  final Color? backgroundColor;
  final bool isTwinCard;
  final int matchCount;

  const UserProfileCard({
    super.key,
    required this.data,
    required this.onTap,
    this.compactMode = false,
    this.backgroundColor,
    this.isTwinCard = false,
    this.matchCount = 0,
  });

  @override
  ConsumerState<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends ConsumerState<UserProfileCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.compactMode) {
      return _buildCompactCard(context);
    }
    return _buildNormalCard(context);
  }

  Hobby? _findHobby(String name, List<Hobby> allHobbies) {
    for (final h in allHobbies) {
      if (h.name == name) return h;
    }
    return null;
  }

  // ── Compact Mode (Twin Card + Top Creators grid) ──────────────────────

  Widget _buildCompactCard(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final hobbiesAsync = ref.watch(allHobbiesProvider);
    final allHobbies = hobbiesAsync.value ?? [];

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey.shade300,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.isTwinCard ? 0.16 : 0.08,
              ),
              blurRadius: widget.isTwinCard ? 24 : 10,
              offset: Offset(0, widget.isTwinCard ? 8 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: AppCachedImage(
                  imageUrl: widget.data.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.person, color: Colors.grey, size: 40),
                    ),
                  ),
                ),
              ),

              // Rich gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: widget.isTwinCard
                          ? const [0.0, 0.3, 1.0]
                          : const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: widget.isTwinCard ? 0.05 : 0.02,
                        ),
                        Colors.black.withValues(
                          alpha: widget.isTwinCard ? 0.88 : 0.78,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Primary hobby badge — top-left
              Positioned(
                top: widget.isTwinCard ? 14 : 10,
                left: widget.isTwinCard ? 14 : 10,
                child: _buildPrimaryHobbyBadge(colors, allHobbies),
              ),

              // Follow pill
              Positioned(
                top: widget.isTwinCard ? 14 : 10,
                right: widget.isTwinCard ? 14 : 10,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isTwinCard ? 16 : 10,
                    vertical: widget.isTwinCard ? 8 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(
                      widget.isTwinCard ? 18 : 14,
                    ),
                  ),
                  child: Text(
                    'Follow',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: widget.isTwinCard ? 13 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Bottom info
              Positioned(
                bottom: widget.isTwinCard ? 16 : 10,
                left: widget.isTwinCard ? 16 : 10,
                right: widget.isTwinCard ? 16 : 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.isTwinCard ? 20 : 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: widget.isTwinCard ? -0.3 : 0,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.data.age ?? ''} · ${widget.data.location ?? ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: widget.isTwinCard ? 14 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Hobby chips on the twin card
                    if (widget.isTwinCard) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            widget.data.hobbies.take(4).map((hobby) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  hobby,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Normal Mode (Talents Near You) ────────────────────────────────────

  Widget _buildNormalCard(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hobbiesAsync = ref.watch(allHobbiesProvider);
    final allHobbies = hobbiesAsync.value ?? [];
    final hobbyLookup = {for (final h in allHobbies) h.name: h};

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.backgroundColor ??
              (isDark
                  ? colors.primary.withValues(alpha: 0.08)
                  : colors.primary.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Avatar with gradient ring + hobby badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 23,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        child: ClipOval(
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: AppCachedImage(
                              imageUrl: widget.data.imageUrl,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      left: -4,
                      child: _buildPrimaryHobbyBadge(colors, allHobbies),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.data.age ?? ''} · ${widget.data.location ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Gradient follow button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),

            // Bio
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Text(
                widget.data.bio ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Colored hobby chips
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: widget.data.hobbies.take(4).map((hobbyName) {
                final hobby = hobbyLookup[hobbyName];
                final hobbyColor = hobby?.colorValue ?? const Color(0xFF6C63FF);
                final hobbyIcon = hobby?.icon ?? '🎯';

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        hobbyColor.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          hobbyColor.withValues(alpha: isDark ? 0.28 : 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hobbyIcon,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hobbyName,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? hobbyColor.withValues(alpha: 0.9)
                              : hobbyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────

  Widget _buildPrimaryHobbyBadge(AppColorScheme colors, List<Hobby> allHobbies) {
    if (widget.data.hobbies.isEmpty) return const SizedBox.shrink();

    final primaryHobbyName = widget.data.hobbies.first;
    final hobby = _findHobby(primaryHobbyName, allHobbies);
    final hobbyIcon = hobby?.icon ?? '🎯';

    return Container(
      width: widget.isTwinCard ? 40 : 34,
      height: widget.isTwinCard ? 40 : 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(colors.primary, Colors.white, 0.82),
        border: Border.all(
          color: Color.lerp(colors.primary, Colors.white, 0.7)!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          hobbyIcon,
          style: TextStyle(fontSize: widget.isTwinCard ? 20 : 15),
        ),
      ),
    );
  }
}

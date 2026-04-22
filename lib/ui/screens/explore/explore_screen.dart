import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/profile_card_data.dart';
import '../../../core/app_theme.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/explore_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/providers/message_providers.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
import '../../../core/providers/navigation_providers.dart';
import '../../widgets/user_profile_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int _nearbyLimit = 5;

  String? _distanceLabel(double? km) {
    if (km == null) return null;
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    final userId = ref.watch(currentUserIdProvider);
    final twinAsync = ref.watch(twinMatchProvider);
    final nearbyAsync = ref.watch(nearbyUsersProvider);
    final topAsync = ref.watch(topCreatorsProvider);
    final currentProfileAsync = ref.watch(currentProfileProvider);
    final fullProfile = ref.watch(fullProfileProvider).asData?.value;
    final hasLocation = fullProfile?.latitude != null &&
        fullProfile?.longitude != null;
    final locationLabel = fullProfile?.location;

    final hour = DateTime.now().hour;
    final (greetingText, greetingEmoji) = hour < 5
        ? ('Night owl', '🌙')
        : hour < 12
            ? ('Good morning', '☀️')
            : hour < 17
                ? ('Good afternoon', '🌤️')
                : hour < 22
                    ? ('Good evening', '🌆')
                    : ('Night owl', '🌙');
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = (notificationsAsync.value ?? [])
        .where((n) => !n.isRead)
        .length;
    final unreadMessages = ref.watch(unreadMessagesCountProvider);
    final userHobbiesAsync = userId != null
        ? ref.watch(userHobbiesProvider(userId))
        : const AsyncValue<List<Never>>.data([]);

    final userHobbies = userHobbiesAsync.value ?? [];

    // Build a distance lookup map from the nearby results — reused by all sections
    final distanceMap = {
      for (final u in (nearbyAsync.value ?? [])) u.id: u.distanceKm,
    };

    // Collect all displayed user IDs for batch hobby lookup.
    // Sort + join into a stable string key so Riverpod equality works.
    final allCardUserIds = <String>[
      if (twinAsync.value != null) twinAsync.value!.id,
      ...(topAsync.value ?? []).map((p) => p.id),
      ...(nearbyAsync.value ?? []).map((u) => u.id),
    ]..sort();
    final idsKey = allCardUserIds.join(',');
    final displayHobbiesAsync = ref.watch(displayHobbiesProvider(idsKey));
    final displayHobbies = displayHobbiesAsync.value ?? {};

    final scaffoldBg =
        isDark ? AppColors.darkScaffold : AppColors.lightScaffold;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Sticky top bar (menu | logo | chat | bell) ─────────
            SliverAppBar(
              pinned: true,
              primary: false,
              automaticallyImplyLeading: false,
              backgroundColor: scaffoldBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 64,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(mainScaffoldKeyProvider)
                            .currentState
                            ?.openDrawer();
                      },
                      child: Icon(
                        Icons.menu_rounded,
                        size: 22,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [colors.primary, colors.accent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'likewise',
                        style: GoogleFonts.greatVibes(
                          fontSize: 45,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/messages');
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 21,
                                color:
                                    isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            if (unreadMessages > 0)
                              Positioned(
                                right: 11,
                                top: 10,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkScaffold
                                          : AppColors.lightScaffold,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/notifications');
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 22,
                                color:
                                    isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 11,
                                top: 10,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkScaffold
                                          : AppColors.lightScaffold,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Welcome card + rest ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome card (compact) ───────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        decoration: BoxDecoration(
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
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.45),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: AppCachedImage(
                                  imageUrl:
                                      currentProfileAsync.value?.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        greetingEmoji,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        greetingText,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            isAuthenticated
                                                ? (currentProfileAsync
                                                        .value?.fullName ??
                                                    'there')
                                                : 'there',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text('👋',
                                          style: TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _welcomeChip(
                                    onTap: _showLocationSheet,
                                    leading: const Icon(
                                      Icons.place_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    label: _compactLocation(locationLabel),
                                    trailing: const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _talentCluster(colors, userHobbies),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Your Twin (Best Match) ──────────────────────────────
            if (isAuthenticated)
              twinAsync.when(
                data: (twin) {
                  if (twin == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  final twinHobby = displayHobbies[twin.id];
                  final cardData = twin.toCardData(
                    hobbies: twinHobby != null ? [twinHobby] : [],
                    locationOverride: _distanceLabel(distanceMap[twin.id]),
                  );
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(context, colors, 'Your Twin'),
                          const SizedBox(height: 14),
                          AspectRatio(
                            aspectRatio: 1.5,
                            child: UserProfileCard(
                              data: cardData,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.push('/user/${twin.id}');
                              },
                              compactMode: true,
                              isTwinCard: true,
                              matchCount: twin.matchCount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

            // ── Top Creators ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _buildSectionHeader(
                  context,
                  colors,
                  'Top Creators',
                  showSeeAll: true,
                  onSeeAll: () => context.push('/top-creators'),
                ),
              ),
            ),
            topAsync.when(
              data: (topCreators) {
                final top = topCreators.take(10).toList();
                if (top.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No creators found yet')),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: GridView.builder(
                      padding: const EdgeInsets.only(left: 4, right: 20),
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.80,
                      ),
                      itemCount: top.length,
                      itemBuilder: (context, index) {
                        final creatorHobby = displayHobbies[top[index].id];
                        final cardData = top[index].toCardData(
                          hobbies: creatorHobby != null ? [creatorHobby] : [],
                          locationOverride: _distanceLabel(distanceMap[top[index].id]),
                        );
                        return UserProfileCard(
                          data: cardData,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/user/${top[index].id}');
                          },
                          compactMode: true,
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: Center(child: Text('Something went wrong')),
                ),
              ),
            ),

            // ── Talents Near You (Pinned) ──────────────────────────
            // Gated behind profile having a saved location; hidden entirely
            // until the user grants permission and coords are written back.
            if (hasLocation) ...[
              SliverAppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                pinned: true,
                floating: true,
                snap: true,
                toolbarHeight: 60,
                automaticallyImplyLeading: false,
                flexibleSpace: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _buildSectionHeader(
                    context,
                    colors,
                    'Talents near you',
                    showSeeAll: true,
                    onSeeAll: () => context.push('/nearby-talents'),
                  ),
                ),
              ),
              if (isAuthenticated)
              nearbyAsync.when(
                data: (nearby) {
                  if (nearby.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('No nearby talents found yet')),
                      ),
                    );
                  }
                  final shownCount = nearby.length.clamp(0, _nearbyLimit);
                  final shown = nearby.take(shownCount).toList();
                  final canLoadMore = shownCount < nearby.length && shownCount < 20;
                  final atCap = shownCount >= 20 && nearby.length > 20;

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        // User cards
                        if (index < shown.length) {
                          final user = shown[index];
                          final nearbyHobby = displayHobbies[user.id];
                          final cardData = user.toCardData(
                            hobbies: nearbyHobby != null ? [nearbyHobby] : [],
                            locationOverride: _distanceLabel(user.distanceKm),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: UserProfileCard(
                              data: cardData,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.push('/user/${user.id}');
                              },
                              compactMode: false,
                            ),
                          );
                        }

                        // Extra tile: load-more trigger or "See more" button
                        if (canLoadMore) {
                          // Auto-load next batch when this tile enters the viewport
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _nearbyLimit = (_nearbyLimit + 5).clamp(0, 20);
                              });
                            }
                          });
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          );
                        }

                        // "See more" button (at cap of 20, or all shown but total > shown)
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 120),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push('/nearby-talents');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.primary.withValues(alpha: 0.1)
                                    : colors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'See more talents',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: shown.length + (canLoadMore || atCap ? 1 : 0),
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, __) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'Sign in to discover talents near you',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black38,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Bottom clearance for the floating nav bar (64pt height + 24pt
            // gap-from-screen-bottom + device safe-area inset).
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100 + MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeChip({
    required VoidCallback onTap,
    required Widget leading,
    required String label,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// Trim a full geocoded location string down to just the city/locality.
  String _compactLocation(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Set location';
    return raw.split(',').first.trim();
  }

  /// Cluster of up-to-5 talent circles, primary centered and larger.
  /// Layout adapts to the number of talents:
  /// - 1 → just the primary, centered
  /// - 2 → primary center-right, one secondary on the left
  /// - 3 → primary center, 1 on each side
  /// - 4 → primary just right of center, 2 on the left, 1 on the right
  /// - 5 → primary center, 2 on each side
  /// Non-interactive (display only).
  Widget _talentCluster(AppColorScheme colors, List<dynamic> userHobbies) {
    if (userHobbies.isEmpty) return const SizedBox.shrink();

    final primary =
        userHobbies.where((h) => h.isPrimary).firstOrNull;
    final nonPrimary =
        userHobbies.where((h) => !h.isPrimary).toList();

    final visibleCount = userHobbies.length.clamp(0, 5);
    final primaryIdx = visibleCount ~/ 2;

    // Build slot list: primary at primaryIdx, non-primary fills the rest.
    final slots = List<dynamic>.filled(visibleCount, null, growable: false);
    if (primary != null) slots[primaryIdx] = primary;
    final nonPrimaryTargets = [
      for (var i = 0; i < visibleCount; i++)
        if (i != primaryIdx) i,
    ];
    for (var i = 0;
        i < nonPrimary.length && i < nonPrimaryTargets.length;
        i++) {
      slots[nonPrimaryTargets[i]] = nonPrimary[i];
    }

    const primarySize = 34.0;
    const secondarySize = 22.0;
    const step = 19.0;

    // Compute bounds so the primary (bigger) never clips at the edges.
    double minLeft = 0;
    double maxRight = 0;
    for (var i = 0; i < visibleCount; i++) {
      final size = (i == primaryIdx) ? primarySize : secondarySize;
      final cx = i * step;
      final l = cx - size / 2;
      final r = cx + size / 2;
      if (i == 0) {
        minLeft = l;
        maxRight = r;
      } else {
        if (l < minLeft) minLeft = l;
        if (r > maxRight) maxRight = r;
      }
    }
    final width = maxRight - minLeft;

    return SizedBox(
      width: width,
      height: primarySize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visibleCount; i++)
            _talentCircle(
              slot: slots[i],
              isPrimary: i == primaryIdx,
              leftOffset: i * step - (i == primaryIdx ? primarySize : secondarySize) / 2 - minLeft,
              primarySize: primarySize,
              secondarySize: secondarySize,
              colors: colors,
            ),
        ],
      ),
    );
  }

  Widget _talentCircle({
    required dynamic slot,
    required bool isPrimary,
    required double leftOffset,
    required double primarySize,
    required double secondarySize,
    required AppColorScheme colors,
  }) {
    final size = isPrimary ? primarySize : secondarySize;
    final icon = slot?.hobby?.icon ?? '🎯';

    return Positioned(
      left: leftOffset,
      top: (primarySize - size) / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: isPrimary
                ? colors.primary
                : Colors.white.withValues(alpha: 0.75),
            width: isPrimary ? 2.2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isPrimary ? 0.18 : 0.1),
              blurRadius: isPrimary ? 6 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            icon,
            style: TextStyle(fontSize: isPrimary ? 16 : 12),
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ref.read(appColorSchemeProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          bool detecting = false;
          String? error;

          Future<void> detect() async {
            setSheetState(() {
              detecting = true;
              error = null;
            });
            final ok =
                await LocationService.detectAndSaveForCurrentUser(ref);
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.pop(sheetCtx);
            } else {
              setSheetState(() {
                detecting = false;
                error =
                    'Couldn\'t detect your location. Check permissions and try again.';
              });
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used to find talents near you.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: MaterialButton(
                      onPressed: detecting ? null : detect,
                      elevation: 0,
                      highlightElevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.accent],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Center(
                          child: detecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.my_location_rounded,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Detect my location',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: detecting
                          ? null
                          : () => Navigator.pop(sheetCtx),
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    AppColorScheme colors,
    String title, {
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
        if (showSeeAll)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onSeeAll?.call();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See all',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

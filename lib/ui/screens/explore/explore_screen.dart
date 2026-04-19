import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/profile_card_data.dart';
import '../../../core/app_theme.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/explore_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/providers/message_providers.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
import '../../../core/providers/navigation_providers.dart';
import '../../widgets/user_profile_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  int _nearbyLimit = 5;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

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
    // Primary hobbies first so the largest orbit circle highlights the primary
    final sortedUserHobbies = [...userHobbies]
      ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
    final hobbyNames = sortedUserHobbies
        .map((uh) => uh.hobby?.name)
        .whereType<String>()
        .take(5)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header Bar + Welcome Card ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar: menu | logo | bell ──────────────────
                    Row(
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
                          child: const Text(
                            'likewise',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
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
                                    color: isDark ? Colors.white70 : Colors.black87,
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
                                    color: isDark ? Colors.white70 : Colors.black87,
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

                    const SizedBox(height: 18),

                    // ── Welcome card ─────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [colors.primary, colors.accent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -10,
                              right: -10,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -20,
                              left: 50,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Welcome back',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  isAuthenticated
                                                      ? '${currentProfileAsync.value?.fullName ?? 'there'}'
                                                      : 'there',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.5,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text('👋', style: TextStyle(fontSize: 18)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Discover talents near you',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(10, 0),
                                    child: _buildWelcomeOrbit(colors, hobbyNames, currentProfileAsync.value?.avatarUrl),
                                  ),
                                ],
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

            // Extra bottom space only when nearby is empty or not showing "See more"
            if (!isAuthenticated || nearbyAsync.value == null || nearbyAsync.value!.isEmpty)
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeOrbit(AppColorScheme colors, List<String> hobbyNames, String? avatarUrl) {
    if (hobbyNames.isEmpty) return const SizedBox.shrink();

    final allHobbies = ref.watch(allHobbiesProvider).value ?? [];

    const avatarRadius = 26.0;
    const ringPad = 3.0;
    const totalCenter = avatarRadius + ringPad;
    const orbitRadius = 44.0;
    const hobbySize = 20.0;
    const containerSize = (totalCenter + orbitRadius + hobbySize / 2 + 4) * 2;
    const center = containerSize / 2;
    final count = hobbyNames.length.clamp(1, 5);

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: AnimatedBuilder(
        animation: _orbitController,
        builder: (context, child) {
          final t = _orbitController.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ...List.generate(count, (i) {
                final phase = i * (2 * math.pi / count);
                final radialDrift = math.sin(t * 2 * math.pi + phase * 1.4) * 2.5;
                final angularDrift = math.sin(t * 2 * math.pi * 0.7 + phase * 1.1) * 0.04;
                final yDrift = math.cos(t * 2 * math.pi * 1.3 + phase * 0.8) * 1.5;

                final baseAngle = -math.pi / 2 + phase;
                final angle = baseAngle + angularDrift;
                final radius = orbitRadius + radialDrift;

                final cx = center + radius * math.cos(angle);
                final cy = center + radius * math.sin(angle) + yDrift;
                final isPrimary = i == 0;

                final hobby = allHobbies.where((h) => h.name == hobbyNames[i]).firstOrNull;
                final hobbyIcon = hobby?.icon ?? '🎯';

                final size = isPrimary ? hobbySize + 4 : hobbySize;

                return Positioned(
                  left: cx - size / 2,
                  top: cy - size / 2,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      border: Border.all(
                        color: Colors.white,
                        width: isPrimary ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isPrimary ? 0.12 : 0.06),
                          blurRadius: isPrimary ? 8 : 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        hobbyIcon,
                        style: TextStyle(fontSize: isPrimary ? 14 : 12),
                      ),
                    ),
                  ),
                );
              }),

              Positioned(
                left: center - totalCenter,
                top: center - totalCenter,
                child: Container(
                  width: totalCenter * 2,
                  height: totalCenter * 2,
                  padding: const EdgeInsets.all(ringPad),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  child: AppCachedImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(50),
                    errorWidget: Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Colors.white, size: 30),
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

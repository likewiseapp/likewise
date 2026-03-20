
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/matched_user.dart';
import '../../core/models/user_hobby.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/explore_providers.dart';
import '../../core/providers/follow_providers.dart';
import '../../core/providers/hobby_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/services/follow_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/app_theme.dart';
import '../../core/theme_provider.dart';
import '../widgets/app_cached_image.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Search Screen
// ═════════════════════════════════════════════════════════════════════════════

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// Extra hobbies added via the filter sheet (beyond the user's own).
  List<String> _extraFilterHobbies = [];
  String _searchQuery = '';
  double _searchDistance = 500.0;
  String _selectedTag = 'All';

  static const int _pageSize = 9;
  static const int _maxPages = 2; // 2 pages × 9 = 18 cards total
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  static const List<String> _quickTags = ['All', 'Trending'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    if (_visibleCount >= _pageSize * _maxPages) return; // already at max
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    if (_visibleCount >= _pageSize * _maxPages) return;
    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _visibleCount += _pageSize;
          _isLoadingMore = false;
        });
      }
    });
  }

  void _resetPagination() {
    _visibleCount = _pageSize;
    _isLoadingMore = false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    return (_searchDistance != 500.0 ? 1 : 0) + _extraFilterHobbies.length;
  }

  void _showFilterSheet(
    BuildContext context,
    AppColorScheme colors,
    bool isDark,
  ) {
    HapticFeedback.mediumImpact();
    // Get current user's hobby names to exclude from filter sheet
    final uid = ref.read(currentUserIdProvider);
    final userHobbiesList = uid != null
        ? (ref.read(userHobbiesProvider(uid)).value ?? [])
        : <UserHobby>[];
    final ownedNames = userHobbiesList
        .where((uh) => uh.hobby != null)
        .map((uh) => uh.hobby!.name)
        .toSet();
    final primaryName = userHobbiesList
        .where((uh) => uh.isPrimary && uh.hobby != null)
        .map((uh) => uh.hobby!.name)
        .firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FilterSheet(
          colors: colors,
          isDark: isDark,
          selectedHobbies: _extraFilterHobbies,
          searchDistance: _searchDistance,
          ownedHobbyNames: ownedNames,
          primaryHobbyName: primaryName,
          onApply: (hobbies, distance) {
            setState(() {
              _extraFilterHobbies = hobbies;
              _searchDistance = distance;
              _resetPagination();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    // Load user's own hobbies from backend
    final userId = ref.watch(currentUserIdProvider);
    final userHobbies = userId != null
        ? ref.watch(userHobbiesProvider(userId)).value ?? []
        : <UserHobby>[];
    // Primary hobby name (for highlight)
    final primaryHobbyName = userHobbies
        .where((uh) => uh.isPrimary && uh.hobby != null)
        .map((uh) => uh.hobby!.name)
        .firstOrNull;
    // All user hobby names
    final myHobbyNames = userHobbies
        .where((uh) => uh.hobby != null)
        .map((uh) => uh.hobby!.name)
        .toList();
    // The full hobby pool = user's own hobbies + filter-added hobbies.
    final hobbyPool = <String>{...myHobbyNames, ..._extraFilterHobbies};

    // Build the hobby filter key based on which pill is active:
    //  • "All" or "Trending" → the entire pool
    //  • Individual hobby pill → just that one hobby
    final isHobbySelected =
        _selectedTag != 'All' && _selectedTag != 'Trending';
    final activeHobbies = isHobbySelected
        ? <String>{_selectedTag}
        : hobbyPool;
    final hobbyNamesKey = ([...activeHobbies]..sort()).join(',');

    // When typing a name query, bypass hobby filter entirely so ALL matching
    // users appear regardless of shared hobbies (Instagram-style people search).
    final isSearching = _searchQuery.isNotEmpty;
    final effectiveHobbyKey = isSearching ? '' : hobbyNamesKey;

    List<MatchedUser> users;
    bool isLoading = false;
    if (!isAuthenticated) {
      users = [];
    } else {
      final searchAsync = ref.watch(searchResultsProvider((
        query: _searchQuery,
        category: null,
        hobbyNames: effectiveHobbyKey,
        distanceKm: _searchDistance,
      )));
      users = searchAsync.value ?? <MatchedUser>[];
      isLoading = searchAsync.isLoading;

      // Trending → sort by highest followers (only in grid mode)
      if (!isSearching && _selectedTag == 'Trending') {
        users = [...users]
          ..sort((a, b) => b.followerCount.compareTo(a.followerCount));
      }
    }
    final topPadding = MediaQuery.of(context).padding.top;
    // Search mode: no tags row → smaller header
    // Grid mode: 12 (top) + 48 (search) + 12 (gap) + 34 (tags) + 12 (bottom)
    final headerHeight =
        isSearching ? topPadding + 72.0 : topPadding + 118.0;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          children: [
            // ── Scrollable Content ───────────────────────────────────────
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: headerHeight)),

                // Distance active chip (hobbies shown in tag strip above)
                if (_searchDistance != 500.0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [
                          _ActiveChip(
                            label: '📍 ${_searchDistance.round()} km',
                            onRemove: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _searchDistance = 500.0;
                                _resetPagination();
                              });
                            },
                            colors: colors,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                // List (search mode) or grid (discovery mode)
                SliverToBoxAdapter(
                  child: isLoading && users.isEmpty
                      ? _buildLoadingState(colors, isDark)
                      : users.isEmpty && isSearching
                          ? _buildEmptyState(isDark)
                          : isSearching
                              ? _buildUserList(users, colors, isDark)
                              : users.isEmpty
                                  ? _buildEmptyState(isDark)
                                  : _buildAsymmetricGrid(
                                      users,
                                      colors,
                                      isDark,
                                    ),
                ),

                // ── Load-more footer ────────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildLoadMoreFooter(
                    users: users,
                    colors: colors,
                    isDark: isDark,
                  ),
                ),

                // Space above bottom nav bar (64px bar + system bottom inset)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 64 + MediaQuery.of(context).padding.bottom + 16,
                  ),
                ),
              ],
            ),

            // ── Glassmorphic Header (overlay) ────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildGlassHeader(
                colors, isDark,
                myHobbyNames: myHobbyNames,
                primaryHobbyName: primaryHobbyName,
                isSearching: isSearching,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Glassmorphic Header ──────────────────────────────────────────────────

  Widget _buildGlassHeader(
    AppColorScheme colors,
    bool isDark, {
    required List<String> myHobbyNames,
    required String? primaryHobbyName,
    required bool isSearching,
  }) {
    return Container(
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Search Row ───────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (v) => setState(() {
                              _searchQuery = v;
                              _resetPagination();
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search people...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                size: 22,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _resetPagination();
                                        });
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _showFilterSheet(
                          context,
                          ref.read(appColorSchemeProvider),
                          Theme.of(context).brightness == Brightness.dark,
                        ),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: _activeFilterCount > 0
                                    ? colors.primary
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black45),
                                size: 24,
                              ),
                              if (_activeFilterCount > 0)
                                Positioned(
                                  top: 9,
                                  right: 9,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!isSearching) ...[
                  const SizedBox(height: 12),

                  // ── Tags row: quick tags + user hobby pills + extra filter pills ──
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Static quick tags first
                        ..._quickTags.map((tag) {
                          final isSelected = tag == _selectedTag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedTag = tag;
                                  _resetPagination();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary
                                      : (isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(99),
                                  border: isSelected
                                      ? null
                                      : Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : Colors.black.withValues(alpha: 0.08),
                                        ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : (isDark ? Colors.white70 : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        // User's own hobbies (primary first, right after Trending)
                        ...[
                          if (primaryHobbyName != null) primaryHobbyName,
                          ...myHobbyNames.where((h) => h != primaryHobbyName),
                        ].map((hobby) {
                          final isPrimary = hobby == primaryHobbyName;
                          final isSelected = _selectedTag == hobby;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedTag = hobby;
                                  _resetPagination();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary
                                      : (isDark
                                            ? colors.primary.withValues(alpha: 0.15)
                                            : colors.primary.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(99),
                                  border: isSelected
                                      ? null
                                      : Border.all(
                                          color: colors.primary.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPrimary) ...[
                                      Icon(
                                        Icons.star_rounded,
                                        size: 13,
                                        color: isSelected
                                            ? Colors.white
                                            : colors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      hobby,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white.withValues(alpha: 0.9)
                                                  : colors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        // Extra hobbies from filter sheet (same behavior as own hobbies)
                        ..._extraFilterHobbies
                            .where((h) => !myHobbyNames.contains(h))
                            .map((hobby) {
                          final isSelected = _selectedTag == hobby;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedTag = hobby;
                                  _resetPagination();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary
                                      : (isDark
                                            ? colors.primary.withValues(alpha: 0.15)
                                            : colors.primary.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(99),
                                  border: isSelected
                                      ? null
                                      : Border.all(
                                          color: colors.primary.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  hobby,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white.withValues(alpha: 0.9)
                                              : colors.primary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  ], // end if (!isSearching)
                ],
              ),
            ),
          ),
    );
  }

  // ── Load-more Footer ─────────────────────────────────────────────────────

  Widget _buildLoadMoreFooter({
    required List<MatchedUser> users,
    required AppColorScheme colors,
    required bool isDark,
  }) {
    if (users.isEmpty) return const SizedBox.shrink();

    final hasMore = _visibleCount < _pageSize * _maxPages;

    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.primary,
            ),
          ),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.08),
                indent: 16,
                endIndent: 12,
              ),
            ),
            Text(
              'You\'ve seen everyone',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.08),
                indent: 12,
                endIndent: 16,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Asymmetric Grid ──────────────────────────────────────────────────────

  Widget _buildAsymmetricGrid(
    List<MatchedUser> users,
    AppColorScheme colors,
    bool isDark,
  ) {
    // Wrap-around helper so we always fill every slot even with few users.
    MatchedUser u(int i) => users[i % users.length];

    Widget tile(MatchedUser user, _TileSize size) => GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/user/${user.id}');
      },
      child: _GridTile(user: user, size: size, colors: colors),
    );

    /// Builds one page of 9 cards using the original staggered wireframe.
    ///
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

          // ── Row A: Big left (2/3) + 2 stacked right (1/3) ─────
          SizedBox(
            height: 256,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: tile(u(pageOffset + 0), _TileSize.large)),
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

          // ── Row B: 3 equal small tiles ─────────────────────────
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

          // ── Row C: 2 stacked left (1/3) + Big right (2/3) ─────
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
                Expanded(flex: 2, child: tile(u(pageOffset + 8), _TileSize.large)),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      );
    }

    // Build pages based on _visibleCount (multiples of 9).
    final pageCount = (_visibleCount / _pageSize).ceil().clamp(1, 2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          for (int p = 0; p < pageCount; p++) buildPage(p * _pageSize),
        ],
      ),
    );
  }

  // ── Instagram-style User List (active search mode) ───────────────────────

  Widget _buildUserList(
    List<MatchedUser> users,
    AppColorScheme colors,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final user in users)
            _UserListTile(user: user, colors: colors, isDark: isDark),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────

  // ── Loading State ─────────────────────────────────────────────────────────

  Widget _buildLoadingState(AppColorScheme colors, bool isDark) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding people...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 36,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No one found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try broadening your search or filters',
              style: TextStyle(
                color: isDark ? Colors.white24 : Colors.black26,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Instagram-style User List Tile
// ─────────────────────────────────────────────────────────────────────────────

class _UserListTile extends ConsumerStatefulWidget {
  final MatchedUser user;
  final AppColorScheme colors;
  final bool isDark;

  const _UserListTile({
    required this.user,
    required this.colors,
    required this.isDark,
  });

  @override
  ConsumerState<_UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends ConsumerState<_UserListTile> {
  bool _followLoading = false;

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_followLoading) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    setState(() => _followLoading = true);
    final client = ref.read(supabaseProvider);
    try {
      if (currentlyFollowing) {
        await FollowService(client).unfollow(currentUserId, widget.user.id);
        await NotificationService(client).deleteFollowNotification(
          recipientId: widget.user.id,
          actorId: currentUserId,
        );
      } else {
        await FollowService(client).follow(currentUserId, widget.user.id);
        await NotificationService(client).createFollowNotification(
          recipientId: widget.user.id,
          actorId: currentUserId,
        );
      }
      ref.invalidate(isFollowingProvider(widget.user.id));
      ref.invalidate(profileStatsProvider(widget.user.id));
      ref.invalidate(currentProfileProvider);
      ref.invalidate(followingIdsProvider);
      ref.invalidate(notificationsProvider);
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

    // Subtitle: primary hobby + distance
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
            // ── Avatar ─────────────────────────────────────────────
            CircleAvatar(
              radius: 26,
              backgroundColor: colors.primary.withValues(alpha: 0.15),
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
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

            // ── Name + username + subtitle ──────────────────────────
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

            // ── Follow button ───────────────────────────────────────
            GestureDetector(
              onTap: _followLoading ? null : () => _toggleFollow(isFollowing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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

// ─────────────────────────────────────────────────────────────────────────────
// Grid Tile — sized profile card
// ─────────────────────────────────────────────────────────────────────────────

enum _TileSize { large, medium, small }

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
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    setState(() => _followLoading = true);
    final client = ref.read(supabaseProvider);
    try {
      if (currentlyFollowing) {
        await FollowService(client).unfollow(currentUserId, widget.user.id);
        await NotificationService(client).deleteFollowNotification(
          recipientId: widget.user.id,
          actorId: currentUserId,
        );
      } else {
        await FollowService(client).follow(currentUserId, widget.user.id);
        await NotificationService(client).createFollowNotification(
          recipientId: widget.user.id,
          actorId: currentUserId,
        );
      }
      ref.invalidate(isFollowingProvider(widget.user.id));
      ref.invalidate(profileStatsProvider(widget.user.id));
      ref.invalidate(currentProfileProvider);
      ref.invalidate(followingIdsProvider);
      ref.invalidate(notificationsProvider);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = ref.watch(isFollowingProvider(widget.user.id)).value ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image ────────────────────────────────────────────────────
          AppCachedImage(
            imageUrl: widget.user.avatarUrl,
            fit: BoxFit.cover,
            errorWidget: Container(color: Colors.grey.shade800),
          ),

          // ── Gradient overlay ─────────────────────────────────────────
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

          // ── Primary hobby badge (top-left) ────────────────────────────
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

          // ── Bottom card content ───────────────────────────────────────
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
      _TileSize.medium => _MediumContent(
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

// ── Primary hobby badge ───────────────────────────────────────────────────────

class _HobbyBadge extends StatelessWidget {
  final String icon;
  final String? name; // null = icon only (small/medium tiles)

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

// ── Large tile content (avatar + name + bio + distance + follow) ─────────────

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
    final bio =
        (user.bio ?? '').length > 44 ? '${(user.bio ?? '').substring(0, 44)}…' : (user.bio ?? '');

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
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
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

// ── Medium tile content (name + distance + small follow) ─────────────────────

class _MediumContent extends StatelessWidget {
  final MatchedUser user;
  final AppColorScheme colors;
  final String locationText;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onFollow;

  const _MediumContent({
    required this.user,
    required this.colors,
    required this.locationText,
    required this.isFollowing,
    required this.isLoading,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
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
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
                if (locationText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 9,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        locationText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onFollow();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isFollowing
                    ? Colors.white.withValues(alpha: 0.18)
                    : colors.primary,
                borderRadius: BorderRadius.circular(99),
                boxShadow: isFollowing
                    ? null
                    : [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isFollowing ? '✓' : '+ Follow',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: isFollowing ? 0.85 : 1.0,
                        ),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small tile content (name + distance only) ─────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Badges
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Active Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final AppColorScheme colors;
  final bool isDark;

  const _ActiveChip({
    required this.label,
    required this.onRemove,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 12,
                color: isDark ? Colors.white70 : colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Filter Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _FilterSheet extends ConsumerStatefulWidget {
  final AppColorScheme colors;
  final bool isDark;
  final List<String> selectedHobbies;
  final double searchDistance;
  final Function(List<String>, double) onApply;
  final Set<String> ownedHobbyNames;
  final String? primaryHobbyName;

  const _FilterSheet({
    required this.colors,
    required this.isDark,
    required this.selectedHobbies,
    required this.searchDistance,
    required this.onApply,
    this.ownedHobbyNames = const {},
    this.primaryHobbyName,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late List<String> _tempSelectedHobbies;
  late double _tempDistance;
  static const int _previewCount = 8;

  @override
  void initState() {
    super.initState();
    _tempSelectedHobbies = List.from(widget.selectedHobbies);
    _tempDistance = widget.searchDistance;
  }

  bool get _hasChanges =>
      _tempSelectedHobbies.isNotEmpty || _tempDistance != 500.0;

  void _openAllHobbiesSheet(
    BuildContext context,
    List<Map<String, dynamic>> allHobbies,
    Color surfaceColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllHobbiesDialog(
        colors: widget.colors,
        isDark: widget.isDark,
        allHobbies: allHobbies,
        selectedHobbies: _tempSelectedHobbies,
        surfaceColor: surfaceColor,
        onChanged: (updated) => setState(() => _tempSelectedHobbies = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHobbiesAsync = ref.watch(allHobbiesProvider);
    final allHobbiesMaps = (allHobbiesAsync.value ?? [])
        .where((h) => !widget.ownedHobbyNames.contains(h.name))
        .map((h) => {
              'name': h.name,
              'icon': h.icon,
              'color': h.color,
              'category': h.category,
            })
        .toList();
    final surfaceColor =
        widget.isDark ? AppColors.darkScaffold : AppColors.lightScaffold;

    return Scaffold(
      backgroundColor: widget.isDark ? AppColors.darkSurface : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const Spacer(),
                  if (_hasChanges)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _tempSelectedHobbies.clear();
                          _tempDistance = 500.0;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade100,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Scrollable Content ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Distance ───────────────────────────────────────
                    _SectionLabel(
                      icon: Icons.near_me_rounded,
                      label: 'Distance',
                      color: widget.colors.primary,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Up to',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.colors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_tempDistance.round()} km',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: widget.colors.primary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              activeTrackColor: widget.colors.primary,
                              inactiveTrackColor: widget.colors.primary
                                  .withValues(alpha: 0.12),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 9,
                                elevation: 3,
                                pressedElevation: 5,
                              ),
                              overlayColor: widget.colors.primary
                                  .withValues(alpha: 0.08),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20,
                              ),
                            ),
                            child: Slider(
                              value: _tempDistance,
                              min: 5,
                              max: 500,
                              divisions: 99,
                              onChanged: (value) {
                                setState(() => _tempDistance = value);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '5 km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  '500 km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Hobbies ────────────────────────────────────────
                    _SectionLabel(
                      icon: Icons.interests_rounded,
                      label: 'Interests',
                      color: widget.colors.primary,
                    ),
                    const SizedBox(height: 14),

                    // User's own hobbies — display-only, all fit in one row
                    if (widget.ownedHobbyNames.isNotEmpty) ...[
                      Text(
                        'Your hobbies',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final allHobbies =
                            ref.read(allHobbiesProvider).value ?? [];
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.ownedHobbyNames.map((name) {
                            final hobbyData = allHobbies
                                .where((h) => h.name == name)
                                .firstOrNull;
                            final icon = hobbyData?.icon ?? '✨';
                            final isPrimary =
                                name == widget.primaryHobbyName;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.colors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.colors.primary
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPrimary) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: widget.colors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    '$icon $name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: widget.colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Filter-selected hobbies — wrap, 5 per row then new line
                    if (_tempSelectedHobbies.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tempSelectedHobbies.map((name) {
                          final hobbyData = allHobbiesMaps.firstWhere(
                            (h) => h['name'] == name,
                            orElse: () => {'name': name, 'icon': '✨'},
                          );
                          final icon = hobbyData['icon'] ?? '✨';
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(
                                  () => _tempSelectedHobbies.remove(name));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.colors.primary
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.colors.primary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$icon $name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: widget.colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: widget.colors.primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      'Add more interests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white54
                            : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Unselected hobbies — wrap grid (first 8 that aren't selected)
                    Builder(builder: (_) {
                      final unselected = allHobbiesMaps
                          .where((h) =>
                              !_tempSelectedHobbies.contains(h['name']))
                          .toList();
                      final visible = unselected.length > _previewCount
                          ? unselected.sublist(0, _previewCount)
                          : unselected;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          ...visible.map((hobby) {
                            final name = hobby['name'] as String;
                            final icon = hobby['icon'] ?? '✨';
                            return _HobbyChip(
                              name: name,
                              icon: icon,
                              isSelected: false,
                              colors: widget.colors,
                              isDark: widget.isDark,
                              surfaceColor: surfaceColor,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(
                                    () => _tempSelectedHobbies.add(name));
                              },
                            );
                          }),
                          // Show more button
                          if (allHobbiesMaps.length > _previewCount)
                            GestureDetector(
                              onTap: () => _openAllHobbiesSheet(
                                context,
                                allHobbiesMaps,
                                surfaceColor,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: widget.isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                  ),
                                ),
                                child: Text(
                                  'Show more',
                                  style: TextStyle(
                                    color: widget.colors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ── Apply Button ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              decoration: BoxDecoration(
                color:
                    widget.isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onApply(_tempSelectedHobbies, _tempDistance);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _hasChanges ? 'Apply Filters' : 'Done',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
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

// ═════════════════════════════════════════════════════════════════════════════
// All Hobbies Bottom Sheet Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _AllHobbiesDialog extends StatefulWidget {
  final AppColorScheme colors;
  final bool isDark;
  final List<Map<String, dynamic>> allHobbies;
  final List<String> selectedHobbies;
  final Color surfaceColor;
  final ValueChanged<List<String>> onChanged;

  const _AllHobbiesDialog({
    required this.colors,
    required this.isDark,
    required this.allHobbies,
    required this.selectedHobbies,
    required this.surfaceColor,
    required this.onChanged,
  });

  @override
  State<_AllHobbiesDialog> createState() => _AllHobbiesDialogState();
}

class _AllHobbiesDialogState extends State<_AllHobbiesDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedHobbies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.allHobbies
        : widget.allHobbies
            .where((h) => (h['name'] as String)
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();
    final bg = widget.isDark ? AppColors.darkSurface : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // ── Handle bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title + Unselect all + Done ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'All Interests',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selected.clear());
                        },
                        child: Text(
                          'Unselect all',
                          style: TextStyle(
                            color: Colors.redAccent.shade100,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        widget.onChanged(_selected);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: widget.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search field ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search interests...',
                      hintStyle: TextStyle(
                        color: widget.isDark
                            ? Colors.white24
                            : Colors.black26,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: widget.isDark
                            ? Colors.white70
                            : Colors.black26,
                        size: 20,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                size: 20,
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

              // ── Hobby list ─────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No interests found',
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.black26,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: filtered.map((hobby) {
                            final name = hobby['name'] as String;
                            final icon =
                                hobby['icon'] as String? ?? '✨';
                            final isSelected = _selected.contains(name);
                            return _HobbyChip(
                              name: name,
                              icon: icon,
                              isSelected: isSelected,
                              colors: widget.colors,
                              isDark: widget.isDark,
                              surfaceColor: widget.surfaceColor,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (isSelected) {
                                    _selected.remove(name);
                                  } else {
                                    _selected.add(name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Reusable Hobby Chip
// ═════════════════════════════════════════════════════════════════════════════

class _HobbyChip extends StatelessWidget {
  final String name;
  final String icon;
  final bool isSelected;
  final AppColorScheme colors;
  final bool isDark;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _HobbyChip({
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.isDark,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : colors.primary)
                    : (isDark ? Colors.white60 : Colors.black54),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

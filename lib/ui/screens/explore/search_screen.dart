import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/matched_user.dart';
import '../../../core/models/user_hobby.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/explore_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/search/search_header.dart';
import '../../widgets/search/search_asymmetric_grid.dart';
import '../../widgets/search/search_filter_sheet.dart';
import '../../widgets/search/search_user_list_tile.dart';
import '../waves/user_waves_viewer.dart';

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

  int _searchMode = 0; // 0 = People, 1 = Waves
  String _waveQuery = '';

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
    final tagCount =
        (_selectedTag != 'All' && _selectedTag != 'Trending') ? 1 : 0;
    return (_searchDistance != 500.0 ? 1 : 0) +
        _extraFilterHobbies.length +
        tagCount;
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
        builder: (_) => SearchFilterSheet(
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
              // Reset selected tag if it no longer exists in the new pool
              final newPool = <String>{...ownedNames, ...hobbies};
              if (_selectedTag != 'All' &&
                  _selectedTag != 'Trending' &&
                  !newPool.contains(_selectedTag)) {
                _selectedTag = 'All';
              }
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
    final isHobbySelected = _selectedTag != 'All' && _selectedTag != 'Trending';
    final activeHobbies = isHobbySelected ? <String>{_selectedTag} : hobbyPool;
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
      final searchAsync = ref.watch(
        searchResultsProvider((
          query: _searchQuery,
          category: null,
          hobbyNames: effectiveHobbyKey,
          distanceKm: _searchDistance,
        )),
      );
      users = searchAsync.value ?? <MatchedUser>[];
      isLoading = searchAsync.isLoading;

      // Trending → sort by highest followers (only in grid mode)
      if (!isSearching && _selectedTag == 'Trending') {
        users = [...users]
          ..sort((a, b) => b.followerCount.compareTo(a.followerCount));
      }
    }
    final topPadding = MediaQuery.of(context).padding.top;
    // Toggle + search + optional tags
    final headerHeight = _searchMode == 1
        ? topPadding + 110.0
        : isSearching
            ? topPadding + 110.0
            : topPadding + 152.0;

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

                if (_searchMode == 0) ...[

                // Distance active chip (hobbies shown in tag strip above)
                if (_searchDistance != 500.0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [
                          SearchActiveChip(
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
                      ? _buildSearchEmptyState(isDark)
                      : isSearching
                      ? _buildUserList(users, colors, isDark)
                      : users.isEmpty
                      ? _buildDiscoveryEmptyState(isDark)
                      : SearchAsymmetricGrid(
                          users: users,
                          visibleCount: _visibleCount,
                          pageSize: _pageSize,
                          maxPages: _maxPages,
                          colors: colors,
                          onUserTap: (id) => context.push('/user/$id'),
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

                ], // end People mode

                // ── Waves mode ──────────────────────────────────────────
                if (_searchMode == 1)
                  SliverToBoxAdapter(
                    child: _buildWavesContent(colors, isDark, userHobbies),
                  ),

                // Clearance for the floating nav bar (64pt height + 24pt
                // gap-from-screen-bottom + device safe-area inset).
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100 + MediaQuery.of(context).padding.bottom,
                  ),
                ),
              ],
            ),

            // ── Glassmorphic Header (overlay) ────────────────────────────
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
                        color: colors.primary.withValues(alpha: 0.1)),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── People / Waves toggle (top-most) ────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              for (final (i, label) in [
                                (0, 'People'),
                                (1, 'Waves'),
                              ])
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _searchController.clear();
                                      setState(() {
                                        _searchMode = i;
                                        _searchQuery = '';
                                        _waveQuery = '';
                                        _resetPagination();
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: _searchMode == i
                                            ? (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.12)
                                                : Colors.white)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(7),
                                        boxShadow: _searchMode == i
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(
                                                          alpha: 0.06),
                                                  blurRadius: 4,
                                                  offset:
                                                      const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _searchMode == i
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: _searchMode == i
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                                : (isDark
                                                    ? Colors.white38
                                                    : Colors.black38),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ── Search bar row ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
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
                                    if (_searchMode == 0) {
                                      _searchQuery = v;
                                      _resetPagination();
                                    } else {
                                      _waveQuery = v;
                                    }
                                  }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDark ? Colors.white : Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _searchMode == 0
                                        ? 'Search people...'
                                        : 'Search waves...',
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
                                    suffixIcon: (_searchQuery.isNotEmpty ||
                                            _waveQuery.isNotEmpty)
                                        ? GestureDetector(
                                            onTap: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                                _waveQuery = '';
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
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            if (_searchMode == 0) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _showFilterSheet(
                                    context, colors, isDark),
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
                          ],
                        ),
                      ),

                      // ── Tags row (People mode only, not searching) ──
                      if (_searchMode == 0 && !isSearching)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          child: SizedBox(
                            height: 34,
                            child: SearchTagsRow(
                              selectedTag: _selectedTag,
                              myHobbyNames: myHobbyNames,
                              primaryHobbyName: primaryHobbyName,
                              extraFilterHobbies: _extraFilterHobbies,
                              colors: colors,
                              isDark: isDark,
                              onTagSelected: (tag) => setState(() {
                                _selectedTag = tag;
                                _resetPagination();
                              }),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
            SearchUserListTile(user: user, colors: colors, isDark: isDark),
        ],
      ),
    );
  }

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

  // ── Empty States ─────────────────────────────────────────────────────────

  Widget _buildSearchEmptyState(bool isDark) {
    return _buildEmptyState(
      isDark: isDark,
      icon: Icons.person_search_rounded,
      title: 'No one found',
      subtitle: 'Try a different name or username',
    );
  }

  Widget _buildDiscoveryEmptyState(bool isDark) {
    return _buildEmptyState(
      isDark: isDark,
      icon: Icons.group_off_rounded,
      title: 'No matches yet',
      subtitle: 'Try adding more hobbies or broadening your filters',
    );
  }

  Widget _buildWavesContent(
    AppColorScheme colors,
    bool isDark,
    List<UserHobby> userHobbies,
  ) {
    final wavesAsync = ref.watch(searchWavesProvider(_waveQuery));
    final allHobbies = ref.watch(allHobbiesProvider).asData?.value ?? [];
    final hobbyMap = {for (final h in allHobbies) h.id: h};

    return wavesAsync.when(
      loading: () => const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      error: (e, _) => SizedBox(
        height: 300,
        child: Center(
          child: Text('Failed to load waves',
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black26)),
        ),
      ),
      data: (waves) {
        if (waves.isEmpty) {
          return SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined,
                      size: 48,
                      color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: 12),
                  Text(
                    _waveQuery.isNotEmpty
                        ? 'No waves match "$_waveQuery"'
                        : 'No waves yet',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black26,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: waves.length,
            itemBuilder: (context, i) {
              final wave = waves[i];
              final hobby = wave.hobbyId != null
                  ? hobbyMap[wave.hobbyId]
                  : null;

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserWavesViewer(
                        waves: waves,
                        initialIndex: i,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppCachedImage(
                        imageUrl: wave.thumbnailUrl ?? '',
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade200,
                          child: Icon(Icons.play_circle_outline,
                              size: 32,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black12),
                        ),
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Talent badge
                      if (hobby != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${hobby.icon} ${hobby.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // Bottom info
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (wave.caption.isNotEmpty)
                              Text(
                                wave.caption,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '@${wave.username ?? 'user'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white70, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  _formatCount(wave.viewCount),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatCount(int n) {
    if (n < 1000) return n.toString();
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
                icon,
                size: 36,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
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

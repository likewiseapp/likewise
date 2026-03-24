import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/matched_user.dart';
import '../../../core/models/user_hobby.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/explore_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/search/search_header.dart';
import '../../widgets/search/search_asymmetric_grid.dart';
import '../../widgets/search/search_filter_sheet.dart';
import '../../widgets/search/search_user_list_tile.dart';

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
    // Search mode: no tags row → smaller header
    // Grid mode: 12 (top) + 48 (search) + 12 (gap) + 34 (tags) + 12 (bottom)
    final headerHeight = isSearching ? topPadding + 72.0 : topPadding + 118.0;

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
              child: SearchHeader(
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                searchQuery: _searchQuery,
                isSearching: isSearching,
                selectedTag: _selectedTag,
                activeFilterCount: _activeFilterCount,
                myHobbyNames: myHobbyNames,
                primaryHobbyName: primaryHobbyName,
                extraFilterHobbies: _extraFilterHobbies,
                colors: colors,
                isDark: isDark,
                onSearchChanged: (v) => setState(() {
                  _searchQuery = v;
                  _resetPagination();
                }),
                onSearchCleared: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _resetPagination();
                  });
                },
                onTagSelected: (tag) => setState(() {
                  _selectedTag = tag;
                  _resetPagination();
                }),
                onFilterTap: () => _showFilterSheet(
                  context,
                  ref.read(appColorSchemeProvider),
                  Theme.of(context).brightness == Brightness.dark,
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

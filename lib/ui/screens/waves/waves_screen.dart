import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/providers/navigation_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/wave_comments_sheet.dart';
import 'wave_player_manager.dart';

class WavesScreen extends ConsumerStatefulWidget {
  const WavesScreen({super.key});

  @override
  ConsumerState<WavesScreen> createState() => _WavesScreenState();
}

class _WavesScreenState extends ConsumerState<WavesScreen> {
  final PageController _pageController = PageController();
  late final WavePlayerManager _player;
  @override
  void initState() {
    super.initState();
    _player = WavePlayerManager(
      isMounted: () => mounted,
      setState: setState,
      qualityUrlResolver: (_) async => null,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabActiveChanged(bool isActive) {
    if (isActive) {
      _player.reset();
      setState(() {});
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      ref.invalidate(wavesProvider);
    } else {
      _player.deactivate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wavesAsync = ref.watch(wavesProvider);
    final isTabActive = ref.watch(selectedTabProvider) == 1;
    _player.isTabActive = isTabActive;

    ref.listen(selectedTabProvider, (_, next) => _onTabActiveChanged(next == 1));

    final colors = ref.watch(appColorSchemeProvider);

    final activeHobbyId = ref.watch(waveHobbyFilterProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          wavesAsync.when(
        loading: () => _WavesLoadingScreen(colors: colors),
        error: (e, _) => Center(
          child: Text(
            'Failed to load waves\n$e',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        data: (waves) {
          final wavesChanged = _player.setWaves(waves);

          if (waves.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined,
                      size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No waves yet.\nBe the first to post one!',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (wavesChanged && isTabActive) {
            _player.firstVideoReady = false;
            _player.loadAndPlay(0);
          }

          if (!_player.firstVideoReady) {
            return _WavesLoadingScreen(colors: colors);
          }

          return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: waves.length,
                onPageChanged: _player.onPageChanged,
                itemBuilder: (context, index) => _WaveItem(
                  wave: waves[index],
                  controller: _player.controllers[index],
                  error: _player.errors[index],
                  isActive: index == _player.currentIndex && isTabActive,
                  onTogglePlayPause: () {
                    final ctrl = _player.controllers[index];
                    if (ctrl == null || !ctrl.value.isInitialized) return;
                    setState(() {
                      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
                    });
                  },
                  onRetry: () {
                    _player.errors.remove(index);
                    _player.loadAndPlay(index);
                  },
                ),
          );
        },
      ),

          // ── Filter button (top-left) ──────────────────────────────────
          Positioned(
            top: 14 + MediaQuery.of(context).padding.top,
            left: 14,
            child: GestureDetector(
              onTap: () => _showHobbyFilter(context, ref, colors),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: activeHobbyId != null
                      ? colors.primary.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activeHobbyId != null
                        ? colors.primary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: activeHobbyId != null
                          ? colors.primary
                          : Colors.white,
                    ),
                    if (activeHobbyId != null) ...[
                      const SizedBox(width: 6),
                      Consumer(builder: (_, ref, __) {
                        final hobbies = ref.watch(allHobbiesProvider);
                        final name = hobbies.whenOrNull(
                          data: (list) => list
                              .where((h) => h.id == activeHobbyId)
                              .map((h) => '${h.icon} ${h.name}')
                              .firstOrNull,
                        );
                        return Text(
                          name ?? '...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          ref.read(waveHobbyFilterProvider.notifier).clear();
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHobbyFilter(
      BuildContext context, WidgetRef ref, AppColorScheme colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HobbyFilterSheet(ref: ref, colors: colors),
    );
  }
}

// ── Hobby filter bottom sheet ────────────────────────────────────────────────

class _HobbyFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final AppColorScheme colors;

  const _HobbyFilterSheet({required this.ref, required this.colors});

  @override
  ConsumerState<_HobbyFilterSheet> createState() => _HobbyFilterSheetState();
}

class _HobbyFilterSheetState extends ConsumerState<_HobbyFilterSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allHobbies = ref.watch(allHobbiesProvider);
    final userId = ref.watch(currentUserIdProvider);
    final userHobbiesAsync =
        userId != null ? ref.watch(userHobbiesProvider(userId)) : null;
    final activeId = ref.watch(waveHobbyFilterProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text(
                  'Filter by talent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (activeId != null)
                  GestureDetector(
                    onTap: () {
                      ref.read(waveHobbyFilterProvider.notifier).clear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: widget.colors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search talents...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.white38, size: 20),
                filled: true,
                fillColor: Colors.white10,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Flexible(
            child: allHobbies.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Colors.white38),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (hobbies) {
                final userHobbyIds = userHobbiesAsync?.whenOrNull(
                      data: (list) =>
                          list.map((uh) => uh.hobbyId).toSet(),
                    ) ??
                    <int>{};

                var filtered = hobbies.where(
                  (h) => h.name.toLowerCase().contains(_query),
                ).toList();

                // User's hobbies first
                filtered.sort((a, b) {
                  final aUser = userHobbyIds.contains(a.id) ? 0 : 1;
                  final bUser = userHobbyIds.contains(b.id) ? 0 : 1;
                  if (aUser != bUser) return aUser.compareTo(bUser);
                  return a.name.compareTo(b.name);
                });

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final hobby = filtered[i];
                    final isUserHobby = userHobbyIds.contains(hobby.id);
                    final isActive = hobby.id == activeId;

                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: Text(hobby.icon,
                          style: const TextStyle(fontSize: 20)),
                      title: Row(
                        children: [
                          Text(
                            hobby.name,
                            style: TextStyle(
                              color: isActive
                                  ? widget.colors.primary
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (isUserHobby) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: widget.colors.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'yours',
                                style: TextStyle(
                                  color: widget.colors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isActive
                          ? Icon(Icons.check_circle_rounded,
                              color: widget.colors.primary, size: 20)
                          : null,
                      onTap: () {
                        ref
                            .read(waveHobbyFilterProvider.notifier)
                            .set(hobby.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waves loading screen ──────────────────────────────────────────────────────

class _WavesLoadingScreen extends StatefulWidget {
  final AppColorScheme colors;

  const _WavesLoadingScreen({required this.colors});

  @override
  State<_WavesLoadingScreen> createState() => _WavesLoadingScreenState();
}

class _WavesLoadingScreenState extends State<_WavesLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.colors.primary, widget.colors.accent],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.colors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading waves...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual wave item ──────────────────────────────────────────────────────

class _WaveItem extends ConsumerStatefulWidget {
  final Wave wave;
  final VideoPlayerController? controller;
  final String? error;
  final bool isActive;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onRetry;

  const _WaveItem({
    required this.wave,
    required this.controller,
    required this.error,
    required this.isActive,
    required this.onTogglePlayPause,
    required this.onRetry,
  });

  @override
  ConsumerState<_WaveItem> createState() => _WaveItemState();
}

// Module-level — persists across item rebuilds so bumping is dedup'd per
// session without needing a shared-prefs round-trip.
final _bumpedWaveIds = <String>{};

class _WaveItemState extends ConsumerState<_WaveItem> {
  bool _showControls = false;
  bool _captionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(waveLikesProvider.notifier).seedFrom(widget.wave);
    });
  }

  Future<void> _toggleLike() async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(waveLikesProvider.notifier).toggle(widget.wave.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not like — try again'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openComments() {
    showWaveCommentsSheet(context, waveId: widget.wave.id);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final ctrl = widget.controller;
    final isReady = ctrl != null && ctrl.value.isInitialized;

    // Bump view count once per session per wave, the first time this item is
    // active. Safe from double-bumps thanks to the module-level Set.
    if (widget.isActive && _bumpedWaveIds.add(widget.wave.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(waveEngagementServiceProvider)
            .bumpView(widget.wave.id)
            .catchError((_) {
          // Silent failure — view bumps aren't user-critical.
          _bumpedWaveIds.remove(widget.wave.id);
        });
      });
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video or thumbnail background ──────────────────────────────
          if (isReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            )
          else
            AppCachedImage(
              imageUrl: widget.wave.thumbnailUrl ?? '',
              fit: BoxFit.cover,
              errorWidget: Container(color: Colors.grey.shade900),
            ),

          // ── Gradient overlay ───────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.2, 0.55, 1.0],
              ),
            ),
          ),

          // ── Error overlay ──────────────────────────────────────────────
          if (widget.error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white54, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load video',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: widget.onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white30, width: 1),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          // ── Loading indicator (controller exists but not yet ready) ────
          else if (widget.controller != null && !isReady)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2.5,
              ),
            ),

          // ── Play/pause tap indicator ───────────────────────────────────
          if (_showControls && isReady)
            Center(
              child: GestureDetector(
                onTap: widget.onTogglePlayPause,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ctrl.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),

          // ── View count badge (top-right) ───────────────────────────────
          Positioned(
            top: 16 + MediaQuery.of(context).padding.top,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatWaveCount(widget.wave.viewCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom info: avatar + username + caption ───────────────────
          Positioned(
            left: 16,
            right: 84,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: AppCachedImage(
                          imageUrl: widget.wave.avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.white.withValues(alpha: 0.15),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.wave.username != null
                            ? '@${widget.wave.username}'
                            : (widget.wave.fullName ?? 'Unknown'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (widget.wave.caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                        () => _captionExpanded = !_captionExpanded),
                    child: Text(
                      widget.wave.caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                      maxLines: _captionExpanded ? 8 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Right action buttons ───────────────────────────────────────
          Positioned(
            right: 10,
            bottom: 120,
            child: Column(
              children: [
                // Like — watches the per-wave like state via select for
                // narrow rebuilds and animates the heart on toggle.
                Consumer(
                  builder: (context, ref, _) {
                    final liked = ref.watch(waveLikesProvider
                        .select((m) => m[widget.wave.id]?.liked ?? false));
                    final count = ref.watch(waveLikesProvider
                        .select((m) =>
                            m[widget.wave.id]?.count ?? widget.wave.likeCount));
                    return _ActionBtn(
                      icon: liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      count: count,
                      filled: liked,
                      filledColor: const Color(0xFFFF3B5C),
                      onTap: _toggleLike,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  count: widget.wave.commentCount,
                  onTap: _openComments,
                ),
                const SizedBox(height: 16),
                _ActionBtn(
                  icon: Icons.share_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share coming soon'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Progress bar ───────────────────────────────────────────────
          if (isReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 88,
              child: VideoProgressIndicator(
                ctrl,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: colors.primary,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatWaveCount(int n) {
  if (n < 1000) return n.toString();
  final k = n / 1000;
  if (k < 10) return '${k.toStringAsFixed(1)}k';
  if (k < 1000) return '${k.toStringAsFixed(0)}k';
  final m = n / 1000000;
  return '${m.toStringAsFixed(1)}M';
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool filled;
  final Color? filledColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    this.count,
    this.filled = false,
    this.filledColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = filled ? (filledColor ?? Colors.white) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: filled ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatWaveCount(count!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


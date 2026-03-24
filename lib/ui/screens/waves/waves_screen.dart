import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave.dart';
import '../../../core/providers/navigation_providers.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';

class WavesScreen extends ConsumerStatefulWidget {
  const WavesScreen({super.key});

  @override
  ConsumerState<WavesScreen> createState() => _WavesScreenState();
}

class _WavesScreenState extends ConsumerState<WavesScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _firstVideoReady = false;

  // Controllers keyed by wave list index
  final Map<int, VideoPlayerController> _controllers = {};
  List<Wave> _waves = [];

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initController(int index) async {
    if (index < 0 || index >= _waves.length) return;
    if (_controllers.containsKey(index)) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_waves[index].videoUrl),
    );
    _controllers[index] = controller;

    try {
      await controller.initialize();
      controller.setLooping(true);
      if (mounted) {
        setState(() {
          if (index == 0) _firstVideoReady = true;
        });
      }
      // Only play if this became the active index by the time init finishes
      if (index == _currentIndex && _isTabActive && mounted) {
        controller.play();
      }
    } catch (_) {
      // Mark ready even on error so we don't get stuck on the loading screen
      if (index == 0 && mounted) setState(() => _firstVideoReady = true);
    }
  }

  bool get _isTabActive => ref.read(selectedTabProvider) == 1;

  void _onPageChanged(int index) {
    // Pause the outgoing video
    _controllers[_currentIndex]?.pause();

    setState(() => _currentIndex = index);

    // Play the incoming video if already initialized
    final current = _controllers[index];
    if (current != null && current.value.isInitialized && _isTabActive) {
      current.play();
    }

    // Pre-load next
    _initController(index + 1);

    // Dispose controllers that are 2+ pages away to free memory
    final toRemove = _controllers.keys
        .where((k) => (k - index).abs() > 1)
        .toList();
    for (final k in toRemove) {
      _controllers[k]?.dispose();
      _controllers.remove(k);
    }
  }

  void _onTabActiveChanged(bool isActive) {
    if (isActive) {
      _reset();
    } else {
      _controllers[_currentIndex]?.pause();
    }
  }

  void _reset() {
    // Dispose all controllers and reset state, then re-fetch
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    setState(() {
      _currentIndex = 0;
      _firstVideoReady = false;
      _waves = [];
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    ref.invalidate(wavesProvider);

    // Cap the loading screen at 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_firstVideoReady) {
        setState(() => _firstVideoReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wavesAsync = ref.watch(wavesProvider);
    final isTabActive = ref.watch(selectedTabProvider) == 1;

    // React to tab switches without a page change
    ref.listen(selectedTabProvider, (_, next) => _onTabActiveChanged(next == 1));

    return Scaffold(
      backgroundColor: Colors.black,
      body: wavesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (e, _) => Center(
          child: Text(
            'Failed to load waves\n$e',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        data: (waves) {
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

          // Seed the wave list and kick off the first two controllers
          if (_waves != waves) {
            _waves = waves;
            _firstVideoReady = false;
            _initController(0);
            _initController(1);
          }

          if (!_firstVideoReady) {
            return _WavesLoadingScreen(colors: ref.watch(appColorSchemeProvider));
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: waves.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _WaveItem(
              wave: waves[index],
              controller: _controllers[index],
              isActive: index == _currentIndex && isTabActive,
              onTogglePlayPause: () {
                final c = _controllers[index];
                if (c == null || !c.value.isInitialized) return;
                setState(() {
                  c.value.isPlaying ? c.pause() : c.play();
                });
              },
            ),
          );
        },
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
  final bool isActive;
  final VoidCallback onTogglePlayPause;

  const _WaveItem({
    required this.wave,
    required this.controller,
    required this.isActive,
    required this.onTogglePlayPause,
  });

  @override
  ConsumerState<_WaveItem> createState() => _WaveItemState();
}

class _WaveItemState extends ConsumerState<_WaveItem> {
  bool _showControls = false;

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
              imageUrl: widget.wave.thumbnailUrl,
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

          // ── Loading indicator (controller exists but not yet ready) ────
          if (ctrl != null && !isReady)
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

          // ── Bottom info ────────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.wave.caption.isNotEmpty)
                  Text(
                    widget.wave.caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // ── Right action buttons ───────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              children: [
                _ActionBtn(icon: Icons.favorite_rounded, colors: colors),
                const SizedBox(height: 20),
                _ActionBtn(icon: Icons.chat_bubble_rounded, colors: colors),
                const SizedBox(height: 20),
                _ActionBtn(icon: Icons.share_rounded, colors: colors),
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

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final AppColorScheme colors;

  const _ActionBtn({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

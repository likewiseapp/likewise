import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave.dart';
import '../../../core/providers/navigation_providers.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: wavesAsync.when(
        loading: () => _WavesLoadingScreen(colors: colors),
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

          if (_player.setWaves(waves) && isTabActive) {
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
              isActive: index == _player.currentIndex && isTabActive,
              onTogglePlayPause: () {
                final ctrl = _player.controllers[index];
                if (ctrl == null || !ctrl.value.isInitialized) return;
                setState(() {
                  ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
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
          if (widget.controller != null && !isReady)
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

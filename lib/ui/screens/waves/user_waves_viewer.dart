import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/wave_comments_sheet.dart';
import 'wave_player_manager.dart';

class UserWavesViewer extends ConsumerStatefulWidget {
  final List<Wave> waves;
  final int initialIndex;

  const UserWavesViewer({
    super.key,
    required this.waves,
    required this.initialIndex,
  });

  @override
  ConsumerState<UserWavesViewer> createState() => _UserWavesViewerState();
}

class _UserWavesViewerState extends ConsumerState<UserWavesViewer> {
  late final PageController _pageController;
  late final WavePlayerManager _player;
  bool _showControls = false;
  bool _captionExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _player = WavePlayerManager(
      isMounted: () => mounted,
      setState: setState,
      qualityUrlResolver: (_) async => null,
    );
    _player.setWaves(widget.waves);
    _player.currentIndex = widget.initialIndex;
    _player.isTabActive = true;
    _player.loadAndPlay(widget.initialIndex);
  }

  @override
  void dispose() {
    _player.deactivate();
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  Future<void> _toggleLike(String waveId) async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(waveLikesProvider.notifier).toggle(waveId);
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

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.waves.length,
            onPageChanged: (index) {
              _player.onPageChanged(index);
              setState(() {
                _showControls = false;
                _captionExpanded = false;
              });
            },
            itemBuilder: (context, index) {
              final wave = widget.waves[index];
              final ctrl = _player.controllers[index];
              final error = _player.errors[index];
              final isReady = ctrl != null && ctrl.value.isInitialized;
              final isActive = index == _player.currentIndex;

              if (isActive) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ref.read(waveLikesProvider.notifier).seedFrom(wave);
                  }
                });
              }

              return GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video or thumbnail
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
                        imageUrl: wave.thumbnailUrl ?? '',
                        fit: BoxFit.cover,
                        errorWidget: Container(color: Colors.grey.shade900),
                      ),

                    // Gradient overlay
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

                    // Error overlay
                    if (error != null)
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
                              onTap: () {
                                _player.errors.remove(index);
                                _player.loadAndPlay(index);
                              },
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
                    else if (ctrl != null && !isReady)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2.5,
                        ),
                      ),

                    // Play/pause controls
                    if (_showControls && isReady)
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              ctrl.value.isPlaying
                                  ? ctrl.pause()
                                  : ctrl.play();
                            });
                          },
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

                    // View count badge (top-right)
                    Positioned(
                      top: 16 + MediaQuery.of(context).padding.top,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
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
                            const Icon(Icons.visibility_rounded,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              _formatCount(wave.viewCount),
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

                    // Bottom info: avatar + username + caption
                    Positioned(
                      left: 16,
                      right: 84,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
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
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: AppCachedImage(
                                    imageUrl: wave.avatarUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
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
                                  wave.username != null
                                      ? '@${wave.username}'
                                      : (wave.fullName ?? 'Unknown'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (wave.caption.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() =>
                                  _captionExpanded = !_captionExpanded),
                              child: Text(
                                wave.caption,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black54, blurRadius: 6),
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

                    // Right action buttons
                    Positioned(
                      right: 10,
                      bottom: MediaQuery.of(context).padding.bottom + 36,
                      child: Column(
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final liked = ref.watch(waveLikesProvider
                                  .select((m) =>
                                      m[wave.id]?.liked ?? false));
                              final count = ref.watch(waveLikesProvider
                                  .select((m) =>
                                      m[wave.id]?.count ??
                                      wave.likeCount));
                              return _ActionBtn(
                                icon: liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                count: count,
                                filled: liked,
                                filledColor: const Color(0xFFFF3B5C),
                                onTap: () => _toggleLike(wave.id),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _ActionBtn(
                            icon: Icons.mode_comment_outlined,
                            count: wave.commentCount,
                            onTap: () => showWaveCommentsSheet(context,
                                waveId: wave.id),
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

                    // Progress bar
                    if (isReady)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.of(context).padding.bottom,
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
            },
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 14,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int n) {
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
              _formatCount(count!),
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

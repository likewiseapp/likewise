import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  String _savedQualityLabel = 'Auto';
  final _manifestCache = <String, List<_HlsQuality>>{};

  @override
  void initState() {
    super.initState();
    _player = WavePlayerManager(
      isMounted: () => mounted,
      setState: setState,
      qualityUrlResolver: _resolveQualityUrl,
    );
    _loadSavedQuality();
  }

  Future<void> _loadSavedQuality() async {
    final label = await _QualityPrefs.load();
    if (mounted) setState(() => _savedQualityLabel = label);
  }

  Future<String?> _resolveQualityUrl(String masterUrl) async {
    if (_savedQualityLabel == 'Auto') return null;
    try {
      final qualities = _manifestCache[masterUrl]
          ?? await _parseQualities(masterUrl);
      _manifestCache[masterUrl] = qualities;
      return qualities
          .where((q) => q.label == _savedQualityLabel)
          .firstOrNull
          ?.url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onQualityChange(int index, String label, String url) async {
    await _QualityPrefs.save(label);
    if (!mounted) return;
    setState(() => _savedQualityLabel = label);
    _manifestCache.clear();
    _player.changeQuality(index, url);
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
              error: _player.errors[index],
              isActive: index == _player.currentIndex && isTabActive,
              onTogglePlayPause: () {
                final ctrl = _player.controllers[index];
                if (ctrl == null || !ctrl.value.isInitialized) return;
                setState(() {
                  ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
                });
              },
              onQualityChange: (label, url) =>
                  _onQualityChange(index, label, url),
              onRetry: () {
                _player.errors.remove(index);
                _player.loadAndPlay(index);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Quality preference (shared_preferences) ───────────────────────────────────

class _QualityPrefs {
  static const _key = 'wave_quality_label';

  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'Auto';
  }

  static Future<void> save(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, label);
  }
}

// ── HLS quality model + parser ────────────────────────────────────────────────

class _HlsQuality {
  final String label;
  final String url;
  final int bandwidth;

  const _HlsQuality({
    required this.label,
    required this.url,
    required this.bandwidth,
  });
}

Future<List<_HlsQuality>> _parseQualities(String masterUrl) async {
  final res = await http.get(Uri.parse(masterUrl));
  final lines = res.body.split('\n');
  final qualities = <_HlsQuality>[];

  for (int i = 0; i < lines.length - 1; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

    final nextLine = lines[i + 1].trim();
    if (nextLine.isEmpty || nextLine.startsWith('#')) continue;

    final resMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
    final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    final height = resMatch?.group(1);
    final bandwidth = int.tryParse(bwMatch?.group(1) ?? '') ?? 0;

    final label = height != null ? '${height}p' : 'Unknown';
    final url = nextLine.startsWith('http')
        ? nextLine
        : Uri.parse(masterUrl).resolve(nextLine).toString();

    qualities.add(_HlsQuality(label: label, url: url, bandwidth: bandwidth));
  }

  // Highest quality first
  qualities.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));

  // Always prepend Auto (master playlist — lets the player do ABR)
  return [
    _HlsQuality(label: 'Auto', url: masterUrl, bandwidth: 0),
    ...qualities,
  ];
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
  final void Function(String label, String url) onQualityChange;
  final VoidCallback onRetry;

  const _WaveItem({
    required this.wave,
    required this.controller,
    required this.error,
    required this.isActive,
    required this.onTogglePlayPause,
    required this.onQualityChange,
    required this.onRetry,
  });

  @override
  ConsumerState<_WaveItem> createState() => _WaveItemState();
}

class _WaveItemState extends ConsumerState<_WaveItem> {
  bool _showControls = false;
  String _selectedQualityLabel = 'Auto';

  @override
  void initState() {
    super.initState();
    _loadSavedQuality();
  }

  Future<void> _loadSavedQuality() async {
    final label = await _QualityPrefs.load();
    if (mounted) setState(() => _selectedQualityLabel = label);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _showQualitySheet() {
    final colors = ref.read(appColorSchemeProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QualitySheet(
        masterUrl: widget.wave.videoUrl ?? '',
        selectedLabel: _selectedQualityLabel,
        colors: colors,
        onSelect: (quality) {
          Navigator.of(context).pop();
          setState(() => _selectedQualityLabel = quality.label);
          widget.onQualityChange(quality.label, quality.url);
        },
      ),
    );
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
                const SizedBox(height: 20),
                _QualityBtn(
                  label: _selectedQualityLabel,
                  colors: colors,
                  onTap: _showQualitySheet,
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

// ── Quality button ────────────────────────────────────────────────────────────

class _QualityBtn extends StatelessWidget {
  final String label;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _QualityBtn({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
            child: const Icon(Icons.hd_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quality picker sheet ──────────────────────────────────────────────────────

class _QualitySheet extends StatefulWidget {
  final String masterUrl;
  final String selectedLabel;
  final AppColorScheme colors;
  final void Function(_HlsQuality) onSelect;

  const _QualitySheet({
    required this.masterUrl,
    required this.selectedLabel,
    required this.colors,
    required this.onSelect,
  });

  @override
  State<_QualitySheet> createState() => _QualitySheetState();
}

class _QualitySheetState extends State<_QualitySheet> {
  List<_HlsQuality>? _qualities;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final qualities = await _parseQualities(widget.masterUrl);
      if (mounted) setState(() { _qualities = qualities; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _qualities = [_HlsQuality(label: 'Auto', url: widget.masterUrl, bandwidth: 0)];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Video Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              )
            else
              ...(_qualities ?? []).map(
                (q) => ListTile(
                  title: Text(
                    q.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: q.label == 'Auto'
                      ? const Text(
                          'Adjusts to your connection',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        )
                      : null,
                  trailing: widget.selectedLabel == q.label
                      ? Icon(Icons.check_rounded, color: widget.colors.primary)
                      : null,
                  onTap: () => widget.onSelect(q),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

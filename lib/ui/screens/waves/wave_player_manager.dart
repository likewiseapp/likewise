import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave.dart';

/// Manages HLS video player lifecycle with forward preloading.
///
/// Keeps at most 3 controllers alive: [prev, current, next].
/// Forward swipe → preloaded (instant). Backward swipe → kept in memory (instant).
class WavePlayerManager {
  WavePlayerManager({
    required bool Function() isMounted,
    required void Function(VoidCallback fn) setState,
    this.qualityUrlResolver,
  })  : _isMounted = isMounted,
        _setState = setState;

  /// Optional resolver: given a master HLS URL returns the preferred quality
  /// sub-playlist URL, or null to use the master URL (Auto / ABR).
  final Future<String?> Function(String masterUrl)? qualityUrlResolver;

  final bool Function() _isMounted;
  final void Function(VoidCallback fn) _setState;

  final Map<int, VideoPlayerController> controllers = {};
  List<Wave> _waves = [];
  int currentIndex = 0;
  bool firstVideoReady = false;
  bool isTabActive = false;
  int _loadGeneration = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Updates the wave list. Returns true if the list changed.
  bool setWaves(List<Wave> waves) {
    if (_waves == waves) return false;
    _waves = waves;
    return true;
  }

  Future<String> _resolveUrl(String masterUrl) async {
    if (qualityUrlResolver == null) return masterUrl;
    return await qualityUrlResolver!(masterUrl) ?? masterUrl;
  }

  /// Initializes [index], plays it, then preloads the next video.
  Future<void> loadAndPlay(int index) async {
    if (index < 0 || index >= _waves.length) return;

    final gen = _loadGeneration;
    final url = await _resolveUrl(_waves[index].videoUrl);

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
    );
    // Replaces any stale preload — the old controller's guard will self-dispose.
    controllers[index] = controller;

    // 7-second absolute fallback so the splash never gets stuck
    if (index == 0) {
      Future.delayed(const Duration(seconds: 7), () {
        if (_isMounted() && !firstVideoReady && gen == _loadGeneration) {
          _setState(() => firstVideoReady = true);
        }
      });
    }

    try {
      if (index == 0) {
        // Use the 3-second splash to preload the next video in parallel
        preload(1);
        await Future.wait([
          controller.initialize(),
          Future.delayed(const Duration(seconds: 3)),
        ]);
      } else {
        await controller.initialize();
      }

      if (!_isMounted() ||
          controllers[index] != controller ||
          gen != _loadGeneration) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);

      _setState(() {
        if (index == 0) firstVideoReady = true;
      });

      if (index == currentIndex && isTabActive) {
        controller.play();
        preload(index + 1);
      }
    } catch (_) {
      if (index == 0 && _isMounted() && gen == _loadGeneration) {
        _setState(() => firstVideoReady = true);
      }
    }
  }

  /// Pre-initializes [index] silently without playing.
  Future<void> preload(int index) async {
    if (index < 0 || index >= _waves.length) return;
    if (controllers.containsKey(index)) return; // already loaded or loading

    final gen = _loadGeneration;
    final url = await _resolveUrl(_waves[index].videoUrl);

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
    );
    controllers[index] = controller;

    try {
      await controller.initialize();

      if (!_isMounted() ||
          controllers[index] != controller ||
          gen != _loadGeneration) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);
      // Don't play — just sit ready for the swipe.
    } catch (_) {
      // Preload failed silently — will load on demand when swiped to.
      if (controllers[index] == controller) {
        controllers.remove(index);
      }
      controller.dispose();
    }
  }

  /// Handles page swipe: plays the target, preloads next, disposes old.
  void onPageChanged(int index) {
    controllers[currentIndex]?.pause();

    // Keep previous (instant back), current, and next preload target.
    _disposeExcept({
      if (index > 0) index - 1,
      index,
      index + 1,
    });

    _setState(() => currentIndex = index);

    final ctrl = controllers[index];
    if (ctrl != null && ctrl.value.isInitialized) {
      // Already preloaded — instant playback
      if (isTabActive) ctrl.play();
      preload(index + 1);
    } else {
      // Not preloaded (backward swipe or preload failed) — load on demand
      loadAndPlay(index);
    }
  }

  /// Pauses the current video and cancels in-flight loads.
  void deactivate() {
    _loadGeneration++;
    controllers[currentIndex]?.pause();
  }

  /// Full reset: dispose everything, clear state.
  void reset() {
    _loadGeneration++;
    for (final c in controllers.values) {
      c.dispose();
    }
    controllers.clear();
    currentIndex = 0;
    firstVideoReady = false;
    _waves = [];
  }

  /// Reinitializes the controller at [index] with a new [url] (quality switch).
  Future<void> changeQuality(int index, String url) async {
    if (index < 0 || index >= _waves.length) return;

    // Pause immediately to kill audio, then pull from the map and trigger a
    // rebuild. The VideoPlayer widget must fully unmount before dispose —
    // use addPostFrameCallback to guarantee that.
    final old = controllers[index];
    old?.pause();
    controllers.remove(index);
    _setState(() {});
    SchedulerBinding.instance.addPostFrameCallback((_) => old?.dispose());

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controllers[index] = controller;

    try {
      await controller.initialize();

      if (!_isMounted() || controllers[index] != controller) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);
      if (index == currentIndex && isTabActive) controller.play();

      _setState(() {});
    } catch (_) {
      if (controllers[index] == controller) controllers.remove(index);
      controller.dispose();
    }
  }

  /// Dispose all controllers and prevent future callbacks.
  void dispose() {
    _loadGeneration++;
    for (final c in controllers.values) {
      c.dispose();
    }
    controllers.clear();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _disposeExcept(Set<int> keep) {
    final toRemove = controllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in toRemove) {
      controllers[k]?.dispose();
      controllers.remove(k);
    }
  }
}

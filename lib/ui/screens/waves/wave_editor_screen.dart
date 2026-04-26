import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave_edit_state.dart';
import '../../../core/theme_provider.dart';

class WaveEditorScreen extends ConsumerStatefulWidget {
  final WaveEditState initialState;

  const WaveEditorScreen({super.key, required this.initialState});

  @override
  ConsumerState<WaveEditorScreen> createState() => _WaveEditorScreenState();
}

class _WaveEditorScreenState extends ConsumerState<WaveEditorScreen> {
  late WaveEditState _state;
  VideoPlayerController? _videoController;
  List<Uint8List> _keyframes = [];
  bool _loading = true;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _init();
  }

  Future<void> _init() async {
    final ctrl = VideoPlayerController.file(File(_state.videoPath));
    await ctrl.initialize();
    ctrl.setLooping(true);
    ctrl.addListener(_onVideoProgress);
    ctrl.play();

    try {
      final frames = await ProVideoEditor.instance.getKeyFrames(
        KeyFramesConfigs(
          video: EditorVideo.file(File(_state.videoPath)),
          maxOutputFrames: 14,
          outputSize: const Size(60, 80),
          outputFormat: ThumbnailFormat.jpeg,
          boxFit: ThumbnailBoxFit.cover,
        ),
      );
      if (mounted) setState(() => _keyframes = frames);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _videoController = ctrl;
        _loading = false;
      });
    }
  }

  void _onVideoProgress() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying &&
        _videoController!.value.position >= _state.trimEnd) {
      _videoController!.seekTo(_state.trimStart);
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    super.dispose();
  }

  void _onNext() {
    _videoController?.pause();
    context.push('/wave-caption', extra: _state);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);

    if (_loading || _videoController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Wave',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _onNext,
            child: Text(
              'Next',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Video preview ──────────────────────────────────────────────
          Expanded(child: _buildPreview()),

          // ── Tool tabs ──────────────────────────────────────────────────
          _TabBar(
            active: _activeTab,
            onSelect: (i) {
              setState(() => _activeTab = i);
              if (i == 0) _videoController?.seekTo(_state.trimStart);
            },
            colors: colors,
          ),

          // ── Tool panel ─────────────────────────────────────────────────
          SizedBox(
            height: 220,
            child: _activeTab == 0
                ? _TrimPanel(
                    state: _state,
                    keyframes: _keyframes,
                    onChanged: (s) {
                      setState(() => _state = s);
                      _videoController?.seekTo(s.trimStart);
                    },
                    formatDuration: _formatDuration,
                  )
                : _FilterPanel(
                    selected: _state.filter,
                    onSelect: (f) =>
                        setState(() => _state = _state.copyWith(filter: f)),
                    colors: colors,
                  ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final ctrl = _videoController!;
    final filter = _state.filter.flutterColorFilter;

    Widget video = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: ctrl.value.size.width,
        height: ctrl.value.size.height,
        child: VideoPlayer(ctrl),
      ),
    );

    if (filter != null) {
      video = ColorFiltered(colorFilter: filter, child: video);
    }

    return GestureDetector(
      onTap: () => setState(() {
        ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
      }),
      child: video,
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int active;
  final void Function(int) onSelect;
  final AppColorScheme colors;

  const _TabBar(
      {required this.active, required this.onSelect, required this.colors});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (Icons.content_cut_rounded, 'Trim'),
      (Icons.palette_rounded, 'Filter'),
    ];

    return Container(
      height: 56,
      color: Colors.black,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final (icon, label) = tabs[i];
          final isActive = active == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isActive ? colors.primary : Colors.white38,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? colors.primary : Colors.white38,
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Trim panel ─────────────────────────────────────────────────────────────────

class _TrimPanel extends StatelessWidget {
  final WaveEditState state;
  final List<Uint8List> keyframes;
  final void Function(WaveEditState) onChanged;
  final String Function(Duration) formatDuration;

  static const _maxClip = Duration(seconds: 60);

  const _TrimPanel({
    required this.state,
    required this.keyframes,
    required this.onChanged,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = state.videoDuration.inMilliseconds.toDouble();
    final startMs = state.trimStart.inMilliseconds.toDouble();
    final endMs = state.trimEnd.inMilliseconds.toDouble();
    final clipDuration = state.trimEnd - state.trimStart;
    final overLimit = clipDuration > _maxClip;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 64,
              child: keyframes.isEmpty
                  ? Container(color: Colors.white10)
                  : Row(
                      children: keyframes
                          .map((b) => Expanded(
                                child: Image.memory(b,
                                    fit: BoxFit.cover, height: 64),
                              ))
                          .toList(),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: const SliderThemeData(
              thumbColor: Colors.white,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              overlayColor: Colors.transparent,
            ),
            child: RangeSlider(
              min: 0,
              max: totalMs,
              values: RangeValues(startMs, endMs),
              onChanged: (vals) {
                var start = Duration(milliseconds: vals.start.toInt());
                var end = Duration(milliseconds: vals.end.toInt());
                if (end - start > _maxClip) {
                  if (start != state.trimStart) {
                    start = end - _maxClip;
                  } else {
                    end = start + _maxClip;
                  }
                }
                onChanged(state.copyWith(trimStart: start, trimEnd: end));
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(state.trimStart),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                'Clip: ${formatDuration(clipDuration)}${overLimit ? ' (max 1 min)' : ''}',
                style: TextStyle(
                  color: overLimit ? Colors.redAccent : Colors.white38,
                  fontSize: 12,
                ),
              ),
              Text(formatDuration(state.trimEnd),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter panel ───────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final WaveFilter selected;
  final void Function(WaveFilter) onSelect;
  final AppColorScheme colors;

  const _FilterPanel({
    required this.selected,
    required this.onSelect,
    required this.colors,
  });

  static const _gradients = <WaveFilter, List<Color>>{
    WaveFilter.none: [Color(0xFF888888), Color(0xFF444444)],
    WaveFilter.vivid: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
    WaveFilter.warm: [Color(0xFFFF9A3C), Color(0xFFFF6F61)],
    WaveFilter.cool: [Color(0xFF4BC0C8), Color(0xFF4169E1)],
    WaveFilter.fade: [Color(0xFFBDC3C7), Color(0xFF9EA7A9)],
    WaveFilter.noir: [Color(0xFF444444), Color(0xFF111111)],
    WaveFilter.drama: [Color(0xFF8B0000), Color(0xFF1A1A2E)],
  };

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: WaveFilter.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final filter = WaveFilter.values[i];
        final isSelected = filter == selected;
        return GestureDetector(
          onTap: () => onSelect(filter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: _gradients[filter]!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isSelected ? colors.primary : Colors.white24,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, color: colors.primary, size: 24)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                filter.label,
                style: TextStyle(
                  color: isSelected ? colors.primary : Colors.white54,
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

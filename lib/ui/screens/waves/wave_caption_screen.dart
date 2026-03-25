import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/wave_edit_state.dart';
import '../../../core/providers/wave_providers.dart';
import '../../../core/theme_provider.dart';

class WaveCaptionScreen extends ConsumerStatefulWidget {
  final WaveEditState editState;

  const WaveCaptionScreen({super.key, required this.editState});

  @override
  ConsumerState<WaveCaptionScreen> createState() => _WaveCaptionScreenState();
}

class _WaveCaptionScreenState extends ConsumerState<WaveCaptionScreen> {
  VideoPlayerController? _preview;
  final _captionCtrl = TextEditingController();

  bool _isRendering = true;
  double _renderProgress = 0;
  String? _renderedPath;
  String? _renderError;
  bool _uploadStarted = false;
  final _taskId = 'wave_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _startOriginalPreview();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRender());
  }

  Future<void> _startOriginalPreview() async {
    final ctrl = VideoPlayerController.file(File(widget.editState.videoPath));
    await ctrl.initialize();
    ctrl.setLooping(true);
    ctrl.play();
    if (mounted) setState(() => _preview = ctrl);
  }

  /// Returns a target bitrate in bps based on the video's display resolution.
  /// Capped at 1080p — no 4K support in this app.
  int _adaptiveBitrate(Size resolution) {
    final longerSide = resolution.longestSide;
    if (longerSide >= 2160) return 8_000_000; // 4K    → 8 Mbps
    if (longerSide >= 1080) return 5_000_000; // 1080p → 5 Mbps
    if (longerSide >= 720)  return 2_500_000; // 720p  → 2.5 Mbps
    return 1_200_000;                          // 480p and below → 1.2 Mbps
  }

  Future<void> _startRender() async {
    try {
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/$_taskId.mp4';

      final matrix = widget.editState.filter.colorMatrix;

      final renderData = VideoRenderData(
        id: _taskId,
        video: EditorVideo.file(File(widget.editState.videoPath)),
        startTime: widget.editState.trimStart,
        endTime: widget.editState.trimEnd,
        enableAudio: true,
        bitrate: _adaptiveBitrate(widget.editState.videoResolution),
        colorMatrixList: matrix != null ? [matrix] : [],
      );

      ProVideoEditor.instance.progressStreamById(_taskId).listen((p) {
        if (mounted) setState(() => _renderProgress = p.progress);
      });

      await ProVideoEditor.instance.renderVideoToFile(outPath, renderData);
      if (!mounted) return;

      final renderedCtrl = VideoPlayerController.file(File(outPath));
      await renderedCtrl.initialize();
      renderedCtrl.setLooping(true);
      renderedCtrl.play();

      _preview?.dispose();

      setState(() {
        _preview = renderedCtrl;
        _renderedPath = outPath;
        _isRendering = false;
      });
    } on RenderCanceledException {
      // user navigated away — safe
    } catch (e) {
      if (mounted) {
        setState(() {
          _renderError = e.toString();
          _isRendering = false;
        });
      }
    }
  }

  void _post() {
    if (_renderedPath == null) return;
    _uploadStarted = true;
    // Fire upload in the background provider, then navigate home immediately.
    // The banner on the main screen will track progress.
    ref.read(waveUploadProvider.notifier).upload(
          File(_renderedPath!),
          _captionCtrl.text.trim(),
        );
    context.go('/');
  }

  @override
  void dispose() {
    if (_isRendering) ProVideoEditor.instance.cancel(_taskId);
    _preview?.dispose();
    _captionCtrl.dispose();
    // Skip deletion if upload was started — the notifier still holds the file.
    // OS temp dir will clean it up eventually.
    if (_renderedPath != null && !_uploadStarted) {
      try {
        File(_renderedPath!).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'New Wave',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: _isRendering ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Video preview ─────────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video
                  if (_preview != null && _preview!.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _preview!.value.size.width,
                        height: _preview!.value.size.height,
                        child: VideoPlayer(_preview!),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white38),
                    ),

                  // Render progress overlay
                  if (_isRendering)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _renderProgress,
                                  minHeight: 5,
                                  backgroundColor: Colors.white24,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Processing ${(_renderProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Render error overlay
                  if (_renderError != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Failed to process video',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _renderError!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Caption + post ────────────────────────────────────────────
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _captionCtrl,
                    enabled: !_isRendering,
                    maxLines: 2,
                    maxLength: 200,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: colors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Post button
                  SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: (!_isRendering && _renderError == null)
                            ? LinearGradient(
                                colors: [colors.primary, colors.accent])
                            : null,
                        color: (_isRendering || _renderError != null)
                            ? Colors.white12
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextButton(
                        onPressed: (!_isRendering && _renderError == null)
                            ? _post
                            : null,
                        child: Text(
                          _isRendering ? 'Processing...' : 'Post Wave',
                          style: TextStyle(
                            color: (!_isRendering && _renderError == null)
                                ? Colors.white
                                : Colors.white38,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

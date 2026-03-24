import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../core/models/wave_edit_state.dart';
import '../../../core/theme_provider.dart';

class UploadWaveScreen extends ConsumerStatefulWidget {
  const UploadWaveScreen({super.key});

  @override
  ConsumerState<UploadWaveScreen> createState() =>
      _UploadWaveScreenState();
}

class _UploadWaveScreenState extends ConsumerState<UploadWaveScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);

    final picked =
        await ImagePicker().pickVideo(source: ImageSource.gallery);

    if (!mounted) return;

    if (picked == null) {
      context.pop();
      return;
    }

    try {
      final meta = await ProVideoEditor.instance
          .getMetadata(EditorVideo.file(File(picked.path)));

      if (!mounted) return;

      final editState = WaveEditState(
        videoPath: picked.path,
        videoDuration: meta.duration,
        trimStart: Duration.zero,
        trimEnd: meta.duration,
      );

      context.pushReplacement('/wave-editor', extra: editState);
    } catch (_) {
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: colors.primary),
      ),
    );
  }
}

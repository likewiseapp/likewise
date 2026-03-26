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
  ConsumerState<UploadWaveScreen> createState() => _UploadWaveScreenState();
}

class _UploadWaveScreenState extends ConsumerState<UploadWaveScreen> {
  bool _busy = false;

  static const int _maxFileSizeBytes = 150 * 1024 * 1024; // 150 MB
  static const Duration _maxDuration = Duration(seconds: 62); // 1 min 2 sec

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSourcePicker());
  }

  void _showSourcePicker() {
    final colors = ref.read(appColorSchemeProvider);
    showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
                'Create a Wave',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Max 1 min 2 sec · 150 MB',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop(ImageSource.gallery);
                },
              ),
              _SourceTile(
                icon: Icons.videocam_rounded,
                label: 'Record with Camera',
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).then((source) {
      if (source == null) {
        if (mounted) context.pop();
      } else {
        _pickVideo(source);
      }
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);

    final picked = await ImagePicker().pickVideo(
      source: source,
      // Enforces 2-min cap at the OS camera level when recording
      maxDuration: _maxDuration,
    );

    if (!mounted) return;

    if (picked == null) {
      context.pop();
      return;
    }

    try {
      final meta = await ProVideoEditor.instance
          .getMetadata(EditorVideo.file(File(picked.path)));

      if (!mounted) return;

      if (meta.fileSize > _maxFileSizeBytes) {
        _showSizeError();
        return;
      }

      if (meta.duration > _maxDuration) {
        _showDurationError();
        return;
      }

      final editState = WaveEditState(
        videoPath: picked.path,
        videoDuration: meta.duration,
        videoResolution: meta.resolution,
        trimStart: Duration.zero,
        trimEnd: meta.duration,
      );

      context.pushReplacement('/wave-editor', extra: editState);
    } catch (_) {
      if (mounted) context.pop();
    }
  }

  void _showDurationError() {
    final colors = ref.read(appColorSchemeProvider);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Video too long',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Videos must be 1 minute 2 seconds or less.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: Text('OK', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  void _showSizeError() {
    final colors = ref.read(appColorSchemeProvider);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Video too large',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Please choose a video under 150 MB.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: Text('OK', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _busy
            ? CircularProgressIndicator(color: colors.primary)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colors.primary, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

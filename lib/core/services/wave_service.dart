import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bunny_config.dart';
import '../models/wave.dart';
import 'bunny_service.dart';

class WaveService {
  final SupabaseClient _client;

  WaveService(this._client);

  Future<List<Wave>> fetchWaves() async {
    final data = await _client
        .from('waves')
        .select()
        .eq('status', 'approved')
        .eq('transcoding_ready', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Wave.fromJson(e)).toList();
  }

  Future<void> uploadWave(
    File videoFile,
    String caption,
    String userId, {
    void Function(double progress)? onCompressProgress,
    void Function(double progress)? onUploadProgress,
  }) async {
    // Step 1: Compress video using native APIs (AVFoundation on iOS/macOS,
    // Media3 on Android). p1080High ≈ CRF 22 — high quality, smaller file.
    final tmpDir = await getTemporaryDirectory();
    final compressedPath =
        '${tmpDir.path}/wave_${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final sub = ProVideoEditor.instance.progressStream
        .listen((p) => onCompressProgress?.call(p.progress));

    try {
      await ProVideoEditor.instance.renderVideoToFile(
        compressedPath,
        VideoRenderData(
          video: EditorVideo.file(videoFile),
          // Fixed bitrate ≈ CRF 22 quality. No transform set so the
          // original resolution and aspect ratio are fully preserved.
          bitrate: 6000000,
        ),
      );
    } finally {
      await sub.cancel();
    }

    // Step 2: Upload compressed file to Bunny Storage for admin review
    final compressedFile = File(compressedPath);
    try {
      final path = BunnyPaths.rawWave(userId);
      await BunnyService().uploadFile(
        path,
        compressedFile,
        'video/mp4',
        onProgress: onUploadProgress,
      );

      // Step 3: Save pending record — video_id/url/thumbnail null until approved
      await _client.from('waves').insert({
        'user_id': userId,
        'raw_video_url': BunnyService.cdnUrl(path),
        'caption': caption,
        'status': 'pending',
      });
    } finally {
      try {
        await compressedFile.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteWave(String waveId) async {
    await _client.from('waves').delete().eq('id', waveId);
  }
}

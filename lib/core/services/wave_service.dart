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

  /// Approved + transcoding-ready waves for a specific user, newest first.
  /// Used by profile screens (own profile = "My waves", others' profiles).
  Future<List<Wave>> fetchWavesByUser(String userId) async {
    final rows = await _client
        .from('waves')
        .select(
          'id, user_id, video_id, video_url, raw_video_url, thumbnail_url, '
          'caption, created_at, status, transcoding_ready, approved_at, '
          'view_count, like_count, comment_count',
        )
        .eq('user_id', userId)
        .eq('status', 'approved')
        .eq('transcoding_ready', true)
        .order('created_at', ascending: false) as List;

    return rows
        .map((r) => Wave.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Wave>> fetchWaves() async {
    final viewerId = _client.auth.currentUser?.id;

    // Step 1: fetch waves + viewer's own wave_likes rows (filtered embed).
    // `waves.user_id` FKs to auth.users, not to public.profiles, so we can't
    // nest the profile via PostgREST — profiles are fetched in step 2.
    var query = _client.from('waves').select(
          'id, user_id, video_id, video_url, raw_video_url, thumbnail_url, '
          'caption, created_at, status, transcoding_ready, approved_at, '
          'view_count, like_count, comment_count, '
          'wave_likes (user_id)',
        );

    if (viewerId != null) {
      query = query.eq('wave_likes.user_id', viewerId);
    }

    final rows = await query
        .eq('status', 'approved')
        .eq('transcoding_ready', true)
        .order('created_at', ascending: false) as List;

    if (rows.isEmpty) return [];

    // Step 2: batch-fetch profiles for the poster user_ids.
    final userIds = rows
        .map((r) => r['user_id'] as String)
        .toSet()
        .toList();

    final profileRows = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', userIds) as List;

    final profileMap = {
      for (final p in profileRows) p['id'] as String: p as Map<String, dynamic>,
    };

    // Step 3: merge the profile back into each row so Wave.fromJson can pick
    // it up via the `profiles` key (matches the existing pattern used by
    // message_service.dart).
    return rows.map((row) {
      final merged = <String, dynamic>{
        ...row as Map<String, dynamic>,
        'profiles': profileMap[row['user_id']],
      };
      return Wave.fromJson(merged);
    }).toList();
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

  /// Fetch waves filtered to only show posters who share at least one hobby
  /// with the given [hobbyIds] list.
  Future<List<Wave>> fetchWavesByHobbies(List<int> hobbyIds) async {
    if (hobbyIds.isEmpty) return fetchWaves();

    final viewerId = _client.auth.currentUser?.id;

    // Get user IDs that have at least one of the given hobbies
    final hobbyUsers = await _client
        .from('user_hobbies')
        .select('user_id')
        .inFilter('hobby_id', hobbyIds);
    final matchedUserIds =
        (hobbyUsers as List).map((e) => e['user_id'] as String).toSet();

    if (matchedUserIds.isEmpty) return [];

    var query = _client.from('waves').select(
          'id, user_id, video_id, video_url, raw_video_url, thumbnail_url, '
          'caption, created_at, status, transcoding_ready, approved_at, '
          'view_count, like_count, comment_count, '
          'wave_likes (user_id)',
        );

    if (viewerId != null) {
      query = query.eq('wave_likes.user_id', viewerId);
    }

    final rows = await query
        .inFilter('user_id', matchedUserIds.toList())
        .eq('status', 'approved')
        .eq('transcoding_ready', true)
        .order('created_at', ascending: false) as List;

    if (rows.isEmpty) return [];

    final userIds =
        rows.map((r) => r['user_id'] as String).toSet().toList();

    final profileRows = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', userIds) as List;

    final profileMap = {
      for (final p in profileRows)
        p['id'] as String: p as Map<String, dynamic>,
    };

    return rows.map((row) {
      final merged = <String, dynamic>{
        ...row as Map<String, dynamic>,
        'profiles': profileMap[row['user_id']],
      };
      return Wave.fromJson(merged);
    }).toList();
  }

  Future<void> deleteWave(String waveId) async {
    await _client.from('waves').delete().eq('id', waveId);
  }
}

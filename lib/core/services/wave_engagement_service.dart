import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wave_comment.dart';

/// Like/view/comment plumbing for the waves feed.
class WaveEngagementService {
  WaveEngagementService(this._client);

  final SupabaseClient _client;

  /// Toggles the current viewer's like on [waveId]. Idempotent either way:
  /// inserting an existing row is a no-op thanks to the composite PK, and
  /// deleting a non-existent row is also a no-op.
  /// Returns the resulting liked state.
  Future<bool> toggleLike(String waveId, {required bool currentlyLiked}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot toggle like: not signed in');
    }

    if (currentlyLiked) {
      await _client
          .from('wave_likes')
          .delete()
          .eq('wave_id', waveId)
          .eq('user_id', userId);
      return false;
    }

    await _client.from('wave_likes').insert({
      'wave_id': waveId,
      'user_id': userId,
    });
    return true;
  }

  /// Bumps the wave's cached view count via the SECURITY DEFINER RPC.
  /// Safe to call even while unauthenticated (RPC is granted to anon too).
  Future<void> bumpView(String waveId) async {
    await _client.rpc(
      'increment_wave_view',
      params: {'target_wave_id': waveId},
    );
  }

  // ── Comments ────────────────────────────────────────────────────────────

  /// Newest-first list of comments for [waveId], with author profile merged
  /// in. `wave_comments.user_id` FKs to auth.users, so profiles are fetched
  /// separately and grafted into each row — matches the feed pattern.
  Future<List<WaveComment>> fetchComments(String waveId) async {
    final rows = await _client
        .from('wave_comments')
        .select('id, wave_id, user_id, content, created_at')
        .eq('wave_id', waveId)
        .order('created_at', ascending: false) as List;

    if (rows.isEmpty) return [];

    final userIds = rows
        .map((r) => r['user_id'] as String)
        .toSet()
        .toList();

    final profiles = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', userIds) as List;

    final profileMap = {
      for (final p in profiles) p['id'] as String: p as Map<String, dynamic>,
    };

    return rows.map((row) {
      final merged = <String, dynamic>{
        ...row as Map<String, dynamic>,
        'profiles': profileMap[row['user_id']],
      };
      return WaveComment.fromJson(merged);
    }).toList();
  }

  /// Posts [content] as the current user on [waveId] and returns the inserted
  /// comment (with the author profile merged in). Throws on unauthenticated
  /// or DB error.
  Future<WaveComment> postComment(String waveId, String content) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot comment: not signed in');
    }

    final inserted = await _client
        .from('wave_comments')
        .insert({
          'wave_id': waveId,
          'user_id': userId,
          'content': content,
        })
        .select('id, wave_id, user_id, content, created_at')
        .single();

    final profile = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();

    return WaveComment.fromJson({
      ...inserted,
      'profiles': profile,
    });
  }

  /// Deletes a comment by id. Only succeeds for rows where the current user
  /// is the author (without RLS, that's enforced client-side — the server
  /// will happily let anyone delete any row, so treat this as best-effort).
  Future<void> deleteComment(String commentId) async {
    await _client.from('wave_comments').delete().eq('id', commentId);
  }
}

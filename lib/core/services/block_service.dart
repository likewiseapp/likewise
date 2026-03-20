import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  final SupabaseClient _client;

  const BlockService(this._client);

  Future<void> blockUser(String blockerId, String blockedId) async {
    await _client.from('blocks').insert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'reason': 'other',
    });
  }

  Future<bool> isBlocking(String blockerId, String blockedId) async {
    final result = await _client
        .from('blocks')
        .select('blocker_id')
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId)
        .maybeSingle();
    return result != null;
  }

  Future<void> unblockUser(String blockerId, String blockedId) async {
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  /// Returns profiles of users that [userId] has blocked.
  Future<List<Map<String, dynamic>>> fetchBlockedProfiles(String userId) async {
    final blocks = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', userId);

    final ids = (blocks as List).map((b) => b['blocked_id'] as String).toList();
    if (ids.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', ids);

    return (profiles as List).cast<Map<String, dynamic>>();
  }

  /// Returns IDs of users who have blocked [userId].
  Future<Set<String>> fetchUsersWhoBlockedMe(String userId) async {
    final results = await _client
        .from('blocks')
        .select('blocker_id')
        .eq('blocked_id', userId);
    return (results as List).map((r) => r['blocker_id'] as String).toSet();
  }

  /// Returns all user IDs that [userId] has blocked OR been blocked by.
  Future<Set<String>> fetchBlockedUserIds(String userId) async {
    final results = await Future.wait([
      _client.from('blocks').select('blocked_id').eq('blocker_id', userId),
      _client.from('blocks').select('blocker_id').eq('blocked_id', userId),
    ]);

    final ids = <String>{};
    for (final row in results[0] as List) {
      ids.add(row['blocked_id'] as String);
    }
    for (final row in results[1] as List) {
      ids.add(row['blocker_id'] as String);
    }
    return ids;
  }
}

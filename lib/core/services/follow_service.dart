import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class FollowService {
  final SupabaseClient _client;

  FollowService(this._client);

  Future<void> follow(String followerId, String followingId) async {
    await _client.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  Future<void> unfollow(String followerId, String followingId) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    final data = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return data != null;
  }

  Future<Set<String>> fetchFollowingIds(String userId) async {
    final data = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    return (data as List).map((e) => e['following_id'] as String).toSet();
  }

  Future<List<ProfileStats>> fetchFollowers(String userId) async {
    final data = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    final ids = (data as List).map((e) => e['follower_id'] as String).toList();
    if (ids.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url, bio, location, is_verified')
        .inFilter('id', ids);

    final profileMap = {
      for (final p in profiles as List) p['id'] as String: p as Map<String, dynamic>
    };

    return ids
        .where(profileMap.containsKey)
        .map((id) => ProfileStats.fromJson(profileMap[id]!))
        .toList();
  }

  Future<List<ProfileStats>> fetchFollowing(String userId) async {
    final data = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);

    final ids = (data as List).map((e) => e['following_id'] as String).toList();
    if (ids.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url, bio, location, is_verified')
        .inFilter('id', ids);

    final profileMap = {
      for (final p in profiles as List) p['id'] as String: p as Map<String, dynamic>
    };

    return ids
        .where(profileMap.containsKey)
        .map((id) => ProfileStats.fromJson(profileMap[id]!))
        .toList();
  }
}

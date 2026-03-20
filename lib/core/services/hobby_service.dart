import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hobby.dart';

class HobbyService {
  final SupabaseClient _client;

  HobbyService(this._client);

  Future<List<Hobby>> fetchAll() async {
    final data = await _client.from('hobbies').select().order('id');
    return (data as List).map((e) => Hobby.fromJson(e)).toList();
  }

  /// Batch-fetch one representative hobby name per user in [userIds].
  /// Prefers the primary hobby; falls back to a random one if none is primary.
  /// Returns {userId: hobbyName}.
  Future<Map<String, String>> fetchDisplayHobbies(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    // Fetch ALL hobbies for the requested users (with name join)
    final data = await _client
        .from('user_hobbies')
        .select('user_id, is_primary, hobbies(name)')
        .inFilter('user_id', userIds);

    // Group by user: pick primary if available, otherwise first entry
    final primaryMap = <String, String>{};
    final fallbackMap = <String, String>{};

    for (final row in data as List) {
      final userId = row['user_id'] as String;
      final hobbyData = row['hobbies'] as Map<String, dynamic>?;
      final name = hobbyData?['name'] as String?;
      if (name == null) continue;

      final isPrimary = row['is_primary'] as bool? ?? false;
      if (isPrimary) {
        primaryMap[userId] = name;
      } else {
        fallbackMap.putIfAbsent(userId, () => name);
      }
    }

    // Merge: primary wins, fallback fills gaps
    final result = <String, String>{};
    for (final uid in userIds) {
      final hobby = primaryMap[uid] ?? fallbackMap[uid];
      if (hobby != null) result[uid] = hobby;
    }
    return result;
  }
}

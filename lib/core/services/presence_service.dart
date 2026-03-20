import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  final SupabaseClient _client;

  const PresenceService(this._client);

  /// Returns the current online status. Defaults to true if no row exists yet.
  Future<bool> fetchOnlineStatus(String userId) async {
    final result = await _client
        .from('user_presence')
        .select('is_online')
        .eq('user_id', userId)
        .maybeSingle();
    // No row yet → treat as online (will be written on first toggle)
    return result?['is_online'] as bool? ?? true;
  }

  /// Upserts the presence row with the given status.
  Future<void> setPresence(String userId, bool isOnline) async {
    await _client.from('user_presence').upsert({
      'user_id': userId,
      'is_online': isOnline,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

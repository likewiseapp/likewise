import 'package:supabase_flutter/supabase_flutter.dart';

class AccountService {
  final SupabaseClient _client;

  AccountService(this._client);

  /// Submit a deletion request. [reason] must be one of the values defined
  /// in the DB check constraint: not_useful, privacy_concerns,
  /// too_many_notifications, found_another_app, temporary_break, other.
  Future<void> requestDeletion({
    required String userId,
    required String reason,
    String? description,
  }) async {
    await _client.from('delete_account_requests').insert({
      'user_id': userId,
      'reason': reason,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  /// Returns the pending deletion request row for [userId], or null if none.
  Future<Map<String, dynamic>?> getPendingRequest(String userId) async {
    final result = await _client
        .from('delete_account_requests')
        .select('id, reason, description, created_at')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    return result;
  }
}

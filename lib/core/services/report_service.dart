import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _client;

  ReportService(this._client);

  /// Submit a report. [category] must be one of the values defined in the
  /// DB check constraint: spam, harassment, inappropriate_content,
  /// fake_account, hate_speech, violence, other.
  Future<void> submitReport({
    required String reporterId,
    required String reportedEntityId,
    required String reportedEntityType, // 'profile' | 'reel' | 'comment' | 'message'
    required String category,
    String? description,
  }) async {
    await _client.from('reports').insert({
      'reporter_id': reporterId,
      'reported_entity_id': reportedEntityId,
      'reported_entity_type': reportedEntityType,
      'category': category,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
  }

  /// Returns true if the current user has already reported this entity.
  Future<bool> hasReported({
    required String reporterId,
    required String reportedEntityId,
  }) async {
    final result = await _client
        .from('reports')
        .select('id')
        .eq('reporter_id', reporterId)
        .eq('reported_entity_id', reportedEntityId)
        .maybeSingle();
    return result != null;
  }
}

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  /// Real-time stream of the user's notifications — re-fetches whenever a row
  /// is inserted, updated, or deleted in `notifications` for this recipient.
  Stream<List<AppNotification>> streamNotifications(String userId) {
    late StreamController<List<AppNotification>> controller;
    RealtimeChannel? channel;

    Future<void> refetch() async {
      try {
        final list = await fetchNotifications(userId);
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<AppNotification>>(
      onListen: () {
        refetch();
        channel = _client
            .channel('notifications_watch_$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'recipient_id',
                value: userId,
              ),
              callback: (_) => refetch(),
            )
            .subscribe();
      },
      onCancel: () {
        channel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .neq('type', 'message')
        .order('created_at', ascending: false)
        .limit(50);

    final notifications = data as List;
    if (notifications.isEmpty) return [];

    final actorIds = notifications
        .map((e) => e['actor_id'] as String)
        .toSet()
        .toList();

    final profiles = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', actorIds);

    final profileMap = {
      for (final p in profiles as List) p['id'] as String: p as Map<String, dynamic>
    };

    return notifications.map((e) {
      final actor = profileMap[e['actor_id'] as String];
      return AppNotification.fromJson({...e, 'actor': actor});
    }).toList();
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  /// Creates a follow notification, replacing any existing one from the same
  /// actor so re-follow doesn't produce duplicate entries.
  Future<void> createFollowNotification({
    required String recipientId,
    required String actorId,
  }) async {
    // Delete stale notification first (follow → unfollow → follow again)
    await _client
        .from('notifications')
        .delete()
        .eq('recipient_id', recipientId)
        .eq('actor_id', actorId)
        .eq('type', 'follow');

    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': 'follow',
      'entity_type': 'profile',
    });
  }

  Future<void> deleteFollowNotification({
    required String recipientId,
    required String actorId,
  }) async {
    await _client
        .from('notifications')
        .delete()
        .eq('recipient_id', recipientId)
        .eq('actor_id', actorId)
        .eq('type', 'follow');
  }

  /// Fetches the user's notification preferences row. Lazy-creates a default
  /// row (all toggles on) on first call.
  Future<Map<String, dynamic>> getPreferences(String userId) async {
    final existing = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) return existing;

    final created = await _client
        .from('notification_preferences')
        .insert({'user_id': userId})
        .select()
        .single();
    return created;
  }

  /// Upserts a single preference field for the user.
  Future<void> updatePreference({
    required String userId,
    required String field,
    required bool value,
  }) async {
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      field: value,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

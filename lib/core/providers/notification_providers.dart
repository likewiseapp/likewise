import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'auth_providers.dart';

final notificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(<AppNotification>[]);
  final client = ref.watch(supabaseProvider);
  return NotificationService(client).streamNotifications(userId);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseProvider));
});

// ── Notification preferences ─────────────────────────────────────────────

const notificationPreferenceFields = [
  'push_enabled',
  'follows',
  'messages',
  'twin_match',
  'mentions',
  'likes',
  'comments',
];

class NotificationPreferencesNotifier
    extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return _allTrue();
    final row = await ref.read(notificationServiceProvider).getPreferences(userId);
    return {
      for (final f in notificationPreferenceFields)
        f: (row[f] as bool?) ?? true,
    };
  }

  /// Optimistically updates a single preference, persists it, and reverts
  /// the local state if the server call fails.
  Future<void> setPreference(String field, bool value) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final current = state.value ?? _allTrue();
    final previous = current[field] ?? true;
    state = AsyncData({...current, field: value});
    try {
      await ref.read(notificationServiceProvider).updatePreference(
            userId: userId,
            field: field,
            value: value,
          );
    } catch (_) {
      state = AsyncData({...current, field: previous});
      rethrow;
    }
  }

  Map<String, bool> _allTrue() =>
      {for (final f in notificationPreferenceFields) f: true};
}

final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesNotifier, Map<String, bool>>(
  NotificationPreferencesNotifier.new,
);

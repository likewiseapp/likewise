import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/presence_service.dart';
import 'auth_providers.dart';

class OnlineStatusNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return true;
    final client = ref.watch(supabaseProvider);
    return PresenceService(client).fetchOnlineStatus(userId);
  }

  Future<void> toggle(bool isOnline) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    // Optimistic update
    state = AsyncData(isOnline);
    try {
      final client = ref.read(supabaseProvider);
      await PresenceService(client).setPresence(userId, isOnline);
    } catch (_) {
      // Revert on failure
      state = AsyncData(!isOnline);
    }
  }
}

final onlineStatusProvider =
    AsyncNotifierProvider<OnlineStatusNotifier, bool>(
  OnlineStatusNotifier.new,
);

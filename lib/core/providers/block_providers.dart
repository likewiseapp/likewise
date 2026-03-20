import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/block_service.dart';
import 'auth_providers.dart';

/// True if the current user has blocked [targetUserId].
final isBlockingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return false;
  final client = ref.watch(supabaseProvider);
  return BlockService(client).isBlocking(currentUserId, targetUserId);
});

/// Set of user IDs who have blocked the current user (batch, for list screens).
final blockedByIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final client = ref.watch(supabaseProvider);
  return BlockService(client).fetchUsersWhoBlockedMe(userId);
});

/// True if [targetUserId] has blocked the current user.
final isBlockedByProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return false;
  final client = ref.watch(supabaseProvider);
  return BlockService(client).isBlocking(targetUserId, currentUserId);
});

final blockedUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final client = ref.watch(supabaseProvider);
  return BlockService(client).fetchBlockedProfiles(userId);
});

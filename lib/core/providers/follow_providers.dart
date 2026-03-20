import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/follow_service.dart';
import 'auth_providers.dart';

final followersProvider =
    FutureProvider.family<List<ProfileStats>, String>((ref, userId) async {
  final client = ref.watch(supabaseProvider);
  return FollowService(client).fetchFollowers(userId);
});

final followingProvider =
    FutureProvider.family<List<ProfileStats>, String>((ref, userId) async {
  final client = ref.watch(supabaseProvider);
  return FollowService(client).fetchFollowing(userId);
});

final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return false;
  final client = ref.watch(supabaseProvider);
  return FollowService(client).isFollowing(currentUserId, targetUserId);
});

final followingIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final client = ref.watch(supabaseProvider);
  return FollowService(client).fetchFollowingIds(userId);
});

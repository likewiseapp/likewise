import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/matched_user.dart';
import '../models/profile.dart';
import '../services/block_service.dart';
import '../services/explore_service.dart';
import 'auth_providers.dart';
import 'follow_providers.dart';

final twinMatchProvider = FutureProvider<MatchedUser?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final client = ref.watch(supabaseProvider);
  final followedIds = await ref.watch(followingIdsProvider.future);
  final result = await ExploreService(client).fetchTwinMatch(userId);
  if (result == null) return null;
  return followedIds.contains(result.id) ? null : result;
});

final nearbyUsersProvider = FutureProvider<List<MatchedUser>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final client = ref.watch(supabaseProvider);
  final followedIds = await ref.watch(followingIdsProvider.future);
  final results = await ExploreService(client).fetchNearbyUsers(userId);
  return results.where((u) => !followedIds.contains(u.id)).toList();
});

final topCreatorsProvider = FutureProvider<List<ProfileStats>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  final blockedIds = userId != null
      ? await BlockService(client).fetchBlockedUserIds(userId)
      : const <String>{};
  final followedIds = await ref.watch(followingIdsProvider.future);
  return ExploreService(client).fetchTopCreators(
    excludeUserId: userId,
    blockedIds: blockedIds,
    followedIds: followedIds,
  );
});

final allTopCreatorsProvider = FutureProvider<List<ProfileStats>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  final blockedIds = userId != null
      ? await BlockService(client).fetchBlockedUserIds(userId)
      : const <String>{};
  final followedIds = await ref.watch(followingIdsProvider.future);
  return ExploreService(client).fetchTopCreators(
    limit: 50,
    excludeUserId: userId,
    blockedIds: blockedIds,
    followedIds: followedIds,
  );
});

final searchResultsProvider = FutureProvider.family<List<MatchedUser>,
    ({String query, String? category, String hobbyNames, double distanceKm})>(
    (ref, params) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final client = ref.watch(supabaseProvider);
  final hobbyNamesList = params.hobbyNames.isEmpty
      ? const <String>[]
      : params.hobbyNames.split(',');
  return ExploreService(client).searchUsers(
    userId,
    query: params.query,
    category: params.category,
    hobbyNames: hobbyNamesList,
    radiusKm: params.distanceKm,
  );
});

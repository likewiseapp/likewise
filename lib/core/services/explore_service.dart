import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/matched_user.dart';
import '../models/profile.dart';

class ExploreService {
  final SupabaseClient _client;

  ExploreService(this._client);

  Future<MatchedUser?> fetchTwinMatch(String userId) async {
    final data = await _client.rpc(
      'fn_twin_match',
      params: {'current_user_id': userId},
    );
    final list = data as List;
    if (list.isEmpty) return null;
    return MatchedUser.fromJson(list.first);
  }

  Future<List<MatchedUser>> fetchNearbyUsers(String userId) async {
    final data = await _client.rpc(
      'fn_nearby_by_location',
      params: {'current_user_id': userId},
    );
    return (data as List).map((e) => MatchedUser.fromJson(e)).toList();
  }

  Future<List<MatchedUser>> searchUsers(
    String userId, {
    String query = '',
    String? category,
    List<String> hobbyNames = const [],
    double radiusKm = 500,
  }) async {
    final data = await _client.rpc(
      'fn_search_users',
      params: {
        'current_user_id': userId,
        'query_text': query,
        'hobby_category': category,
      },
    );
    final users = (data as List).map((e) => MatchedUser.fromJson(e)).toList();

    if (users.isEmpty) return users;

    final userIds = users.map((u) => u.id).toList();

    // Fetch primary hobbies for all returned users in one query
    final hobbyData = await _client
        .from('user_hobbies')
        .select('user_id, hobbies(name, icon)')
        .inFilter('user_id', userIds)
        .eq('is_primary', true);

    final hobbyMap = <String, (String, String)>{};
    for (final row in hobbyData as List) {
      final hobby = row['hobbies'] as Map<String, dynamic>?;
      if (hobby != null) {
        hobbyMap[row['user_id'] as String] = (
          hobby['name'] as String,
          hobby['icon'] as String,
        );
      }
    }

    var result = users.map((u) {
      final hobby = hobbyMap[u.id];
      if (hobby == null) return u;
      return u.copyWith(primaryHobbyName: hobby.$1, primaryHobbyIcon: hobby.$2);
    }).toList();

    // Keep only users that have at least one of the selected hobbies
    if (hobbyNames.isNotEmpty) {
      final idData = await _client
          .from('hobbies')
          .select('id')
          .inFilter('name', hobbyNames);
      final hobbyIds = (idData as List).map((e) => e['id'] as int).toList();

      if (hobbyIds.isEmpty) return [];

      final matchData = await _client
          .from('user_hobbies')
          .select('user_id')
          .inFilter('user_id', userIds)
          .inFilter('hobby_id', hobbyIds);
      final matchedIds = (matchData as List)
          .map((e) => e['user_id'] as String)
          .toSet();

      result = result.where((u) => matchedIds.contains(u.id)).toList();
    }

    // Distance filtering: fetch caller's coords + all candidate coords,
    // compute Haversine client-side, keep only users within radiusKm.
    // Users without coords are always included.
    final meData = await _client
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', userId)
        .maybeSingle();
    final myLat = (meData?['latitude'] as num?)?.toDouble();
    final myLng = (meData?['longitude'] as num?)?.toDouble();

    if (myLat != null && myLng != null) {
      final candidateIds = result.map((u) => u.id).toList();
      final coordData = await _client
          .from('profiles')
          .select('id, latitude, longitude')
          .inFilter('id', candidateIds);
      final coordMap = <String, (double, double)>{};
      for (final row in coordData as List) {
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) coordMap[row['id'] as String] = (lat, lng);
      }

      result = result.where((u) {
        final coord = coordMap[u.id];
        if (coord == null) return true; // no coords → always show
        return _haversineKm(myLat, myLng, coord.$1, coord.$2) <= radiusKm;
      }).toList();

      // Enrich with distance
      result = result.map((u) {
        final coord = coordMap[u.id];
        if (coord == null) return u;
        final dist = _haversineKm(myLat, myLng, coord.$1, coord.$2);
        return MatchedUser(
          id: u.id, username: u.username, fullName: u.fullName,
          avatarUrl: u.avatarUrl, bio: u.bio, location: u.location,
          isVerified: u.isVerified, matchCount: u.matchCount,
          followerCount: u.followerCount, distanceKm: dist,
          primaryHobbyName: u.primaryHobbyName,
          primaryHobbyIcon: u.primaryHobbyIcon,
        );
      }).toList();
    }

    return result;
  }

  /// Haversine distance in km between two lat/lng points.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;

  Future<List<ProfileStats>> fetchTopCreators({
    int limit = 10,
    String? excludeUserId,
    Set<String> blockedIds = const {},
    Set<String> followedIds = const {},
  }) async {
    var query = _client.from('v_top_creators').select();
    if (excludeUserId != null) {
      query = query.neq('id', excludeUserId);
    }
    final excludeIds = {...blockedIds, ...followedIds};
    if (excludeIds.isNotEmpty) {
      query = query.not('id', 'in', '(${excludeIds.join(',')})');
    }
    final data = await query.limit(limit);
    return (data as List).map((e) => ProfileStats.fromJson(e)).toList();
  }

  /// Fetch primary hobby (name + icon) for a list of user IDs.
  /// Returns {userId: (name, icon)}.
  Future<Map<String, (String, String)>> fetchPrimaryHobbies(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final hobbyData = await _client
        .from('user_hobbies')
        .select('user_id, hobbies(name, icon)')
        .inFilter('user_id', userIds)
        .eq('is_primary', true);

    final map = <String, (String, String)>{};
    for (final row in hobbyData as List) {
      final hobby = row['hobbies'] as Map<String, dynamic>?;
      if (hobby != null) {
        map[row['user_id'] as String] = (
          hobby['name'] as String,
          hobby['icon'] as String,
        );
      }
    }
    return map;
  }
}

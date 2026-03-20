import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../models/user_hobby.dart';
import '../services/profile_service.dart';
import 'auth_providers.dart';

final currentProfileProvider = FutureProvider<ProfileStats?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final client = ref.watch(supabaseProvider);
  return ProfileService(client).fetchProfileStats(userId);
});

final profileStatsProvider =
    FutureProvider.family<ProfileStats?, String>((ref, userId) async {
  final client = ref.watch(supabaseProvider);
  return ProfileService(client).fetchProfileStats(userId);
});

final userHobbiesProvider =
    FutureProvider.family<List<UserHobby>, String>((ref, userId) async {
  final client = ref.watch(supabaseProvider);
  return ProfileService(client).fetchUserHobbies(userId);
});

final fullProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final client = ref.watch(supabaseProvider);
  return ProfileService(client).fetchProfile(userId);
});

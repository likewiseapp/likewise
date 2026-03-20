import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hobby.dart';
import '../services/hobby_service.dart';
import 'auth_providers.dart';

final allHobbiesProvider = FutureProvider<List<Hobby>>((ref) async {
  final client = ref.watch(supabaseProvider);
  return HobbyService(client).fetchAll();
});

/// Batch-fetch a display hobby (primary or fallback) for each user.
/// Family key is a comma-joined, sorted string of user IDs so Riverpod
/// equality works correctly (List creates a new reference every build).
final displayHobbiesProvider =
    FutureProvider.family<Map<String, String>, String>(
        (ref, joinedIds) async {
  if (joinedIds.isEmpty) return {};
  final userIds = joinedIds.split(',');
  final client = ref.watch(supabaseProvider);
  return HobbyService(client).fetchDisplayHobbies(userIds);
});

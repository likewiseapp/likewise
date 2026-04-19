import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/account_service.dart';
import 'auth_providers.dart';

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref.watch(supabaseProvider));
});

final pendingDeletionRequestProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(accountServiceProvider).getPendingRequest(userId);
});

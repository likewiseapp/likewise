import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

// ── Profile-exists notifier ───────────────────────────────────────────────────
// Tracks whether the authenticated user has a profile row.
// null  = still checking
// true  = profile exists
// false = no profile (needs /complete-profile)

class ProfileExistsNotifier extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() async {
    // Re-run whenever auth state changes.
    ref.watch(authStateProvider);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return null;

    final data = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    return data != null;
  }

  /// Call this after successfully creating a profile so the router redirects immediately.
  void markCreated() => state = const AsyncData(true);
}

final profileExistsNotifierProvider =
    AsyncNotifierProvider<ProfileExistsNotifier, bool?>(
  ProfileExistsNotifier.new,
);

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  // Use stream value when available; fall back to synchronous session so
  // providers don't return null on the first frame while the stream warms up.
  return authState.whenData((state) => state.session?.user.id).value
      ?? Supabase.instance.client.auth.currentUser?.id;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserIdProvider) != null;
});

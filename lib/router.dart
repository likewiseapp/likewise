import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/providers/auth_providers.dart';
import 'core/theme_provider.dart';
import 'ui/screens/auth/auth_screen.dart';
import 'ui/screens/auth/complete_profile_screen.dart';
import 'ui/screens/social/blocked_users_screen.dart';
import 'ui/screens/messages/chat_screen.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/profile/user_profile_screen.dart';
import 'ui/screens/social/follow_list_screen.dart';
import 'ui/screens/messages/messages_screen.dart';
import 'ui/screens/profile/edit_profile_screen.dart';
import 'ui/screens/messages/message_requests_screen.dart';
import 'ui/screens/messages/new_chat_screen.dart';
import 'ui/screens/notifications/notifications_screen.dart';
import 'ui/screens/settings/settings_screen.dart';
import 'ui/screens/explore/nearby_talents_screen.dart';
import 'ui/screens/explore/top_creators_screen.dart';
import 'ui/screens/settings/theme_selector_screen.dart';
import 'ui/screens/waves/upload_wave_screen.dart';
import 'ui/screens/waves/wave_editor_screen.dart';
import 'ui/screens/waves/wave_caption_screen.dart';
import 'core/models/wave_edit_state.dart';

// Notifies GoRouter whenever auth state or profile-exists state changes.
class _AuthListenable extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  final Ref _ref;

  _AuthListenable(this._ref) {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
    // Also re-trigger the router when the profile-exists check completes.
    _ref.listen(profileExistsNotifierProvider, (_, __) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthListenable(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;

      // profileExists: null = still loading, true = has profile, false = no profile
      final profileExists = switch (ref.read(profileExistsNotifierProvider)) {
        AsyncData(:final value) => value,
        _ => null,
      };

      // ── Splash ──────────────────────────────────────────────────────────
      if (loc == '/splash') {
        if (!isAuthenticated) return '/auth';
        if (profileExists == null) return null; // wait for profile check
        return profileExists ? '/' : '/complete-profile';
      }

      // ── Not authenticated ────────────────────────────────────────────────
      if (!isAuthenticated) {
        return (loc == '/auth') ? null : '/auth';
      }

      // ── Authenticated, no profile ────────────────────────────────────────
      if (profileExists == false && loc != '/complete-profile') {
        return '/complete-profile';
      }

      // ── Authenticated, has profile ───────────────────────────────────────
      if (profileExists == true) {
        if (loc == '/auth' || loc == '/complete-profile') return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/new-chat',
        builder: (context, state) => const NewChatScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final name = state.uri.queryParameters['name'] ?? '';
          final avatar = state.uri.queryParameters['avatar'] ?? '';
          final userId = state.uri.queryParameters['userId'] ?? '';
          final isRequest =
              state.uri.queryParameters['isRequest'] == 'true';
          return ChatScreen(
            conversationId: conversationId,
            otherUserName: name,
            otherUserAvatar: avatar,
            otherUserId: userId,
            isRequest: isRequest,
          );
        },
      ),
      GoRoute(
        path: '/message-requests',
        builder: (context, state) => const MessageRequestsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/theme-selector',
        builder: (context, state) => const ThemeSelectorScreen(),
      ),
      GoRoute(
        path: '/blocked-users',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/top-creators',
        builder: (context, state) => const TopCreatorsScreen(),
      ),
      GoRoute(
        path: '/nearby-talents',
        builder: (context, state) => const NearbyTalentsScreen(),
      ),
      GoRoute(
        path: '/upload-wave',
        builder: (context, state) => const UploadWaveScreen(),
      ),
      GoRoute(
        path: '/wave-editor',
        redirect: (context, state) =>
            state.extra is WaveEditState ? null : '/',
        builder: (context, state) {
          final editState = state.extra as WaveEditState;
          return WaveEditorScreen(initialState: editState);
        },
      ),
      GoRoute(
        path: '/wave-caption',
        redirect: (context, state) =>
            state.extra is WaveEditState ? null : '/',
        builder: (context, state) {
          final editState = state.extra as WaveEditState;
          return WaveCaptionScreen(editState: editState);
        },
      ),
      GoRoute(
        path: '/follow-list/:id/:tab',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          final tab =
              int.tryParse(state.pathParameters['tab'] ?? '0') ?? 0;
          final userName = state.uri.queryParameters['name'] ?? '';
          return FollowListScreen(
            userId: userId,
            userName: userName,
            initialTab: tab,
          );
        },
      ),
    ],
  );
});

class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.accent],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'likewise',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

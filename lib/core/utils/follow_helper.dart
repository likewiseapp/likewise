import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/profile_providers.dart';
import '../services/follow_service.dart';
import '../services/notification_service.dart';

/// Shared follow/unfollow action used across grid tiles and list tiles.
/// Handles the service calls and provider invalidations.
/// The caller is responsible for managing loading state.
Future<void> performToggleFollow(
  WidgetRef ref,
  String targetUserId, {
  required bool currentlyFollowing,
}) async {
  final currentUserId = ref.read(currentUserIdProvider);
  if (currentUserId == null) return;
  final client = ref.read(supabaseProvider);

  if (currentlyFollowing) {
    await FollowService(client).unfollow(currentUserId, targetUserId);
    await NotificationService(client).deleteFollowNotification(
      recipientId: targetUserId,
      actorId: currentUserId,
    );
  } else {
    await FollowService(client).follow(currentUserId, targetUserId);
    await NotificationService(client).createFollowNotification(
      recipientId: targetUserId,
      actorId: currentUserId,
    );
  }

  ref.invalidate(isFollowingProvider(targetUserId));
  ref.invalidate(profileStatsProvider(targetUserId));
  ref.invalidate(currentProfileProvider);
  ref.invalidate(followingIdsProvider);
  ref.invalidate(notificationsProvider);
}

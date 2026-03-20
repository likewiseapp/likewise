import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';
import '../models/online_user.dart';
import '../services/message_service.dart';
import 'auth_providers.dart';

final conversationsProvider =
    StreamProvider<List<Conversation>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  final client = ref.watch(supabaseProvider);
  return MessageService(client).streamConversations(userId);
});

final requestConversationsProvider =
    FutureProvider<List<Conversation>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final client = ref.watch(supabaseProvider);
  return MessageService(client).fetchRequestConversations(userId);
});

final onlineUsersProvider = FutureProvider<List<OnlineUser>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  return MessageService(client).fetchOnlineUsers(excludeUserId: userId);
});

final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final client = ref.watch(supabaseProvider);
  return MessageService(client).streamMessages(conversationId);
});

final unreadMessagesCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider).value ?? [];
  return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// Set of message IDs soft-deleted by the current user in a conversation.
final deletedMessageIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, conversationId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final client = ref.watch(supabaseProvider);
  return MessageService(client).fetchMyDeletions(conversationId, userId);
});

/// Map of messageId → list of reactions, keyed by conversation ID for refresh.
final reactionsProvider = FutureProvider.family<
    Map<String, List<MessageReaction>>,
    List<String>>((ref, messageIds) async {
  final client = ref.watch(supabaseProvider);
  return MessageService(client).fetchReactions(messageIds);
});

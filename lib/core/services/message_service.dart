import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';
import '../models/online_user.dart';

class MessageService {
  final SupabaseClient _client;

  MessageService(this._client);

  Future<List<Conversation>> fetchConversations(String userId) async {
    final data = await _client
        .from('conversations')
        .select('id, user1_id, user2_id, status, created_at, messages(id, content, created_at, sender_id, is_read)')
        .or('user1_id.eq.$userId,and(user2_id.eq.$userId,status.eq.active)')
        .order('created_at', ascending: false);

    final rows = data as List;
    if (rows.isEmpty) return [];

    final userIds = rows
        .expand((row) => [row['user1_id'] as String, row['user2_id'] as String])
        .toSet()
        .toList();

    final profileData = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', userIds);

    final profileMap = {
      for (final p in profileData as List) p['id'] as String: p as Map<String, dynamic>
    };

    return rows.map((row) {
      final isUser1 = row['user1_id'] == userId;
      final otherId = isUser1 ? row['user2_id'] as String : row['user1_id'] as String;
      final other = profileMap[otherId];
      final messages = (row['messages'] as List?) ?? [];

      messages.sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));

      final lastMsg = messages.isNotEmpty ? messages.last : null;
      final unreadCount = messages
          .where((m) => m['sender_id'] != userId && m['is_read'] == false)
          .length;

      return Conversation(
        id: row['id'] as String,
        user1Id: row['user1_id'] as String,
        user2Id: row['user2_id'] as String,
        status: row['status'] as String? ?? 'request',
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)?.toLocal()
            : null,
        otherUsername: other?['username'] as String?,
        otherFullName: other?['full_name'] as String?,
        otherAvatarUrl: other?['avatar_url'] as String?,
        lastMessage: lastMsg?['content'] as String?,
        lastMessageAt: lastMsg?['created_at'] != null
            ? DateTime.tryParse(lastMsg!['created_at'] as String)?.toLocal()
            : null,
        lastMessageSenderId: lastMsg?['sender_id'] as String?,
        lastMessageIsRead: lastMsg?['is_read'] as bool? ?? false,
        unreadCount: unreadCount,
      );
    }).toList()
      ..sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(0);
        final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
  }

  /// Real-time stream of conversations — re-fetches whenever a message is
  /// inserted or a conversation status changes.
  Stream<List<Conversation>> streamConversations(String userId) {
    late StreamController<List<Conversation>> controller;
    RealtimeChannel? channel;

    Future<void> refetch() async {
      try {
        final convs = await fetchConversations(userId);
        if (!controller.isClosed) controller.add(convs);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<Conversation>>(
      onListen: () {
        refetch();
        channel = _client
            .channel('convos_watch_$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              callback: (_) => refetch(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'conversations',
              callback: (_) => refetch(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'conversations',
              callback: (_) => refetch(),
            )
            .subscribe();
      },
      onCancel: () {
        channel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return (data as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<List<OnlineUser>> fetchOnlineUsers({String? excludeUserId}) async {
    var query = _client.from('v_online_users').select();
    if (excludeUserId != null) query = query.neq('id', excludeUserId);
    final data = await query;
    return (data as List).map((e) => OnlineUser.fromJson(e)).toList();
  }

  /// Fetch request conversations where [userId] is the recipient (user2_id).
  Future<List<Conversation>> fetchRequestConversations(String userId) async {
    final data = await _client
        .from('conversations')
        .select('id, user1_id, user2_id, status, created_at, messages(id, content, created_at, sender_id, is_read)')
        .eq('user2_id', userId)
        .eq('status', 'request')
        .order('created_at', ascending: false);

    final rows = data as List;
    if (rows.isEmpty) return [];

    final senderIds = rows.map((row) => row['user1_id'] as String).toSet().toList();

    final profileData = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', senderIds);

    final profileMap = {
      for (final p in profileData as List) p['id'] as String: p as Map<String, dynamic>
    };

    return rows.map((row) {
      final other = profileMap[row['user1_id'] as String];
      final messages = (row['messages'] as List?) ?? [];
      messages.sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));
      final lastMsg = messages.isNotEmpty ? messages.last : null;

      return Conversation(
        id: row['id'] as String,
        user1Id: row['user1_id'] as String,
        user2Id: row['user2_id'] as String,
        status: 'request',
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)?.toLocal()
            : null,
        otherUsername: other?['username'] as String?,
        otherFullName: other?['full_name'] as String?,
        otherAvatarUrl: other?['avatar_url'] as String?,
        lastMessage: lastMsg?['content'] as String?,
        lastMessageAt: lastMsg?['created_at'] != null
            ? DateTime.tryParse(lastMsg!['created_at'] as String)?.toLocal()
            : null,
        lastMessageSenderId: lastMsg?['sender_id'] as String?,
        lastMessageIsRead: lastMsg?['is_read'] as bool? ?? false,
        unreadCount: messages
            .where((m) => m['sender_id'] != userId && m['is_read'] == false)
            .length,
      );
    }).toList();
  }

  /// Find existing conversation between two users (checks both directions)
  /// or create a new one. Returns `(conversationId, isExistingRequest)`.
  /// conversationId is null if permission settings prevent the message.
  /// isExistingRequest is true when a pending request already exists from this user.
  Future<({String? id, bool isPendingRequest})> getOrCreateConversation(
      String userId, String otherUserId) async {
    // Check direction 1: userId = user1, otherUserId = user2
    final res1 = await _client
        .from('conversations')
        .select('id, status')
        .eq('user1_id', userId)
        .eq('user2_id', otherUserId)
        .maybeSingle();

    if (res1 != null) {
      final isPending = res1['status'] == 'request';
      return (id: res1['id'] as String, isPendingRequest: isPending);
    }

    // Check direction 2: otherUserId = user1, userId = user2
    final res2 = await _client
        .from('conversations')
        .select('id, status')
        .eq('user1_id', otherUserId)
        .eq('user2_id', userId)
        .maybeSingle();

    if (res2 != null) {
      return (id: res2['id'] as String, isPendingRequest: false);
    }

    // No existing conversation — check recipient's message permission
    final profileData = await _client
        .from('profiles')
        .select('message_permission')
        .eq('id', otherUserId)
        .single();
    final permission =
        profileData['message_permission'] as String? ?? 'everyone';

    if (permission == 'none') {
      return (id: null, isPendingRequest: false);
    }

    // Check if recipient follows sender
    final recipientFollowsSender = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', otherUserId)
        .eq('following_id', userId)
        .maybeSingle();

    if (permission == 'followers_only' && recipientFollowsSender == null) {
      return (id: null, isPendingRequest: false);
    }

    // 'request' if permission='everyone' but recipient doesn't follow sender
    final status =
        (permission == 'everyone' && recipientFollowsSender == null)
            ? 'request'
            : 'active';

    final inserted = await _client.from('conversations').insert({
      'user1_id': userId,
      'user2_id': otherUserId,
      'status': status,
    }).select('id').single();

    return (id: inserted['id'] as String, isPendingRequest: false);
  }

  /// Accept a message request by setting conversation status to 'active'.
  Future<void> acceptConversation(String conversationId) async {
    await _client
        .from('conversations')
        .update({'status': 'active'})
        .eq('id', conversationId);
  }

  /// Insert a message and return the inserted row (for optimistic→real swap).
  Future<Message> sendMessage(
    String conversationId,
    String senderId,
    String content, {
    String? replyToId,
  }) async {
    final data = await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
    }).select().single();
    return Message.fromJson(data);
  }

  /// Mark all messages in a conversation as read (except those sent by userId).
  Future<void> markMessagesAsRead(
      String conversationId, String userId) async {
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  /// Hard-delete a message only if it hasn't been read yet.
  /// Returns true if deleted, false if already read.
  Future<bool> unsendMessage(String messageId, String senderId) async {
    final result = await _client
        .from('messages')
        .delete()
        .eq('id', messageId)
        .eq('sender_id', senderId)
        .eq('is_read', false)
        .select();
    return (result as List).isNotEmpty;
  }

  /// Soft-delete a message for the current user only.
  /// Inserts into `message_deletions` so the message stays visible to the other user.
  Future<void> deleteMessageForMe(String messageId, String userId) async {
    await _client.from('message_deletions').upsert(
      {'message_id': messageId, 'user_id': userId},
      onConflict: 'message_id,user_id',
    );
  }

  /// Soft-delete a message for everyone by setting `deleted_at`.
  /// Only the sender should call this.
  Future<void> deleteMessageForEveryone(
      String messageId, String senderId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId)
        .eq('sender_id', senderId);
  }

  /// Hard-delete a conversation and all its messages (cascade on backend).
  Future<void> deleteConversation(String conversationId) async {
    await _client.from('conversations').delete().eq('id', conversationId);
  }

  /// Fetch IDs of messages soft-deleted by this user in a conversation.
  Future<Set<String>> fetchMyDeletions(
      String conversationId, String userId) async {
    final data = await _client
        .from('message_deletions')
        .select('message_id')
        .eq('user_id', userId);
    return (data as List)
        .map((e) => e['message_id'] as String)
        .toSet();
  }

  /// Add an emoji reaction (upsert — one per user+emoji+message).
  Future<void> addReaction(
      String messageId, String userId, String emoji) async {
    await _client.from('message_reactions').upsert(
      {
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      },
      onConflict: 'message_id,user_id,emoji',
    );
  }

  /// Remove an emoji reaction.
  Future<void> removeReaction(
      String messageId, String userId, String emoji) async {
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji);
  }

  /// Batch fetch reactions for a list of message IDs.
  /// Returns a map of messageId → list of reactions.
  Future<Map<String, List<MessageReaction>>> fetchReactions(
      List<String> messageIds) async {
    if (messageIds.isEmpty) return {};
    final data = await _client
        .from('message_reactions')
        .select()
        .inFilter('message_id', messageIds)
        .order('created_at');
    final reactions =
        (data as List).map((e) => MessageReaction.fromJson(e)).toList();

    final map = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      map.putIfAbsent(r.messageId, () => []).add(r);
    }
    return map;
  }

  /// Real-time stream of messages for a conversation using Supabase Realtime.
  Stream<List<Message>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map((e) => Message.fromJson(e)).toList());
  }
}

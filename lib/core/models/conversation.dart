class Conversation {
  final String id;
  final String user1Id;
  final String user2Id;
  final String status;
  final DateTime? createdAt;
  final String? otherUsername;
  final String? otherFullName;
  final String? otherAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final bool lastMessageIsRead;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.status = 'request',
    this.createdAt,
    this.otherUsername,
    this.otherFullName,
    this.otherAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessageIsRead = false,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      status: json['status'] as String? ?? 'request',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      otherUsername: json['other_username'] as String?,
      otherFullName: json['other_full_name'] as String?,
      otherAvatarUrl: json['other_avatar_url'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)?.toLocal()
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime? createdAt;
  final String? replyToId;

  /// Local-only flags for optimistic UI (not persisted to DB).
  final bool isPending;
  final bool hasFailed;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    this.createdAt,
    this.replyToId,
    this.isPending = false,
    this.hasFailed = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      replyToId: json['reply_to_id'] as String?,
    );
  }

  Message copyWith({
    String? id,
    bool? isPending,
    bool? hasFailed,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      isRead: isRead,
      createdAt: createdAt,
      replyToId: replyToId,
      isPending: isPending ?? this.isPending,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }
}

class AppNotification {
  final String id;
  final String recipientId;
  final String actorId;
  final String type;
  final String? entityId;
  final String? entityType;
  final bool isRead;
  final DateTime? createdAt;
  final String? actorUsername;
  final String? actorFullName;
  final String? actorAvatarUrl;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    this.entityId,
    this.entityType,
    this.isRead = false,
    this.createdAt,
    this.actorUsername,
    this.actorFullName,
    this.actorAvatarUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      actorId: json['actor_id'] as String,
      type: json['type'] as String,
      entityId: json['entity_id'] as String?,
      entityType: json['entity_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      actorUsername: actor?['username'] as String?,
      actorFullName: actor?['full_name'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
    );
  }
}

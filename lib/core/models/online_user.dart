class OnlineUser {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final DateTime? lastSeenAt;

  const OnlineUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.lastSeenAt,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
    );
  }
}

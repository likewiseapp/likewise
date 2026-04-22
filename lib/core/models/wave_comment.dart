class WaveComment {
  final String id;
  final String waveId;
  final String userId;
  final String content;
  final DateTime createdAt;

  // Denormalised author profile (merged in by the service layer, not a
  // PostgREST embed — see fetchComments for the reason).
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  const WaveComment({
    required this.id,
    required this.waveId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory WaveComment.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return WaveComment(
      id: json['id'] as String,
      waveId: json['wave_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: profile?['username'] as String?,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

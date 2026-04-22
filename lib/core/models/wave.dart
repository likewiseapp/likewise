class Wave {
  final String id;
  final String userId;
  final String? rawVideoUrl;
  final String? videoId;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final DateTime createdAt;

  // Engagement (cached aggregates + per-viewer state)
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool viewerLiked;

  // Denormalised poster profile (joined by the feed query)
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  const Wave({
    required this.id,
    required this.userId,
    this.rawVideoUrl,
    this.videoId,
    this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.createdAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewerLiked = false,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory Wave.fromJson(Map<String, dynamic> json) {
    // The feed query joins `profiles` via the user_id FK. PostgREST returns
    // that as a nested object under the relation name (`profiles`).
    final profile = json['profiles'] as Map<String, dynamic>?;

    // Viewer-liked is expressed as a (zero-or-one row) wave_likes join.
    // If present at all → liked.
    final likesJoin = json['wave_likes'];
    final viewerLiked = likesJoin is List
        ? likesJoin.isNotEmpty
        : likesJoin is Map;

    return Wave(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      rawVideoUrl: json['raw_video_url'] as String?,
      videoId: json['video_id'] as String?,
      videoUrl: json['video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      viewerLiked: viewerLiked,
      username: profile?['username'] as String?,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Wave copyWith({
    int? viewCount,
    int? likeCount,
    int? commentCount,
    bool? viewerLiked,
  }) {
    return Wave(
      id: id,
      userId: userId,
      rawVideoUrl: rawVideoUrl,
      videoId: videoId,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      createdAt: createdAt,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      viewerLiked: viewerLiked ?? this.viewerLiked,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
  }
}

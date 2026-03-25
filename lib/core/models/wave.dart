class Wave {
  final String id;
  final String userId;
  final String? rawVideoUrl;
  final String? videoId;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final DateTime createdAt;

  const Wave({
    required this.id,
    required this.userId,
    this.rawVideoUrl,
    this.videoId,
    this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.createdAt,
  });

  factory Wave.fromJson(Map<String, dynamic> json) => Wave(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        rawVideoUrl: json['raw_video_url'] as String?,
        videoId: json['video_id'] as String?,
        videoUrl: json['video_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        caption: json['caption'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

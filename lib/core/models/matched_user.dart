class MatchedUser {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool isVerified;
  final int matchCount;
  final int followerCount;
  final double? distanceKm;
  final String? primaryHobbyName;
  final String? primaryHobbyIcon;

  const MatchedUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.isVerified = false,
    this.matchCount = 0,
    this.followerCount = 0,
    this.distanceKm,
    this.primaryHobbyName,
    this.primaryHobbyIcon,
  });

  factory MatchedUser.fromJson(Map<String, dynamic> json) {
    return MatchedUser(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      matchCount: (json['match_count'] as num?)?.toInt() ?? 0,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  MatchedUser copyWith({String? primaryHobbyName, String? primaryHobbyIcon}) {
    return MatchedUser(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      bio: bio,
      location: location,
      isVerified: isVerified,
      matchCount: matchCount,
      followerCount: followerCount,
      distanceKm: distanceKm,
      primaryHobbyName: primaryHobbyName ?? this.primaryHobbyName,
      primaryHobbyIcon: primaryHobbyIcon ?? this.primaryHobbyIcon,
    );
  }
}

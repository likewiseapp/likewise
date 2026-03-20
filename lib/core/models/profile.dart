class Profile {
  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? gender;
  final String? bio;
  final String? avatarUrl;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? dateOfBirth;
  final bool isVerified;
  final String themePreference;
  final String profileVisibility;
  final String messagePermission;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    this.gender,
    this.bio,
    this.avatarUrl,
    this.location,
    this.latitude,
    this.longitude,
    this.dateOfBirth,
    this.isVerified = false,
    this.themePreference = 'Purple Dream',
    this.profileVisibility = 'public',
    this.messagePermission = 'everyone',
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      themePreference: json['theme_preference'] as String? ?? 'Purple Dream',
      profileVisibility: json['profile_visibility'] as String? ?? 'public',
      messagePermission: json['message_permission'] as String? ?? 'everyone',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'gender': gender,
      'bio': bio,
      'avatar_url': avatarUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'is_verified': isVerified,
      'theme_preference': themePreference,
      'profile_visibility': profileVisibility,
      'message_permission': messagePermission,
    };
  }
}

class ProfileStats {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool isVerified;
  final String? themePreference;
  final int? age;
  final int followerCount;
  final int followingCount;
  final double? distanceKm;
  final String profileVisibility;

  const ProfileStats({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.isVerified = false,
    this.themePreference,
    this.age,
    this.followerCount = 0,
    this.followingCount = 0,
    this.distanceKm,
    this.profileVisibility = 'public',
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      themePreference: json['theme_preference'] as String?,
      age: json['age'] as int?,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      profileVisibility: json['profile_visibility'] as String? ?? 'public',
    );
  }
}

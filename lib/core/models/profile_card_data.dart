import 'matched_user.dart';
import 'profile.dart';

class ProfileCardData {
  final String id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final String? imageUrl;
  final List<String> hobbies;
  final String? location;
  final int? age;
  final int matchCount;

  const ProfileCardData({
    required this.id,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.imageUrl,
    this.hobbies = const [],
    this.location,
    this.age,
    this.matchCount = 0,
  });
}

extension MatchedUserToCard on MatchedUser {
  ProfileCardData toCardData({
    List<String> hobbies = const [],
    String? locationOverride,
  }) {
    return ProfileCardData(
      id: id,
      name: fullName,
      bio: bio,
      avatarUrl: avatarUrl,
      imageUrl: avatarUrl,
      hobbies: hobbies,
      location: locationOverride ?? location,
      matchCount: matchCount,
    );
  }
}

extension ProfileStatsToCard on ProfileStats {
  ProfileCardData toCardData({
    List<String> hobbies = const [],
    int? age,
    String? locationOverride,
  }) {
    return ProfileCardData(
      id: id,
      name: fullName,
      bio: bio,
      avatarUrl: avatarUrl,
      imageUrl: avatarUrl,
      hobbies: hobbies,
      location: locationOverride ?? location,
      age: age ?? this.age,
    );
  }
}

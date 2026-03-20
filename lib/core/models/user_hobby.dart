import 'hobby.dart';

class UserHobby {
  final String userId;
  final int hobbyId;
  final bool isPrimary;
  final Hobby? hobby;

  const UserHobby({
    required this.userId,
    required this.hobbyId,
    this.isPrimary = false,
    this.hobby,
  });

  factory UserHobby.fromJson(Map<String, dynamic> json) {
    return UserHobby(
      userId: json['user_id'] as String,
      hobbyId: json['hobby_id'] as int,
      isPrimary: json['is_primary'] as bool? ?? false,
      hobby: json['hobbies'] != null
          ? Hobby.fromJson(json['hobbies'] as Map<String, dynamic>)
          : null,
    );
  }
}

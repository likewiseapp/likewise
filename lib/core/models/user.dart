class User {
  final String id;
  final String name;
  final String bio;
  final String avatarUrl;
  final String backgroundImageUrl;
  final List<String> hobbies;
  final String location;
  final int age;

  const User({
    required this.id,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    required this.backgroundImageUrl,
    required this.hobbies,
    required this.location,
    required this.age,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String,
      avatarUrl: json['avatarUrl'] as String,
      backgroundImageUrl: json['backgroundImageUrl'] as String,
      hobbies: List<String>.from(json['hobbies'] as List),
      location: json['location'] as String,
      age: json['age'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'hobbies': hobbies,
      'location': location,
      'age': age,
    };
  }
}

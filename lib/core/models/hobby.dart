import 'package:flutter/material.dart';

class Hobby {
  final int id;
  final String name;
  final String icon;
  final String color;
  final String category;

  const Hobby({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
  });

  Color get colorValue {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory Hobby.fromJson(Map<String, dynamic> json) {
    return Hobby(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'category': category,
    };
  }
}

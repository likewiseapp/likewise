import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppColorScheme {
  final String name;
  final Color primary;
  final Color accent;

  const AppColorScheme({
    required this.name,
    required this.primary,
    required this.accent,
  });

  Color get primaryLight => Color.lerp(primary, Colors.white, 0.2)!;

  static const List<AppColorScheme> presets = [
    AppColorScheme(
      name: 'Purple Dream',
      primary: Color(0xFF6C63FF),
      accent: Color(0xFFE056FD),
    ),
    AppColorScheme(
      name: 'Ocean',
      primary: Color(0xFF0095FF),
      accent: Color(0xFF00D4FF),
    ),
    AppColorScheme(
      name: 'Sunset',
      primary: Color(0xFFFF6B6B),
      accent: Color(0xFFFFB347),
    ),
    AppColorScheme(
      name: 'Forest',
      primary: Color(0xFF00B894),
      accent: Color(0xFF6DD5FA),
    ),
    AppColorScheme(
      name: 'Rose',
      primary: Color(0xFFF093FB),
      accent: Color(0xFFF5576C),
    ),
    AppColorScheme(
      name: 'Midnight',
      primary: Color(0xFF667EEA),
      accent: Color(0xFF764BA2),
    ),
    AppColorScheme(
      name: 'Coral',
      primary: Color(0xFFFF758C),
      accent: Color(0xFFFF7EB3),
    ),
    AppColorScheme(
      name: 'Emerald',
      primary: Color(0xFF11998E),
      accent: Color(0xFF38EF7D),
    ),
  ];
}

class AppColorSchemeNotifier extends Notifier<AppColorScheme> {
  @override
  AppColorScheme build() => AppColorScheme.presets[0];

  void setScheme(AppColorScheme scheme) {
    state = scheme;
  }
}

final appColorSchemeProvider =
    NotifierProvider<AppColorSchemeNotifier, AppColorScheme>(
  AppColorSchemeNotifier.new,
);

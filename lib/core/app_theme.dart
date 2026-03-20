import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.outfit(
      fontWeight: FontWeight.bold,
      fontSize: 32,
      letterSpacing: -1.0,
    ),
    displayMedium: GoogleFonts.outfit(
      fontWeight: FontWeight.bold,
      fontSize: 28,
      letterSpacing: -0.5,
    ),
    displaySmall: GoogleFonts.outfit(
      fontWeight: FontWeight.bold,
      fontSize: 24,
    ),
    headlineLarge: GoogleFonts.outfit(
      fontWeight: FontWeight.w800,
      fontSize: 30,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.outfit(
      fontWeight: FontWeight.w600,
      fontSize: 20,
    ),
    titleLarge: GoogleFonts.outfit(
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: -0.3,
    ),
    titleMedium: GoogleFonts.outfit(
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    bodyLarge: GoogleFonts.inter(fontSize: 16),
    bodyMedium: GoogleFonts.inter(fontSize: 14),
    bodySmall: GoogleFonts.inter(fontSize: 12),
    labelLarge: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );

  static ThemeData lightTheme(Color seedColor) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black,
    ),
  );

  static ThemeData darkTheme(Color seedColor) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F17),
    textTheme: textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
    ),
  );
}

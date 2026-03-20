import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Canonical color constants used throughout the app.
/// Always reference these instead of writing raw Color() literals.
class AppColors {
  // ── Scaffold backgrounds ────────────────────────────────────────────────
  static const darkScaffold = Color(0xFF0F0F17);
  static const lightScaffold = Color(0xFFF2F4F8);

  // Settings screen uses a slightly different tint (iOS-style grouped bg)
  static const lightScaffoldAlt = Color(0xFFF5F5F7);

  // ── Surface / card / modal backgrounds ─────────────────────────────────
  // Used for popups, bottom sheets, dialogs, cards in dark mode
  static const darkSurface = Color(0xFF1E1E28);

  // ── Semantic / functional colors ────────────────────────────────────────
  static const onlineGreen = Color(0xFF34C759);

  // ── Notification type indicator colors ──────────────────────────────────
  static const notifLike    = Color(0xFFFF4757);
  static const notifMention = Color(0xFF0095FF);
  static const notifTwin    = Color(0xFF00B894);
}

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
    scaffoldBackgroundColor: AppColors.lightScaffold,
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
    scaffoldBackgroundColor: AppColors.darkScaffold,
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

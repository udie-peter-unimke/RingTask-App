// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // ─────────────────────── LIGHT THEME ─────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto',

    // Colour scheme (seed-based)
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),

    // Text theme – **Material 3 names only**
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall:  TextStyle(fontSize: 36, fontWeight: FontWeight.w400),

      headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w400),

      titleLarge:    TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

      bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400),

      labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),

    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  // ─────────────────────── DARK THEME ──────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),

    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall:  TextStyle(fontSize: 36, fontWeight: FontWeight.w400),

      headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w400),

      titleLarge:    TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

      bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400),

      labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),

    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData oled = dark.copyWith(
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    cardColor: AppColors.surfaceDark,
  );
}
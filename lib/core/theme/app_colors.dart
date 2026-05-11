// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Central place for every colour used in the app.
class AppColors {
  // ── Brand ────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF0066FF);   // blue
  static const Color primaryDark = Color(0xFF0040B2);   // darker blue for dark mode

  // ── Neutrals ─────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark  = Color(0xFF121212);
  static const Color surfaceDark     = Color(0xFF1E1E1E);

  // ── Semantic ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error   = Color(0xFFF44336);
}
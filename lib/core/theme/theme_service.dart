// lib/core/theme/theme_service.dart
import 'package:flutter/material.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'app_theme.dart';

/// Extension on SettingsModel – single source of truth for theme logic.
extension ThemeService on SettingsModel {
  // ──────────────────────  THEME MODE  ────────────────────── //
  /// Convert stored string → Flutter's ThemeMode
  ThemeMode get flutterThemeMode {
    return switch (themeMode) {
      'light' => ThemeMode.light,
      'dark' || 'oled' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  // ──────────────────────  DARK / LIGHT  ──────────────────── //
  bool get isDarkMode   => themeMode == 'dark' || themeMode == 'oled';
  bool get isLightMode  => themeMode == 'light';
  bool get isSystemMode => themeMode == 'system';

  // ──────────────────────  PRIMARY COLOR  ─────────────────── //
  /// Parses hex string like "#FF0066" or "0xFF0066FF" → Color
  Color? get primaryColorValue {
    if (primaryColor == null || primaryColor!.isEmpty) return null;
    try {
      final String hex = primaryColor!
          .replaceFirst('#', '')
          .replaceFirst('0x', '');
      if (hex.length != 6 && hex.length != 8) return null;
      final int? value = int.tryParse(hex, radix: 16);
      if (value == null) return null;
      return Color(hex.length == 6 ? 0xFF000000 + value : value);
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────  BASE THEME  ────────────────────── //
  /// Resolves requested brightness to correct AppTheme without requiring BuildContext.
  ThemeData _baseThemeForBrightness(Brightness brightness) {
    // Pick base theme based on brightness and special OLED mode
    final ThemeData base = switch (brightness) {
      Brightness.light => AppTheme.light,
      Brightness.dark  => themeMode == 'oled' ? AppTheme.oled : AppTheme.dark,
    };

    // Apply dynamic primary colour if set
    final Color? customPrimary = primaryColorValue;
    if (customPrimary == null) return base;

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: customPrimary,
        secondary: customPrimary,
      ),
    );
  }

  // ──────────────────────  FINAL THEME  ───────────────────── //
  /// Returns fully configured ThemeData for a specific brightness.
  ThemeData finalThemeForBrightness(Brightness brightness) {
    final ThemeData base = _baseThemeForBrightness(brightness);
    return base.copyWith(
      textTheme: base.textTheme.apply(fontSizeFactor: fontSize),
    );
  }

  // ──────────────────────  DISPLAY HELPERS  ───────────────── //
  String get themeModeDisplay {
    return switch (themeMode) {
      'light'  => 'Light',
      'dark'   => 'Dark',
      'oled'   => 'OLED (Pure Black)',
      'system' => 'System Default',
      _        => 'Unknown',
    };
  }

  /// Deprecated: Use [finalThemeForBrightness] instead to avoid MediaQuery dependency.
  @Deprecated('Use finalThemeForBrightness(brightness) to avoid assertion errors')
  ThemeData finalTheme(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return finalThemeForBrightness(brightness);
  }
}

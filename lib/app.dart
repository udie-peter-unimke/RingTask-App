// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/blocs/auth/auth_event.dart';
import 'package:ringtask/blocs/tts/tts_event.dart';
import 'package:ringtask/blocs/tts/tts_settings_event.dart';
import 'package:ringtask/blocs/settings/settings_event.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/auth/auth_state.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/tts/tts_bloc.dart';
import 'package:ringtask/blocs/tts/tts_settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/router.dart';

// 🔥 CRITICAL: Global navigator key for WorkManager → FakeCallScreen
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class RingTaskApp extends StatelessWidget {
  const RingTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AppStarted()),
        ),
        BlocProvider<TaskBloc>(create: (_) => getIt<TaskBloc>()),
        BlocProvider<TtsBloc>(
          create: (_) => getIt<TtsBloc>()..add(const InitializeTts()),
        ),
        BlocProvider<TtsSettingsBloc>(
          create: (_) =>
          getIt<TtsSettingsBloc>()..add(const LoadTtsSettings()),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) => getIt<SettingsBloc>()..add(const LoadSettings()),
        ),
      ],
      child: const _RingTaskMaterialApp(),
    );
  }
}

/// Separated so BlocBuilder can read SettingsBloc from context
class _RingTaskMaterialApp extends StatelessWidget {
  const _RingTaskMaterialApp();

  /// Maps the stored String value → Flutter ThemeMode enum
  ThemeMode _resolveThemeMode(SettingsState state) {
    String mode = 'system';

    if (state is SettingsLoaded) {
      mode = state.settings.themeMode;
    } else if (state is SettingsUpdateSuccess) {
      mode = state.settings.themeMode;
    } else if (state is SettingsSyncSuccess) {
      mode = state.syncedSettings.themeMode;
    } else if (state is SettingsResetSuccess) {
      mode = state.defaultSettings.themeMode;
    }

    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // Only fire on actual logout — not on the initial AuthInitial at app start.
      // prev is AuthSuccess  → user was logged in
      // prev is AuthLoading  → covers edge-case mid-request logout
      listenWhen: (prev, next) =>
      next is AuthInitial && prev is! AuthInitial,
      listener: (_, __) {
        // navigatorKey is defined at file scope and assigned to MaterialApp
        // below, so it's safe to call here even before first frame.
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRouter.loginRoute,
              (route) => false, // wipes the entire back-stack
        );
      },
      child: BlocBuilder<SettingsBloc, SettingsState>(
        // Only rebuild when theme actually changes — avoids unnecessary repaints
        buildWhen: (prev, next) =>
        _resolveThemeMode(prev) != _resolveThemeMode(next),
        builder: (context, settingsState) {
          return MaterialApp(
            navigatorKey: navigatorKey, // 🔥 REQUIRED for background fake calls
            title: 'RingTask',
            debugShowCheckedModeBanner: false,
            themeMode: _resolveThemeMode(settingsState),

            // ── Light theme ────────────────────────────────────────────────
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3),
                brightness: Brightness.light,
              ),
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              cardColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF2196F3),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                ),
              ),
              dividerColor: Colors.grey.shade200,
            ),

            // ── Dark theme ─────────────────────────────────────────────────
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF2196F3),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                ),
              ),
              dividerColor: Colors.white12,
            ),

            initialRoute: '/login',
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}
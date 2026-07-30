import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/auth/auth_state.dart';
import 'package:ringtask/blocs/loop/loop_bloc.dart';
import 'package:ringtask/blocs/loop/loop_event.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/core/theme/theme_service.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/router.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:ringtask/presentation/screens/auth/login_screen.dart';
// TODO: Ensure your exact splash screen file path is imported here
import 'package:ringtask/presentation/screens/splash/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize loop tasks on first auth check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLoopTasks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rescheduleLoopTasksOnResume();
    }
  }

  Future<void> _initializeLoopTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        AppLogger.info('Initializing loop tasks for user: ${user.uid}');

        // Trigger LoadLoopsEvent to sync with Firestore and handle scheduling
        // LoopBloc's _onLoadLoops already handles initial scheduling from repository stream
        context.read<LoopBloc>().add(LoadLoopsEvent(user.uid));
      }
    } catch (e) {
      AppLogger.error('Error initializing loop tasks: $e');
    }
  }

  Future<void> _rescheduleLoopTasksOnResume() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        AppLogger.info('Rescheduling loop tasks on app resume (deferred)');
        // Layer 4: Defer non-critical tasks to allow immediate navigation
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        // Re-trigger load to ensure everything is in sync and correctly scheduled
        context.read<LoopBloc>().add(LoadLoopsEvent(user.uid));
      }
    } catch (e) {
      AppLogger.error('Error rescheduling loop tasks: $e');
    }
  }

  SettingsModel _resolveSettings(SettingsState state) {
    if (state is SettingsLoaded) return state.settings;
    if (state is SettingsUpdateSuccess) return state.settings;
    if (state is SettingsSyncSuccess) return state.syncedSettings;
    if (state is SettingsResetSuccess) return state.defaultSettings;
    if (state is SettingsUpdating) return state.currentSettings;
    return SettingsModel.defaultSettings();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Wrap at the highest level with the AuthBloc listener
    // to reliably intercept the transition into AuthSuccess globally.
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          AppLogger.info('AuthBloc Listener: User authenticated successfully: ${state.uid}');
          _initializeLoopTasks();
        } else if (state is AuthInitial) {
          AppLogger.info('AuthBloc Listener: User unauthenticated / logged out');
        }
      },
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = _resolveSettings(state);

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'RingTask',
            debugShowCheckedModeBanner: false,
            theme: settings.finalThemeForBrightness(Brightness.light),
            darkTheme: settings.finalThemeForBrightness(Brightness.dark),
            themeMode: settings.flutterThemeMode,
            home: const AuthWrapper(),
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return const SplashScreen();
        }

        if (state is AuthOnboardingRequired) {
          return const OnboardingScreen();
        }

        if (state is AuthSuccess) {
          return const AppNavigationWrapper();
        }

        return const LoginScreen();
      },
    );
  }
}

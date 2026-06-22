// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/auth/auth_state.dart';
import 'package:ringtask/blocs/loop/loop_bloc.dart';
import 'package:ringtask/blocs/loop/loop_event.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/core/theme/theme_service.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/router.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';
import 'package:ringtask/repositories/loop_repository.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:ringtask/presentation/screens/auth/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  late final LoopRepository _loopRepository;
  late final FakeCallService _fakeCallService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loopRepository = getIt<LoopRepository>();
    _fakeCallService = getIt<FakeCallService>();

    // Initialize loop tasks on first auth
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

        // Load cached tasks and schedule them
        final cachedTasks = await _loopRepository.getCachedTasks();
        if (cachedTasks.isNotEmpty) {
          await _fakeCallService.rescheduleLoopTasks(cachedTasks);
          AppLogger.info('Initialized ${cachedTasks.length} cached loop tasks');
        }

        // Trigger LoadLoopsEvent to sync with Firestore
        if (mounted) {
          context.read<LoopBloc>().add(LoadLoopsEvent(user.uid));
        }
      }
    } catch (e) {
      AppLogger.error('Error initializing loop tasks: $e');
    }
  }

  Future<void> _rescheduleLoopTasksOnResume() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        AppLogger.info('Rescheduling loop tasks on app resume');

        final cachedTasks = await _loopRepository.getCachedTasks();
        if (cachedTasks.isNotEmpty) {
          await _fakeCallService.rescheduleLoopTasks(cachedTasks);
          AppLogger.info('Loop tasks rescheduled: ${cachedTasks.length} tasks');
        }
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
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final settings = _resolveSettings(state);

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'RingTask',
          debugShowCheckedModeBanner: false,
          theme: settings.finalTheme(context),
          themeMode: ThemeMode.light, // Handled by finalTheme inside the builder
          home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is AuthOnboardingRequired) {
            return const OnboardingScreen();
          }

          if (state is AuthSuccess) {
            return BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthSuccess) {
                  AppLogger.info('User authenticated: ${state.uid}');
                  _initializeLoopTasks();
                } else if (state is AuthInitial) {
                  AppLogger.info('User unauthenticated');
                }
              },
              child: const AppNavigationWrapper(),
            );
          }

          return const LoginScreen();
        },
      ),
      onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}

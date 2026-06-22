// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/firebase_options.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/repositories/auth_repository.dart';
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/repositories/fake_call_repository.dart';
import 'package:ringtask/repositories/voice_repository.dart';
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/auth/auth_event.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_event.dart';
import 'package:ringtask/blocs/voice/voice_bloc.dart';
import 'package:ringtask/blocs/loop/loop_bloc.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/app.dart';

void main() async {
  // ===== Initialization =====
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (only if not already initialized, e.g. after hot restart)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    AppLogger.error('Firebase initialization failed. Check your firebase_options.dart: $e');
  }

  // Initialize AppLogger
  AppLogger.initialize();

  // Setup Service Locator (all services, datasources, repos, permissions)
  await setupServiceLocator();

  // ===== Run App =====
  runApp(const RingTaskApp());
}

class RingTaskApp extends StatelessWidget {
  const RingTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(
            authRepository: getIt<IAuthRepository>(),
          )..add(const AppStarted()),
        ),
        BlocProvider(
          create: (context) => TaskBloc(
            taskRepository: getIt<TaskRepository>(),
            fakeCallRepository: getIt<FakeCallRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => SettingsBloc(
            settingsRepository: getIt(),
          )..add(const LoadSettings()),
        ),
        BlocProvider(
          create: (context) => VoiceBloc(
            voiceRepository: getIt<IVoiceRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => LoopBloc(
            repository: getIt(),
            fakeCallService: getIt(),
          ),
        ),
      ],
      child: const MainApp(),
    );
  }
}

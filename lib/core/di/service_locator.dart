// lib/core/di/service_locator.dart

import 'package:get_it/get_it.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ringtask/utils/logger.dart';

// Datasources
import 'package:ringtask/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ringtask/data/datasources/local/cache_manager.dart';

// Blocs
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/fake_call/fake_call_bloc.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/tts/tts_bloc.dart';
import 'package:ringtask/blocs/tts/tts_settings_bloc.dart';
import 'package:ringtask/blocs/voice/voice_bloc.dart';

// Repositories
import 'package:ringtask/repositories/auth_repository.dart';
import 'package:ringtask/repositories/fake_call_repository.dart';
import 'package:ringtask/repositories/settings_repository.dart';
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/repositories/tts_repository.dart';
import 'package:ringtask/repositories/voice_repository.dart';

// Services
import 'package:ringtask/services/firebase/firebase_auth_service.dart';
import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/services/firebase/notification_service.dart';
import 'package:ringtask/services/firebase/permission_service.dart';
import 'package:ringtask/services/firebase/tts_service.dart';
import 'package:ringtask/services/firebase/voice_service.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';

final getIt = GetIt.instance;

// Helper for FakeCallBloc param
extension GetItX on GetIt {
  T call<T extends Object>({dynamic param1, dynamic param2}) =>
      this<T>(param1: param1, param2: param2);
}

Future<void> setupServiceLocator() async {
  AppLogger.initialize(logLevel: LogLevel.debug);
  AppLogger.info('Setting up Service Locator...');

  // ====================== CORE SERVICES ======================
  getIt.registerLazySingleton<PermissionService>(() => PermissionService());
  getIt.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());
  getIt.registerLazySingleton<FirestoreService>(() => FirestoreService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());

  getIt.registerLazySingleton<FakeCallService>(() {
    final service = FakeCallService();
    service.initialize();
    return service;
  });

  getIt.registerLazySingleton<FlutterTts>(() => FlutterTts());
  getIt.registerLazySingleton<TtsService>(
        () => TtsService(getIt<FlutterTts>()),
  );

  // VoiceService is async (mic init, permissions, etc.)
  getIt.registerSingletonAsync<VoiceService>(() async {
    final service = VoiceService();
    await service.initialize();
    return service;
  });

  // Wait for async core services (VoiceService)
  await getIt.allReady();

  // ====================== LOCAL CACHE ======================
  getIt.registerSingletonAsync<SharedPreferences>(
        () async => SharedPreferences.getInstance(),
  );

  getIt.registerLazySingleton<CacheManager>(
        () => CacheManager(prefs: getIt<SharedPreferences>()),
  );

  // Wait for SharedPreferences + CacheManager
  await getIt.allReady();

  // ====================== DATASOURCES ======================
  getIt.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(FirebaseAuth.instance),
  );

  // If you later add TaskRemoteDataSource / TaskLocalDataSource, register them here.

  // ====================== REPOSITORIES ======================
  getIt.registerLazySingleton<SettingsRepository>(
        () => SettingsRepository(getIt<CacheManager>()),
  );

  getIt.registerLazySingleton<AuthRepository>(
        () => AuthRepository(
      authRemoteDataSource: getIt<AuthRemoteDataSource>(),
      firestoreService: getIt<FirestoreService>(),
    ),
  );

  getIt.registerLazySingleton<TaskRepository>(
        () => TaskRepository(
      getIt<FirestoreService>(),
      getIt<CacheManager>(),
    ),
  );

  getIt.registerLazySingleton<TtsRepository>(
        () => TtsRepository(getIt<FlutterTts>()),
  );

  getIt.registerLazySingleton<VoiceRepository>(
        () => VoiceRepository(
      voiceService: getIt<VoiceService>(),
      permissionService: getIt<PermissionService>(),
    ),
  );

  getIt.registerLazySingleton<FakeCallRepository>(
        () => FakeCallRepository(),
  );

  // ====================== BLOCS ======================
  getIt.registerFactory<AuthBloc>(
        () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );

  getIt.registerFactory<SettingsBloc>(
        () => SettingsBloc(settingsRepository: getIt<SettingsRepository>()),
  );

  getIt.registerFactory<TaskBloc>(
        () => TaskBloc(taskRepository: getIt<TaskRepository>()),
  );

  getIt.registerFactory<TtsBloc>(
        () => TtsBloc(ttsRepository: getIt<TtsRepository>()),
  );

  getIt.registerFactory<TtsSettingsBloc>(
        () => TtsSettingsBloc(
      settingsRepository: getIt<SettingsRepository>(),
      ttsRepository: getIt<TtsRepository>(),
    ),
  );

  getIt.registerFactory<VoiceBloc>(
        () => VoiceBloc(voiceRepository: getIt<VoiceRepository>()),
  );

  // FakeCallBloc with userId param
  getIt.registerFactoryParam<FakeCallBloc, String, void>(
        (userId, _) => FakeCallBloc(
      fakeCallRepository: getIt<FakeCallRepository>(),
      taskRepository: getIt<TaskRepository>(),
      ttsService: getIt<TtsService>(),
      userId: userId,
    ),
  );

  AppLogger.info('✅ Service Locator setup completed successfully!');
}

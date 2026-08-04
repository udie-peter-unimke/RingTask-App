// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// ===== Repositories =====
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/repositories/settings_repository.dart';
import 'package:ringtask/repositories/loop_repository.dart';
import 'package:ringtask/repositories/auth_repository.dart';
import 'package:ringtask/repositories/fake_call_repository.dart';
import 'package:ringtask/repositories/tts_repository.dart';
import 'package:ringtask/repositories/voice_repository.dart';
import 'package:ringtask/repositories/subscription/subscription_repository.dart';
import 'package:ringtask/repositories/subscription/subscription_repository_impl.dart';

// ===== Datasources (Local) =====
import 'package:ringtask/data/datasources/local/cache_manager.dart';
import 'package:ringtask/data/datasources/local/loop_local_datasource.dart';
import 'package:ringtask/data/datasources/local/subscription_local_datasource.dart';

import 'package:ringtask/data/datasources/remote/loop_remote_datasource.dart';
import 'package:ringtask/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ringtask/data/datasources/remote/subscription_remote_datasource.dart';
import 'package:ringtask/services/entitlement/entitlement_service.dart';

// ===== Services =====
import 'package:ringtask/services/firebase/fake_call_service.dart';
import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/services/firebase/firebase_auth_service.dart';
import 'package:ringtask/services/firebase/voice_service.dart';
import 'package:ringtask/services/firebase/permission_service.dart';
import 'package:ringtask/services/scheduler/alarm_scheduler.dart';
import 'package:ringtask/services/sync_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ===== Blocs =====
import 'package:ringtask/blocs/tts/tts_settings_bloc.dart';
import 'package:ringtask/blocs/subscription/subscription_bloc.dart';
import 'package:ringtask/blocs/loop/loop_bloc.dart';

// ===== Utils =====
import 'package:ringtask/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  AppLogger.info('🚀 Setting up service locator...');

  try {
    // ===== Firebase Instances =====
    _registerFirebaseServices();

    // ===== SharedPreferences =====
    await _registerSharedPreferences();

    // ===== Core Managers & Local Services =====
    _registerLocalServices();

    // ===== Firebase Services =====
   await _registerFirebaseClients();

    // ===== Datasources =====
    _registerDatasources();

    // ===== Repositories =====
    _registerRepositories();

    // ===== Scheduler & Sync Services =====
    await _registerSchedulerAndSyncServices();

    AppLogger.info('✅ Service locator setup complete');
  } catch (e, stack) {
    AppLogger.error('❌ Service locator setup failed: $e');
    AppLogger.error(stack.toString());
    rethrow;
  }
}

void _registerFirebaseServices() {
  getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  getIt.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  AppLogger.info('✓ Firebase instances registered');
}

Future<void> _registerSharedPreferences() async {
  final sharedPrefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPrefs);
  AppLogger.info('✓ SharedPreferences registered');
}

void _registerLocalServices() {
  getIt.registerSingleton<CacheManager>(
    CacheManager(prefs: getIt<SharedPreferences>()),
  );
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());
  AppLogger.info('✓ Local services registered');
}

Future<void> _registerFirebaseClients() async {
  final firestoreService = FirestoreService(
    firestore: getIt<FirebaseFirestore>(),
  );
  getIt.registerSingleton<FirestoreService>(firestoreService);

  final firebaseAuthService = FirebaseAuthService(
    firebaseAuth: getIt<FirebaseAuth>(),
  );
  getIt.registerSingleton<FirebaseAuthService>(firebaseAuthService);

  // === FIX IS HERE ===
  final voiceService = VoiceService();
  // Register it immediately so other services can see it
  getIt.registerSingleton<VoiceService>(voiceService);
  // Initialize in background to avoid blocking app startup
  voiceService.initialize().catchError((e) => AppLogger.error('VoiceService init failed: $e'));

  final fakeCallService = FakeCallService();
  getIt.registerSingleton<FakeCallService>(fakeCallService);

  final permissionService = PermissionService();
  getIt.registerSingleton<IPermissionService>(permissionService);

  AppLogger.info('✓ Firebase services registered');
}

void _registerDatasources() {
  getIt.registerSingleton<LoopLocalDataSource>(
    LoopLocalDataSource(prefs: getIt<SharedPreferences>()),
  );

  getIt.registerSingleton<LoopRemoteDataSource>(
    LoopRemoteDataSource(firestore: getIt<FirebaseFirestore>()),
  );

  getIt.registerSingleton<AuthRemoteDataSource>(
    AuthRemoteDataSourceImpl(getIt<FirebaseAuth>()),
  );

  getIt.registerSingleton<SubscriptionLocalDataSource>(
    SubscriptionLocalDataSource(cacheManager: getIt<CacheManager>()),
  );

  getIt.registerSingleton<SubscriptionRemoteDataSource>(
    SubscriptionRemoteDataSource(firestore: getIt<FirebaseFirestore>()),
  );

  AppLogger.info('✓ Datasources registered');
}

void _registerRepositories() {
  // Task Repository
  final taskRepository = TaskRepository(
    firestoreService: getIt<FirestoreService>(),
    cacheManager: getIt<CacheManager>(),
  );
  getIt.registerSingleton<TaskRepository>(taskRepository);

  // Loop Repository
  final loopRepository = LoopRepository(
    localDataSource: getIt<LoopLocalDataSource>(),
    remoteDataSource: getIt<LoopRemoteDataSource>(),
  );
  getIt.registerSingleton<LoopRepository>(loopRepository);

  // Settings Repository
  final settingsRepository = SettingsRepository(
    getIt<CacheManager>(),
  );
  getIt.registerSingleton<SettingsRepository>(settingsRepository);

  // Auth Repository
  final authRepository = AuthRepository(
    authRemoteDataSource: getIt<AuthRemoteDataSource>(),
  );
  getIt.registerSingleton<IAuthRepository>(authRepository);

  // FakeCall Repository
  final fakeCallRepository = FakeCallRepository(
    service: getIt<FakeCallService>(),
  );
  getIt.registerSingleton<FakeCallRepository>(fakeCallRepository);

  // Voice Repository
  final voiceRepository = VoiceRepository(
    voiceService: getIt<VoiceService>(),
    permissionService: getIt<IPermissionService>() as PermissionService,
  );
  getIt.registerSingleton<IVoiceRepository>(voiceRepository);

  // TTS Repository
  final ttsRepository = TtsRepository(FlutterTts());
  getIt.registerSingleton<TtsRepository>(ttsRepository);
  getIt.registerLazySingleton<TtsSettingsBloc>(
        () => TtsSettingsBloc(
      settingsRepository: getIt<SettingsRepository>(),
      ttsRepository: getIt<TtsRepository>(),
    ),
  );

  // Subscription Repository
  getIt.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      remoteDataSource: getIt<SubscriptionRemoteDataSource>(),
      localDataSource: getIt<SubscriptionLocalDataSource>(),
    ),
  );

  // Entitlement Service
  getIt.registerLazySingleton<EntitlementService>(
    () => EntitlementService(subscriptionRepository: getIt<SubscriptionRepository>()),
  );

  // Subscription Bloc
  getIt.registerFactory<SubscriptionBloc>(
    () => SubscriptionBloc(
      repository: getIt<SubscriptionRepository>(),
      entitlementService: getIt<EntitlementService>(),
    ),
  );
  
  // Loop Bloc
  getIt.registerFactory<LoopBloc>(
    () => LoopBloc(
      repository: getIt<LoopRepository>(),
      fakeCallService: getIt<FakeCallService>(),
      entitlementService: getIt<EntitlementService>(),
      settingsRepository: getIt<SettingsRepository>(),
    ),
  );

  AppLogger.info('✓ Repositories registered');
}

Future<void> _registerSchedulerAndSyncServices() async {
  // Register AlarmScheduler
  final alarmScheduler = AlarmScheduler();
  await alarmScheduler.initialize();
  getIt.registerSingleton<AlarmScheduler>(alarmScheduler);

  // Register SyncService
  final syncService = SyncService(
    getIt<TaskRepository>(),
    getIt<Connectivity>(),
  );
  getIt.registerSingleton<SyncService>(syncService);

  // Initialize FakeCallService (already registered as singleton)
  final fakeCallService = getIt<FakeCallService>();
  // We don't await this so Flutter engine can signal 'ready' to native ASAP
  fakeCallService.initialize().catchError((e) => AppLogger.error('FakeCallService init failed: $e'));

  AppLogger.info('✓ Scheduler and Sync services registered');
}

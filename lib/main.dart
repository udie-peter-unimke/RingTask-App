// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:ringtask/app.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/services/scheduler/alarm_scheduler.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';

class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'App Initialization Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(error, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => runApp(const RingTaskApp()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.initialize(logLevel: LogLevel.debug);
  AppLogger.info('🚀 Starting RingTask v1.0.0...');

  try {
    // 1. Firebase
    await Firebase.initializeApp();
    AppLogger.info('✅ Firebase initialized');

    // 2. GoogleSignIn — initializes automatically on first use
    AppLogger.info('✅ GoogleSignIn ready');

    // 3. Service Locator
    await setupServiceLocator();
    AppLogger.info('✅ Service Locator initialized');

    // ✅ REMOVED: Workmanager().initialize() — flutter workmanager plugin is
    // no longer used. Scheduling is handled natively via MethodChannel →
    // MainActivity → FakeCallWorker (Kotlin WorkManager directly).

    // 4. AlarmScheduler
    await AlarmScheduler.initialize();
    AppLogger.info('✅ AlarmScheduler initialized');

    // 5. FakeCallService — initialize first, permissions second
    await getIt<FakeCallService>().initialize();
    AppLogger.info('✅ FakeCallService initialized');

    // 6. Request permissions AFTER initialize, sequenced to avoid
    // "permissionRequestInProgress" conflict
    await getIt<FakeCallService>().requestPermissions();
    AppLogger.info('✅ Permissions requested');

    // 7. Run app
    runApp(const RingTaskApp());
    AppLogger.info('🎉 RingTask started successfully!');

  } catch (e, stackTrace) {
    AppLogger.error('❌ FATAL ERROR: $e', stackTrace: stackTrace);
    runApp(ErrorScreen(error: e.toString()));
  }
}
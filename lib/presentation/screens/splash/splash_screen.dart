// lib/presentation/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ringtask/app.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/core/constants/app_assets.dart';
import 'package:ringtask/utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Start Firebase and DI in parallel
      await Future.wait([
        Firebase.initializeApp(),
        setupServiceLocator(),
      ]);

      AppLogger.info('✅ Core systems initialized');

      if (!mounted) return;

      // Navigate to the main app
      // We use pushReplacement to remove splash from stack
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RingTaskApp()),
      );
    } catch (e, stack) {
      AppLogger.error('❌ Bootstrap failed', error: e, stackTrace: stack);
      // In a real app, you might show an error screen here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alarm,
                size: 60,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'RingTask',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          ],
        ),
      ),
    );
  }
}

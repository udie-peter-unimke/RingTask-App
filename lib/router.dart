// lib/router.dart
import 'package:flutter/material.dart';
import 'package:ringtask/presentation/screens/home/home_screen.dart';
import 'package:ringtask/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:ringtask/presentation/screens/splash/splash_screen.dart';
import 'package:ringtask/presentation/screens/auth/login_screen.dart';
import 'package:ringtask/presentation/screens/auth/signup_screen.dart';
import 'package:ringtask/presentation/screens/voice_input/voice_input_screen.dart';
import 'package:ringtask/presentation/screens/loop/loop_screen.dart';
import 'package:ringtask/presentation/screens/settings/settings_screen.dart';
import 'package:ringtask/presentation/screens/fake_call/fake_call_screen.dart';
import 'package:ringtask/presentation/screens/tts/tts_notification_screen.dart';
import 'package:ringtask/utils/logger.dart';

class AppRouter {
  // Route names
  static const String splashRoute = '/splash';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String onboardingRoute = '/onboarding';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String homeRoute = '/home';
  static const String loopRoute = '/loop';
  static const String settingsRoute = '/settings';
  static const String fakeCallRoute = '/fake-call';
  static const String voiceRoute = '/voice';
  static const String ttsRoute = '/tts';

  /// Generate routes based on route name and arguments
  static Route<dynamic> generateRoute(RouteSettings settings) {
    AppLogger.info('Navigating to: ${settings.name}');

    try {
      switch (settings.name) {
        case splashRoute:
          return _buildRoute(settings, const SplashScreen());

        case loginRoute:
          return _buildRoute(settings, const LoginScreen());

        case registerRoute:
          return _buildRoute(settings, const SignUpScreen());

        case onboardingRoute:
          return _buildRoute(settings, const OnboardingScreen());

        case forgotPasswordRoute:
          return _buildErrorRoute(settings); // TODO: Implement ForgotPasswordScreen

        case homeRoute:
          return _buildRoute(settings, const TaskHomeScreen());

        case loopRoute:
          return _buildRoute(settings, const TaskLoopScreen());

        case settingsRoute:
          return _buildRoute(settings, const SettingsScreen());

        case fakeCallRoute:
          final args = settings.arguments as Map<String, dynamic>?;
          return _buildRoute(
            settings,
            FakeCallScreen(data: args ?? {}),
          );

        case voiceRoute:
          return _buildRoute(settings, const VoiceInputScreen());

        case ttsRoute:
          final args = settings.arguments as Map<String, dynamic>?;
          final isOverlay = args?['isFullScreenOverlay'] ?? false;
          return _buildRoute(
            settings,
            TtsNotificationScreen(
              currentTask: args ?? {},
              isFullScreenOverlay: isOverlay,
            ),
          );

        default:
          AppLogger.warning('Unknown route: ${settings.name}');
          return _buildRoute(settings, const TaskHomeScreen());
      }
    } catch (e) {
      AppLogger.error('Error generating route: $e');
      return _buildErrorRoute(settings);
    }
  }

  /// Build a material page route with transitions
  static MaterialPageRoute<dynamic> _buildRoute(
      RouteSettings settings,
      Widget page, {
        bool fullscreenDialog = false,
      }) {
    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// Build error route
  static MaterialPageRoute<dynamic> _buildErrorRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Route not found: ${settings.name}'),
        ),
      ),
      settings: settings,
    );
  }

  /// Navigate to a route with replacement
  static Future<T?> navigateTo<T>(
      BuildContext context,
      String routeName, {
        Object? arguments,
      }) {
    return Navigator.pushNamed<T>(
      context,
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate to a route and remove all previous routes
  static Future<T?> navigateToAndClearStack<T>(
      BuildContext context,
      String routeName, {
        Object? arguments,
      }) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      routeName,
          (route) => false,
      arguments: arguments,
    );
  }

  /// Navigate and replace current route
  static Future<T?> navigateToReplacement<T extends Object?, TO extends Object?>(
      BuildContext context,
      String routeName, {
        TO? result,
        Object? arguments,
      }) async {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  /// Pop current route
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.pop<T>(context, result);
  }

  /// Check if can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}

/// Main app widget that handles routing
class AppNavigationWrapper extends StatelessWidget {
  const AppNavigationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const TaskHomeScreen();
  }
}

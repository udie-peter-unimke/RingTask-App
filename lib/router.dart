// lib/router.dart
import 'package:flutter/material.dart';
import 'package:ringtask/presentation/screens/auth/login_screen.dart';
import 'package:ringtask/presentation/screens/auth/signup_screen.dart';
import 'package:ringtask/presentation/screens/home/home_screen.dart';
import 'package:ringtask/presentation/screens/voice_input/voice_input_screen.dart';
import 'package:ringtask/presentation/screens/fake_call/fake_call_screen.dart';
import 'package:ringtask/presentation/screens/tts/tts_notification_screen.dart';
import 'package:ringtask/presentation/screens/settings/settings_screen.dart';

class AppRouter {
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String homeRoute = '/home';
  static const String voiceRoute = '/voice';
  static const String fakeCallRoute = '/fake_call';
  static const String ttsRoute = '/tts';
  static const String settingsRoute = '/settings';

  // ✅ FIXED: renamed `settings` → `routeSettings` to avoid shadowing RouteSettings type
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case loginRoute:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signupRoute:
        return MaterialPageRoute(builder: (_) => const SignUpScreen());
      case homeRoute:
        return MaterialPageRoute(builder: (_) => const TaskHomeScreen());
      case voiceRoute:
        return MaterialPageRoute(builder: (_) => const VoiceInputScreen());
      case fakeCallRoute:
      // ✅ FakeCallScreen reads arguments itself via ModalRoute.of(context)?.settings.arguments
      // in didChangeDependencies() — no constructor params needed here.
        return MaterialPageRoute(builder: (_) => const FakeCallScreen());
      case ttsRoute:
        return MaterialPageRoute(builder: (_) => const TtsNotificationScreen());
      case settingsRoute:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
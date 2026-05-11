// lib/core/constants/app_assets.dart
// RingTask App Assets - Centralized asset paths

class AppAssets {
  // Prevent instantiation
  AppAssets._();

  // =====================================================
  // IMAGES
  // =====================================================
  static const String logo = 'assets/images/logo.png';
  static const String splashBackground = 'assets/images/splash_bg.jpg';

  static const String onboarding1 = 'assets/images/onboarding_1.png';
  static const String onboarding2 = 'assets/images/onboarding_2.png';
  static const String onboarding3 = 'assets/images/onboarding_3.png';

  // Task-related images
  static const String taskCompleted = 'assets/images/task_completed.png';
  static const String urgentTask = 'assets/images/urgent_task.png';
  static const String emptyTasks = 'assets/images/empty_tasks.png';

  // =====================================================
  // ICONS
  // =====================================================
  static const String icHome = 'assets/icons/home.png';
  static const String icVoice = 'assets/icons/voice_input.png';
  static const String icCall = 'assets/icons/fake_call.png';
  static const String icSettings = 'assets/icons/settings.png';
  static const String icNotification = 'assets/icons/notification.png';
  static const String icCalendar = 'assets/icons/calendar.png';

  // =====================================================
  // SOUNDS
  // =====================================================
  static const String ringtone = 'assets/sounds/ringtone.mp3';
  static const String callEnd = 'assets/sounds/call_end.mp3';
  static const String reminderBeep = 'assets/sounds/reminder_beep.mp3';

  // =====================================================
  // FONTS
  // =====================================================
  static const String fontPrimary = 'Poppins';
  static const String fontSecondary = 'Roboto';

  // =====================================================
  // COLORS (Brand)
  // =====================================================
  static const int primaryColor = 0xFF2196F3;      // Blue 500
  static const int primaryVariant = 0xFF1976D2;    // Blue 700
  static const int urgentColor = 0xFFF44336;       // Red 500
  static const int successColor = 0xFF4CAF50;      // Green 500
  static const int backgroundColor = 0xFFF8F9FA;   // Grey 50
}

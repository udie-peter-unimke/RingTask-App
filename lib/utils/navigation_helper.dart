// Navigation helper for the RingTask app
// Provides centralized navigation logic and route constants

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationHelper {
  // Private constructor to prevent instantiation
  NavigationHelper._();

  // ---------------------------------------------------------------------------
  // 📍 ROUTE NAMES (constants for type-safe navigation)
  // ---------------------------------------------------------------------------

  // Auth routes
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Main app routes
  static const String home = '/';
  static const String createTask = '/create-task';
  static const String editTask = '/edit-task';
  static const String taskDetails = '/task-details';

  // Voice routes
  static const String voiceInput = '/voice-input';

  // Fake call routes
  static const String fakeCall = '/fake-call';
  static const String incomingCall = '/incoming-call';

  // Settings routes
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String notifications = '/settings/notifications';
  static const String appearance = '/settings/appearance';
  static const String about = '/settings/about';

  // ---------------------------------------------------------------------------
  // 🧭 BASIC NAVIGATION METHODS
  // ---------------------------------------------------------------------------

  /// Navigate to a route by path
  static void navigateTo(BuildContext context, String path,
      {Object? extra, Map<String, String>? queryParams}) {
    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri(path: path, queryParameters: queryParams);
      context.go(uri.toString(), extra: extra);
    } else {
      context.go(path, extra: extra);
    }
  }

  /// Push a new route (keeps current route in stack)
  static void pushTo(BuildContext context, String path,
      {Object? extra, Map<String, String>? queryParams}) {
    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri(path: path, queryParameters: queryParams);
      context.push(uri.toString(), extra: extra);
    } else {
      context.push(path, extra: extra);
    }
  }

  /// Navigate back to previous route
  static void goBack(BuildContext context, {Object? result}) {
    if (context.canPop()) {
      context.pop(result);
    }
  }

  /// Check if can go back
  static bool canGoBack(BuildContext context) {
    return context.canPop();
  }

  /// Replace current route with new route
  static void replace(BuildContext context, String path,
      {Object? extra, Map<String, String>? queryParams}) {
    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri(path: path, queryParameters: queryParams);
      context.pushReplacement(uri.toString(), extra: extra);
    } else {
      context.pushReplacement(path, extra: extra);
    }
  }

  // ---------------------------------------------------------------------------
  // 🏠 SCREEN-SPECIFIC NAVIGATION
  // ---------------------------------------------------------------------------

  // Auth Navigation
  static void goToLogin(BuildContext context) {
    context.go(login);
  }

  static void goToSignup(BuildContext context) {
    context.go(signup);
  }

  static void goToForgotPassword(BuildContext context) {
    context.push(forgotPassword);
  }

  // Home Navigation
  static void goToHome(BuildContext context) {
    context.go(home);
  }

  // Task Navigation
  static void goToCreateTask(BuildContext context) {
    context.push(createTask);
  }

  static void goToEditTask(BuildContext context, String taskId) {
    context.push('$editTask/$taskId');
  }

  static void goToTaskDetails(BuildContext context, String taskId) {
    context.push('$taskDetails/$taskId');
  }

  // Voice Navigation
  static void goToVoiceInput(BuildContext context) {
    context.push(voiceInput);
  }

  // Fake Call Navigation
  static void goToFakeCall(BuildContext context, {required String taskId}) {
    context.push(fakeCall, extra: {'taskId': taskId});
  }

  static void goToIncomingCall(BuildContext context,
      {required String taskId, required String taskTitle}) {
    context.push(
      incomingCall,
      extra: {
        'taskId': taskId,
        'taskTitle': taskTitle,
      },
    );
  }

  // Settings Navigation
  static void goToSettings(BuildContext context) {
    context.push(settings);
  }

  static void goToProfile(BuildContext context) {
    context.push(profile);
  }

  static void goToNotificationSettings(BuildContext context) {
    context.push(notifications);
  }

  static void goToAppearanceSettings(BuildContext context) {
    context.push(appearance);
  }

  static void goToAbout(BuildContext context) {
    context.push(about);
  }

  // ---------------------------------------------------------------------------
  // 🚪 MODAL & DIALOG HELPERS
  // ---------------------------------------------------------------------------

  /// Show bottom sheet
  static Future<T?> showBottomSheet<T>(
      BuildContext context, {
        required Widget child,
        bool isDismissible = true,
        bool enableDrag = true,
        Color? backgroundColor,
      }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => child,
    );
  }

  /// Show dialog
  static Future<T?> showDialogModal<T>(
      BuildContext context, {
        required Widget child,
        bool barrierDismissible = true,
      }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => child,
    );
  }

  /// Show confirmation dialog
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
        bool isDangerous = false,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDangerous
                ? TextButton.styleFrom(
              foregroundColor: Colors.red,
            )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show delete confirmation dialog
  static Future<bool?> showDeleteConfirmation(
      BuildContext context, {
        required String itemName,
        String? customMessage,
      }) {
    return showConfirmationDialog(
      context,
      title: 'Delete $itemName?',
      message: customMessage ??
          'Are you sure you want to delete this $itemName? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 3),
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 4),
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info snackbar
  static void showInfoSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 3),
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show warning snackbar
  static void showWarningSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 3),
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show custom snackbar
  static void showSnackBar(
      BuildContext context, {
        required Widget content,
        Color? backgroundColor,
        Duration duration = const Duration(seconds: 3),
        SnackBarAction? action,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔄 NAVIGATION GUARDS & VALIDATORS
  // ---------------------------------------------------------------------------

  /// Check if user is authenticated before navigation
  static void navigateIfAuthenticated(
      BuildContext context,
      String path, {
        required bool isAuthenticated,
        String? redirectPath,
      }) {
    if (isAuthenticated) {
      context.go(path);
    } else {
      context.go(redirectPath ?? login);
    }
  }

  /// Navigate and clear all previous routes (useful for logout)
  static void navigateAndClearStack(BuildContext context, String path) {
    // In go_router, use go() which replaces the entire stack
    context.go(path);
  }

  /// Navigate to home and clear stack
  static void goToHomeAndClear(BuildContext context) {
    navigateAndClearStack(context, home);
  }

  /// Navigate to login and clear stack
  static void goToLoginAndClear(BuildContext context) {
    navigateAndClearStack(context, login);
  }

  // ---------------------------------------------------------------------------
  // 📱 FULLSCREEN NAVIGATION (for fake call)
  // ---------------------------------------------------------------------------

  /// Push fullscreen route (useful for fake call screen)
  static Future<T?> pushFullscreenRoute<T>(
      BuildContext context, {
        required Widget screen,
        bool barrierDismissible = false,
      }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (context) => screen,
        fullscreenDialog: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔔 DEEP LINK HANDLERS
  // ---------------------------------------------------------------------------

  /// Handle deep link navigation for notifications
  static void handleNotificationTap(
      BuildContext context, {
        required String taskId,
      }) {
    goToTaskDetails(context, taskId);
  }

  /// Handle incoming call notification tap
  static void handleIncomingCallNotification(
      BuildContext context, {
        required String taskId,
        required String taskTitle,
      }) {
    goToIncomingCall(context, taskId: taskId, taskTitle: taskTitle);
  }

  // ---------------------------------------------------------------------------
  // 🎯 UTILITY METHODS
  // ---------------------------------------------------------------------------

  /// Get current route path
  static String? getCurrentRoute(BuildContext context) {
    return GoRouterState.of(context).uri.toString();
  }

  /// Get route parameters
  static Map<String, String> getRouteParams(BuildContext context) {
    return GoRouterState.of(context).pathParameters;
  }

  /// Get query parameters
  static Map<String, String> getQueryParams(BuildContext context) {
    return GoRouterState.of(context).uri.queryParameters;
  }

  /// Check if on specific route
  static bool isOnRoute(BuildContext context, String routePath) {
    final currentPath = getCurrentRoute(context);
    return currentPath == routePath;
  }

  /// Dismiss all snackbars
  static void dismissAllSnackBars(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Dismiss keyboard
  static void dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // ---------------------------------------------------------------------------
  // 🚀 ADVANCED NAVIGATION
  // ---------------------------------------------------------------------------

  /// Navigate with slide transition
  static Future<T?> pushWithSlideTransition<T>(
      BuildContext context, {
        required Widget screen,
        SlideDirection direction = SlideDirection.left,
      }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final begin = _getSlideOffset(direction);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          final tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  /// Navigate with fade transition
  static Future<T?> pushWithFadeTransition<T>(
      BuildContext context, {
        required Widget screen,
      }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Helper method to get slide offset based on direction
  static Offset _getSlideOffset(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.left:
        return const Offset(1.0, 0.0);
      case SlideDirection.right:
        return const Offset(-1.0, 0.0);
      case SlideDirection.up:
        return const Offset(0.0, 1.0);
      case SlideDirection.down:
        return const Offset(0.0, -1.0);
    }
  }
}

// ---------------------------------------------------------------------------
// 📐 ENUMS
// ---------------------------------------------------------------------------

/// Slide direction for custom transitions
enum SlideDirection {
  left,
  right,
  up,
  down,
}
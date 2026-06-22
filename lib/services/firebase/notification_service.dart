import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:ringtask/utils/logger.dart';

import 'package:ringtask/data/models/loop_model.dart';

abstract class INotificationService {
  Future<void> initialize();
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  });
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  });
  Future<void> cancelNotification(int id);
  Future<void> cancelAllNotifications();
  Future<List<PendingNotificationRequest>> getPendingNotifications();
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> setNotificationClickHandler(
      Function(String?) onSelectNotification,
      );
}

class NotificationService implements INotificationService {
  static const String channelId = 'ringtask_channel';
  static const String channelName = 'RingTask Notifications';
  static const String channelDescription =
      'Notifications for RingTask reminders and task updates';

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Function(String?)? _onSelectNotification;
  bool _isInitialized = false;

  NotificationService();

  @override
  Future<void> initialize() async {
    try {
      AppLogger.info('Initializing NotificationService');

      const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');

      const InitializationSettings initializationSettings =
      InitializationSettings(
        android: androidInitSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      await _createAndroidNotificationChannel();
      _isInitialized = true;

      AppLogger.info('NotificationService initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  Future<void> _createAndroidNotificationChannel() async {
    try {
      AppLogger.debug('Creating Android notification channel');

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        showBadge: true,
      );

      // ✅ Correctly resolve the platform-specific implementation
      final androidImpl = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(channel);
      }

      AppLogger.debug('Android notification channel created');
    } catch (e) {
      AppLogger.error('Error creating notification channel: $e');
    }
  } // ← Added missing closing brace for the method body

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        AppLogger.warning(
            'NotificationService not initialized → initializing now');
        await initialize();
      }

      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await showInstantNotification(
        id: id,
        title: title,
        body: body,
        payload: payload ?? 'task_reminder',
      );

      AppLogger.info('Simple notification shown: $title');
    } catch (e) {
      AppLogger.error('Simple notification failed: $e');
    }
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      AppLogger.info(
          'Scheduling notification: "$title" at ${scheduledTime.toIso8601String()}');

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF2196F3),
      );

      const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      AppLogger.info('Notification scheduled successfully');
    } catch (e) {
      AppLogger.error('Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Show notification for loop task
  Future<void> showLoopTaskNotification(TaskLoopItem task) async {
    await showInstantNotification(
      id: task.id.hashCode,
      title: 'Loop Task: ${task.title}',
      body: 'Scheduled for ${task.timeString} ${task.period}',
      payload: task.id,
    );
  }

  /// Show notification for loop task completion
  Future<void> showLoopTaskCompletionNotification(String taskTitle) async {
    final id = DateTime.now().millisecond;
    await showInstantNotification(
      id: id,
      title: 'Task Completed',
      body: '$taskTitle marked as done',
    );
  }


  @override
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      AppLogger.info('Showing instant notification: $title');

      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF2196F3),
      );

      const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

      await _flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );

      AppLogger.info('Instant notification shown successfully');
    } catch (e) {
      AppLogger.error('Error showing instant notification: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      AppLogger.info('Cancelling notification with ID: $id');
      await _flutterLocalNotificationsPlugin.cancel(id: id);
      AppLogger.info('Notification cancelled successfully');
    } catch (e) {
      AppLogger.error('Error cancelling notification: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      AppLogger.info('Cancelling all notifications');
      await _flutterLocalNotificationsPlugin.cancelAll();
      AppLogger.info('All notifications cancelled successfully');
    } catch (e) {
      AppLogger.error('Error cancelling all notifications: $e');
      rethrow;
    }
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      AppLogger.info('Fetching pending notifications');
      final pending = await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      AppLogger.info('Retrieved ${pending.length} pending notifications');
      return pending;
    } catch (e) {
      AppLogger.error('Error fetching pending notifications: $e');
      return [];
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    AppLogger.debug('Notification tapped – payload: ${response.payload}');
    _onSelectNotification?.call(response.payload);
  }

  @override
  Future<void> setNotificationClickHandler(
      Function(String?) onSelectNotification,
      ) async {
    try {
      AppLogger.info('Setting notification click handler');
      _onSelectNotification = onSelectNotification;
      AppLogger.info('Notification click handler set successfully');
    } catch (e) {
      AppLogger.error('Error setting notification click handler: $e');
      rethrow;
    }
  }

  Future<bool> requestNotificationPermissions() async {
    try {
      AppLogger.info('Requesting notification permissions (Android 13+)');

      // ✅ Fixed: Removed split-line syntax errors and isolated generic call layout
      final androidImpl = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl == null) {
        AppLogger.warning('Android implementation not available');
        return false;
      }

      final bool? granted = await androidImpl.requestNotificationsPermission();
      AppLogger.info('Notification permissions granted: $granted');
      return granted == true;
    } catch (e) {
      AppLogger.error('Error requesting notification permissions: $e');
      return false;
    }
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      AppLogger.info('Scheduling daily notification at $hour:$minute');

      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      AppLogger.info('Daily notification scheduled successfully');
    } catch (e) {
      AppLogger.error('Error scheduling daily notification: $e');
      rethrow;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  bool get isInitialized => _isInitialized;

  Future<void> dispose() async {
    try {
      AppLogger.info('Disposing NotificationService');
      await cancelAllNotifications();
      AppLogger.info('NotificationService disposed successfully');
    } catch (e) {
      AppLogger.error('Error disposing NotificationService: $e');
    }
  }
}
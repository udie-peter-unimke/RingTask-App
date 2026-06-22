// lib/services/firebase/fake_call_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/app.dart';
import 'package:ringtask/services/scheduler/alarm_scheduler.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/utils/ringtone_file_helper.dart';
import 'package:ringtask/router.dart';
import 'package:ringtask/data/models/loop_model.dart';

class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;

  FakeCallService._internal()
      : _notifications = FlutterLocalNotificationsPlugin(),
        _tts = FlutterTts();

  final FlutterLocalNotificationsPlugin _notifications;
  final FlutterTts _tts;

  static const _workChannel = MethodChannel('ringtask/workmanager');

  bool _isTtsInitialized = false;
  bool _isInitialized = false;

  // ---------------------------------------------------------------------------
  // Time parsing
  // ---------------------------------------------------------------------------

  /// Safely parses a 12-hour [timeString] in 'H:mm' or 'HH:mm' format.
  ///
  /// Returns a `(hour, minute)` record on success, or `null` if the value is
  /// null, empty, missing the colon separator, non-numeric, or out of range.
  ///
  /// This is the single fix point for:
  ///   RangeError (length): Invalid value: Only valid value is 0: 1
  /// which fires when [timeString] contains no ':' — split(':') then returns a
  /// 1-element list and accessing index [1] throws.
  ///
  /// [taskId] is used purely for log context; it does not affect the result.
  ({int hour, int minute})? _parseTimeString(
      String? timeString,
      String taskId,
      ) {
    if (timeString == null || timeString.isEmpty) {
      AppLogger.error(
        '[FakeCallService] Null/empty timeString for task $taskId — skipping',
      );
      return null;
    }

    final parts = timeString.split(':');

    if (parts.length < 2) {
      // Root cause of the reported RangeError: a stored value with no ':'
      // (e.g. '', '1200', 'null') produces a 1-element list. Index [1]
      // is invalid and Dart throws: "Only valid value is 0: 1".
      AppLogger.error(
        '[FakeCallService] Malformed timeString="$timeString" for task $taskId '
            '— no colon separator found. RangeError prevented.',
      );
      return null;
    }

    // Use tryParse, not parse — a non-numeric segment throws FormatException.
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());

    if (hour == null || minute == null) {
      AppLogger.error(
        '[FakeCallService] Non-numeric timeString="$timeString" for task $taskId '
            '— hour=${parts[0]}, minute=${parts[1]}',
      );
      return null;
    }

    // 12-hour clock: hour 1–12, minute 0–59.
    // Hour 0 is not a valid 12-hour value but we allow it defensively
    // in case a 24-hour string slips through; the AM/PM conversion below
    // handles it correctly for midnight (12 AM → 0).
    if (hour < 0 || hour > 12 || minute < 0 || minute > 59) {
      AppLogger.error(
        '[FakeCallService] Out-of-range timeString="$timeString" for task $taskId '
            '— hour=$hour (expected 0–12), minute=$minute (expected 0–59)',
      );
      return null;
    }

    return (hour: hour, minute: minute);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('FakeCallService initialize() skipped — already running');
      return;
    }

    _isInitialized = true;
    final stopwatch = Stopwatch()..start();

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) _navigateToCallScreen(payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'fake_call_channel_v2', // ✅ SYNC: Match Native CHANNEL_ID
      'Fake Incoming Call',
      description: 'Simulated incoming call for task reminder',
      importance: Importance.max,
      playSound: true, // ✅ Match native fix
      enableVibration: true,
    );

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(channel);
    await _initializeTts();

    _workChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFakeCallAnswered':
          AppLogger.info('Native signaled fake call answered, navigating to /tts');
          Map<String, dynamic>? data;

          if (call.arguments is String) {
            data = jsonDecode(call.arguments as String) as Map<String, dynamic>;
          } else if (call.arguments is Map) {
            data = Map<String, dynamic>.from(call.arguments as Map);
          }

          if (data == null) {
            AppLogger.error(
              'onFakeCallAnswered: null/invalid arguments: ${call.arguments}',
            );
            break;
          }

          final navigator = navigatorKey.currentState;
          if (navigator == null) {
            AppLogger.error('onFakeCallAnswered: navigatorKey not ready');
            break;
          }

          // Navigate directly to TTS screen with a small retry loop.
          // During cold starts, the message from native may arrive before
          // the MaterialApp/Navigator is fully mounted.
          _safeNavigateToTts(data);
          AppLogger.info('onFakeCallAnswered: triggered safe navigation');
          break;

        default:
          AppLogger.warning('FakeCallService: unknown native method: ${call.method}');
      }
    });

    // ✅ Notify Kotlin that Flutter is ready — drains any payload cached
    // during cold start (alarm fired before Flutter engine was running).
    // Must be called AFTER setMethodCallHandler so navigateToFakeCall
    // is already registered when Kotlin responds.
    try {
      await _workChannel.invokeMethod('flutterReady');
      AppLogger.info('flutterReady sent to native');
    } catch (e) {
      AppLogger.error('flutterReady invoke failed: $e');
    }

    AppLogger.info('FakeCallService initialized in ${stopwatch.elapsedMilliseconds}ms');
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<void> requestNotificationAndAlarmPermissions() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        // 1. Notification Permission
        await androidImpl.requestNotificationsPermission();
        await Future.delayed(const Duration(milliseconds: 300));

        // 2. Exact Alarms Permission
        await androidImpl.requestExactAlarmsPermission();
      }
    } catch (e) {
      AppLogger.error('Error requesting notification and alarm permissions: $e');
    }
  }

  Future<void> requestSystemAlertWindowPermission() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        // System Alert Window (Display over other apps)
        // This is CRITICAL for the fake call to show over other apps/lockscreen
        final status = await Permission.systemAlertWindow.status;
        if (!status.isGranted) {
          AppLogger.info('Requesting System Alert Window permission...');
          await Permission.systemAlertWindow.request();
        } else {
          AppLogger.info('System Alert Window permission already granted');
        }
      }
    } catch (e) {
      AppLogger.error('Error requesting System Alert Window permission: $e');
    }
  }

  @Deprecated('Use granular request methods instead')
  Future<void> requestPermissions() async {
    await requestNotificationAndAlarmPermissions();
    await Future.delayed(const Duration(milliseconds: 300));
    await requestSystemAlertWindowPermission();
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _navigateToCallScreen(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      // ✅ Trigger native Kotlin activity instead of Flutter route
      showFakeCall(data);
    } catch (e) {
      AppLogger.error('Error navigating to call screen: $e');
    }
  }

  Future<void> _safeNavigateToTts(Map<String, dynamic> data) async {
    // Ensure the TTS screen starts in overlay mode when answered from native
    final Map<String, dynamic> navData = Map.from(data);
    navData['isFullScreenOverlay'] = true;

    int attempts = 0;
    while (attempts < 10) {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamed(AppRouter.ttsRoute, arguments: navData);
        AppLogger.info('Safe navigation successful on attempt $attempts');
        return;
      }
      AppLogger.warning('Navigator not ready (attempt $attempts), retrying...');
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }
    AppLogger.error('Safe navigation failed after $attempts attempts');
  }

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isTtsInitialized = true;
      AppLogger.info('TTS initialized');
    } catch (e) {
      AppLogger.error('TTS initialization failed: $e');
      _isTtsInitialized = false;
    }
  }

  Future<void> speakText(String text) async {
    if (!_isTtsInitialized) await _initializeTts();
    if (_isTtsInitialized) {
      try {
        await _tts.speak(text);
      } catch (e) {
        AppLogger.error('TTS speak failed: $e');
      }
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      AppLogger.error('Error stopping TTS: $e');
    }
  }

  Future<void> setTtsLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      AppLogger.error('TTS Lang Error: $e');
    }
  }

  Future<void> setTtsSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      AppLogger.error('TTS Rate Error: $e');
    }
  }

  Future<void> setTtsVolume(double volume) async {
    try {
      await _tts.setVolume(volume);
    } catch (e) {
      AppLogger.error('TTS Volume Error: $e');
    }
  }

  Future<void> setTtsPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      AppLogger.error('TTS Pitch Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling — single task
  // ---------------------------------------------------------------------------

  /// Schedule a fake call for a single task
  Future<void> scheduleFakeCall({
    required String taskId,
    required String title,
    required String description,
    required DateTime scheduledTime,
    String callerName = 'Task Reminder',
    String? ringtonePath,
    RecurrenceType? recurrence,
  }) async {
    // ✅ Resolve content:// URI to an absolute path NOW, while we have
    // permission. Background contexts cannot read content:// URIs.
    final resolvedRingtonePath =
    await RingtoneFileHelper.resolveToAbsolutePath(ringtonePath);
    AppLogger.info(
      'Resolved ringtonePath: $ringtonePath → $resolvedRingtonePath',
    );

    final delay = scheduledTime.difference(DateTime.now());

    if (delay.isNegative || delay.inSeconds < 1) {
      final payload = jsonEncode({
        'taskId': taskId,
        'title': title,
        'description': description,
        'scheduledTime': scheduledTime.toIso8601String(),
        'callerName': callerName,
        'ringtonePath': resolvedRingtonePath,
        'recurrence': recurrence != null ? recurrenceToString(recurrence) : null,
      });
      _navigateToCallScreen(payload);
      return;
    }

    await getIt<AlarmScheduler>().scheduleCall(
      taskId: taskId,
      taskTitle: title,
      taskDescription: description,
      scheduledTime: scheduledTime,
      callerName: callerName,
      ringtonePath: resolvedRingtonePath,
      recurrence: recurrence,
    );

    AppLogger.info('Fake call scheduled: $title in ${delay.inMinutes}min');
  }

  // ---------------------------------------------------------------------------
  // Scheduling — loop tasks
  // ---------------------------------------------------------------------------

  /// Reschedule all active loop tasks on app resume or after permission grant.
  Future<void> rescheduleLoopTasks(List<TaskLoopItem> tasks) async {
    try {
      final activeTasks = tasks.where((t) => t.isActive).toList();

      if (activeTasks.isEmpty) {
        AppLogger.info('No active loop tasks to reschedule');
        return;
      }

      AppLogger.info('Rescheduling ${activeTasks.length} active loop tasks');

      for (final task in activeTasks) {
        try {
          // ✅ FIX: use _parseTimeString instead of raw split/parse.
          //
          // Previously:
          //   final timeParts = task.timeString.split(':');
          //   int hour = int.parse(timeParts[0]);
          //   final minute = int.parse(timeParts[1]);   ← RangeError when no ':'
          //
          // If timeString has no ':' (e.g. '', '1200', or a value that came
          // back from Firestore/cache in an unexpected format), split(':')
          // returns a 1-element list. Accessing index [1] throws:
          //   RangeError (length): Invalid value: Only valid value is 0: 1
          final parsed = _parseTimeString(task.timeString, task.id);
          if (parsed == null) {
            // _parseTimeString already logged the specific reason.
            AppLogger.error(
              '[FakeCallService] Skipping reschedule for task "${task.title}" '
                  '(id=${task.id}) — fix timeString="${task.timeString}" in Firestore/cache.',
            );
            continue;
          }

          // Convert 12-hour (hour, period) → 24-hour
          int hour = parsed.hour;
          final minute = parsed.minute;

          if (task.period == 'PM' && hour != 12) {
            hour += 12;
          } else if (task.period == 'AM' && hour == 12) {
            hour = 0;
          }

          final now = DateTime.now();
          var scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );

          // If time has passed today, schedule for tomorrow
          if (scheduledTime.isBefore(now)) {
            scheduledTime = scheduledTime.add(const Duration(days: 1));
          }

          // For recurring tasks, calculate next occurrence
          if (task.recurrence == RecurrenceType.weekly) {
            // Add 7 days for weekly tasks (simplified; could be optimized for specific days)
            scheduledTime = scheduledTime.add(const Duration(days: 7));
          } else if (task.recurrence == RecurrenceType.monthly) {
            // Add 30 days for monthly tasks (simplified)
            scheduledTime = scheduledTime.add(const Duration(days: 30));
          }

          await scheduleFakeCall(
            taskId: task.id,
            title: task.title,
            description:
            'Recurring ${task.recurrence.toString().split('.').last}: ${task.customDaysDisplay}',
            scheduledTime: scheduledTime,
            callerName: 'Loop Task',
            recurrence: task.recurrence,
          );

          AppLogger.info(
            'Rescheduled loop task: ${task.title} at ${task.timeString}',
          );
        } catch (e) {
          AppLogger.error('Error rescheduling individual loop task: $e');
        }
      }

      AppLogger.info('Loop tasks rescheduling completed');
    } catch (e) {
      AppLogger.error('Error rescheduling loop tasks: $e');
    }
  }

  /// Batch schedule multiple loop tasks at once.
  Future<void> batchScheduleLoopTasks(List<TaskLoopItem> tasks) async {
    try {
      AppLogger.info('Batch scheduling ${tasks.length} loop tasks');

      for (final task in tasks) {
        if (task.isActive) {
          try {
            // ✅ FIX: same _parseTimeString guard as rescheduleLoopTasks.
            //
            // Previously:
            //   final timeParts = task.timeString.split(':');
            //   int hour = int.parse(timeParts[0]);
            //   final minute = int.parse(timeParts[1]);   ← RangeError when no ':'
            final parsed = _parseTimeString(task.timeString, task.id);
            if (parsed == null) {
              AppLogger.error(
                '[FakeCallService] Skipping batch schedule for task "${task.title}" '
                    '(id=${task.id}) — fix timeString="${task.timeString}" in Firestore/cache.',
              );
              continue;
            }

            // Convert 12-hour (hour, period) → 24-hour
            int hour = parsed.hour;
            final minute = parsed.minute;

            if (task.period == 'PM' && hour != 12) {
              hour += 12;
            } else if (task.period == 'AM' && hour == 12) {
              hour = 0;
            }

            final now = DateTime.now();
            var scheduledTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );

            if (scheduledTime.isBefore(now)) {
              scheduledTime = scheduledTime.add(const Duration(days: 1));
            }

            await scheduleFakeCall(
              taskId: task.id,
              title: task.title,
              description:
              'Loop: ${task.recurrence.toString().split('.').last}',
              scheduledTime: scheduledTime,
              callerName: 'Loop Task Reminder',
              recurrence: task.recurrence,
            );
          } catch (e) {
            AppLogger.error('Error scheduling loop task ${task.id}: $e');
          }
        }
      }

      AppLogger.info('Batch scheduling completed for ${tasks.length} tasks');
    } catch (e) {
      AppLogger.error('Error in batch schedule loop tasks: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Native bridge
  // ---------------------------------------------------------------------------

  // Immediate call — trigger native Kotlin activity.
  Future<void> showFakeCall(Map<String, dynamic> data) async {
    try {
      final payload = jsonEncode(data);
      await _workChannel.invokeMethod('triggerFakeCall', {'payload': payload});
      AppLogger.info('showFakeCall: triggered native triggerFakeCall');
    } catch (e) {
      AppLogger.error('showFakeCall failed: $e');
    }
  }

  /// Cancel a specific task's scheduled call
  Future<void> cancelTask(String taskId) async {
    try {
      await _workChannel.invokeMethod('cancelFakeCall', {'tag': taskId});
      AppLogger.info('Cancelled fake call for task: $taskId');
    } catch (e) {
      AppLogger.error('Error cancelling task: $e');
    }
  }

  /// Cancel all scheduled calls and notifications
  Future<void> cancelAll() async {
    // ⚠️ Only cancels the default-tag alarm — task-specific alarms
    // must be cancelled individually via cancelTask(taskId)
    try {
      await _workChannel.invokeMethod('cancelFakeCall', {'tag': 'fakeCall'});
      await _notifications.cancelAll();
      AppLogger.info('All fake calls cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling all: $e');
    }
  }

  // stopCall is a no-op — FakeCallScreen owns its own audio lifecycle
  Future<void> stopCall() async {}

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isTtsInitialized => _isTtsInitialized;
  bool get isInitialized => _isInitialized;
}
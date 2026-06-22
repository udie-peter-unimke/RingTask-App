// lib/services/scheduler/alarm_scheduler.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ringtask/utils/logger.dart';

import 'package:ringtask/data/models/loop_model.dart';

class AlarmScheduler {
  static const _channel = MethodChannel('ringtask/workmanager');

  Future<void> initialize() async {
    // flutterReady is sent by FakeCallService.initialize() after the
    // method call handler is registered — do not call it here.
    AppLogger.info('AlarmScheduler initialized successfully');
  }

  Future<bool> scheduleCall({
    required String taskId,
    required String taskTitle,
    required String taskDescription,
    required DateTime scheduledTime,
    String callerName = 'RingTask Reminder',
    String? ringtonePath,
    RecurrenceType? recurrence,
  }) async {
    try {
      final delay = scheduledTime.difference(DateTime.now());
      if (delay.isNegative) {
        AppLogger.warning('Cannot schedule call in past: $scheduledTime');
        return false;
      }

      // Cancel any existing alarm for this task before rescheduling
      await _channel.invokeMethod('cancelFakeCall', {'tag': taskId});

      await _channel.invokeMethod('scheduleFakeCall', {
        'delayMillis': delay.inMilliseconds,
        'triggerAtMillis': scheduledTime.millisecondsSinceEpoch,
        'tag': taskId,
        'payload': jsonEncode({
          'taskId': taskId,
          'title': taskTitle,
          'description': taskDescription,
          'scheduledTime': scheduledTime.toIso8601String(),
          'callerName': callerName,
          'ringtonePath': ringtonePath,
          'recurrence': recurrence != null ? recurrenceToString(recurrence) : null,
        }),
      });

      AppLogger.info('Call scheduled: $taskTitle in ${delay.inMinutes}min');
      return true;
    } catch (e, s) {
      AppLogger.error('Schedule failed: $e', stackTrace: s);
      return false;
    }
  }

  Future<bool> cancelScheduledCall(String taskId) async {
    try {
      await _channel.invokeMethod('cancelFakeCall', {'tag': taskId});
      AppLogger.info('Cancelled call: $taskId');
      return true;
    } catch (e, s) {
      AppLogger.error('Cancel failed: $e', stackTrace: s);
      return false;
    }
  }

  Future<void> cancelAllFakeCalls() async {
    // ⚠️ Only cancels the default-tag alarm — task-specific alarms
    // must be cancelled individually via cancelScheduledCall(taskId)
    try {
      await _channel.invokeMethod('cancelFakeCall', {'tag': 'fakeCall'});
      AppLogger.info('All scheduled calls cleared');
    } catch (e, s) {
      AppLogger.error('Cancel all failed: $e', stackTrace: s);
    }
  }

  Future<bool> rescheduleCall({
    required String taskId,
    required String taskTitle,
    required String taskDescription,
    required DateTime newScheduledTime,
    String callerName = 'RingTask Reminder',
    String? ringtonePath,
  }) async {
    await cancelScheduledCall(taskId);
    return scheduleCall(
      taskId: taskId,
      taskTitle: taskTitle,
      taskDescription: taskDescription,
      scheduledTime: newScheduledTime,
      callerName: callerName,
      ringtonePath: ringtonePath,
    );
  }
}
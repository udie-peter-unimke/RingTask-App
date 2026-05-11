// lib/services/scheduler/alarm_scheduler.dart
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:ringtask/utils/logger.dart';

class AlarmScheduler {
  static const _channel = MethodChannel('ringtask/workmanager');

  static Future<void> initialize() async {
    // ✅ No setMethodCallHandler here — FakeCallService.initialize() already
    // owns the handler for 'navigateToFakeCall' on this channel. Setting a
    // second handler here would silently overwrite it and break navigation.

    // ✅ Tell Android the Flutter side is live. MainActivity flushes any
    // payload cached during a cold start via the flutterReady handler,
    // which then invokes 'navigateToFakeCall' → FakeCallService.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _channel.invokeMethod<void>('flutterReady').catchError((e) {
        AppLogger.warning('flutterReady invoke failed: $e');
      });
    });

    AppLogger.info('✅ AlarmScheduler initialized successfully');
  }

  Future<bool> scheduleCall({
    required String taskId,
    required String taskTitle,
    required String taskDescription,
    required DateTime scheduledTime,
    String callerName = 'RingTask Reminder',
  }) async {
    try {
      final delay = scheduledTime.difference(DateTime.now());
      if (delay.isNegative) {
        AppLogger.warning('⚠️ Cannot schedule call in past: $scheduledTime');
        return false;
      }

      // Cancel only this specific task before rescheduling
      await _channel.invokeMethod('cancelFakeCall', {'tag': taskId});

      await _channel.invokeMethod('scheduleFakeCall', {
        'delayMillis': delay.inMilliseconds,
        'tag': taskId,
        'payload': jsonEncode({
          'taskId': taskId,
          'title': taskTitle,
          'description': taskDescription,
          'callerName': callerName,
        }),
      });

      AppLogger.info('✅ Call scheduled: $taskTitle in ${delay.inMinutes}min');
      return true;
    } catch (e, s) {
      AppLogger.error('❌ Schedule failed: $e', stackTrace: s);
      return false;
    }
  }

  Future<bool> cancelScheduledCall(String taskId) async {
    try {
      await _channel.invokeMethod('cancelFakeCall', {'tag': taskId});
      AppLogger.info('🗑️ Cancelled call: $taskId');
      return true;
    } catch (e, s) {
      AppLogger.error('❌ Cancel failed: $e', stackTrace: s);
      return false;
    }
  }

  Future<void> cancelAllFakeCalls() async {
    try {
      await _channel.invokeMethod('cancelFakeCall', {'tag': 'fakeCall'});
      AppLogger.info('🗑️ All scheduled calls cleared');
    } catch (e, s) {
      AppLogger.error('❌ Cancel all failed: $e', stackTrace: s);
    }
  }

  Future<bool> rescheduleCall({
    required String taskId,
    required String taskTitle,
    required String taskDescription,
    required DateTime newScheduledTime,
    String callerName = 'RingTask Reminder',
  }) async {
    await cancelScheduledCall(taskId);
    return scheduleCall(
      taskId: taskId,
      taskTitle: taskTitle,
      taskDescription: taskDescription,
      scheduledTime: newScheduledTime,
      callerName: callerName,
    );
  }
}
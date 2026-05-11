// lib/repositories/fake_call_repository.dart
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';
import 'package:ringtask/utils/logger.dart';
// ✅ REMOVED: import 'package:workmanager/workmanager.dart';

class FakeCallRepository {
  final FakeCallService _service;

  FakeCallRepository({FakeCallService? service})
      : _service = service ?? getIt<FakeCallService>();

  Future<bool> initiateFakeCall(TaskModel task) async {
    try {
      AppLogger.info('Initiating fake call for: ${task.title}');

      final payload = {
        'title': task.title,
        'description': task.description,
        'callerName': 'Ringtask Reminder',
        'ringtonePath': 'assets/sounds/ringtone.mp3',
      };

      await _service.showFakeCall(payload);
      await Future.delayed(const Duration(milliseconds: 1500));
      await _service.speakText(_formatTaskForSpeech(task));

      return true;
    } catch (e, s) {
      AppLogger.error('initiateFakeCall failed: $e\n$s');
      return false;
    }
  }

  Future<bool> endFakeCall() async {
    try {
      await _service.stopCall();
      return true;
    } catch (e) {
      AppLogger.error('endFakeCall failed: $e');
      return false;
    }
  }

  Future<bool> readTaskDetails(TaskModel task) async {
    try {
      await _service.speakText(_formatTaskForSpeech(task));
      return true;
    } catch (e) {
      AppLogger.error('readTaskDetails failed: $e');
      return false;
    }
  }

  Future<bool> scheduleTaskReminder(TaskModel task) async {
    try {
      if (task.scheduledTime == null) {
        AppLogger.warning('No scheduledTime → cannot schedule');
        return false;
      }

      final scheduled = task.scheduledTime!;

      if (scheduled.isBefore(DateTime.now())) {
        return await initiateFakeCall(task);
      }

      await _service.scheduleFakeCall(
        taskId: task.id,
        title: task.title,
        description: task.description,
        scheduledTime: scheduled,
        callerName: 'RingTask',
      );

      AppLogger.info('Scheduled fake call at $scheduled');
      return true;
    } catch (e, s) {
      AppLogger.error('scheduleTaskReminder failed: $e\n$s');
      return false;
    }
  }

  Future<bool> cancelScheduledReminder(String taskId) async {
    try {
      // ✅ Delegate to FakeCallService which uses the MethodChannel
      await _service.cancelTask(taskId);
      return true;
    } catch (e) {
      AppLogger.error('cancel failed: $e');
      return false;
    }
  }

  Future<void> cancelAllReminders() async {
    await _service.cancelAll();
  }

  String _formatTaskForSpeech(TaskModel task) {
    final parts = <String>[
      'Hello! You have a task.',
      'Title: ${task.title}.',
    ];

    if (task.description.isNotEmpty) {
      parts.add('Description: ${task.description}.');
    }

    if (task.scheduledTime != null) {
      final d = task.scheduledTime!;
      final dateStr = '${d.day} ${_monthName(d.month)} ${d.year}';
      final timeStr =
      d.hour == 0 && d.minute == 0 ? '' : ' at ${_formatTime(d)}';
      parts.add('Due on $dateStr$timeStr.');
    }

    parts.add('Good luck!');
    return parts.join(' ');
  }

  String _monthName(int m) => [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m - 1];

  String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$min $period';
  }
}
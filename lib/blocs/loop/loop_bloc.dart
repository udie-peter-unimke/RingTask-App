// lib/blocs/loop/loop_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ringtask/repositories/settings_repository.dart';
import 'package:ringtask/repositories/loop_repository.dart';
import 'package:ringtask/services/entitlement/entitlement_service.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';
import 'package:ringtask/utils/logger.dart';
import 'loop_event.dart';
import 'package:ringtask/data/models/loop_model.dart';
import 'loop_state.dart';

class LoopBloc extends Bloc<LoopEvent, LoopState> {
  final LoopRepository _repository;
  final FakeCallService _fakeCallService;
  final EntitlementService _entitlementService;
  final SettingsRepository _settingsRepository;

  LoopBloc({
    required LoopRepository repository,
    required FakeCallService fakeCallService,
    required EntitlementService entitlementService,
    required SettingsRepository settingsRepository,
  })  : _repository = repository,
        _fakeCallService = fakeCallService,
        _entitlementService = entitlementService,
        _settingsRepository = settingsRepository,
        super(const LoopInitial()) {
    on<LoadLoopsEvent>(_onLoadLoops, transformer: restartable());
    on<ToggleTaskActiveEvent>(_onToggleTaskActive);
    on<DeleteTaskEvent>(_onDeleteTask);
    on<CreateTaskEvent>(_onCreateTask);
    on<UpdateTaskEvent>(_onUpdateTask);
    on<ClearAllTasksEvent>(_onClearAllTasks);
  }

  // ---------------------------------------------------------------------------
  // Time parsing
  // ---------------------------------------------------------------------------

  /// Safely parses a 12-hour [timeString] in 'H:mm' or 'HH:mm' format.
  ({int hour, int minute})? _parseTimeString(
      String? timeString,
      String taskId,
      ) {
    if (timeString == null || timeString.isEmpty) {
      AppLogger.error('[LoopBloc] Null/empty timeString for task $taskId');
      return null;
    }

    final parts = timeString.split(':');

    if (parts.length < 2) {
      AppLogger.error(
        '[LoopBloc] Malformed timeString="$timeString" for task $taskId '
            '— no colon separator found. RangeError prevented.',
      );
      return null;
    }

    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());

    if (hour == null || minute == null) {
      AppLogger.error(
        '[LoopBloc] Non-numeric timeString="$timeString" for task $taskId '
            '— hour=${parts[0]}, minute=${parts[1]}',
      );
      return null;
    }

    if (hour < 0 || hour > 12 || minute < 0 || minute > 59) {
      AppLogger.error(
        '[LoopBloc] Out-of-range timeString="$timeString" for task $taskId '
            '— hour=$hour (expected 0–12), minute=$minute (expected 0–59)',
      );
      return null;
    }

    return (hour: hour, minute: minute);
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  Future<void> _onLoadLoops(
      LoadLoopsEvent event,
      Emitter<LoopState> emit,
      ) async {
    emit(const LoopLoading());
    try {
      await for (final tasks in _repository.getTasksStream(event.userId)) {
        final activeTasks = tasks.where((t) => t.isActive).toList();
        for (final task in activeTasks) {
          await _scheduleTaskCall(task);
        }
        emit(LoopLoaded(tasks));
      }
    } catch (e) {
      emit(LoopError('Error loading tasks: $e'));
    }
  }

  Future<void> _onToggleTaskActive(
      ToggleTaskActiveEvent event,
      Emitter<LoopState> emit,
      ) async {
    final previousState = state;
    try {
      await _repository.toggleTaskActive(event.userId, event.task, event.value);

      if (event.value) {
        await _scheduleTaskCall(event.task);
      } else {
        await _fakeCallService.cancelTask(event.task.id);
      }

      if (previousState is LoopLoaded) {
        final updatedTasks = previousState.tasks.map((t) {
          return t.id == event.task.id ? t.copyWith(isActive: event.value) : t;
        }).toList();
        emit(LoopLoaded(
          updatedTasks,
          message: 'Task ${event.value ? "activated" : "deactivated"}',
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to toggle task: $e');
      emit(LoopError('Failed to toggle task: $e'));
      if (previousState is LoopLoaded) emit(previousState);
    }
  }

  Future<void> _onDeleteTask(
      DeleteTaskEvent event,
      Emitter<LoopState> emit,
      ) async {
    final previousState = state;
    try {
      await _fakeCallService.cancelTask(event.taskId);
      await _repository.deleteTask(event.userId, event.taskId);

      if (previousState is LoopLoaded) {
        final updatedTasks = previousState.tasks.where((t) => t.id != event.taskId).toList();
        emit(LoopLoaded(updatedTasks, message: 'Task deleted'));
      }
    } catch (e) {
      AppLogger.error('Failed to delete task: $e');
      emit(LoopError('Failed to delete task: $e'));
      if (previousState is LoopLoaded) emit(previousState);
    }
  }

  Future<void> _onCreateTask(
      CreateTaskEvent event,
      Emitter<LoopState> emit,
      ) async {
    final previousState = state;

    if (!_entitlementService.canUseRecurrenceType(event.recurrence)) {
      emit(LoopError('Recurrence type "${event.recurrence.name}" is a Premium feature.'));
      if (previousState is LoopLoaded) emit(previousState);
      return;
    }

    try {
      final newTask = TaskLoopItem(
        id: '',
        title: event.title,
        timeString: event.timeString,
        period: event.period,
        recurrence: event.recurrence,
        customDaysDisplay: event.customDaysDisplay,
        isActive: true,
        weekdays: event.weekdays,
        specificDate: event.specificDate,
      );

      final id = await _repository.createTask(event.userId, newTask);
      final taskWithId = newTask.copyWith(id: id);

      await _scheduleTaskCall(taskWithId);

      if (previousState is LoopLoaded) {
        emit(LoopLoaded(
          previousState.tasks,
          message: 'Task created and scheduled',
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to create task: $e');
      emit(LoopError('Failed to create task: $e'));
      if (previousState is LoopLoaded) emit(previousState);
    }
  }

  Future<void> _onUpdateTask(
      UpdateTaskEvent event,
      Emitter<LoopState> emit,
      ) async {
    final previousState = state;

    if (!_entitlementService.canUseRecurrenceType(event.task.recurrence)) {
      emit(LoopError('Recurrence type "${event.task.recurrence.name}" is a Premium feature.'));
      if (previousState is LoopLoaded) emit(previousState);
      return;
    }

    try {
      await _repository.updateTask(event.userId, event.task);

      if (event.task.isActive) {
        await _fakeCallService.cancelTask(event.task.id);
        await _scheduleTaskCall(event.task);
      }

      if (previousState is LoopLoaded) {
        final updatedTasks = previousState.tasks.map((t) {
          return t.id == event.task.id ? event.task : t;
        }).toList();
        emit(LoopLoaded(updatedTasks, message: 'Task updated'));
      }
    } catch (e) {
      AppLogger.error('Failed to update task: $e');
      emit(LoopError('Failed to update task: $e'));
      if (previousState is LoopLoaded) emit(previousState);
    }
  }

  Future<void> _onClearAllTasks(
      ClearAllTasksEvent event,
      Emitter<LoopState> emit,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _fakeCallService.cancelAll();
        await _repository.clearAllTasks(user.uid);
        emit(const LoopLoaded([], message: 'All tasks cleared'));
      }
    } catch (e) {
      AppLogger.error('Failed to clear tasks: $e');
      emit(LoopError('Failed to clear tasks: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Monthly date helper
  // ---------------------------------------------------------------------------

  DateTime _createValidMonthlyDate(
      int year,
      int month,
      int day,
      int hour,
      int minute,
      ) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final validDay = day > daysInMonth ? daysInMonth : day;
    return DateTime(year, month, validDay, hour, minute);
  }

  // ---------------------------------------------------------------------------
  // Scheduling helper
  // ---------------------------------------------------------------------------

  Future<void> _scheduleTaskCall(TaskLoopItem task) async {
    try {
      final parsed = _parseTimeString(task.timeString, task.id);
      if (parsed == null) {
        AppLogger.error(
          '[LoopBloc] Skipping schedule for task "${task.title}" (id=${task.id}) '
              '— fix timeString="${task.timeString}" in Firestore/cache.',
        );
        return;
      }

      int hour = parsed.hour;
      final minute = parsed.minute;

      if (task.period == 'PM' && hour != 12) {
        hour += 12;
      } else if (task.period == 'AM' && hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      DateTime computed; // Changed from DateTime? to satisfy downstream requirements

      if (task.recurrence == RecurrenceType.oneTime) {
        if (task.specificDate == null) {
          AppLogger.warning(
            'One-time task has no specificDate; skipping schedule.',
          );
          return;
        }

        computed = DateTime(
          task.specificDate!.year,
          task.specificDate!.month,
          task.specificDate!.day,
          hour,
          minute,
        );

        if (computed.isBefore(now)) {
          AppLogger.info(
            'One-time task ${task.title} scheduled date is in the past; skipping.',
          );
          return;
        }
      } else if (task.recurrence == RecurrenceType.weekly) {
        if (task.weekdays.isEmpty) {
          AppLogger.warning(
            'Weekly task has no weekdays selected; defaulting to next occurrence (tomorrow).',
          );
          computed = DateTime(now.year, now.month, now.day, hour, minute);
          if (computed.isBefore(now)) {
            computed = computed.add(const Duration(days: 1));
          }
        } else {
          final todayWeekday = now.weekday;
          int daysUntil = 100;

          for (final weekday in task.weekdays) {
            final candidate = (weekday - todayWeekday) % 7;
            final todayAtTaskTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );
            final normalized =
            candidate == 0 && todayAtTaskTime.isBefore(now)
                ? 7
                : candidate;
            daysUntil = daysUntil < normalized ? daysUntil : normalized;
          }

          final targetDay = now.add(Duration(days: daysUntil));
          computed = DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            hour,
            minute,
          );
        }
      } else if (task.recurrence == RecurrenceType.monthly) {
        final targetDay = task.specificDate?.day ?? now.day;

        int year = now.year;
        int month = now.month;

        computed = _createValidMonthlyDate(year, month, targetDay, hour, minute);

        if (computed.isBefore(now)) {
          year = now.year;
          month = now.month + 1;
          if (month > 12) {
            month = 1;
            year += 1;
          }
          computed = _createValidMonthlyDate(year, month, targetDay, hour, minute);
        }
      } else {
        computed = DateTime(now.year, now.month, now.day, hour, minute);
        if (computed.isBefore(now)) {
          computed = computed.add(const Duration(days: 1));
        }
      }

      final settings = await _settingsRepository.getSettings();

      await _fakeCallService.scheduleFakeCall(
        taskId: task.id,
        title: task.title,
        description: 'Recurring ${task.recurrence.toString().split('.').last}',
        scheduledTime: computed,
        callerName: settings.defaultCallerName ?? 'Task Reminder',
        ringtonePath: settings.fakeCallRingtone,
        vibrationEnabled: settings.fakeCallVibrate,
        recurrence: task.recurrence,
        weekdays: task.weekdays,
        specificDate: task.specificDate,
      );

      AppLogger.info('Task scheduled: ${task.title} at $computed');
    } catch (e) {
      AppLogger.error('Error scheduling task call: $e');
    }
  }
}
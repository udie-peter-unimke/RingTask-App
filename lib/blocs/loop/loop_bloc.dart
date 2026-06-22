// lib/blocs/loop/loop_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:ringtask/repositories/loop_repository.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';
import 'package:ringtask/utils/logger.dart';
import 'loop_event.dart';
import 'package:ringtask/data/models/loop_model.dart';
import 'loop_state.dart';

class LoopBloc extends Bloc<LoopEvent, LoopState> {
  final LoopRepository _repository;
  final FakeCallService _fakeCallService;

  LoopBloc({
    required LoopRepository repository,
    required FakeCallService fakeCallService,
  })  : _repository = repository,
        _fakeCallService = fakeCallService,
        super(const LoopInitial()) {
    on<LoadLoopsEvent>(_onLoadLoops);
    on<ToggleTaskActiveEvent>(_onToggleTaskActive);
    on<DeleteTaskEvent>(_onDeleteTask);
    on<CreateTaskEvent>(_onCreateTask);
    on<UpdateTaskEvent>(_onUpdateTask);
    on<SeedSampleDataEvent>(_onSeedSampleData);
    on<ClearAllTasksEvent>(_onClearAllTasks);
  }

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
  /// [taskId] is used purely for log context.
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
      // Root cause of the reported RangeError: a stored value with no ':'
      // (e.g. '', '1200', a field missing from Firestore doc) produces a
      // 1-element list. Accessing index [1] throws:
      //   RangeError (length): Invalid value: Only valid value is 0: 1
      AppLogger.error(
        '[LoopBloc] Malformed timeString="$timeString" for task $taskId '
            '— no colon separator found. RangeError prevented.',
      );
      return null;
    }

    // Use tryParse, not parse — a non-numeric segment throws FormatException.
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

  /// Load tasks and schedule active ones via FakeCallService.
  Future<void> _onLoadLoops(
      LoadLoopsEvent event,
      Emitter<LoopState> emit,
      ) async {
    emit(const LoopLoading());
    try {
      await for (final tasks in _repository.getTasksStream(event.userId)) {
        // Schedule all active tasks with FakeCallService
        for (final task in tasks.where((t) => t.isActive)) {
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
    // ✅ FIX: capture state BEFORE any emit.
    final previousState = state;
    try {
      await _repository.toggleTaskActive(event.userId, event.task, event.value);

      // If toggled on, schedule fake call; if off, cancel it
      if (event.value) {
        await _scheduleTaskCall(event.task);
      } else {
        await _fakeCallService.cancelTask(event.task.id);
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
    // ✅ FIX: same state-restore fix as _onToggleTaskActive.
    final previousState = state;
    try {
      await _fakeCallService.cancelTask(event.taskId);
      await _repository.deleteTask(event.userId, event.taskId);
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
    // ✅ FIX: same state-restore fix.
    final previousState = state;
    try {
      final newTask = TaskLoopItem(
        id: '',
        title: event.title,
        timeString: event.timeString,
        period: event.period,
        recurrence: event.recurrence,
        customDaysDisplay: event.customDaysDisplay,
        isActive: true,
      );

      final id = await _repository.createTask(event.userId, newTask);
      final taskWithId = newTask.copyWith(id: id);

      // Schedule the newly created task
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
    // ✅ FIX: same state-restore fix.
    final previousState = state;
    try {
      await _repository.updateTask(event.userId, event.task);

      // Reschedule with updated details
      if (event.task.isActive) {
        await _fakeCallService.cancelTask(event.task.id);
        await _scheduleTaskCall(event.task);
      }
    } catch (e) {
      AppLogger.error('Failed to update task: $e');
      emit(LoopError('Failed to update task: $e'));
      if (previousState is LoopLoaded) emit(previousState);
    }
  }

  Future<void> _onSeedSampleData(
      SeedSampleDataEvent event,
      Emitter<LoopState> emit,
      ) async {
    // ✅ FIX: same state-restore fix.
    final previousState = state;
    try {
      final cachedTasks = await _repository.getCachedTasks();
      if (cachedTasks.isNotEmpty) return;

      final sample = [
        TaskLoopItem(
          id: '',
          title: 'FRI-SUN PROJECT REVIEW',
          timeString: '12:00',
          period: 'PM',
          recurrence: RecurrenceType.weekly,
          customDaysDisplay: 'Every Day',
          isActive: true,
        ),
        TaskLoopItem(
          id: '',
          title: 'HEALTH & PERSONAL MEDITATION',
          timeString: '6:00',
          period: 'AM',
          recurrence: RecurrenceType.daily,
          customDaysDisplay: 'Every Day',
          isActive: true,
        ),
        TaskLoopItem(
          id: '',
          title: 'WAKE UP & STRETCH',
          timeString: '7:30',
          period: 'AM',
          recurrence: RecurrenceType.daily,
          customDaysDisplay: 'Every Day',
          isActive: true,
        ),
        TaskLoopItem(
          id: '',
          title: 'DO TO WORKSPACE',
          timeString: '9:00',
          period: 'AM',
          recurrence: RecurrenceType.weekly,
          customDaysDisplay: 'Mon, Tue, Wed, Thu, Fri, Sat',
          isActive: false,
        ),
        TaskLoopItem(
          id: '',
          title: 'LEAVE WORKSPACE',
          timeString: '6:00',
          period: 'PM',
          recurrence: RecurrenceType.weekly,
          customDaysDisplay: 'Mon, Tue, Wed, Thu, Fri, Sat',
          isActive: false,
        ),
      ];

      await _repository.batchCreateTasks(event.userId, sample);

      if (previousState is LoopLoaded) {
        emit(LoopLoaded(
          previousState.tasks,
          message: 'Sample tasks seeded',
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to seed data: $e');
      emit(LoopError('Failed to seed data: $e'));
      if (previousState is LoopLoaded) emit(previousState);
    }
  }

  Future<void> _onClearAllTasks(
      ClearAllTasksEvent event,
      Emitter<LoopState> emit,
      ) async {
    try {
      await _fakeCallService.cancelAll();
      await _repository.clearLocalCache();
      emit(const LoopLoaded([]));
    } catch (e) {
      AppLogger.error('Failed to clear tasks: $e');
      emit(LoopError('Failed to clear tasks: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling helper
  // ---------------------------------------------------------------------------

  /// Schedule a task alarm via FakeCallService.
  ///
  /// Returns silently on parse failure — the error is logged with full context
  /// so the offending task and its raw timeString value are visible in logcat.
  /// A failed schedule does not propagate — other tasks in a batch continue.
  Future<void> _scheduleTaskCall(TaskLoopItem task) async {
    try {
      // ✅ FIX: use _parseTimeString instead of raw split/parse.
      //
      // Previously:
      //   final timeParts = task.timeString.split(':');
      //   int hour = int.parse(timeParts[0]);
      //   final minute = int.parse(timeParts[1]);   ← RangeError when no ':'
      //
      // If timeString has no ':' (e.g. '', '1200', or a Firestore field that
      // came back in an unexpected format), split(':') returns a 1-element
      // list. Accessing index [1] throws:
      //   RangeError (length): Invalid value: Only valid value is 0: 1
      final parsed = _parseTimeString(task.timeString, task.id);
      if (parsed == null) {
        // _parseTimeString already logged the specific reason and raw value.
        AppLogger.error(
          '[LoopBloc] Skipping schedule for task "${task.title}" (id=${task.id}) '
              '— fix timeString="${task.timeString}" in Firestore/cache.',
        );
        return;
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

      await _fakeCallService.scheduleFakeCall(
        taskId: task.id,
        title: task.title,
        description: 'Recurring ${task.recurrence.toString().split('.').last}',
        scheduledTime: scheduledTime,
        callerName: 'Task Reminder',
        recurrence: task.recurrence,
      );

      AppLogger.info('Task scheduled: ${task.title} at ${task.timeString}');
    } catch (e) {
      AppLogger.error('Error scheduling task call: $e');
    }
  }
}
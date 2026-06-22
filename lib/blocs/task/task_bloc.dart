import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/repositories/fake_call_repository.dart';
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/blocs/task/task_state.dart';
import 'package:ringtask/utils/logger.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository taskRepository;
  final FakeCallRepository fakeCallRepository;
  StreamSubscription<List<TaskModel>>? _tasksSubscription;

  TaskBloc({
    required this.taskRepository,
    required this.fakeCallRepository,
  }) : super(const TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<TasksUpdated>(_onTasksUpdated);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    // Safety state gate: skip if already loading and list is empty
    if (state is TaskLoading && state.tasks.isEmpty) {
      AppLogger.warning('LoadTasks event skipped — already in progress');
      return;
    }

    try {
      // 1. Setup real-time listener
      _tasksSubscription?.cancel();
      _tasksSubscription = taskRepository.getTasksStream(event.userId).listen((tasks) {
        add(TasksUpdated(tasks));
      });

      // 2. Initial loading state (keep existing tasks if any)
      emit(TaskLoading(tasks: state.tasks));

      // 2. 🚀 CACHE FIRST: Show cached tasks immediately for instant UI
      final cachedTasks = await taskRepository.getCachedTasks(event.userId);
      if (cachedTasks != null && cachedTasks.isNotEmpty) {
        emit(TaskLoaded(cachedTasks));
        AppLogger.info('⚡ Displayed ${cachedTasks.length} cached tasks');
      }

      // 3. ☁️ SYNC: Fetch fresh data from Firestore
      final allTasks = await taskRepository.getAllTasks(event.userId);

      // 4. Final state: Update with fresh data.
      // We don't merge here to allow Firestore to be the source of truth
      // (e.g., if a task was deleted on another device).
      emit(TaskLoaded(allTasks));
      AppLogger.info('✅ Loaded ${allTasks.length} tasks from Firestore');

      // 5. Registration for alarms
      _rescheduleAllUpcomingAlarms(allTasks, event.settings);

    } catch (e) {
      AppLogger.error('❌ LoadTasks failed: $e');
      // On error, try to fall back to whatever we have in state
      emit(TaskError('Failed to load tasks: $e', tasks: state.tasks));
    }
  }

  // Helper method running un-awaited to offload work from the synchronous cycle
  void _rescheduleAllUpcomingAlarms(List<TaskModel> tasks, SettingsModel? settings) {
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.scheduledTime != null && task.scheduledTime!.isAfter(now)) {
        // Fire and forget down to native platform channels
        _scheduleFakeCallSafely(task, settings: settings);
      }
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    final currentTasks = state.tasks;
    emit(TaskOperationInProgress(currentTasks));

    try {
      final taskWithTimestamps = event.task.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isUrgent: event.task.scheduledTime != null
            ? _isTaskUrgent(event.task.scheduledTime!)
            : false,
      );

      final savedTask = await taskRepository.createTask(
        event.userId,
        taskWithTimestamps,
      );

      if (savedTask == null) {
        emit(TaskError('Failed to create task locally', tasks: currentTasks));
        return;
      }

      // Schedule reminder immediately (this is a local operation)
      if (savedTask.scheduledTime != null &&
          savedTask.scheduledTime!.isAfter(DateTime.now())) {
        await _scheduleFakeCallSafely(savedTask, settings: event.settings);
      }

      final updatedTasks = [...currentTasks, savedTask];
      emit(TaskAdded(savedTask, updatedTasks));
    } catch (e) {
      AppLogger.error('❌ AddTask failed: $e');
      emit(TaskError('Could not add task: $e', tasks: currentTasks));
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    final currentTasks = state.tasks;
    emit(TaskOperationInProgress(currentTasks));

    try {
      final updatedTask = event.task.copyWith(
        updatedAt: DateTime.now(),
        isUrgent: event.task.scheduledTime != null
            ? _isTaskUrgent(event.task.scheduledTime!)
            : false,
      );

      final savedTask = await taskRepository.updateTask(
        event.userId,
        updatedTask.id,
        updatedTask,
      );

      if (savedTask == null) {
        emit(TaskError('Task update failed locally', tasks: currentTasks));
        return;
      }

      await fakeCallRepository.cancelScheduledReminder(savedTask.id);

      if (savedTask.scheduledTime != null &&
          savedTask.scheduledTime!.isAfter(DateTime.now())) {
        await _scheduleFakeCallSafely(savedTask, settings: event.settings);
      }

      final updatedTasks = currentTasks
          .map((t) => t.id == savedTask.id ? savedTask : t)
          .toList();

      emit(TaskUpdated(savedTask, updatedTasks));
    } catch (e) {
      AppLogger.error('❌ UpdateTask failed: $e');
      emit(TaskError('Could not update task: $e', tasks: currentTasks));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    final currentTasks = state.tasks;
    emit(TaskOperationInProgress(currentTasks));

    try {
      final success = await taskRepository.deleteTask(
        event.userId,
        event.taskId,
      );

      if (!success) {
        emit(TaskError('Delete failed locally', tasks: currentTasks));
        return;
      }

      await fakeCallRepository.cancelScheduledReminder(event.taskId);

      final updatedTasks =
      currentTasks.where((t) => t.id != event.taskId).toList();
      emit(TaskDeleted(event.taskId, updatedTasks));
    } catch (e) {
      AppLogger.error('❌ DeleteTask failed: $e');
      emit(TaskError('Could not delete task: $e', tasks: currentTasks));
    }
  }

  void _onTasksUpdated(TasksUpdated event, Emitter<TaskState> emit) {
    emit(TaskLoaded(event.tasks));
  }

  @override
  Future<void> close() {
    _tasksSubscription?.cancel();
    return super.close();
  }

  Future<void> _scheduleFakeCallSafely(
      TaskModel task, {
        SettingsModel? settings,
      }) async {
    try {
      await fakeCallRepository.scheduleTaskReminder(
        task,
        settings: settings,
      );
      AppLogger.info('⏰ Scheduled: ${task.title}');
    } catch (e) {
      AppLogger.error('❌ Schedule failed for ${task.title}: $e');
    }
  }

  bool _isTaskUrgent(DateTime scheduledTime) {
    final diff = scheduledTime.difference(DateTime.now());
    return diff.inHours <= 2 && diff.inMilliseconds > 0;
  }
}
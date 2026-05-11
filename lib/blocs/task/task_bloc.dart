// lib/blocs/task/task_bloc.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/blocs/task/task_state.dart';
import 'package:ringtask/utils/logger.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository taskRepository;
  static const _channel = MethodChannel('ringtask/workmanager');

  TaskBloc({required this.taskRepository}) : super(const TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    try {
      emit(TaskLoading(tasks: state.tasks));
      final allTasks = await taskRepository.getAllTasks(event.userId);

      for (final task in allTasks) {
        if (task.scheduledTime != null &&
            task.scheduledTime!.isAfter(DateTime.now())) {
          await _scheduleFakeCallSafely(task);
        }
      }

      emit(TaskLoaded(allTasks));
      AppLogger.info('✅ Loaded ${allTasks.length} tasks');
    } catch (e) {
      AppLogger.error('❌ LoadTasks failed: $e');
      emit(TaskError('Failed to load tasks: $e', tasks: state.tasks));
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

      final success = await taskRepository.createTask(
        event.userId,
        taskWithTimestamps,
      );

      if (!success) {
        emit(TaskError('Failed to create task', tasks: currentTasks));
        return;
      }

      if (taskWithTimestamps.scheduledTime != null &&
          taskWithTimestamps.scheduledTime!.isAfter(DateTime.now())) {
        await _scheduleFakeCallSafely(taskWithTimestamps);
      }

      final updatedTasks = [...currentTasks, taskWithTimestamps];
      emit(TaskAdded(taskWithTimestamps, updatedTasks));
      AppLogger.info('✅ Added task: ${taskWithTimestamps.title}');
    } catch (e) {
      AppLogger.error('❌ AddTask failed: $e');
      emit(TaskError('Failed to add task: $e', tasks: currentTasks));
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

      final success = await taskRepository.updateTask(
        event.userId,
        updatedTask.id,
        updatedTask,
      );

      if (!success) {
        emit(TaskError('Task not found', tasks: currentTasks));
        return;
      }

      // ✅ Cancel only THIS task's scheduled call before rescheduling
      await _cancelTaskSafely(updatedTask.id);

      if (updatedTask.scheduledTime != null &&
          updatedTask.scheduledTime!.isAfter(DateTime.now())) {
        await _scheduleFakeCallSafely(updatedTask);
      }

      final updatedTasks = currentTasks
          .map((t) => t.id == updatedTask.id ? updatedTask : t)
          .toList();

      emit(TaskUpdated(updatedTask, updatedTasks));
      AppLogger.info('✅ Updated task: ${updatedTask.title}');
    } catch (e) {
      AppLogger.error('❌ UpdateTask failed: $e');
      emit(TaskError('Failed to update task: $e', tasks: currentTasks));
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
        emit(TaskError('Task not found', tasks: currentTasks));
        return;
      }

      // ✅ Cancel only THIS task's scheduled call
      await _cancelTaskSafely(event.taskId);

      final updatedTasks =
      currentTasks.where((t) => t.id != event.taskId).toList();
      emit(TaskDeleted(event.taskId, updatedTasks));
      AppLogger.info('✅ Deleted task: ${event.taskId}');
    } catch (e) {
      AppLogger.error('❌ DeleteTask failed: $e');
      emit(TaskError('Failed to delete task: $e', tasks: currentTasks));
    }
  }

  // ✅ Now async + awaited so failures are caught
  // ✅ Passes taskId as tag so each task's call is independently cancellable
  Future<void> _scheduleFakeCallSafely(TaskModel task) async {
    try {
      final delay = task.scheduledTime!.difference(DateTime.now());

      // ✅ Build description speech — guard against empty string
      final description = task.description.trim();

      final payload = jsonEncode({
        'taskId': task.id,
        'title': task.title.trim(),
        'description': description, // may be empty — FakeCallScreen handles it
        'callerName': 'RingTask Reminder',
        'ringtonePath': 'sounds/ringtone.mp3',
      });

      await _channel.invokeMethod('scheduleFakeCall', {
        'delayMillis': (delay.isNegative ? Duration.zero : delay).inMilliseconds,
        'payload': payload,
        'tag': 'fakeCall_${task.id}', // ✅ Unique tag per task
      });

      AppLogger.info('⏰ Scheduled: ${task.title} in ${delay.inMinutes}min');
    } catch (e) {
      AppLogger.error('❌ Schedule failed for ${task.title}: $e');
    }
  }

  // ✅ Cancels a specific task's scheduled call by its unique tag
  Future<void> _cancelTaskSafely(String taskId) async {
    try {
      await _channel.invokeMethod('cancelFakeCall', {'tag': 'fakeCall_$taskId'});
      AppLogger.info('🗑️ Cancelled scheduled call for task: $taskId');
    } catch (e) {
      AppLogger.error('❌ Cancel failed for task $taskId: $e');
    }
  }

  bool _isTaskUrgent(DateTime scheduledTime) {
    final diff = scheduledTime.difference(DateTime.now());
    return diff.inHours <= 2 && diff.inMilliseconds > 0;
  }
}
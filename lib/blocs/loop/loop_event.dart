import 'package:equatable/equatable.dart';
import '../../data/models/loop_model.dart';

/// Base class for all loop-related events
abstract class LoopEvent extends Equatable {
  const LoopEvent();

  @override
  List<Object?> get props => [];
}

/// Load all tasks from Firestore (listens to real-time updates)
class LoadLoopsEvent extends LoopEvent {
  final String userId;
  const LoadLoopsEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Toggle task active/inactive status
class ToggleTaskActiveEvent extends LoopEvent {
  final String userId;
  final TaskLoopItem task;
  final bool value;

  const ToggleTaskActiveEvent({
    required this.userId,
    required this.task,
    required this.value,
  });

  @override
  List<Object?> get props => [userId, task, value];
}

/// Delete a task from Firestore
class DeleteTaskEvent extends LoopEvent {
  final String userId;
  final String taskId;

  const DeleteTaskEvent({required this.userId, required this.taskId});

  @override
  List<Object?> get props => [userId, taskId];
}

/// Create a new task in Firestore
class CreateTaskEvent extends LoopEvent {
  final String userId;
  final String title;
  final String timeString;
  final String period;
  final RecurrenceType recurrence;
  final String customDaysDisplay;

  const CreateTaskEvent({
    required this.userId,
    required this.title,
    required this.timeString,
    required this.period,
    required this.recurrence,
    required this.customDaysDisplay,
  });

  @override
  List<Object?> get props => [
    userId,
    title,
    timeString,
    period,
    recurrence,
    customDaysDisplay,
  ];
}

/// Update an existing task in Firestore
class UpdateTaskEvent extends LoopEvent {
  final String userId;
  final TaskLoopItem task;

  const UpdateTaskEvent({required this.userId, required this.task});

  @override
  List<Object?> get props => [userId, task];
}

/// Seed sample/default tasks if collection is empty
class SeedSampleDataEvent extends LoopEvent {
  final String userId;
  const SeedSampleDataEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Clear all tasks (optional, for development/testing)
class ClearAllTasksEvent extends LoopEvent {
  const ClearAllTasksEvent();
}
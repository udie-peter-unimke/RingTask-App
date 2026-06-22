import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/data/models/settings_model.dart';  // ← add this import

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  final String userId;
  final SettingsModel? settings;                              // ← added
  const LoadTasks(this.userId, {this.settings});
  @override List<Object?> get props => [userId, settings];
}

class AddTask extends TaskEvent {
  final String userId;
  final TaskModel task;
  final SettingsModel? settings;                              // ← added
  const AddTask(this.userId, this.task, {this.settings});
  @override List<Object?> get props => [userId, task, settings];
}

class UpdateTask extends TaskEvent {
  final String userId;
  final TaskModel task;
  final SettingsModel? settings;                              // ← added
  const UpdateTask(this.userId, this.task, {this.settings});
  @override List<Object?> get props => [userId, task, settings];
}

class DeleteTask extends TaskEvent {
  final String userId;
  final String taskId;
  // ← no settings needed — delete just cancels, doesn't schedule
  const DeleteTask(this.userId, this.taskId);
  @override List<Object?> get props => [userId, taskId];
}

class TasksUpdated extends TaskEvent {
  final List<TaskModel> tasks;
  const TasksUpdated(this.tasks);
  @override
  List<Object?> get props => [tasks];
}

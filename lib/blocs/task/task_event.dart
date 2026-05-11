import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/task_model.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  final String userId;  // ✅ Added
  const LoadTasks(this.userId);
  @override List<Object?> get props => [userId];
}

class AddTask extends TaskEvent {
  final String userId;  // ✅ Added
  final TaskModel task;
  const AddTask(this.userId, this.task);
  @override List<Object?> get props => [userId, task];
}

class UpdateTask extends TaskEvent {
  final String userId;  // ✅ Added
  final TaskModel task;
  const UpdateTask(this.userId, this.task);
  @override List<Object?> get props => [userId, task];
}

class DeleteTask extends TaskEvent {
  final String userId;  // ✅ Added
  final String taskId;
  const DeleteTask(this.userId, this.taskId);
  @override List<Object?> get props => [userId, taskId];
}

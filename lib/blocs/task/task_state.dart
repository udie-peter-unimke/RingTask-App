import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/task_model.dart';

abstract class TaskState extends Equatable {
  final List<TaskModel> tasks;
  final bool isLoading;
  final String? error;

  const TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [tasks, isLoading, error];

  TaskState copyWith({
    List<TaskModel>? tasks,
    bool? isLoading,
    String? error,
  });
}

class TaskInitial extends TaskState {
  const TaskInitial() : super();

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    // Keep initial state pure. State transitions belong in the Bloc handlers.
    return const TaskInitial();
  }

  @override
  String toString() => 'TaskInitial';
}

class TaskLoading extends TaskState {
  const TaskLoading({super.tasks}) : super(isLoading: true);

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    return TaskLoading(tasks: tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskLoading { tasks: ${tasks.length} }';
}

class TaskLoaded extends TaskState {
  const TaskLoaded(List<TaskModel> tasks) : super(tasks: tasks);

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    // ✅ FIXED: Return TaskLoaded explicitly to preserve structural type checking
    return TaskLoaded(tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskLoaded { tasks: ${tasks.length} }';
}

class TaskOperationInProgress extends TaskState {
  const TaskOperationInProgress(List<TaskModel> currentTasks)
      : super(tasks: currentTasks, isLoading: true);

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    return TaskOperationInProgress(tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskOperationInProgress { tasks: ${tasks.length} }';
}

class TaskAdded extends TaskState {
  final TaskModel addedTask;

  const TaskAdded(this.addedTask, List<TaskModel> updatedTasks)
      : super(tasks: updatedTasks);

  @override
  List<Object?> get props => [addedTask, tasks, isLoading, error];

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    return TaskAdded(addedTask, tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskAdded { "${addedTask.title}", tasks: ${tasks.length} }';
}

class TaskUpdated extends TaskState {
  final TaskModel updatedTask;

  const TaskUpdated(this.updatedTask, List<TaskModel> updatedTasks)
      : super(tasks: updatedTasks);

  @override
  List<Object?> get props => [updatedTask, tasks, isLoading, error];

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    return TaskUpdated(updatedTask, tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskUpdated { "${updatedTask.title}", tasks: ${tasks.length} }';
}

class TaskDeleted extends TaskState {
  final String deletedTaskId;

  const TaskDeleted(this.deletedTaskId, List<TaskModel> updatedTasks)
      : super(tasks: updatedTasks);

  @override
  List<Object?> get props => [deletedTaskId, tasks, isLoading, error];

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    return TaskDeleted(deletedTaskId, tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskDeleted { id: $deletedTaskId, tasks: ${tasks.length} }';
}

class TaskError extends TaskState {
  String get message => error ?? 'Unknown error';

  const TaskError(String message, {super.tasks}) : super(error: message);

  @override
  TaskState copyWith({List<TaskModel>? tasks, bool? isLoading, String? error}) {
    // ✅ FIXED: Return TaskError to keep properties aligned without type pollution
    return TaskError(error ?? message, tasks: tasks ?? this.tasks);
  }

  @override
  String toString() => 'TaskError("$message", tasks: ${tasks.length})';
}
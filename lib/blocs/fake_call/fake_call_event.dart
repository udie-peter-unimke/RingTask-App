
import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/task_model.dart';

/// Base class for all Fake Call events
abstract class FakeCallEvent extends Equatable {
  const FakeCallEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger a fake call for a specific task
class TriggerFakeCallEvent extends FakeCallEvent {
  final TaskModel task;

  const TriggerFakeCallEvent(this.task);

  @override
  List<Object?> get props => [task];
}

class AnswerFakeCallEvent extends FakeCallEvent {
  const AnswerFakeCallEvent();
}

class DeclineFakeCallEvent extends FakeCallEvent {
  const DeclineFakeCallEvent();
}

class EndFakeCallEvent extends FakeCallEvent {
  const EndFakeCallEvent();
}

class MarkTaskCompletedEvent extends FakeCallEvent {
  final String taskId;
  const MarkTaskCompletedEvent(this.taskId);
  @override
  List<Object?> get props => [taskId];
}

class SnoozeTaskEvent extends FakeCallEvent {
  final String taskId;
  final Duration snoozeDuration;
  const SnoozeTaskEvent(this.taskId, this.snoozeDuration);
  @override
  List<Object?> get props => [taskId, snoozeDuration];
}

class ResetFakeCallEvent extends FakeCallEvent {
  const ResetFakeCallEvent();
}

class TtsStartedEvent extends FakeCallEvent {
  const TtsStartedEvent();
}

class TtsCompletedEvent extends FakeCallEvent {
  const TtsCompletedEvent();
}

class TtsErrorEvent extends FakeCallEvent {
  final String error;
  const TtsErrorEvent(this.error);
  @override
  List<Object?> get props => [error];
}
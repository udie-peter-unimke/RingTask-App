import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/task_model.dart';

/// Enum to represent the current state of the fake call
enum FakeCallStatus {
  idle,           // No fake call active
  ringing,
  loading,// Fake call is ringing (incoming call screen)
  answered,       // User answered, call is active
  reading,        // TTS is reading the task
  completed,      // Call ended normally
  declined,       // User declined the call
  snoozed,        // Task was snoozed
  error,          // An error occurred
}

/// State class for Fake Call BLoC
class FakeCallState extends Equatable {
  final FakeCallStatus status;
  final TaskModel? currentTask;
  final bool isTtsSpeaking;
  final String? errorMessage;
  final DateTime? callStartTime;
  final Duration? callDuration;

  const FakeCallState({
    this.status = FakeCallStatus.idle,
    this.currentTask,
    this.isTtsSpeaking = false,
    this.errorMessage,
    this.callStartTime,
    this.callDuration,
  });

  /// Initial state
  factory FakeCallState.initial() {
    return const FakeCallState();
  }

  /// Convenience getters
  bool get isCallActive =>
      status == FakeCallStatus.ringing ||
          status == FakeCallStatus.answered ||
          status == FakeCallStatus.loading ||
          status == FakeCallStatus.reading;


  bool get isRinging => status == FakeCallStatus.ringing;
  bool get isAnswered => status == FakeCallStatus.answered;
  bool get isReading => status == FakeCallStatus.reading;
  bool get isCompleted => status == FakeCallStatus.completed;
  bool get isDeclined => status == FakeCallStatus.declined;
  bool get isSnoozed => status == FakeCallStatus.snoozed;
  bool get hasError => status == FakeCallStatus.error;
  bool get isIdle => status == FakeCallStatus.idle;
  bool get isLoading => status == FakeCallStatus.loading;

  /// Copy with method for state updates
  FakeCallState copyWith({
    FakeCallStatus? status,
    TaskModel? currentTask,
    bool? isTtsSpeaking,
    String? errorMessage,
    DateTime? callStartTime,
    Duration? callDuration,
    bool clearTask = false,
    bool clearError = false,
  }) {
    return FakeCallState(
      status: status ?? this.status,
      currentTask: clearTask ? null : (currentTask ?? this.currentTask),
      isTtsSpeaking: isTtsSpeaking ?? this.isTtsSpeaking,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      callStartTime: callStartTime ?? this.callStartTime,
      callDuration: callDuration ?? this.callDuration,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentTask,
    isTtsSpeaking,
    errorMessage,
    callStartTime,
    callDuration,
  ];

  @override
  String toString() {
    return 'FakeCallState(status: $status, task: ${currentTask?.title}, isTtsSpeaking: $isTtsSpeaking)';
  }
}
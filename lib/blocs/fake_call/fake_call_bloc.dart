import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/fake_call/fake_call_event.dart';
import 'package:ringtask/blocs/fake_call/fake_call_state.dart';
//import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/repositories/fake_call_repository.dart';
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/services/firebase/tts_service.dart';
import 'package:ringtask/utils/logger.dart';

class FakeCallBloc extends Bloc<FakeCallEvent, FakeCallState> {
  final FakeCallRepository _fakeCallRepository;
  final TaskRepository _taskRepository;
  final TtsService _ttsService;
  final String _userId;

  FakeCallBloc({
    required FakeCallRepository fakeCallRepository,
    required TaskRepository taskRepository,
    required TtsService ttsService,
    required String userId,
  })  : _fakeCallRepository = fakeCallRepository,
        _taskRepository = taskRepository,
        _ttsService = ttsService,
        _userId = userId,
        super(FakeCallState.initial()) {

    on<TriggerFakeCallEvent>(_onTriggerFakeCall);
    on<AnswerFakeCallEvent>(_onAnswerFakeCall);
    on<DeclineFakeCallEvent>(_onDeclineFakeCall);
    on<MarkTaskCompletedEvent>(_onMarkTaskCompleted);
    on<SnoozeTaskEvent>(_onSnoozeTask);
    on<ResetFakeCallEvent>(_onReset);
  }

  // ──────────────────────────────────────────────────────────────
  // 1. Task due → WorkManager triggers → Show fake call + ring
  // ──────────────────────────────────────────────────────────────
  Future<void> _onTriggerFakeCall(
      TriggerFakeCallEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final task = event.task;

    AppLogger.info('Fake call triggered for task: ${task.title} (ID: ${task.id})');

    emit(state.copyWith(
      status: FakeCallStatus.ringing,
      currentTask: task,
      callStartTime: DateTime.now(),
    ));

    final success = await _fakeCallRepository.initiateFakeCall(task);

    if (!success) {
      AppLogger.error('Failed to initiate fake call');
      emit(state.copyWith(
        status: FakeCallStatus.error,
        errorMessage: 'Could not start reminder call',
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 2. User answers → Speak the task aloud
  // ──────────────────────────────────────────────────────────────
  Future<void> _onAnswerFakeCall(
      AnswerFakeCallEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final task = state.currentTask;
    if (task == null) return;

    AppLogger.info('User answered fake call – reading task aloud');

    emit(state.copyWith(status: FakeCallStatus.reading));

    await _fakeCallRepository.readTaskDetails(task);

    emit(state.copyWith(status: FakeCallStatus.answered));
  }

  // ──────────────────────────────────────────────────────────────
  // 3. User declines call
  // ──────────────────────────────────────────────────────────────
  Future<void> _onDeclineFakeCall(
      DeclineFakeCallEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    await _cleanupAndEnd(emit, FakeCallStatus.declined);
  }

  // ──────────────────────────────────────────────────────────────
  // 4. Mark task as completed
  // ──────────────────────────────────────────────────────────────
  Future<void> _onMarkTaskCompleted(
      MarkTaskCompletedEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final taskId = state.currentTask?.id;
    if (taskId == null) return;

    AppLogger.info('Marking task as completed: $taskId');

    final success = await _taskRepository.markTaskAsCompleted(_userId, taskId);

    if (success) {
      await _cleanupAndEnd(emit, FakeCallStatus.completed);
    } else {
      emit(state.copyWith(
        status: FakeCallStatus.error,
        errorMessage: 'Failed to mark task as completed',
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 5. Snooze (optional – you can expand later)
  // ──────────────────────────────────────────────────────────────
  Future<void> _onSnoozeTask(
      SnoozeTaskEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    await _cleanupAndEnd(emit, FakeCallStatus.snoozed);
  }

  // ──────────────────────────────────────────────────────────────
  // Helper: Stop everything and reset
  // ──────────────────────────────────────────────────────────────
  Future<void> _cleanupAndEnd(
      Emitter<FakeCallState> emit,
      FakeCallStatus endStatus,
      ) async {
    await _ttsService.stop();
    await _fakeCallRepository.endFakeCall();

    final duration = state.callStartTime != null
        ? DateTime.now().difference(state.callStartTime!)
        : null;

    emit(state.copyWith(
      status: endStatus,
      callDuration: duration,
    ));

    await Future.delayed(const Duration(seconds: 1));
    add(const ResetFakeCallEvent());
  }

  // ──────────────────────────────────────────────────────────────
  // Reset to idle
  // ──────────────────────────────────────────────────────────────
  void _onReset(ResetFakeCallEvent event, Emitter<FakeCallState> emit) {
    emit(FakeCallState.initial());
  }

  @override
  Future<void> close() async {
    await _ttsService.stop();
    return super.close();
  }
}
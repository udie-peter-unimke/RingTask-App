// lib/blocs/fake_call/fake_call_bloc.dart
import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/fake_call/fake_call_event.dart';
import 'package:ringtask/blocs/fake_call/fake_call_state.dart';
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

    on<TriggerFakeCallEvent>(
      _onTriggerFakeCall,
      transformer: droppable(),
    );
    on<AnswerFakeCallEvent>(_onAnswerFakeCall);
    on<DeclineFakeCallEvent>(_onDeclineFakeCall);
    on<MarkTaskCompletedEvent>(_onMarkTaskCompleted);
    on<SnoozeTaskEvent>(_onSnoozeTask);
    on<ResetFakeCallEvent>(_onReset);
  }

  // ── 1. Task due → show fake call ──────────────────────────────────────────
  Future<void> _onTriggerFakeCall(
      TriggerFakeCallEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final task = event.task;
    AppLogger.info('Fake call triggered: ${task.title} (${task.id})');

    emit(state.copyWith(
      status: FakeCallStatus.loading,
      currentTask: task,
      callStartTime: DateTime.now(),
    ));

    try {
      final success = await _fakeCallRepository.initiateFakeCall(task);
      if (success) {
        emit(state.copyWith(status: FakeCallStatus.ringing));
      } else {
        AppLogger.error('initiateFakeCall returned false');
        emit(state.copyWith(
          status: FakeCallStatus.error,
          errorMessage: 'Could not start reminder call',
        ));
      }
    } catch (e) {
      AppLogger.error('initiateFakeCall threw: $e');
      emit(state.copyWith(
        status: FakeCallStatus.error,
        errorMessage: 'Could not start reminder call',
      ));
    }
  }

  // ── 2. User answers → move to tts screen ──────────────────────────────────
  Future<void> _onAnswerFakeCall(
      AnswerFakeCallEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final task = state.currentTask;
    if (task == null) return;

    AppLogger.info('Call answered — moving to tts screen');
    emit(state.copyWith(status: FakeCallStatus.answered));
    // TTS reading is now handled by TtsNotificationScreen to avoid
    // audio focus conflicts during the navigation transition.
  }

  // ── 3. User declines ──────────────────────────────────────────────────────
  Future<void> _onDeclineFakeCall(
      DeclineFakeCallEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    await _cleanupAndEnd(emit, FakeCallStatus.declined);
  }

  // ── 4. Mark task completed ────────────────────────────────────────────────
  Future<void> _onMarkTaskCompleted(
      MarkTaskCompletedEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final taskId = state.currentTask?.id;
    if (taskId == null) return;

    AppLogger.info('Marking task completed: $taskId');

    try {
      final success = await _taskRepository.markTaskAsCompleted(_userId, taskId);
      if (success) {
        await _cleanupAndEnd(emit, FakeCallStatus.completed);
      } else {
        emit(state.copyWith(
          status: FakeCallStatus.error,
          errorMessage: 'Failed to mark task as completed',
        ));
      }
    } catch (e) {
      AppLogger.error('markTaskAsCompleted threw: $e');
      emit(state.copyWith(
        status: FakeCallStatus.error,
        errorMessage: 'Failed to mark task as completed',
      ));
    }
  }

  // ── 5. Snooze ─────────────────────────────────────────────────────────────
  Future<void> _onSnoozeTask(
      SnoozeTaskEvent event,
      Emitter<FakeCallState> emit,
      ) async {
    final task = state.currentTask;
    if (task == null) return;

    try {
      final snoozeUntil = DateTime.now().add(event.snoozeDuration);
      await _fakeCallRepository.snoozeFakeCall(
        task: task,
        until: snoozeUntil,
      );
      AppLogger.info('Task snoozed until $snoozeUntil');
      await _cleanupAndEnd(emit, FakeCallStatus.snoozed);
    } catch (e) {
      AppLogger.error('Snooze failed: $e');
      emit(state.copyWith(
        status: FakeCallStatus.error,
        errorMessage: 'Could not snooze reminder',
      ));
    }
  }

  // ── Helper: stop audio + end call ─────────────────────────────────────────
  Future<void> _cleanupAndEnd(
      Emitter<FakeCallState> emit,
      FakeCallStatus endStatus,
      ) async {
    await _ttsService.stop();
    await _fakeCallRepository.endFakeCall();

    final duration = state.callStartTime != null
        ? DateTime.now().difference(state.callStartTime!)
        : null;

    if (!isClosed) {
      emit(state.copyWith(
        status: endStatus,
        callDuration: duration,
      ));
    }

    // Wait safely before resetting to initial state
    await Future.delayed(const Duration(seconds: 1));
    if (!isClosed) {
      emit(FakeCallState.initial());
    }
  }

  // ── Reset to idle ──────────────────────────────────────────────────────────
  void _onReset(ResetFakeCallEvent event, Emitter<FakeCallState> emit) {
    emit(FakeCallState.initial());
  }

  @override
  Future<void> close() async {
    // Note: Do NOT call _ttsService.stop() here. 
    // This bloc is disposed during navigation from FakeCallScreen to 
    // TtsNotificationScreen. Stopping TTS here would kill the speech 
    // that TtsNotificationScreen just started in its initState.
    return super.close();
  }
}
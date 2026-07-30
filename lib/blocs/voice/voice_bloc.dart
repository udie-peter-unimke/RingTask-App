import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:ringtask/repositories/voice_repository.dart';
import 'package:ringtask/services/entitlement/entitlement_service.dart';
import 'package:ringtask/utils/logger.dart';

import 'voice_event.dart';
import 'voice_state.dart';

class VoiceBloc extends Bloc<VoiceEvent, VoiceState> {
  final IVoiceRepository voiceRepository;
  final EntitlementService _entitlementService;
  Completer<void>? _listeningCompleter;

  VoiceBloc({
    required this.voiceRepository,
    required EntitlementService entitlementService,
  })  : _entitlementService = entitlementService,
        super(const VoiceInitialState()) {
    on<InitializeVoiceEvent>(_onInitializeVoice, transformer: droppable());
    on<StartListeningEvent>(_onStartListening, transformer: droppable());
    on<StopListeningEvent>(_onStopListening);
    on<CancelVoiceEvent>(_onCancelVoice);
    on<VoiceRecognizedEvent>(_onVoiceRecognized);
    on<VoiceErrorEvent>(_onVoiceError);
    on<CheckVoicePermissionEvent>(_onCheckVoicePermission);
    on<RequestVoicePermissionEvent>(_onRequestVoicePermission, transformer: droppable());
    on<ResetVoiceEvent>(_onResetVoice);
    on<OpenVoiceSettingsEvent>(_onOpenVoiceSettings);
  }

  // Initialize voice recognition
  Future<void> _onInitializeVoice(
      InitializeVoiceEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      emit(const VoiceInitializingState());

      final isAvailable = await voiceRepository.isVoiceAvailable();

      if (!isAvailable) {
        emit(const VoiceUnavailableState());
        return;
      }

      final permissionGranted = await voiceRepository.checkMicrophonePermission();

      if (permissionGranted) {
        emit(const VoiceReadyState());
      } else {
        final isPermanentlyDenied = await voiceRepository.isMicrophonePermissionPermanentlyDenied();
        emit(VoicePermissionDeniedState(
          reason: isPermanentlyDenied
              ? 'Microphone permission is permanently denied. Please enable it in settings.'
              : 'Microphone permission is required to use voice input',
          isPermanentlyDenied: isPermanentlyDenied,
        ));
      }
    } catch (e) {
      AppLogger.error('Error initializing voice: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to initialize voice: $e'));
    }
  }

  // Start listening for voice input
  Future<void> _onStartListening(
      StartListeningEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      if (state is VoiceListeningState) {
        AppLogger.info('VoiceBloc: Already listening, ignoring StartListeningEvent');
        return;
      }

      // Proactively check Entitlement for Voice Scheduling
      if (!_entitlementService.canUseUnlimitedVoiceScheduling) {
        // Here we could implement a logic for "10 virtual calls / month"
        // But for now, we'll just log or emit a specific state if needed.
        // For efficiency, we'll proceed but this is where the gate would be.
        AppLogger.info('VoiceBloc: Free user using voice scheduling (limit not enforced yet)');
      }

      // Proactively initialize if not ready
      if (state is VoiceInitialState || state is VoiceErrorState) {
        emit(const VoiceInitializingState());
        final isAvailable = await voiceRepository.isVoiceAvailable();
        if (!isAvailable) {
          emit(const VoiceUnavailableState());
          return;
        }
      }

      emit(const VoiceListeningState());

      final listeningCompleter = Completer<void>();
      _listeningCompleter = listeningCompleter;

      await voiceRepository.startListening(
        onResult: (recognizedText) {
          add(VoiceRecognizedEvent(recognizedText));
          if (!listeningCompleter.isCompleted) {
            listeningCompleter.complete();
          }
        },
        onError: (errorMessage) {
          add(VoiceErrorEvent(errorMessage));
          if (!listeningCompleter.isCompleted) {
            listeningCompleter.complete();
          }
        },
        onPartialResult: (partialText) {
          if (!emit.isDone) {
            emit(VoiceListeningState(partialResult: partialText));
          }
        },
      );

      await listeningCompleter.future;
    } catch (e) {
      AppLogger.error('Error starting voice listening: $e');
      emit(VoiceErrorState(
        errorMessage: 'Failed to start listening: $e',
        errorCode: 'START_LISTEN_ERROR',
      ));
    } finally {
      if (_listeningCompleter?.isCompleted ?? true) {
        _listeningCompleter = null;
      }
    }
  }

  // Stop listening for voice input
  Future<void> _onStopListening(
      StopListeningEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.stopListening();
      _completeListening();
      emit(const VoiceStoppedState());
    } catch (e) {
      AppLogger.error('Error stopping voice listening: $e');
      emit(VoiceErrorState(
        errorMessage: 'Failed to stop listening: $e',
        errorCode: 'STOP_LISTEN_ERROR',
      ));
    }
  }

  // Cancel voice recognition
  Future<void> _onCancelVoice(
      CancelVoiceEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.cancelListening();
      _completeListening();
      emit(const VoiceCancelledState());
    } catch (e) {
      AppLogger.error('Error cancelling voice: $e');
      emit(VoiceErrorState(
        errorMessage: 'Failed to cancel voice recognition: $e',
        errorCode: 'CANCEL_VOICE_ERROR',
      ));
    }
  }

  // Handle recognized voice text
  Future<void> _onVoiceRecognized(
      VoiceRecognizedEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      AppLogger.info('Voice recognized: ${event.recognizedText}');
      emit(VoiceRecognizedState(
        recognizedText: event.recognizedText,
        confidence: 0.95,
      ));
    } catch (e) {
      AppLogger.error('Error processing recognized voice: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to process voice: $e'));
    }
  }

  // Handle voice error
  Future<void> _onVoiceError(
      VoiceErrorEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      AppLogger.error('Voice error occurred: ${event.errorMessage}');
      emit(VoiceErrorState(errorMessage: event.errorMessage));
    } catch (e) {
      AppLogger.error('Error handling voice error: $e');
    }
  }

  // Check microphone permission
  Future<void> _onCheckVoicePermission(
      CheckVoicePermissionEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      emit(const VoicePermissionCheckingState());

      final permissionGranted = await voiceRepository.checkMicrophonePermission();

      if (permissionGranted) {
        emit(const VoicePermissionGrantedState());
      } else {
        emit(const VoicePermissionDeniedState());
      }
    } catch (e) {
      AppLogger.error('Error checking voice permission: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to check permission: $e'));
    }
  }

  // Request microphone permission
  Future<void> _onRequestVoicePermission(
      RequestVoicePermissionEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      emit(const VoicePermissionCheckingState());

      final permissionGranted = await voiceRepository.requestMicrophonePermission();

      if (permissionGranted) {
        emit(const VoicePermissionGrantedState());
        emit(const VoiceReadyState());
      } else {
        final isPermanentlyDenied = await voiceRepository.isMicrophonePermissionPermanentlyDenied();
        emit(VoicePermissionDeniedState(
          reason: isPermanentlyDenied
              ? 'Microphone permission was permanently denied. Please enable it in settings.'
              : 'Microphone permission was denied. Please enable it to use voice input.',
          isPermanentlyDenied: isPermanentlyDenied,
        ));
      }
    } catch (e) {
      AppLogger.error('Error requesting voice permission: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to request permission: $e'));
    }
  }

  // Reset voice state to initial
  Future<void> _onResetVoice(
      ResetVoiceEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.cancelListening();
      _completeListening();
      emit(const VoiceInitialState());
    } catch (e) {
      AppLogger.error('Error resetting voice: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to reset voice: $e'));
    }
  }

  // Open app settings
  Future<void> _onOpenVoiceSettings(
      OpenVoiceSettingsEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.openAppSettings();
    } catch (e) {
      AppLogger.error('Error opening settings: $e');
    }
  }

  void _completeListening() {
    final completer = _listeningCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _listeningCompleter = null;
  }

}

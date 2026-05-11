import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/repositories/voice_repository.dart';
import 'package:ringtask/utils/logger.dart';

import 'voice_event.dart';
import 'voice_state.dart';

class VoiceBloc extends Bloc<VoiceEvent, VoiceState> {
  final VoiceRepository voiceRepository;

  VoiceBloc({required this.voiceRepository}) : super(const VoiceInitialState()) {
    on<InitializeVoiceEvent>(_onInitializeVoice);
    on<StartListeningEvent>(_onStartListening);
    on<StopListeningEvent>(_onStopListening);
    on<CancelVoiceEvent>(_onCancelVoice);
    on<VoiceRecognizedEvent>(_onVoiceRecognized);
    on<VoiceErrorEvent>(_onVoiceError);
    on<CheckVoicePermissionEvent>(_onCheckVoicePermission);
    on<RequestVoicePermissionEvent>(_onRequestVoicePermission);
    on<ResetVoiceEvent>(_onResetVoice);
  }

  /// Initialize voice recognition
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
        emit(const VoicePermissionDeniedState());
      }
    } catch (e) {
      AppLogger.error('Error initializing voice: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to initialize voice: $e'));
    }
  }

  /// Start listening for voice input
  Future<void> _onStartListening(
      StartListeningEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      emit(const VoiceListeningState());

      final permissionGranted = await voiceRepository.checkMicrophonePermission();

      if (!permissionGranted) {
        emit(const VoicePermissionDeniedState());
        return;
      }

      await voiceRepository.startListening(
        onResult: (recognizedText) {
          add(VoiceRecognizedEvent(recognizedText));
        },
        onError: (errorMessage) {
          add(VoiceErrorEvent(errorMessage));
        },
        onPartialResult: (partialText) {
          emit(VoiceListeningState(partialResult: partialText));
        },
      );
    } catch (e) {
      AppLogger.error('Error starting voice listening: $e');
      emit(VoiceErrorState(
        errorMessage: 'Failed to start listening: $e',
        errorCode: 'START_LISTEN_ERROR',
      ));
    }
  }

  /// Stop listening for voice input
  Future<void> _onStopListening(
      StopListeningEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.stopListening();
      emit(const VoiceStoppedState());
    } catch (e) {
      AppLogger.error('Error stopping voice listening: $e');
      emit(VoiceErrorState(
        errorMessage: 'Failed to stop listening: $e',
        errorCode: 'STOP_LISTEN_ERROR',
      ));
    }
  }

  /// Cancel voice recognition
  Future<void> _onCancelVoice(
      CancelVoiceEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.cancelListening();
      emit(const VoiceCancelledState());
    } catch (e) {
      AppLogger.error('Error cancelling voice: $e');
      emit(VoiceErrorState(
        errorMessage: 'Failed to cancel voice recognition: $e',
        errorCode: 'CANCEL_VOICE_ERROR',
      ));
    }
  }

  /// Handle recognized voice text
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

  /// Handle voice error
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

  /// Check microphone permission
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

  /// Request microphone permission
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
        emit(const VoicePermissionDeniedState(
          reason: 'Microphone permission was denied. Please enable it in settings.',
        ));
      }
    } catch (e) {
      AppLogger.error('Error requesting voice permission: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to request permission: $e'));
    }
  }

  /// Reset voice state to initial
  Future<void> _onResetVoice(
      ResetVoiceEvent event,
      Emitter<VoiceState> emit,
      ) async {
    try {
      await voiceRepository.cancelListening();
      emit(const VoiceInitialState());
    } catch (e) {
      AppLogger.error('Error resetting voice: $e');
      emit(VoiceErrorState(errorMessage: 'Failed to reset voice: $e'));
    }
  }

}
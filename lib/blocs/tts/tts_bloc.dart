import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/tts/tts_event.dart';
import 'package:ringtask/blocs/tts/tts_state.dart';
import 'package:ringtask/repositories/tts_repository.dart' hide TtsState;
import 'dart:developer' as developer;

/// Bloc responsible for managing Text-to-Speech functionality
/// Handles speech synthesis, playback control, and notification reading
class TtsBloc extends Bloc<TtsEvent, TtsState> {
  final TtsRepository _ttsRepository;

  TtsBloc({
    required TtsRepository ttsRepository,
  })  : _ttsRepository = ttsRepository,
        super(const TtsInitial()) {
    on<InitializeTts>(_onInitializeTts);
    on<SpeakText>(_onSpeakText);
    on<SpeakTask>(_onSpeakTask);
    on<PauseSpeech>(_onPauseSpeech);
    on<ResumeSpeech>(_onResumeSpeech);
    on<StopSpeech>(_onStopSpeech);
    on<SetSpeechRate>(_onSetSpeechRate);
    on<SetSpeechPitch>(_onSetSpeechPitch);
    on<SetSpeechVolume>(_onSetSpeechVolume);
    on<SetLanguage>(_onSetLanguage);
    on<GetAvailableLanguages>(_onGetAvailableLanguages);
    on<GetAvailableVoices>(_onGetAvailableVoices);
    on<SetVoice>(_onSetVoice);
    on<CheckTtsAvailability>(_onCheckTtsAvailability);
    on<DisposeTts>(_onDisposeTts);
  }

  /// Initialize TTS engine
  Future<void> _onInitializeTts(
      InitializeTts event,
      Emitter<TtsState> emit,
      ) async {
    try {
      emit(const TtsLoading());

      await _ttsRepository.initialize();

      final isAvailable = await _ttsRepository.isTtsAvailable();

      if (!isAvailable) {
        emit(TtsError('Text-to-Speech is not available on this device'));
        return;
      }

      // Get default configuration
      final languages = await _ttsRepository.getAvailableLanguages();
      final voices = await _ttsRepository.getAvailableVoices();
      final currentLanguage = await _ttsRepository.getCurrentLanguage();

      emit(TtsInitialized(
        isAvailable: true,
        availableLanguages: languages,
        availableVoices: voices,
        currentLanguage: currentLanguage ??"English",
        rate: 0.5,
        pitch: 1.0,
        volume: 1.0,
      ));

      developer.log('TTS initialized successfully', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to initialize TTS', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to initialize TTS: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Speak the provided text
  Future<void> _onSpeakText(
      SpeakText event,
      Emitter<TtsState> emit,
      ) async {
    try {
      if (state is! TtsInitialized && state is! TtsSpeaking && state is! TtsPaused) {
        emit(TtsError('TTS not initialized'));
        return;
      }

      emit(_copyWithSpeaking(isSpeaking: true, currentText: event.text));

      await _ttsRepository.speak(event.text);

      emit(_copyWithSpeaking(isSpeaking: false, currentText: null));

      developer.log('Finished speaking: ${event.text}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to speak text', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to speak: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Speak task notification
  Future<void> _onSpeakTask(
      SpeakTask event,
      Emitter<TtsState> emit,
      ) async {
    try {
      if (state is! TtsInitialized && state is! TtsSpeaking && state is! TtsPaused) {
        emit(TtsError('TTS not initialized'));
        return;
      }

      final taskText = 'Task reminder: ${event.taskTitle}. '
          'Scheduled for ${event.taskDate}.';

      emit(_copyWithSpeaking(isSpeaking: true, currentText: taskText));

      await _ttsRepository.speak(taskText);

      emit(_copyWithSpeaking(isSpeaking: false, currentText: null));

      developer.log('Task notification spoken: ${event.taskTitle}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to speak task', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to speak task: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Pause ongoing speech
  Future<void> _onPauseSpeech(
      PauseSpeech event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.pause();

      if (state is TtsSpeaking) {
        final currentState = state as TtsSpeaking;
        emit(TtsPaused(
          isAvailable: currentState.isAvailable,
          availableLanguages: currentState.availableLanguages,
          availableVoices: currentState.availableVoices,
          currentLanguage: currentState.currentLanguage,
          rate: currentState.rate,
          pitch: currentState.pitch,
          volume: currentState.volume,
          currentText: currentState.currentText,
        ));
      }

      developer.log('Speech paused', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to pause speech', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to pause: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Resume paused speech
  Future<void> _onResumeSpeech(
      ResumeSpeech event,
      Emitter<TtsState> emit,
      ) async {
    try {
      if (state is! TtsPaused) {
        return;
      }

      final pausedState = state as TtsPaused;

      emit(TtsSpeaking(
        isAvailable: pausedState.isAvailable,
        availableLanguages: pausedState.availableLanguages,
        availableVoices: pausedState.availableVoices,
        currentLanguage: pausedState.currentLanguage,
        rate: pausedState.rate,
        pitch: pausedState.pitch,
        volume: pausedState.volume,
        currentText: pausedState.currentText,
      ));

      // Note: Some TTS engines don't support resume, might need to re-speak
      await _ttsRepository.speak(pausedState.currentText ?? '');

      developer.log('Speech resumed', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to resume speech', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to resume: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Stop ongoing speech
  Future<void> _onStopSpeech(
      StopSpeech event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.stop();

      if (state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(TtsInitialized(
          isAvailable: currentState.isAvailable,
          availableLanguages: currentState.availableLanguages,
          availableVoices: currentState.availableVoices,
          currentLanguage: currentState.currentLanguage,
          rate: currentState.rate,
          pitch: currentState.pitch,
          volume: currentState.volume,
        ));
      }

      developer.log('Speech stopped', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to stop speech', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to stop: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> _onSetSpeechRate(
      SetSpeechRate event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setSpeechRate(event.rate);

      if (state is TtsInitialized || state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(_copyStateWithNewRate(currentState, event.rate));
      }

      developer.log('Speech rate set to: ${event.rate}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to set speech rate', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to set rate: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Set speech pitch (0.5 to 2.0)
  Future<void> _onSetSpeechPitch(
      SetSpeechPitch event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setPitch(event.pitch);

      if (state is TtsInitialized || state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(_copyStateWithNewPitch(currentState, event.pitch));
      }

      developer.log('Speech pitch set to: ${event.pitch}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to set speech pitch', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to set pitch: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Set speech volume (0.0 to 1.0)
  Future<void> _onSetSpeechVolume(
      SetSpeechVolume event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setVolume(event.volume);

      if (state is TtsInitialized || state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(_copyStateWithNewVolume(currentState, event.volume));
      }

      developer.log('Speech volume set to: ${event.volume}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to set speech volume', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to set volume: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Set speech language
  Future<void> _onSetLanguage(
      SetLanguage event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setLanguage(event.languageCode);

      if (state is TtsInitialized || state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(_copyStateWithNewLanguage(currentState, event.languageCode));
      }

      developer.log('Language set to: ${event.languageCode}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to set language', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to set language: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Get available languages
  Future<void> _onGetAvailableLanguages(
      GetAvailableLanguages event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final languages = await _ttsRepository.getAvailableLanguages();

      if (state is TtsInitialized || state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(_copyStateWithLanguages(currentState, languages));
      }

      developer.log('Retrieved ${languages.length} available languages', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to get languages', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to get languages: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Get available voices
  Future<void> _onGetAvailableVoices(
      GetAvailableVoices event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final voices = await _ttsRepository.getAvailableVoices();

      if (state is TtsInitialized || state is TtsSpeaking || state is TtsPaused) {
        final currentState = state as dynamic;
        emit(_copyStateWithVoices(currentState, voices));
      }

      developer.log('Retrieved ${voices.length} available voices', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to get voices', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to get voices: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Set voice
  Future<void> _onSetVoice(
      SetVoice event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setVoice(event.voiceName);

      developer.log('Voice set to: ${event.voiceName}', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to set voice', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to set voice: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Check TTS availability
  Future<void> _onCheckTtsAvailability(
      CheckTtsAvailability event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final isAvailable = await _ttsRepository.isTtsAvailable();

      if (!isAvailable) {
        emit(TtsError('Text-to-Speech is not available'));
        return;
      }

      developer.log('TTS is available', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to check TTS availability', name: 'TtsBloc', error: e, stackTrace: stackTrace);
      emit(TtsError('Failed to check availability: ${e.toString()}', error: e, stackTrace: stackTrace));
    }
  }

  /// Dispose TTS resources
  Future<void> _onDisposeTts(
      DisposeTts event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.dispose();
      emit(const TtsInitial());

      developer.log('TTS disposed', name: 'TtsBloc');
    } catch (e, stackTrace) {
      developer.log('Failed to dispose TTS', name: 'TtsBloc', error: e, stackTrace: stackTrace);
    }
  }

  // Helper methods to copy state with updated properties
  TtsState _copyWithSpeaking({required bool isSpeaking, String? currentText}) {
    final currentState = state as dynamic;
    if (isSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
      );
    }
  }

  TtsState _copyStateWithNewRate(dynamic currentState, double rate) {
    if (currentState is TtsSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else if (currentState is TtsPaused) {
      return TtsPaused(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
      );
    }
  }

  TtsState _copyStateWithNewPitch(dynamic currentState, double pitch) {
    if (currentState is TtsSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else if (currentState is TtsPaused) {
      return TtsPaused(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: pitch,
        volume: currentState.volume,
      );
    }
  }

  TtsState _copyStateWithNewVolume(dynamic currentState, double volume) {
    if (currentState is TtsSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: volume,
        currentText: currentState.currentText,
      );
    } else if (currentState is TtsPaused) {
      return TtsPaused(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: volume,
        currentText: currentState.currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: volume,
      );
    }
  }

  TtsState _copyStateWithNewLanguage(dynamic currentState, String language) {
    if (currentState is TtsSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: language,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else if (currentState is TtsPaused) {
      return TtsPaused(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: language,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: currentState.availableVoices,
        currentLanguage: language,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
      );
    }
  }

  TtsState _copyStateWithLanguages(dynamic currentState, List<String> languages) {
    if (currentState is TtsSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: languages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else if (currentState is TtsPaused) {
      return TtsPaused(
        isAvailable: currentState.isAvailable,
        availableLanguages: languages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: languages,
        availableVoices: currentState.availableVoices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
      );
    }
  }

  TtsState _copyStateWithVoices(dynamic currentState, List<String> voices) {
    if (currentState is TtsSpeaking) {
      return TtsSpeaking(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: voices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else if (currentState is TtsPaused) {
      return TtsPaused(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: voices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
        currentText: currentState.currentText,
      );
    } else {
      return TtsInitialized(
        isAvailable: currentState.isAvailable,
        availableLanguages: currentState.availableLanguages,
        availableVoices: voices,
        currentLanguage: currentState.currentLanguage,
        rate: currentState.rate,
        pitch: currentState.pitch,
        volume: currentState.volume,
      );
    }
  }

  @override
  Future<void> close() {
    _ttsRepository.dispose();
    return super.close();
  }
}
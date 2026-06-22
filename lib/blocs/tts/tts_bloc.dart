import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/tts/tts_event.dart';
import 'package:ringtask/blocs/tts/tts_state.dart';
import 'package:ringtask/repositories/tts_repository.dart' hide TtsState;
import 'dart:developer' as developer;

class TtsBloc extends Bloc<TtsEvent, TtsState> {
  final TtsRepository _ttsRepository;

  TtsBloc({required TtsRepository ttsRepository})
      : _ttsRepository = ttsRepository,
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Safely extract the base config from any ready state.
  /// Returns null if TTS is not yet initialized.
  TtsReadyState? get _readyState {
    final s = state;
    if (s is TtsInitialized) return s;
    if (s is TtsSpeaking) return s;
    if (s is TtsPaused) return s;
    return null;
  }

  /// Auto-initialize if not already done, then speak.
  /// This is the key fix — callers no longer need to manually send
  /// InitializeTts before SpeakText/SpeakTask.
  Future<bool> _ensureInitialized(Emitter<TtsState> emit) async {
    if (_readyState != null) return true;

    developer.log('Auto-initializing TTS before speak', name: 'TtsBloc');
    await _onInitializeTts(InitializeTts(), emit);

    // After initialization, check if we're in a ready state
    return _readyState != null;
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

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

      final languages = await _ttsRepository.getAvailableLanguages();
      final voices = await _ttsRepository.getAvailableVoices();
      final currentLanguage = await _ttsRepository.getCurrentLanguage();

      emit(TtsInitialized(
        isAvailable: true,
        availableLanguages: languages,
        availableVoices: voices,
        currentLanguage: currentLanguage ?? 'en-US',
        rate: 0.5,
        pitch: 1.0,
        volume: 1.0,
      ));

      developer.log('TTS initialized successfully', name: 'TtsBloc');
    } catch (e, st) {
      developer.log('Failed to initialize TTS', name: 'TtsBloc', error: e, stackTrace: st);
      emit(TtsError('Failed to initialize TTS: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSpeakText(
      SpeakText event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final initialized = await _ensureInitialized(emit);
      if (!initialized) return;

      final ready = _readyState!;

      // ✅ Only stop if we are currently mid-speech — not unconditionally.
      // Calling stop() when idle kills any utterance already in progress
      // on the shared Android TTS engine (e.g. FakeCallService speaking).
      if (state is TtsSpeaking) {
        await _ttsRepository.stop();
      }

      emit(TtsSpeaking(
        isAvailable: ready.isAvailable,
        availableLanguages: ready.availableLanguages,
        availableVoices: ready.availableVoices,
        currentLanguage: ready.currentLanguage,
        rate: ready.rate,
        pitch: ready.pitch,
        volume: ready.volume,
        currentText: event.text,
      ));

      await _ttsRepository.speak(event.text);
      developer.log('Speak requested: ${event.text}', name: 'TtsBloc');
    } catch (e, st) {
      developer.log('Failed to speak text', name: 'TtsBloc', error: e, stackTrace: st);
      emit(TtsError('Failed to speak: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSpeakTask(
      SpeakTask event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final initialized = await _ensureInitialized(emit);
      if (!initialized) return;

      final ready = _readyState!;

      // ✅ Same fix — only stop if mid-speech
      if (state is TtsSpeaking) {
        await _ttsRepository.stop();
      }

      final taskText = StringBuffer();
      taskText.write('Task reminder. ');
      taskText.write('${event.taskTitle}. ');
      if (event.taskDate.isNotEmpty) {
        taskText.write('Scheduled for ${event.taskDate}.');
      }
      final text = taskText.toString();

      emit(TtsSpeaking(
        isAvailable: ready.isAvailable,
        availableLanguages: ready.availableLanguages,
        availableVoices: ready.availableVoices,
        currentLanguage: ready.currentLanguage,
        rate: ready.rate,
        pitch: ready.pitch,
        volume: ready.volume,
        currentText: text,
      ));

      await _ttsRepository.speak(text);
      developer.log('Task spoken: ${event.taskTitle}', name: 'TtsBloc');
    } catch (e, st) {
      developer.log('Failed to speak task', name: 'TtsBloc', error: e, stackTrace: st);
      emit(TtsError('Failed to speak task: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onPauseSpeech(
      PauseSpeech event,
      Emitter<TtsState> emit,
      ) async {
    try {
      if (state is! TtsSpeaking) return;
      final s = state as TtsSpeaking;
      await _ttsRepository.pause();
      emit(TtsPaused(
        isAvailable: s.isAvailable,
        availableLanguages: s.availableLanguages,
        availableVoices: s.availableVoices,
        currentLanguage: s.currentLanguage,
        rate: s.rate,
        pitch: s.pitch,
        volume: s.volume,
        currentText: s.currentText,
      ));
      developer.log('Speech paused', name: 'TtsBloc');
    } catch (e, st) {
      emit(TtsError('Failed to pause: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onResumeSpeech(
      ResumeSpeech event,
      Emitter<TtsState> emit,
      ) async {
    try {
      if (state is! TtsPaused) return;
      final s = state as TtsPaused;

      emit(TtsSpeaking(
        isAvailable: s.isAvailable,
        availableLanguages: s.availableLanguages,
        availableVoices: s.availableVoices,
        currentLanguage: s.currentLanguage,
        rate: s.rate,
        pitch: s.pitch,
        volume: s.volume,
        currentText: s.currentText,
      ));

      // flutter_tts doesn't support true resume — re-speak from beginning
      await _ttsRepository.speak(s.currentText ?? '');
      developer.log('Speech resumed (re-speaking)', name: 'TtsBloc');
    } catch (e, st) {
      emit(TtsError('Failed to resume: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onStopSpeech(
      StopSpeech event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.stop();
      final ready = _readyState;
      if (ready != null) {
        emit(TtsInitialized(
          isAvailable: ready.isAvailable,
          availableLanguages: ready.availableLanguages,
          availableVoices: ready.availableVoices,
          currentLanguage: ready.currentLanguage,
          rate: ready.rate,
          pitch: ready.pitch,
          volume: ready.volume,
        ));
      }
      developer.log('Speech stopped', name: 'TtsBloc');
    } catch (e, st) {
      emit(TtsError('Failed to stop: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSetSpeechRate(
      SetSpeechRate event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setSpeechRate(event.rate);
      final ready = _readyState;
      if (ready != null) emit(ready.copyWith(rate: event.rate));
    } catch (e, st) {
      emit(TtsError('Failed to set rate: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSetSpeechPitch(
      SetSpeechPitch event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setPitch(event.pitch);
      final ready = _readyState;
      if (ready != null) emit(ready.copyWith(pitch: event.pitch));
    } catch (e, st) {
      emit(TtsError('Failed to set pitch: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSetSpeechVolume(
      SetSpeechVolume event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setVolume(event.volume);
      final ready = _readyState;
      if (ready != null) emit(ready.copyWith(volume: event.volume));
    } catch (e, st) {
      emit(TtsError('Failed to set volume: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSetLanguage(
      SetLanguage event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setLanguage(event.languageCode);
      final ready = _readyState;
      if (ready != null) emit(ready.copyWith(currentLanguage: event.languageCode));
    } catch (e, st) {
      emit(TtsError('Failed to set language: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onGetAvailableLanguages(
      GetAvailableLanguages event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final languages = await _ttsRepository.getAvailableLanguages();
      final ready = _readyState;
      if (ready != null) emit(ready.copyWith(availableLanguages: languages));
    } catch (e, st) {
      emit(TtsError('Failed to get languages: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onGetAvailableVoices(
      GetAvailableVoices event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final voices = await _ttsRepository.getAvailableVoices();
      final ready = _readyState;
      if (ready != null) emit(ready.copyWith(availableVoices: voices));
    } catch (e, st) {
      emit(TtsError('Failed to get voices: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onSetVoice(
      SetVoice event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.setVoice(event.voiceName);
      developer.log('Voice set to: ${event.voiceName}', name: 'TtsBloc');
    } catch (e, st) {
      emit(TtsError('Failed to set voice: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onCheckTtsAvailability(
      CheckTtsAvailability event,
      Emitter<TtsState> emit,
      ) async {
    try {
      final isAvailable = await _ttsRepository.isTtsAvailable();
      if (!isAvailable) emit(TtsError('Text-to-Speech is not available'));
    } catch (e, st) {
      emit(TtsError('Failed to check availability: $e', error: e, stackTrace: st));
    }
  }

  Future<void> _onDisposeTts(
      DisposeTts event,
      Emitter<TtsState> emit,
      ) async {
    try {
      await _ttsRepository.stop();
      await _ttsRepository.dispose();
      emit(const TtsInitial());
    } catch (e, st) {
      developer.log('Failed to dispose TTS', name: 'TtsBloc', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> close() async {
    // ✅ Stop speech before closing — prevents repository disposal
    // under an in-flight speak() call
    try {
      await _ttsRepository.stop();
      await _ttsRepository.dispose();
    } catch (_) {}
    return super.close();
  }
}
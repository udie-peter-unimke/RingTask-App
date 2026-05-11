// lib/blocs/tts/tts_settings_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/repositories/settings_repository.dart';
import 'package:ringtask/repositories/tts_repository.dart';

import 'tts_settings_event.dart';
import 'tts_settings_state.dart';

/// Bloc responsible for managing TTS notification settings
class TtsSettingsBloc extends Bloc<TtsSettingsEvent, TtsSettingsState> {
  final SettingsRepository _settingsRepository;
  final TtsRepository _ttsRepository;

  TtsSettingsBloc({
    required SettingsRepository settingsRepository,
    required TtsRepository ttsRepository,
  })  : _settingsRepository = settingsRepository,
        _ttsRepository = ttsRepository,
        super(const TtsSettingsInitial()) {
    on<LoadTtsSettings>(_onLoadSettings);
    on<UpdateEnableTts>(_onUpdateEnableTts);
    on<UpdateReadTitle>(_onUpdateReadTitle);
    on<UpdateReadDescription>(_onUpdateReadDescription);
    on<UpdateScheduleInterval>(_onUpdateScheduleInterval);
    on<PauseSpeech>(_onPauseSpeech);
    on<StopSpeech>(_onStopSpeech);
  }

  Future<void> _onLoadSettings(
      LoadTtsSettings event,
      Emitter<TtsSettingsState> emit,
      ) async {
    try {
      final settings = await _settingsRepository.getSettings();

      emit(TtsSettings(
        enableTts: settings.ttsEnabled,
        readTitle: settings.readTitle,
        readDescription: settings.readDescription,
        scheduleInterval: settings.scheduleInterval,
      ));
    } catch (e) {
      emit(TtsSettingsError('Failed to load TTS settings: $e'));
    }
  }

  Future<void> _onUpdateEnableTts(
      UpdateEnableTts event,
      Emitter<TtsSettingsState> emit,
      ) async {
    final current = await _settingsRepository.getSettings();
    final updated = current.copyWith(ttsEnabled: event.value);
    await _settingsRepository.updateSettings(updated);

    if (state is TtsSettings) {
      emit((state as TtsSettings).copyWith(enableTts: event.value));
    }
  }

  Future<void> _onUpdateReadTitle(
      UpdateReadTitle event,
      Emitter<TtsSettingsState> emit,
      ) async {
    final current = await _settingsRepository.getSettings();
    final updated = current.copyWith(readTitle: event.value);
    await _settingsRepository.updateSettings(updated);

    if (state is TtsSettings) {
      emit((state as TtsSettings).copyWith(readTitle: event.value));
    }
  }

  Future<void> _onUpdateReadDescription(
      UpdateReadDescription event,
      Emitter<TtsSettingsState> emit,
      ) async {
    final current = await _settingsRepository.getSettings();
    final updated = current.copyWith(readDescription: event.value);
    await _settingsRepository.updateSettings(updated);

    if (state is TtsSettings) {
      emit((state as TtsSettings).copyWith(readDescription: event.value));
    }
  }

  Future<void> _onUpdateScheduleInterval(
      UpdateScheduleInterval event,
      Emitter<TtsSettingsState> emit,
      ) async {
    final current = await _settingsRepository.getSettings();
    final updated = current.copyWith(scheduleInterval: event.value);
    await _settingsRepository.updateSettings(updated);

    if (state is TtsSettings) {
      emit((state as TtsSettings).copyWith(scheduleInterval: event.value));
    }
  }

  Future<void> _onPauseSpeech(PauseSpeech event, Emitter<TtsSettingsState> emit) async {
    try {
      await _ttsRepository.pause();
    } catch (e) {
      emit(TtsSettingsError('Failed to pause speech: $e'));
    }
  }

  Future<void> _onStopSpeech(StopSpeech event, Emitter<TtsSettingsState> emit) async {
    try {
      await _ttsRepository.stop();
    } catch (e) {
      emit(TtsSettingsError('Failed to stop speech: $e'));
    }
  }
}
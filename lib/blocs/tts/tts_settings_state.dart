// lib/blocs/tts/tts_settings_state.dart

abstract class TtsSettingsState {
  const TtsSettingsState();
}

class TtsSettingsInitial extends TtsSettingsState {
  const TtsSettingsInitial();
}

class TtsSettings extends TtsSettingsState {
  final bool enableTts;
  final bool readTitle;
  final bool readDescription;
  final String scheduleInterval;

  const TtsSettings({
    this.enableTts = true,
    this.readTitle = true,
    this.readDescription = true,
    this.scheduleInterval = 'Every 15 minutes',
  });

  TtsSettings copyWith({
    bool? enableTts,
    bool? readTitle,
    bool? readDescription,
    String? scheduleInterval,
  }) {
    return TtsSettings(
      enableTts: enableTts ?? this.enableTts,
      readTitle: readTitle ?? this.readTitle,
      readDescription: readDescription ?? this.readDescription,
      scheduleInterval: scheduleInterval ?? this.scheduleInterval,
    );
  }
}

class TtsSettingsError extends TtsSettingsState {
  final String message;
  const TtsSettingsError(this.message);
}

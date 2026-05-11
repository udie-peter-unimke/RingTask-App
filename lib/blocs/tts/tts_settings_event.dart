// lib/blocs/tts/tts_settings_event.dart

abstract class TtsSettingsEvent {
  const TtsSettingsEvent();
}

class LoadTtsSettings extends TtsSettingsEvent {
  const LoadTtsSettings();
}

class UpdateEnableTts extends TtsSettingsEvent {
  final bool value;
  const UpdateEnableTts(this.value);
}

class UpdateReadTitle extends TtsSettingsEvent {
  final bool value;
  const UpdateReadTitle(this.value);
}

class UpdateReadDescription extends TtsSettingsEvent {
  final bool value;
  const UpdateReadDescription(this.value);
}

class UpdateScheduleInterval extends TtsSettingsEvent {
  final String value;
  const UpdateScheduleInterval(this.value);
}

class PauseSpeech extends TtsSettingsEvent {
  const PauseSpeech();
}

class StopSpeech extends TtsSettingsEvent {
  const StopSpeech();
}
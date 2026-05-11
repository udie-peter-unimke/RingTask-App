import 'package:equatable/equatable.dart';

/// Base class for all TTS events
abstract class TtsEvent extends Equatable {
  const TtsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the TTS engine
class InitializeTts extends TtsEvent {
  const InitializeTts();
}

/// Event to speak a given text
class SpeakText extends TtsEvent {
  final String text;

  const SpeakText(this.text);

  @override
  List<Object?> get props => [text];
}

/// Event to speak a task notification
class SpeakTask extends TtsEvent {
  final String taskTitle;
  final String taskDate;

  const SpeakTask({
    required this.taskTitle,
    required this.taskDate,
  });

  @override
  List<Object?> get props => [taskTitle, taskDate];
}

/// Event to pause ongoing speech
class PauseSpeech extends TtsEvent {
  const PauseSpeech();
}

/// Event to resume paused speech
class ResumeSpeech extends TtsEvent {
  const ResumeSpeech();
}

/// Event to stop ongoing speech
class StopSpeech extends TtsEvent {
  const StopSpeech();
}

/// Event to set the speech rate
/// Rate value typically ranges from 0.0 (slowest) to 1.0 (fastest)
class SetSpeechRate extends TtsEvent {
  final double rate;

  const SetSpeechRate(this.rate);

  @override
  List<Object?> get props => [rate];
}

/// Event to set the speech pitch
/// Pitch value typically ranges from 0.5 (lowest) to 2.0 (highest)
class SetSpeechPitch extends TtsEvent {
  final double pitch;

  const SetSpeechPitch(this.pitch);

  @override
  List<Object?> get props => [pitch];
}

/// Event to set the speech volume
/// Volume value ranges from 0.0 (silent) to 1.0 (maximum)
class SetSpeechVolume extends TtsEvent {
  final double volume;

  const SetSpeechVolume(this.volume);

  @override
  List<Object?> get props => [volume];
}

/// Event to set the speech language
class SetLanguage extends TtsEvent {
  final String languageCode;

  const SetLanguage(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

/// Event to get all available languages
class GetAvailableLanguages extends TtsEvent {
  const GetAvailableLanguages();
}

/// Event to get all available voices
class GetAvailableVoices extends TtsEvent {
  const GetAvailableVoices();
}

/// Event to set a specific voice
class SetVoice extends TtsEvent {
  final String voiceName;

  const SetVoice(this.voiceName);

  @override
  List<Object?> get props => [voiceName];
}

/// Event to check if TTS is available on the device
class CheckTtsAvailability extends TtsEvent {
  const CheckTtsAvailability();
}

/// Event to dispose TTS resources
class DisposeTts extends TtsEvent {
  const DisposeTts();
}
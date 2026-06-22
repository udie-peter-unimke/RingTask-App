import 'package:equatable/equatable.dart';

abstract class VoiceEvent extends Equatable {
  const VoiceEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize voice recognition
class InitializeVoiceEvent extends VoiceEvent {
  const InitializeVoiceEvent();
}

/// Event to start listening for voice input
class StartListeningEvent extends VoiceEvent {
  const StartListeningEvent();
}

/// Event to stop listening for voice input
class StopListeningEvent extends VoiceEvent {
  const StopListeningEvent();
}

/// Event to cancel voice recognition
class CancelVoiceEvent extends VoiceEvent {
  const CancelVoiceEvent();
}

/// Event when voice input is recognized
class VoiceRecognizedEvent extends VoiceEvent {
  final String recognizedText;

  const VoiceRecognizedEvent(this.recognizedText);

  @override
  List<Object?> get props => [recognizedText];
}

/// Event when voice recognition encounters an error
class VoiceErrorEvent extends VoiceEvent {
  final String errorMessage;

  const VoiceErrorEvent(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

/// Event to check voice permission status
class CheckVoicePermissionEvent extends VoiceEvent {
  const CheckVoicePermissionEvent();
}

/// Event to request voice permission
class RequestVoicePermissionEvent extends VoiceEvent {
  const RequestVoicePermissionEvent();
}

/// Event to reset voice state
class ResetVoiceEvent extends VoiceEvent {
  const ResetVoiceEvent();
}

/// Event to open app settings for permissions
class OpenVoiceSettingsEvent extends VoiceEvent {
  const OpenVoiceSettingsEvent();
}

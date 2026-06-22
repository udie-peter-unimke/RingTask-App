import 'package:equatable/equatable.dart';

abstract class VoiceState extends Equatable {
  const VoiceState();

  @override
  List<Object?> get props => [];
}

/// Initial state of voice recognition
class VoiceInitialState extends VoiceState {
  const VoiceInitialState();
}

/// State when voice recognition is being initialized
class VoiceInitializingState extends VoiceState {
  const VoiceInitializingState();
}

/// State when voice recognition is ready
class VoiceReadyState extends VoiceState {
  const VoiceReadyState();
}

/// State when actively listening for voice input
class VoiceListeningState extends VoiceState {
  final String? partialResult;

  const VoiceListeningState({this.partialResult});

  @override
  List<Object?> get props => [partialResult];
}

/// State when voice input has been recognized
class VoiceRecognizedState extends VoiceState {
  final String recognizedText;
  final double confidence;

  const VoiceRecognizedState({
    required this.recognizedText,
    this.confidence = 1.0,
  });

  @override
  List<Object?> get props => [recognizedText, confidence];
}

/// State when voice recognition has stopped
class VoiceStoppedState extends VoiceState {
  final String? lastRecognizedText;

  const VoiceStoppedState({this.lastRecognizedText});

  @override
  List<Object?> get props => [lastRecognizedText];
}

/// State when voice recognition encounters an error
class VoiceErrorState extends VoiceState {
  final String errorMessage;
  final String? errorCode;

  const VoiceErrorState({
    required this.errorMessage,
    this.errorCode,
  });

  @override
  List<Object?> get props => [errorMessage, errorCode];
}

/// State when voice permission is checking
class VoicePermissionCheckingState extends VoiceState {
  const VoicePermissionCheckingState();
}

/// State when voice permission is granted
class VoicePermissionGrantedState extends VoiceState {
  const VoicePermissionGrantedState();
}

/// State when voice permission is denied
class VoicePermissionDeniedState extends VoiceState {
  final String reason;
  final bool isPermanentlyDenied;

  const VoicePermissionDeniedState({
    this.reason = 'Microphone permission is required',
    this.isPermanentlyDenied = false,
  });

  @override
  List<Object?> get props => [reason, isPermanentlyDenied];
}

/// State when voice is unavailable on device
class VoiceUnavailableState extends VoiceState {
  final String reason;

  const VoiceUnavailableState({
    this.reason = 'Voice recognition is not available on this device',
  });

  @override
  List<Object?> get props => [reason];
}

/// State when voice recognition is cancelled
class VoiceCancelledState extends VoiceState {
  const VoiceCancelledState();
}
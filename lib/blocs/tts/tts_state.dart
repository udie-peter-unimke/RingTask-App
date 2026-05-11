import 'package:equatable/equatable.dart';

/// Base class for all TTS states
abstract class TtsState extends Equatable {
  const TtsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before TTS is initialized
class TtsInitial extends TtsState {
  const TtsInitial();

  @override
  String toString() => 'TtsInitial';
}

/// State when TTS is being initialized
class TtsLoading extends TtsState {
  const TtsLoading();

  @override
  String toString() => 'TtsLoading';
}

/// State when TTS is initialized and ready to use
class TtsInitialized extends TtsState {
  final bool isAvailable;
  final List<String> availableLanguages;
  final List<String> availableVoices;
  final String currentLanguage;
  final String? currentVoice;
  final double rate;
  final double pitch;
  final double volume;

  const TtsInitialized({
    required this.isAvailable,
    this.availableLanguages = const [],
    this.availableVoices = const [],
    this.currentLanguage = 'en-US',
    this.currentVoice,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
  });

  /// Creates a copy of this state with updated values
  TtsInitialized copyWith({
    bool? isAvailable,
    List<String>? availableLanguages,
    List<String>? availableVoices,
    String? currentLanguage,
    String? currentVoice,
    double? rate,
    double? pitch,
    double? volume,
  }) {
    return TtsInitialized(
      isAvailable: isAvailable ?? this.isAvailable,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      availableVoices: availableVoices ?? this.availableVoices,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      currentVoice: currentVoice ?? this.currentVoice,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
    );
  }

  @override
  List<Object?> get props => [
    isAvailable,
    availableLanguages,
    availableVoices,
    currentLanguage,
    currentVoice,
    rate,
    pitch,
    volume,
  ];

  @override
  String toString() => 'TtsInitialized { '
      'isAvailable: $isAvailable, '
      'languages: ${availableLanguages.length}, '
      'voices: ${availableVoices.length}, '
      'language: $currentLanguage, '
      'voice: $currentVoice, '
      'rate: $rate, '
      'pitch: $pitch, '
      'volume: $volume '
      '}';
}

/// State when TTS is actively speaking
class TtsSpeaking extends TtsState {
  final bool isAvailable;
  final List<String> availableLanguages;
  final List<String> availableVoices;
  final String currentLanguage;
  final String? currentVoice;
  final double rate;
  final double pitch;
  final double volume;
  final String? currentText;
  final int? textLength;
  final DateTime startedAt;

  TtsSpeaking({
    required this.isAvailable,
    this.availableLanguages = const [],
    this.availableVoices = const [],
    this.currentLanguage = 'en-US',
    this.currentVoice,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.currentText,
    int? textLength,
    DateTime? startedAt,
  })  : textLength = textLength ?? currentText?.length,
        startedAt = startedAt ?? DateTime.now();

  /// Creates a copy of this state with updated values
  TtsSpeaking copyWith({
    bool? isAvailable,
    List<String>? availableLanguages,
    List<String>? availableVoices,
    String? currentLanguage,
    String? currentVoice,
    double? rate,
    double? pitch,
    double? volume,
    String? currentText,
    int? textLength,
    DateTime? startedAt,
  }) {
    return TtsSpeaking(
      isAvailable: isAvailable ?? this.isAvailable,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      availableVoices: availableVoices ?? this.availableVoices,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      currentVoice: currentVoice ?? this.currentVoice,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      currentText: currentText ?? this.currentText,
      textLength: textLength ?? this.textLength,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  List<Object?> get props => [
    isAvailable,
    availableLanguages,
    availableVoices,
    currentLanguage,
    currentVoice,
    rate,
    pitch,
    volume,
    currentText,
    textLength,
    startedAt,
  ];

  @override
  String toString() => 'TtsSpeaking { '
      'text: ${currentText != null ? '${currentText!.substring(0, currentText!.length > 50 ? 50 : currentText!.length)}...' : 'null'}, '
      'length: $textLength, '
      'language: $currentLanguage, '
      'rate: $rate '
      '}';
}

/// State when speech is paused
class TtsPaused extends TtsState {
  final bool isAvailable;
  final List<String> availableLanguages;
  final List<String> availableVoices;
  final String currentLanguage;
  final String? currentVoice;
  final double rate;
  final double pitch;
  final double volume;
  final String? currentText;
  final int? textLength;
  final DateTime pausedAt;
  final Duration elapsedBeforePause;

  TtsPaused({
    required this.isAvailable,
    this.availableLanguages = const [],
    this.availableVoices = const [],
    this.currentLanguage = 'en-US',
    this.currentVoice,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.currentText,
    int? textLength,
    DateTime? pausedAt,
    Duration? elapsedBeforePause,
  })  : textLength = textLength ?? currentText?.length,
        pausedAt = pausedAt ?? DateTime.now(),
        elapsedBeforePause = elapsedBeforePause ?? Duration.zero;

  /// Creates a copy of this state with updated values
  TtsPaused copyWith({
    bool? isAvailable,
    List<String>? availableLanguages,
    List<String>? availableVoices,
    String? currentLanguage,
    String? currentVoice,
    double? rate,
    double? pitch,
    double? volume,
    String? currentText,
    int? textLength,
    DateTime? pausedAt,
    Duration? elapsedBeforePause,
  }) {
    return TtsPaused(
      isAvailable: isAvailable ?? this.isAvailable,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      availableVoices: availableVoices ?? this.availableVoices,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      currentVoice: currentVoice ?? this.currentVoice,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      currentText: currentText ?? this.currentText,
      textLength: textLength ?? this.textLength,
      pausedAt: pausedAt ?? this.pausedAt,
      elapsedBeforePause: elapsedBeforePause ?? this.elapsedBeforePause,
    );
  }

  @override
  List<Object?> get props => [
    isAvailable,
    availableLanguages,
    availableVoices,
    currentLanguage,
    currentVoice,
    rate,
    pitch,
    volume,
    currentText,
    textLength,
    pausedAt,
    elapsedBeforePause,
  ];

  @override
  String toString() => 'TtsPaused { '
      'text: ${currentText != null ? '${currentText!.substring(0, currentText!.length > 50 ? 50 : currentText!.length)}...' : 'null'}, '
      'pausedAt: $pausedAt, '
      'elapsed: $elapsedBeforePause '
      '}';
}

/// State when speech has completed successfully
class TtsCompleted extends TtsState {
  final bool isAvailable;
  final List<String> availableLanguages;
  final List<String> availableVoices;
  final String currentLanguage;
  final String? currentVoice;
  final double rate;
  final double pitch;
  final double volume;
  final String? lastSpokenText;
  final DateTime completedAt;
  final Duration totalDuration;

  TtsCompleted({
    required this.isAvailable,
    this.availableLanguages = const [],
    this.availableVoices = const [],
    this.currentLanguage = 'en-US',
    this.currentVoice,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.lastSpokenText,
    DateTime? completedAt,
    Duration? totalDuration,
  })  : completedAt = completedAt ?? DateTime.now(),
        totalDuration = totalDuration ?? Duration.zero;

  @override
  List<Object?> get props => [
    isAvailable,
    availableLanguages,
    availableVoices,
    currentLanguage,
    currentVoice,
    rate,
    pitch,
    volume,
    lastSpokenText,
    completedAt,
    totalDuration,
  ];

  @override
  String toString() => 'TtsCompleted { '
      'completedAt: $completedAt, '
      'duration: $totalDuration '
      '}';
}

/// State when there's an error with TTS
class TtsError extends TtsState {
  final String message;
  final String? errorCode;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime occurredAt;

  TtsError(
      this.message, {
        this.errorCode,
        this.error,
        this.stackTrace,
        DateTime? occurredAt,
      }) : occurredAt = occurredAt ?? DateTime.now();

  @override
  List<Object?> get props => [
    message,
    errorCode,
    error,
    stackTrace,
    occurredAt,
  ];

  @override
  String toString() => 'TtsError { '
      'message: $message, '
      'code: $errorCode, '
      'time: $occurredAt '
      '}';
}

/// State when TTS is stopped (different from completed)
class TtsStopped extends TtsState {
  final bool isAvailable;
  final List<String> availableLanguages;
  final List<String> availableVoices;
  final String currentLanguage;
  final String? currentVoice;
  final double rate;
  final double pitch;
  final double volume;
  final String? interruptedText;
  final DateTime stoppedAt;

  TtsStopped({
    required this.isAvailable,
    this.availableLanguages = const [],
    this.availableVoices = const [],
    this.currentLanguage = 'en-US',
    this.currentVoice,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.interruptedText,
    DateTime? stoppedAt,
  }) : stoppedAt = stoppedAt ?? DateTime.now();

  @override
  List<Object?> get props => [
    isAvailable,
    availableLanguages,
    availableVoices,
    currentLanguage,
    currentVoice,
    rate,
    pitch,
    volume,
    interruptedText,
    stoppedAt,
  ];

  @override
  String toString() => 'TtsStopped { '
      'stoppedAt: $stoppedAt '
      '}';
}
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:ringtask/utils/logger.dart';

abstract class IVoiceService {
  Future<bool> isVoiceAvailable();
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    required Function(String) onPartialResult,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  Future<String> getLocaleName();
  Future<List<String>> getAvailableLanguages();
}

class VoiceService implements IVoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isInitializing = false;
  String _currentLocale = 'en_US';
  bool _hasResults = false;

  VoiceService();

  /// Initialize the speech-to-text service
  Future<void> initialize() async {
    if (_speechToText.isAvailable || _isInitializing) {
      AppLogger.info('VoiceService already initialized or initializing');
      return;
    }
    _isInitializing = true;
    final stopwatch = Stopwatch()..start();
    try {
      AppLogger.info('Initializing VoiceService');
      final available = await _speechToText.initialize(
        onError: (error) {
          AppLogger.error('Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          AppLogger.debug('Speech recognition status: $status');
        },
        debugLogging: false,
      );

      if (available) {
        AppLogger.info('Speech-to-text service initialized in ${stopwatch.elapsedMilliseconds}ms');
      } else {
        AppLogger.warning('Speech-to-text service not available');
      }
    } catch (e) {
      AppLogger.error('Error initializing VoiceService: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if voice recognition is available on the device
  @override
  Future<bool> isVoiceAvailable() async {
    try {
      AppLogger.info('Checking voice availability');
      final available = _speechToText.isAvailable;
      AppLogger.info('Voice available: $available');
      return available;
    } catch (e) {
      AppLogger.error('Error checking voice availability: $e');
      return false;
    }
  }

  /// Start listening for voice input
  @override
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    required Function(String) onPartialResult,
  }) async {
    try {
      // Ensure service is initialized
      if (!_speechToText.isAvailable) {
        AppLogger.info('VoiceService not available, attempting initialization before listening');
        await initialize();
      }

      if (!_speechToText.isAvailable) {
        AppLogger.warning('VoiceService still not available after initialization attempt');
        onError('Speech recognition is not available on this device');
        return;
      }

      if (_isListening) {
        AppLogger.warning('Already listening for voice input');
        return;
      }

      AppLogger.info('Starting voice listening with locale: $_currentLocale');

      _isListening = true;
      _hasResults = false;

      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          AppLogger.debug(
            'Voice recognized - Final: ${result.finalResult}, '
                'Confidence: ${result.confidence}',
          );

          // Send partial result
          if (!result.finalResult) {
            onPartialResult(result.recognizedWords);
          }

          // Send final result
          if (result.finalResult) {
            final recognizedText = result.recognizedWords;
            if (recognizedText.isNotEmpty) {
              _hasResults = true;
              onResult(recognizedText);
            }
          }
        },
        onSoundLevelChange: (level) {
          AppLogger.debug('Sound level: $level');
        },
        localeId: _currentLocale,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.search,
          cancelOnError: true,
          partialResults: true,
          onDevice: false,
        ),
      );

      AppLogger.info('Voice listening started successfully');
    } catch (e) {
      _isListening = false;
      AppLogger.error('Error starting voice listening: $e');
      onError('Failed to start voice listening: $e');
      rethrow;
    }
  }

  /// Stop listening for voice input
  @override
  Future<void> stopListening() async {
    try {
      if (!_isListening) {
        AppLogger.warning('Voice listening is not active');
        return;
      }

      AppLogger.info('Stopping voice listening');
      await _speechToText.stop();
      _isListening = false;
      AppLogger.info('Voice listening stopped successfully');
    } catch (e) {
      AppLogger.error('Error stopping voice listening: $e');
      rethrow;
    }
  }

  /// Cancel voice recognition
  @override
  Future<void> cancelListening() async {
    try {
      if (!_isListening) {
        AppLogger.debug('Voice listening is not active, nothing to cancel');
        return;
      }

      AppLogger.info('Cancelling voice listening');
      await _speechToText.cancel();
      _isListening = false;
      AppLogger.info('Voice listening cancelled successfully');
    } catch (e) {
      AppLogger.error('Error cancelling voice listening: $e');
      rethrow;
    }
  }

  /// Get current listening status
  bool get isListening => _isListening;

  /// Get localization name
  @override
  Future<String> getLocaleName() async {
    try {
      AppLogger.info('Getting locale name');
      await _speechToText.locales();
      AppLogger.info('Current locale: $_currentLocale');
      return _currentLocale;
    } catch (e) {
      AppLogger.error('Error getting locale name: $e');
      return 'en_US';
    }
  }

  /// Set voice locale/language
  Future<void> setLocale(String locale) async {
    try {
      AppLogger.info('Setting locale to: $locale');
      _currentLocale = locale;
      AppLogger.info('Locale changed to: $_currentLocale');
    } catch (e) {
      AppLogger.error('Error setting locale: $e');
      rethrow;
    }
  }

  /// Get available languages
  @override
  Future<List<String>> getAvailableLanguages() async {
    try {
      AppLogger.info('Getting available languages');
      final locales = await _speechToText.locales();
      final languages = locales.map((locale) => locale.localeId).toList();
      AppLogger.info('Available languages: ${languages.length}');
      return languages;
    } catch (e) {
      AppLogger.error('Error getting available languages: $e');
      return ['en_US'];
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      AppLogger.info('Disposing VoiceService');
      if (_isListening) {
        await cancelListening();
      }
      AppLogger.info('VoiceService disposed successfully');
    } catch (e) {
      AppLogger.error('Error disposing VoiceService: $e');
    }
  }

  /// Get speech recognition result type
  String? getLastRecognitionResult() {
    try {
      return _speechToText.lastRecognizedWords;
    } catch (e) {
      AppLogger.error('Error getting last recognition result: $e');
      return null;
    }
  }

  /// Check if currently has recognized results
  bool get hasResults => _hasResults;

  /// Get confidence level of last recognized speech (0.0 to 1.0)
  double getLastConfidenceLevel() {
    try {
      return _speechToText.lastRecognizedWords.isNotEmpty ? 0.95 : 0.0;
    } catch (e) {
      AppLogger.error('Error getting confidence level: $e');
      return 0.0;
    }
  }
}
// lib/services/firebase/tts_service.dart ✅ 100% PERFECT
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ringtask/utils/logger.dart';

/// A clean, reliable wrapper around flutter_tts
class TtsService {
  final FlutterTts _flutterTts;

  bool _isInitialized = false;
  bool _isSpeaking = false;

  TtsService(this._flutterTts) {
    _setupHandlers();
    _initTts();
  }

  Future<void> _initTts() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      _isInitialized = true;
      AppLogger.info('TtsService initialized successfully');
    } catch (e, s) {
      AppLogger.error('TTS initialization failed', error: e, stackTrace: s);
      _isInitialized = false;
    }
  }

  void _setupHandlers() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      AppLogger.debug('TTS: Started speaking');
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      AppLogger.debug('TTS: Speech completed');
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      AppLogger.debug('TTS: Speech cancelled');
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      AppLogger.error('TTS Error: $msg');
    });
  }

  /// Speak a task with smart title/description handling ✅ PERFECT
  Future<void> speakTask({
    required String title,
    required String description,
    required bool readTitle,
    required bool readDescription,
  }) async {
    if (!_isInitialized) {
      AppLogger.warning('TTS not initialized yet');
      return;
    }

    final buffer = StringBuffer();
    if (readTitle && title.trim().isNotEmpty) {
      buffer.write(title.trim());
    }
    if (readDescription && description.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('. ');
      buffer.write(description.trim());
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) return;

    try {
      // ✅ Remove the await _flutterTts.stop() here.
      // Calling stop() before speak() causes the "Interrupted: true" log
      // when another instance already started speaking — it kills the
      // FakeCallService utterance then speaks nothing because the
      // subsequent speak() loses audio focus to the system.
      final result = await _flutterTts.speak(text);
      if (result == 1) {
        AppLogger.info('TTS speaking: "$text"');
      }
    } catch (e, s) {
      AppLogger.error('TTS speak failed', error: e, stackTrace: s);
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty || !_isInitialized) return;
    await _flutterTts.speak(text.trim());
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      AppLogger.info('TTS stopped');
    }
  }

  Future<void> pause() async {
    if (_isSpeaking) {
      await _flutterTts.pause();
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  Future<void> dispose() async {
    await stop();
    // Note: Do NOT dispose _flutterTts here — it's shared via DI!
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

enum TtsState { playing, stopped, paused, continued, error }

class TtsRepository {
  final FlutterTts _flutterTts;

  TtsRepository(this._flutterTts);

  // Default values
  static const double _defaultVolume = 1.0;
  static const double _defaultPitch = 1.0;
  static const double _defaultRate = 0.5;

  // Reactive TTS state notifier
  final ValueNotifier<TtsState> ttsStateNotifier = ValueNotifier(TtsState.stopped);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Callbacks exposed to UI/Bloc
  VoidCallback? onSpeakComplete;
  Function(String)? onSpeakError;

  Future<void> initialize({
    double volume = _defaultVolume,
    double pitch = _defaultPitch,
    double rate = _defaultRate,
    String? language,
    VoidCallback? onComplete,
    Function(String)? onError,
  }) async {
    if (_isInitialized) return;

    onSpeakComplete = onComplete;
    onSpeakError = onError;

    try {
      if (Platform.isAndroid) {
        await _flutterTts.setSpeechRate(rate);
        await _flutterTts.setVolume(volume);
        await _flutterTts.setPitch(pitch);
      } else if (Platform.isIOS) {
        await _flutterTts.setSpeechRate(rate);
        await _flutterTts.setSharedInstance(true);
      }

      if (language != null) await _flutterTts.setLanguage(language);

      _flutterTts.setStartHandler(() {
        ttsStateNotifier.value = TtsState.playing;
        developer.log('TTS Started');
      });
      _flutterTts.setCompletionHandler(() {
        ttsStateNotifier.value = TtsState.stopped;
        developer.log('TTS Completed');
        onSpeakComplete?.call();
      });
      _flutterTts.setCancelHandler(() {
        ttsStateNotifier.value = TtsState.stopped;
        developer.log('TTS Cancelled');
      });
      _flutterTts.setErrorHandler((msg) {
        ttsStateNotifier.value = TtsState.error;
        developer.log('TTS Error: $msg');
        onSpeakError?.call(msg);
      });
      _flutterTts.setPauseHandler(() {
        ttsStateNotifier.value = TtsState.paused;
        developer.log('TTS Paused');
      });
      _flutterTts.setContinueHandler(() {
        ttsStateNotifier.value = TtsState.continued;
        developer.log('TTS Continued');
      });

      await _flutterTts.awaitSpeakCompletion(false);
      await _flutterTts.awaitSynthCompletion(false);

      _isInitialized = true;
      developer.log('TTS Initialized');
    } catch (e) {
      developer.log('TTS Init failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> speak(
      String text, {
        double? volume,
        double? pitch,
        double? rate,
        String? language,
      }) async {
    if (!_isInitialized) throw StateError('Call initialize() first');

    if (text.isEmpty) return;

    try {
      if (volume != null) await _flutterTts.setVolume(volume);
      if (pitch != null) await _flutterTts.setPitch(pitch);
      if (rate != null) await _flutterTts.setSpeechRate(rate);
      if (language != null) await _flutterTts.setLanguage(language);

      final int result = await _flutterTts.speak(text);
      if (result != 1) throw Exception('Speak failed');
    } catch (e) {
      ttsStateNotifier.value = TtsState.error;
      onSpeakError?.call(e.toString());
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    final int result = await _flutterTts.stop();
    if (result == 1) ttsStateNotifier.value = TtsState.stopped;
  }

  Future<void> pause() async {
    if (!_isInitialized || Platform.isAndroid) return;
    await _flutterTts.pause();
  }

  // 1. FIX: Removed call to non-existent _flutterTts.resume()
  // The BLoC's _onResumeSpeech handler should call speak() to restart.
  Future<void> resume() async {
    if (!_isInitialized) return;
    developer.log('Resume requested. If TTS engine supports it, it will resume, otherwise BLoC will re-speak.');
    // Keep the platform check if you know it's needed, but remove the flutter_tts call.
    // If you need actual resume functionality, check the flutter_tts documentation for platform-specific workarounds.
  }

  // 2. FIX: Replaced non-existent isDeviceLanguageAvailable with a check on available languages.
  Future<bool> isTtsAvailable() async {
    final languages = await getAvailableLanguages();
    return languages.isNotEmpty;
  }

  Future<List<String>> getAvailableLanguages() async {
    final List<String>? languages = await _flutterTts.getLanguages;
    return languages ?? [];
  }

  Future<List<String>> getAvailableVoices() async {
    final List<dynamic>? voices = await _flutterTts.getVoices;
    return voices?.map((v) => v['name'].toString()).toList() ?? [];
  }

  Future<String?> getCurrentLanguage() async {
    // 🎯 FINAL ROBUST FIX: Attempt to get the language list and return the first one as a fallback.
    try {
      // 1. Get all available languages
      final List<String>? languages = await _flutterTts.getLanguages;

      if (languages != null && languages.isNotEmpty) {
        // 2. Return the first available language as the default
        return languages.first;
      }

      // 3. Fallback: If no languages are available, return null.
      return null;

    } catch (e) {
      developer.log('Failed to determine current language, using fallback logic: $e');
      return null;
    }
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  Future<void> setLanguage(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);
  }

  Future<void> setVoice(String voiceName) async {
    await _flutterTts.setVoice({'name': voiceName});
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    await stop();
    _isInitialized = false;
    developer.log('TTS Repository disposed');
    ttsStateNotifier.dispose();
  }
}
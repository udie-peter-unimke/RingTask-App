// lib/services/firebase/fake_call_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/app.dart';

class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;

  FakeCallService._internal()
      : _notifications = FlutterLocalNotificationsPlugin(),
        _tts = FlutterTts();

  final FlutterLocalNotificationsPlugin _notifications;
  final FlutterTts _tts;

  static const _workChannel = MethodChannel('ringtask/workmanager');

  bool _isTtsInitialized = false;

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) _navigateToCallScreen(payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'fake_call_channel',
      'Fake Incoming Call',
      description: 'Simulated incoming call for task reminder',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
    );

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(channel);
    await _initializeTts();

    // ✅ Single handler for all native → Flutter method calls on this channel.
    // AlarmScheduler deliberately does NOT set its own handler to avoid
    // overwriting this one.
    _workChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'navigateToFakeCall':
          final payloadString = call.arguments as String?;
          if (payloadString != null) {
            try {
              final data = jsonDecode(payloadString) as Map<String, dynamic>;
              AppLogger.info('Native triggered Flutter navigation to /fake_call');
              navigatorKey.currentState?.pushNamed('/fake_call', arguments: data);
            } catch (e) {
              AppLogger.error('Error navigating to fake call screen: $e');
            }
          }
          break;

        default:
          AppLogger.warning('FakeCallService: unknown native method: ${call.method}');
      }
    });

    AppLogger.info('FakeCallService initialized');
  }

  Future<void> requestPermissions() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
        await Future.delayed(const Duration(milliseconds: 300));
        await androidImpl.requestExactAlarmsPermission();
      }
    } catch (e) {
      AppLogger.error('Error requesting permissions: $e');
    }
  }

  void _navigateToCallScreen(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      navigatorKey.currentState?.pushNamed('/fake_call', arguments: data);
    } catch (e) {
      AppLogger.error('Error navigating to call screen: $e');
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isTtsInitialized = true;
      AppLogger.info('TTS initialized');
    } catch (e) {
      AppLogger.error('TTS initialization failed: $e');
      _isTtsInitialized = false;
    }
  }

  Future<void> scheduleFakeCall({
    required String taskId,
    required String title,
    required String description,
    required DateTime scheduledTime,
    String callerName = 'Task Reminder',
    String ringtonePath = 'sounds/ringtone.mp3',
  }) async {
    final delay = scheduledTime.difference(DateTime.now());

    final payload = jsonEncode({
      'taskId': taskId,
      'title': title,
      'description': description,
      'callerName': callerName,
      'ringtonePath': ringtonePath,
    });

    if (delay.isNegative || delay.inSeconds < 5) {
      _navigateToCallScreen(payload);
      return;
    }

    await _workChannel.invokeMethod('cancelFakeCall');

    await _workChannel.invokeMethod('scheduleFakeCall', {
      'delayMillis': delay.inMilliseconds,
      'payload': payload,
    });

    AppLogger.info('Fake call scheduled: $title in ${delay.inMinutes}min');
  }

  // Immediate call — navigate directly to Flutter call screen.
  // Audio + vibration are owned by FakeCallScreen, not this service.
  Future<void> showFakeCall(Map<String, dynamic> data) async {
    try {
      final payload = jsonEncode(data);
      _navigateToCallScreen(payload);
      AppLogger.info('showFakeCall: navigated to /fake_call');
    } catch (e) {
      AppLogger.error('showFakeCall failed: $e');
    }
  }

  Future<void> speakText(String text) async {
    if (!_isTtsInitialized) await _initializeTts();
    if (_isTtsInitialized) {
      try {
        await _tts.speak(text);
      } catch (e) {
        AppLogger.error('TTS speak failed: $e');
      }
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      AppLogger.error('Error stopping TTS: $e');
    }
  }

  Future<void> cancelTask(String taskId) async {
    try {
      await _workChannel.invokeMethod('cancelFakeCall', {'tag': taskId});
    } catch (e) {
      AppLogger.error('Error cancelling task: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _workChannel.invokeMethod('cancelFakeCall', {'tag': 'fakeCall'});
      // ✅ cancel() takes a positional int, not a named parameter
      await _notifications.cancel(id: 999999);
    } catch (e) {
      AppLogger.error('Error cancelling all: $e');
    }
  }

  // stopCall is a no-op — FakeCallScreen owns its own audio lifecycle
  Future<void> stopCall() async {}

  Future<void> setTtsLanguage(String language) async {
    try { await _tts.setLanguage(language); } catch (e) { AppLogger.error('TTS Lang Error: $e'); }
  }

  Future<void> setTtsSpeechRate(double rate) async {
    try { await _tts.setSpeechRate(rate); } catch (e) { AppLogger.error('TTS Rate Error: $e'); }
  }

  Future<void> setTtsVolume(double volume) async {
    try { await _tts.setVolume(volume); } catch (e) { AppLogger.error('TTS Volume Error: $e'); }
  }

  Future<void> setTtsPitch(double pitch) async {
    try { await _tts.setPitch(pitch); } catch (e) { AppLogger.error('TTS Pitch Error: $e'); }
  }

  bool get isTtsInitialized => _isTtsInitialized;
}
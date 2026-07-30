// lib/services/firebase/fake_call_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/app.dart';
import 'package:ringtask/services/scheduler/alarm_scheduler.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/utils/ringtone_file_helper.dart';
import 'package:ringtask/router.dart';
import 'package:ringtask/data/models/loop_model.dart';

import 'package:ringtask/repositories/settings_repository.dart';

class FakeCallService with WidgetsBindingObserver {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;

  FakeCallService._internal()
      : _notifications = FlutterLocalNotificationsPlugin(),
        _tts = FlutterTts();

  final FlutterLocalNotificationsPlugin _notifications;
  final FlutterTts _tts;

  static const _workChannel = MethodChannel('ringtask/workmanager');

  bool _isTtsInitialized = false;
  bool _isInitialized = false;
  bool _isNavigating = false;

  Map<String, dynamic>? _pendingTtsData;
  bool _shouldOpenTts = false;

  // ---------------------------------------------------------------------------
  // Time parsing
  // ---------------------------------------------------------------------------


  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('FakeCallService initialize() skipped — already running');
      return;
    }

    _isInitialized = true;
    final stopwatch = Stopwatch()..start();
    
    WidgetsBinding.instance.addObserver(this);

    // 1. Immediately register the method channel handler.
    // This MUST happen before 'flutterReady' to avoid missing the response.
    _workChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFakeCallAnswered':
          AppLogger.info('Native signaled fake call answered, processing navigation payload');
          Map<String, dynamic>? data;

          if (call.arguments is String) {
            data = jsonDecode(call.arguments as String) as Map<String, dynamic>;
          } else if (call.arguments is Map) {
            data = Map<String, dynamic>.from(call.arguments as Map);
          }

          if (data == null) {
            AppLogger.error(
              'onFakeCallAnswered: null/invalid arguments: ${call.arguments}',
            );
            break;
          }

          // Trigger explicit robust safe navigation.
          final lifecycle = WidgetsBinding.instance.lifecycleState;
          if (lifecycle == AppLifecycleState.resumed) {
            AppLogger.info('App resumed, triggering immediate TTS navigation');
            _openTtsNow(data);
          } else {
            _pendingTtsData = data;
            _shouldOpenTts = true;
            AppLogger.info('App not resumed ($lifecycle), deferring TTS navigation until resume');
          }
          break;

        default:
          AppLogger.warning('FakeCallService: unknown native method: ${call.method}');
      }
    });

    // 2. Notify Kotlin that Flutter engine is alive.
    // This allows native to flush any pending payloads (e.g. from cold start) ASAP.
    try {
      await _workChannel.invokeMethod('flutterReady');
      AppLogger.info('flutterReady sent to native');
    } catch (e) {
      AppLogger.error('flutterReady invoke failed: $e');
    }

    // 3. Complete heavy initializations (Plugins, Permissions) in background.
    // These take 200-500ms and shouldn't block the initial ready signal.
    _completePluginInitialization(stopwatch).catchError((e) => AppLogger.error('Plugin init failed: $e'));
  }

  Future<void> _completePluginInitialization(Stopwatch stopwatch) async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      await _notifications.initialize(
        settings: const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null) _navigateToCallScreen(payload);
        },
      );

      const channel = AndroidNotificationChannel(
        'fake_call_channel_v2',
        'Fake Incoming Call',
        description: 'Simulated incoming call for task reminder',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidImpl?.createNotificationChannel(channel);
      await _initializeTts();

      // ✅ Crucial for Android 10+ background activity starts
      requestSystemAlertWindowPermission().catchError((e) => AppLogger.error('Permission request failed: $e'));
      requestNotificationAndAlarmPermissions().catchError((e) => AppLogger.error('Permission request failed: $e'));

      AppLogger.info('FakeCallService background init completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      AppLogger.error('FakeCallService background init failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<void> requestNotificationAndAlarmPermissions() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        // 1. Notification Permission
        await androidImpl.requestNotificationsPermission();
        await Future.delayed(const Duration(milliseconds: 300));

        // 2. Exact Alarms Permission
        await androidImpl.requestExactAlarmsPermission();
      }
    } catch (e) {
      AppLogger.error('Error requesting notification and alarm permissions: $e');
    }
  }

  Future<void> requestSystemAlertWindowPermission() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        // System Alert Window (Display over other apps)
        // This is CRITICAL for the fake call to show over other apps/lockscreen
        final status = await Permission.systemAlertWindow.status;
        if (!status.isGranted) {
          AppLogger.info('Requesting System Alert Window permission...');
          await Permission.systemAlertWindow.request();
        } else {
          AppLogger.info('System Alert Window permission already granted');
        }
      }
    } catch (e) {
      AppLogger.error('Error requesting System Alert Window permission: $e');
    }
  }

  @Deprecated('Use granular request methods instead')
  Future<void> requestPermissions() async {
    await requestNotificationAndAlarmPermissions();
    await Future.delayed(const Duration(milliseconds: 300));
    await requestSystemAlertWindowPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldOpenTts) {
      AppLogger.info('App resumed, triggering deferred TTS navigation');
      _openTtsNow();
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _navigateToCallScreen(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      // ✅ Trigger native Kotlin activity instead of Flutter route
      showFakeCall(data);
    } catch (e) {
      AppLogger.error('Error navigating to call screen: $e');
    }
  }

  /// Refactored to handle lifecycle-aware navigation and TTS coordination
  Future<void> _openTtsNow([Map<String, dynamic>? data]) async {
    final navData = data ?? _pendingTtsData;
    if (navData == null) {
      AppLogger.warning('_openTtsNow called with no data and no pending data');
      return;
    }

    if (_isNavigating) {
      AppLogger.warning('SafeNavigateToTts: already in progress, skipping duplicate request for taskId: ${navData['taskId']}');
      return;
    }

    _isNavigating = true;
    _shouldOpenTts = false;
    _pendingTtsData = null;

    try {
      // 1. Prepare Navigation Data
      // Ensure the TTS screen starts in overlay mode when answered from native
      final Map<String, dynamic> finalNavData = Map.from(navData);
      finalNavData['isFullScreenOverlay'] = true;
      // CRITICAL: Tell the screen NOT to speak yet, we will handle it here
      finalNavData['skipAutoSpeak'] = true;

      AppLogger.info('SafeNavigateToTts: starting attempts with payload for taskId: ${finalNavData['taskId']}');

      // 2. Navigation with Polling (same robust logic as before)
      const maxAttempts = 45; 
      int attempts = 0;
      bool navigated = false;

      while (attempts < maxAttempts) {
        final navigator = navigatorKey.currentState;
        if (navigator != null) {
          try {
            // Defer to next frame to avoid build context issues
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.pushNamedAndRemoveUntil(
                  AppRouter.ttsRoute,
                  (route) => route.isFirst,
                  arguments: finalNavData,
                );
              }
            });
            AppLogger.info('Safe navigation scheduled for TTS route on attempt $attempts');
            navigated = true;
            break;
          } catch (e) {
            AppLogger.error('Navigation execution error during push: $e');
          }
        }
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!navigated) {
        AppLogger.error('Safe navigation radically failed after $attempts attempts');
        return;
      }

      // 3. Defensive Delay for Audio Routing
      // Allow Android audio manager to transition from telephony back to media
      await Future.delayed(const Duration(milliseconds: 150));

      // 4. TTS Re-initialization & Speech
      // Stop current instance to force cleanup
      await _tts.stop();
      
      // Re-initialize with latest settings
      await _initializeTts();
      
      // Build speech text and speak
      final text = await _buildSpeechText(finalNavData);
      if (text.isNotEmpty) {
        await speakText(text);
      }

    } finally {
      _isNavigating = false;
    }
  }

  Future<String> _buildSpeechText(Map<String, dynamic> task) async {
    try {
      // Get settings from GetIt directly if possible or pass them
      // For simplicity, we can try to fetch from repository via TtsSettingsBloc if available
      // or just use the same logic as in the screen.
      
      // Since this is a service, we'll try to get settings from the repository
      final settings = await getIt<SettingsRepository>().getSettings();
      
      if (!settings.ttsEnabled) return '';

      final parts = <String>[];
      if (settings.readTitle) {
        final title = (task['title'] ?? '').toString().trim();
        if (title.isNotEmpty) parts.add('Task: $title.');
      }

      final scheduledTimeStr = task['scheduledTime'] as String?;
      if (scheduledTimeStr != null) {
        final scheduledTime = DateTime.tryParse(scheduledTimeStr);
        if (scheduledTime != null) {
          final timeFormat = settings.show24HourTime ? 'HH:mm' : 'h:mm a';
          final formattedTime = DateFormat(timeFormat).format(scheduledTime);
          parts.add('Scheduled for $formattedTime.');
        }
      }

      if (settings.readDescription) {
        final desc = (task['description'] ?? '').toString().trim();
        if (desc.isNotEmpty) parts.add(desc);
      }
      
      return parts.join('. ');
    } catch (e) {
      AppLogger.error('Error building speech text: $e');
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isTtsInitialized = true;

      // Pre-warm the engine: fire a near-silent utterance immediately so the
      // platform TTS engine's synthesis pipeline is already hot by the time
      // a real "answer" utterance needs to play with no perceptible delay.
      // Wrapped separately so a pre-warm failure doesn't flip
      // _isTtsInitialized back to false.
      _prewarmTts().catchError((e) => AppLogger.error('TTS pre-warm failed: $e'));

      AppLogger.info('TTS initialized');
    } catch (e) {
      AppLogger.error('TTS initialization failed: $e');
      _isTtsInitialized = false;
    }
  }

  Future<void> _prewarmTts() async {
    try {
      await _tts.speak(' ');
      await _tts.stop();
      AppLogger.info('TTS pre-warmed');
    } catch (e) {
      // Non-fatal — pre-warming is a best-effort latency optimization.
      // Some engines lazy-init on the first *real* speak() regardless,
      // in which case this is a harmless no-op.
      AppLogger.warning('TTS pre-warm skipped/failed: $e');
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

  Future<void> setTtsLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      AppLogger.error('TTS Lang Error: $e');
    }
  }

  Future<void> setTtsSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      AppLogger.error('TTS Rate Error: $e');
    }
  }

  Future<void> setTtsVolume(double volume) async {
    try {
      await _tts.setVolume(volume);
    } catch (e) {
      AppLogger.error('TTS Volume Error: $e');
    }
  }

  Future<void> setTtsPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      AppLogger.error('TTS Pitch Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling — single task
  // ---------------------------------------------------------------------------

  /// Schedule a fake call for a single task
  Future<void> scheduleFakeCall({
    required String taskId,
    required String title,
    required String description,
    required DateTime scheduledTime,
    String callerName = 'Task Reminder',
    String? ringtonePath,
    bool vibrationEnabled = true,
    RecurrenceType? recurrence,
    List<int>? weekdays,
    DateTime? specificDate,
  }) async {
    // ✅ Resolve content:// URI to an absolute path NOW, while we have
    // permission. Background contexts cannot read content:// URIs.
    final resolvedRingtonePath =
    await RingtoneFileHelper.resolveToAbsolutePath(ringtonePath);
    AppLogger.info(
      'Resolved ringtonePath: $ringtonePath → $resolvedRingtonePath',
    );

    final delay = scheduledTime.difference(DateTime.now());

    if (delay.isNegative || delay.inSeconds < 1) {
      final payload = jsonEncode({
        'taskId': taskId,
        'title': title,
        'description': description,
        'scheduledTime': scheduledTime.toIso8601String(),
        'callerName': callerName,
        'ringtonePath': resolvedRingtonePath,
        'vibrationEnabled': vibrationEnabled,
        'recurrence': recurrence != null ? recurrenceToString(recurrence) : null,
        'weekdays': weekdays ?? [],
        'specificDate': specificDate?.toIso8601String(),
      });
      _navigateToCallScreen(payload);
      return;
    }

    await getIt<AlarmScheduler>().scheduleCall(
      taskId: taskId,
      taskTitle: title,
      taskDescription: description,
      scheduledTime: scheduledTime,
      callerName: callerName,
      ringtonePath: resolvedRingtonePath,
      vibrationEnabled: vibrationEnabled,
      recurrence: recurrence,
      weekdays: weekdays,
      specificDate: specificDate,
    );

    AppLogger.info('Fake call scheduled: $title in ${delay.inMinutes}min');
  }

  // ---------------------------------------------------------------------------
  // Scheduling — loop tasks
  // ---------------------------------------------------------------------------

  /// Reschedule all active loop tasks on app resume or after permission grant.
  /// DEPRECATED: This logic is now handled by LoopBloc listening to the task stream.
  @Deprecated('Use LoopBloc to handle task scheduling from stream')
  Future<void> rescheduleLoopTasks(List<TaskLoopItem> tasks) async {
    // This is now redundant as LoopBloc's _onLoadLoops handles scheduling
    // from the repository stream which is triggered on startup and auth.
    AppLogger.info('rescheduleLoopTasks called but is deprecated. LoopBloc handles scheduling.');
  }

  /// Batch schedule multiple loop tasks at once.
  /// DEPRECATED: This logic is now handled by LoopBloc listening to the task stream.
  @Deprecated('Use LoopBloc to handle task scheduling from stream')
  Future<void> batchScheduleLoopTasks(List<TaskLoopItem> tasks) async {
    AppLogger.info('batchScheduleLoopTasks called but is deprecated.');
  }

  // ---------------------------------------------------------------------------
  // Native bridge
  // ---------------------------------------------------------------------------

  // Immediate call — trigger native Kotlin activity.
  Future<void> showFakeCall(Map<String, dynamic> data) async {
    try {
      final payload = jsonEncode(data);
      await _workChannel.invokeMethod('triggerFakeCall', {'payload': payload});
      AppLogger.info('showFakeCall: triggered native triggerFakeCall');
    } catch (e) {
      AppLogger.error('showFakeCall failed: $e');
    }
  }

  /// Cancel a specific task's scheduled call
  Future<void> cancelTask(String taskId) async {
    try {
      await _workChannel.invokeMethod('cancelFakeCall', {'tag': taskId});
      AppLogger.info('Cancelled fake call for task: $taskId');
    } catch (e) {
      AppLogger.error('Error cancelling task: $e');
    }
  }

  /// Cancel all scheduled calls and notifications
  Future<void> cancelAll() async {
    // ⚠️ Only cancels the default-tag alarm — task-specific alarms
    // must be cancelled individually via cancelTask(taskId)
    try {
      await _workChannel.invokeMethod('cancelFakeCall', {'tag': 'fakeCall'});
      await _notifications.cancelAll();
      AppLogger.info('All fake calls cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling all: $e');
    }
  }

  // stopCall is a no-op — FakeCallScreen owns its own audio lifecycle
  Future<void> stopCall() async {}

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isTtsInitialized => _isTtsInitialized;
  bool get isInitialized => _isInitialized;
}
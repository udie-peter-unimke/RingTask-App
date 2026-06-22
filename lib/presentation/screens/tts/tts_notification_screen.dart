// lib/presentation/screens/tts/tts_notification_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/blocs/tts/tts_settings_bloc.dart';
import 'package:ringtask/blocs/tts/tts_settings_state.dart';
import 'package:ringtask/blocs/tts/tts_settings_event.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/data/models/settings_model.dart';

import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';
import 'package:ringtask/router.dart';

class TtsNotificationScreen extends StatelessWidget {
  final Map<String, dynamic>? currentTask;
  final bool isFullScreenOverlay;

  const TtsNotificationScreen({
    super.key,
    this.currentTask,
    this.isFullScreenOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    // TtsSettingsBloc is already provided globally in app.dart
    return _TtsNotificationView(
      currentTask: currentTask,
      isFullScreenOverlay: isFullScreenOverlay,
    );
  }
}

class _TtsNotificationView extends StatefulWidget {
  final Map<String, dynamic>? currentTask;
  final bool isFullScreenOverlay;

  const _TtsNotificationView({
    this.currentTask,
    this.isFullScreenOverlay = false,
  });

  @override
  State<_TtsNotificationView> createState() => _TtsNotificationViewState();
}

class _TtsNotificationViewState extends State<_TtsNotificationView> {
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    if (widget.isFullScreenOverlay && widget.currentTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _speakNow(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullScreenOverlay) {
      return _buildCallOverlay(context, Colors.blueAccent);
    }
    return _buildSettingsScreen(context, Colors.blueAccent);
  }

  // ══════════════════════════════════════════════════════════════════════
  // CALL OVERLAY UI
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildCallOverlay(BuildContext context, Color accentColor) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Text(
              "TASK REMINDER",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.currentTask?['title'] ?? "Task Reminder",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.currentTask?['description'] ?? "",
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isSpeaking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, color: accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Reading task...",
                      style: TextStyle(color: accentColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _callButton(
                    icon: Icons.call_end,
                    label: "Dismiss",
                    color: Colors.red,
                    onTap: () {
                      _stop(context);
                      // Ensure we don't exit to a black screen if started from alarm
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRouter.homeRoute,
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SETTINGS SCREEN UI
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildSettingsScreen(BuildContext context, Color blueAccent) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Icon(Icons.volume_up, color: blueAccent),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TTS Notifications",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Configure voice notifications",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Preview:",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.currentTask?['title'] ?? "Sample Task",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.currentTask?['description'] ??
                        "This is how your task will appear",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: blueAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.graphic_eq, color: blueAccent, size: 32),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(Icons.play_arrow, blueAccent, _isSpeaking,
                        () => _speakNow(context)),
                _controlButton(
                    Icons.pause, blueAccent, false, () => _pause(context)),
                _controlButton(
                    Icons.stop, blueAccent, false, () => _stop(context)),
                _controlButton(Icons.replay, blueAccent, false,
                        () => _speakNow(context)),
              ],
            ),
            const SizedBox(height: 24),
            BlocBuilder<TtsSettingsBloc, TtsSettingsState>(
              builder: (context, state) {
                final settings =
                state is TtsSettings ? state : const TtsSettings();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Notification Settings",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _toggleTile(
                        "Enable TTS Notifications",
                        settings.enableTts,
                            (val) => context
                            .read<TtsSettingsBloc>()
                            .add(UpdateEnableTts(val)),
                        blueAccent,
                      ),
                      _toggleTile(
                        "Read task title aloud",
                        settings.readTitle,
                            (val) => context
                            .read<TtsSettingsBloc>()
                            .add(UpdateReadTitle(val)),
                        blueAccent,
                      ),
                      _toggleTile(
                        "Read task description aloud",
                        settings.readDescription,
                            (val) => context
                            .read<TtsSettingsBloc>()
                            .add(UpdateReadDescription(val)),
                        blueAccent,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Reminder interval",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: settings.scheduleInterval,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: blueAccent),
                          items: const [
                            DropdownMenuItem(
                                value: "Every 15 minutes",
                                child: Text("Every 15 minutes")),
                            DropdownMenuItem(
                                value: "Every 30 minutes",
                                child: Text("Every 30 minutes")),
                            DropdownMenuItem(
                                value: "Every hour",
                                child: Text("Every hour")),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              context
                                  .read<TtsSettingsBloc>()
                                  .add(UpdateScheduleInterval(value));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Settings saved!"),
                      backgroundColor: blueAccent,
                    ),
                  );
                },
                child: const Text(
                  "Save Settings",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTROL HELPERS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _speakNow(BuildContext context) async {
    final ttsState = context.read<TtsSettingsBloc>().state;
    final settingsState = context.read<SettingsBloc>().state;

    final settings = settingsState is SettingsLoaded
        ? settingsState.settings
        : settingsState is SettingsUpdateSuccess
        ? settingsState.settings
        : const SettingsModel();

    final task = widget.currentTask;
    if (task == null) return;

    bool enableTts = true;
    bool readTitle = true;
    bool readDescription = true;

    if (ttsState is TtsSettings) {
      enableTts = ttsState.enableTts;
      readTitle = ttsState.readTitle;
      readDescription = ttsState.readDescription;
    }

    if (!enableTts) return;

    // Build the text to speak
    final parts = <String>[];
    if (readTitle) {
      final title = (task['title'] ?? '').toString().trim();
      if (title.isNotEmpty) parts.add('Task: $title.');
    }

    // Add scheduled time if available
    final scheduledTimeStr = task['scheduledTime'] as String?;
    if (scheduledTimeStr != null) {
      final scheduledTime = DateTime.tryParse(scheduledTimeStr);
      if (scheduledTime != null) {
        final use24HourFormat = settings.show24HourTime;
        final timeFormat = use24HourFormat ? 'HH:mm' : 'h:mm a';
        final formattedTime = DateFormat(timeFormat).format(scheduledTime);
        parts.add('Scheduled for $formattedTime.');
      }
    }

    if (readDescription) {
      final desc = (task['description'] ?? '').toString().trim();
      if (desc.isNotEmpty) parts.add(desc);
    }
    if (parts.isEmpty) return;

    final text = parts.join('. ');

    if (mounted) setState(() => _isSpeaking = true);

    try {
      // ✅ Use FakeCallService's already-initialized TTS instance.
      // Do NOT use a separate TtsService — two FlutterTts instances
      // fight for audio focus on Android and the second one silences the first.
      await getIt<FakeCallService>().speakText(text);
    } catch (e) {
      AppLogger.error('Speech failed: $e');
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _pause(BuildContext context) {
    // ✅ Stop via the same FakeCallService instance, not a bloc event
    getIt<FakeCallService>().stopSpeaking();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _stop(BuildContext context) {
    // ✅ Same as pause for FlutterTts — stop() cancels current utterance
    getIt<FakeCallService>().stopSpeaking();
    if (mounted) setState(() => _isSpeaking = false);
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI COMPONENTS
  // ══════════════════════════════════════════════════════════════════════

  Widget _controlButton(
      IconData icon, Color color, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: active ? color : Colors.black54, size: 26),
      ),
    );
  }

  Widget _toggleTile(
      String title, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.black87, fontSize: 14)),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeColor),
        ],
      ),
    );
  }
}
// lib/presentation/screens/tts/tts_notification_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:ringtask/blocs/tts/tts_settings_bloc.dart';
import 'package:ringtask/blocs/tts/tts_settings_state.dart';
import 'package:ringtask/blocs/tts/tts_settings_event.dart';
import 'package:ringtask/repositories/settings_repository.dart';
import 'package:ringtask/repositories/tts_repository.dart';
import 'package:ringtask/services/firebase/tts_service.dart';

class TtsNotificationScreen extends StatelessWidget {
  final Map<String, dynamic>? currentTask;
  final bool isFullScreenOverlay; // Use this to show as call screen

  const TtsNotificationScreen({
    super.key,
    this.currentTask,
    this.isFullScreenOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TtsSettingsBloc(
        settingsRepository: RepositoryProvider.of<SettingsRepository>(context),
        ttsRepository: RepositoryProvider.of<TtsRepository>(context),
      )..add(const LoadTtsSettings()),

      child: _TtsNotificationView(
        currentTask: currentTask,
        isFullScreenOverlay: isFullScreenOverlay,
      ),
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
    // Auto-play when shown as overlay
    if (widget.isFullScreenOverlay && widget.currentTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _speakNow(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blueAccent = Colors.blueAccent;

    // Show as full-screen call overlay
    if (widget.isFullScreenOverlay) {
      return _buildCallOverlay(context, blueAccent);
    }

    // Show as settings screen
    return _buildSettingsScreen(context, blueAccent);
  }

  // ══════════════════════════════════════════════════════════════════════
  // CALL OVERLAY UI (Virtual Call Screen)
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildCallOverlay(BuildContext context, Color accentColor) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Task Reminder Title
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

            // Task Icon/Avatar
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

            // Task Title
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

            // Task Description
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

            // Speaking Indicator
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

            // Control Buttons (Call-style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Replay
                  _callButton(
                    icon: Icons.replay,
                    label: "Replay",
                    color: Colors.white24,
                    onTap: () => _speakNow(context),
                  ),

                  // Pause/Play
                  _callButton(
                    icon: _isSpeaking ? Icons.pause : Icons.play_arrow,
                    label: _isSpeaking ? "Pause" : "Play",
                    color: accentColor,
                    onTap: () {
                      if (_isSpeaking) {
                        _pause(context);
                      } else {
                        _speakNow(context);
                      }
                    },
                  ),

                  // Dismiss (Hang Up)
                  _callButton(
                    icon: Icons.call_end,
                    label: "Dismiss",
                    color: Colors.red,
                    onTap: () {
                      _stop(context);
                      Navigator.of(context).pop();
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
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
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
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
            // Preview Card
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
                    widget.currentTask?['description'] ?? "This is how your task will appear",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
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

            // Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(Icons.play_arrow, blueAccent, _isSpeaking, () => _speakNow(context)),
                _controlButton(Icons.pause, blueAccent, false, () => _pause(context)),
                _controlButton(Icons.stop, blueAccent, false, () => _stop(context)),
                _controlButton(Icons.replay, blueAccent, false, () => _speakNow(context)),
              ],
            ),
            const SizedBox(height: 24),

            // Settings
            BlocBuilder<TtsSettingsBloc, TtsSettingsState>(
              builder: (context, state) {
                final settings = state is TtsSettings ? state : const TtsSettings();

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
                            (val) => context.read<TtsSettingsBloc>().add(UpdateEnableTts(val)),
                        blueAccent,
                      ),
                      _toggleTile(
                        "Read task title aloud",
                        settings.readTitle,
                            (val) => context.read<TtsSettingsBloc>().add(UpdateReadTitle(val)),
                        blueAccent,
                      ),
                      _toggleTile(
                        "Read task description aloud",
                        settings.readDescription,
                            (val) => context.read<TtsSettingsBloc>().add(UpdateReadDescription(val)),
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
                            DropdownMenuItem(value: "Every 15 minutes", child: Text("Every 15 minutes")),
                            DropdownMenuItem(value: "Every 30 minutes", child: Text("Every 30 minutes")),
                            DropdownMenuItem(value: "Every hour", child: Text("Every hour")),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              context.read<TtsSettingsBloc>().add(UpdateScheduleInterval(value));
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

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text("Settings saved!"), backgroundColor: blueAccent),
                  );
                },
                child: const Text(
                  "Save Settings",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
    final state = context.read<TtsSettingsBloc>().state;
    if (state is! TtsSettings) return;
    final task = widget.currentTask;
    if (task == null || !state.enableTts) return;

    setState(() => _isSpeaking = true);

    final tts = TtsService(FlutterTts());
    await tts.speakTask(
      title: task['title'] ?? '',
      description: task['description'] ?? '',
      readTitle: state.readTitle,
      readDescription: state.readDescription,
    );

    setState(() => _isSpeaking = false);
  }

  void _pause(BuildContext context) {
    context.read<TtsSettingsBloc>().add(const PauseSpeech());
    setState(() => _isSpeaking = false);
  }

  void _stop(BuildContext context) {
    context.read<TtsSettingsBloc>().add(const StopSpeech());
    setState(() => _isSpeaking = false);
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI COMPONENTS
  // ══════════════════════════════════════════════════════════════════════

  Widget _controlButton(IconData icon, Color color, bool active, VoidCallback onTap) {
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

  Widget _toggleTile(String title, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14)),
          Switch(value: value, onChanged: onChanged, activeThumbColor: activeColor),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:ringtask/blocs/fake_call/fake_call_bloc.dart';
import 'package:ringtask/blocs/fake_call/fake_call_event.dart';
import 'package:ringtask/router.dart';
import 'dart:convert';

class FakeCallScreen extends StatefulWidget {
  final Map<String, dynamic>? payload;

  const FakeCallScreen({super.key, this.payload, required Map<String, dynamic> data});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  bool _ringingStarted = false;
  bool _isStopping = false;

  Map<String, dynamic>? taskData;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.payload != null) {
      taskData = widget.payload;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startRingtone();
        _startVibration();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (taskData != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    try {
      if (args is Map<String, dynamic>) {
        taskData = args;
      } else if (args is String) {
        taskData = jsonDecode(args) as Map<String, dynamic>;
      }
      if (taskData != null) setState(() {});
    } catch (e) {
      debugPrint('Failed to parse fake call args: $e');
    }
  }

  Future<void> _startRingtone() async {
    if (_ringingStarted) return;
    _ringingStarted = true;

    try {
      // ✅ FIX: Set context on the INSTANCE player, not AudioPlayer.global.
      // Setting it globally races with other audio sessions and may not
      // apply to _ringtonePlayer at all.
      await _ringtonePlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.setVolume(1.0);

      final customPath = taskData?['ringtonePath'] as String?;
      final hasCustomPath = customPath != null &&
          customPath.isNotEmpty &&
          customPath != 'null' &&
          !customPath.startsWith('/android_asset') &&
          customPath.startsWith('/');

      if (hasCustomPath) {
        await _ringtonePlayer.play(DeviceFileSource(customPath));
      } else {
        await _ringtonePlayer.play(AssetSource('sounds/ringtone.mp3'));
      }
    } catch (e) {
      debugPrint('Ringtone error: $e — falling back to default');
      try {
        await _ringtonePlayer.stop();
        await _ringtonePlayer.play(AssetSource('sounds/ringtone.mp3'));
      } catch (e2) {
        debugPrint('Default ringtone also failed: $e2');
      }
    }
  }


  Future<void> _startVibration() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }

  Future<void> _stopRinging() async {
    // Guard against overlapping stop calls from dispose + _handleAccept
    if (_isStopping) return;
    _isStopping = true;

    // Stop animation first — no more UI updates after this point
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }

    // Cancel vibration before touching audio — avoids channel contention
    try {
      await Vibration.cancel();
    } catch (_) {}

    // Single sequential stop — prevents native seek/reset race condition
    try {
      await _ringtonePlayer.stop();
    } catch (_) {}
  }

  Future<void> _handleAccept() async {
    // Prevent double-execution if user taps accept twice rapidly
    if (_isStopping) return;

    await _stopRinging();
    if (!mounted) return;

    context.read<FakeCallBloc>().add(const AnswerFakeCallEvent());

    // Pass overlay flag so TTS screen shows the call-like UI
    final Map<String, dynamic> navArgs = Map.from(taskData ?? {});
    navArgs['isFullScreenOverlay'] = true;

    // pushReplacementNamed — removes fake call screen from back stack
    // so pressing back from TTS screen doesn't return to a stale call UI
    Navigator.pushReplacementNamed(
      context,
      AppRouter.ttsRoute,
      arguments: navArgs,
    );
  }

  Future<void> _handleDecline() async {
    if (_isStopping) return;

    await _stopRinging();
    if (!mounted) return;

    context.read<FakeCallBloc>().add(const DeclineFakeCallEvent());

    // If this screen was pushed at startup by an alarm, there might be no
    // home screen behind it. Ensure we have a place to go.
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.homeRoute,
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // _isStopping guards against double-stop if _handleAccept already ran
    if (!_isStopping) {
      _ringtonePlayer.stop();
      Vibration.cancel();
    }
    // Release the player after stop — prevents the native reset/release race
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = taskData?['callerName'] ?? 'Task Reminder';
    final title = taskData?['title'] ?? 'Reminder';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: _buildIncomingCallUI(callerName, title),
      ),
    );
  }

  Widget _buildIncomingCallUI(String callerName, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Text(
            callerName,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2196F3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            'Incoming Task Reminder',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallButton(
                icon: Icons.call_end,
                color: const Color(0xFFFF4444),
                label: 'Decline',
                onTap: _handleDecline,
              ),
              _CallButton(
                icon: Icons.call,
                color: const Color(0xFF4CAF50),
                label: 'Accept',
                onTap: _handleAccept,
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
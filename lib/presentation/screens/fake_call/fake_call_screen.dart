import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  bool _isRinging = true;

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

    _startRingtone();
    _startVibration();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get task data from route arguments
    if (taskData == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          taskData = args;
        });
      }
    }
  }

  Future<void> _startRingtone() async {
    try {
      final ringtonePath = taskData?['ringtonePath'] ?? 'sounds/ringtone.mp3';
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource(ringtonePath));
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  Future<void> _startVibration() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
      debugPrint('Error vibrating: $e');
    }
  }

  Future<void> _stopRinging() async {
    setState(() => _isRinging = false);
    await _ringtonePlayer.stop();
    await Vibration.cancel();
    _pulseController.stop();
  }

  Future<void> _handleAccept() async {
    await _stopRinging();

    // Speak the task description
    final description = taskData?['description'] ??
        taskData?['title'] ??
        'Your task is due now';

    final fakeCallService = getIt<FakeCallService>();
    await fakeCallService.speakText(description);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task: ${taskData?['title'] ?? 'Reminder'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Stay on screen to show task details
      setState(() {});
    }
  }

  Future<void> _handleDecline() async {
    await _stopRinging();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringtonePlayer.dispose();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = taskData?['callerName'] ?? 'Task Reminder';
    final title = taskData?['title'] ?? 'Reminder';
    final description = taskData?['description'] ?? '';

    return Scaffold(
      backgroundColor: _isRinging ? const Color(0xFF1E1E1E) : Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isRinging ? _buildIncomingCallUI(callerName, title) : _buildAnsweredCallUI(title, description),
        ),
      ),
    );
  }

  Widget _buildIncomingCallUI(String callerName, String title) {
    return Container(
      key: const ValueKey('incoming'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),

          // Caller Name
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

          // Task Title
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

          // Pulsing Avatar
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

          // Incoming Call Text
          const Text(
            'Incoming Task Reminder',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),

          const Spacer(),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decline Button
              Column(
                children: [
                  GestureDetector(
                    onTap: _handleDecline,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF4444),
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Accept Button
              Column(
                children: [
                  GestureDetector(
                    onTap: _handleAccept,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50),
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildAnsweredCallUI(String title, String description) {
    return Container(
      key: const ValueKey('answered'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Success Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4CAF50).withValues(alpha:0.1),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 60,
              color: Color(0xFF4CAF50),
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Task Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),

          const SizedBox(height: 20),

          // Task Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Title:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),

            // Task Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          const Row(
            children: [
              Icon(Icons.volume_up, color: Color(0xFF2196F3), size: 20),
              SizedBox(width: 8),
              Text(
                'Reading task aloud...',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Close Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/data/models/task_model.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  bool isListening = false;
  String transcribedText = '';
  DateTime? _selectedDateTime; // ✅ Track picked date/time
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  late stt.SpeechToText _speech;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => isListening = false);
            _animationController.stop();
            _animationController.reset();
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          setState(() => isListening = false);
          _animationController.stop();
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('Speech init error: $e');
      _speechAvailable = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      isListening = true;
      transcribedText = '';
      _selectedDateTime = null; // ✅ Reset picked time on new recording
    });

    _animationController.repeat(reverse: true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          transcribedText = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => isListening = false);
    _animationController.stop();
    _animationController.reset();
  }

  void _toggleListening() {
    if (isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  // ✅ Date/time picker — same flow as create_task_screen
  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2196F3),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2196F3),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future date and time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _selectedDateTime = combined);
  }

  void _saveTask() {
    if (transcribedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please speak a task first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a date and time for the task'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to add tasks'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newTask = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: transcribedText.trim(),
      description: 'Created via voice input',
      scheduledTime: _selectedDateTime!,
    );

    context.read<TaskBloc>().add(AddTask(user.uid, newTask));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Task added successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      transcribedText = '';
      _selectedDateTime = null;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Voice Input',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.black54, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Transcribed text box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minHeight: 100,
                      maxHeight: 200,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        transcribedText.isEmpty
                            ? 'Speak your task...'
                            : transcribedText,
                        style: TextStyle(
                          fontSize: 16,
                          color: transcribedText.isEmpty
                              ? Colors.grey[400]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Mic button
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isListening ? _scaleAnimation.value : 1.0,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: isListening
                                  ? Colors.grey[200]
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(25),
                                  blurRadius: 20,
                                  spreadRadius: isListening ? 5 : 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.mic,
                              size: 40,
                              color: isListening
                                  ? const Color(0xFF2196F3)
                                  : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    isListening ? 'Listening...' : 'Tap mic to start',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),

                  // ✅ Date/time picker + Save — only shown after recording
                  if (transcribedText.isNotEmpty) ...[
                    const SizedBox(height: 32),

                    // Date/time picker button
                    GestureDetector(
                      onTap: _pickDateTime,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedDateTime != null
                                ? const Color(0xFF2196F3)
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: _selectedDateTime != null
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _selectedDateTime == null
                                  ? 'Pick date & time'
                                  : '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year}  ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 15,
                                color: _selectedDateTime != null
                                    ? Colors.black87
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Save button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveTask,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                isActive: false,
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/home'),
              ),
              _buildNavItem(
                icon: Icons.mic,
                label: 'Voice Input',
                isActive: true,
                onTap: () {},
              ),
              _buildNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                isActive: false,
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF2196F3) : Colors.grey[600],
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
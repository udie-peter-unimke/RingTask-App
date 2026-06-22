import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/blocs/task/task_state.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/blocs/voice/voice_bloc.dart';
import 'package:ringtask/blocs/voice/voice_event.dart';
import 'package:ringtask/blocs/voice/voice_state.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/utils/task_parser.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  DateTime? _selectedDateTime;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPickingDateTime = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Reset voice state when entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceBloc>().add(const ResetVoiceEvent());
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _toggleListening(bool isListening) {
    final state = context.read<VoiceBloc>().state;
    if (state is VoicePermissionDeniedState) {
      if (state.isPermanentlyDenied) {
        context.read<VoiceBloc>().add(const OpenVoiceSettingsEvent());
      } else {
        context.read<VoiceBloc>().add(const RequestVoicePermissionEvent());
      }
      return;
    }

    if (isListening) {
      context.read<VoiceBloc>().add(const StopListeningEvent());
    } else {
      context.read<VoiceBloc>().add(const StartListeningEvent());
    }
  }

  Future<void> _pickDateTime() async {
    if (_isPickingDateTime) return;
    _isPickingDateTime = true;

    try {
      final now = DateTime.now();
      final initial = _selectedDateTime != null && _selectedDateTime!.isAfter(now)
          ? _selectedDateTime!
          : now;

      final pickedDate = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );

      if (pickedDate == null || !mounted) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a future date and time'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() => _selectedDateTime = combined);
    } finally {
      _isPickingDateTime = false;
    }
  }

  void _saveTask() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or speak a task'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a date and time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newTask = TaskModel(
      id: '',
      title: text,
      description: '',
      scheduledTime: _selectedDateTime!,
    );

    final settingsState = context.read<SettingsBloc>().state;
    SettingsModel? settings;
    if (settingsState is SettingsLoaded) {
      settings = settingsState.settings;
    } else if (settingsState is SettingsUpdateSuccess) {
      settings = settingsState.settings;
    } else if (settingsState is SettingsSyncSuccess) {
      settings = settingsState.syncedSettings;
    } else if (settingsState is SettingsResetSuccess) {
      settings = settingsState.defaultSettings;
    }

    context.read<TaskBloc>().add(AddTask(user.uid, newTask, settings: settings));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return MultiBlocListener(
      listeners: [
        BlocListener<VoiceBloc, VoiceState>(
          listener: (context, state) {
            if (state is VoiceListeningState && state.partialResult != null) {
              _textController.text = state.partialResult!;
            } else if (state is VoiceRecognizedState) {
              final parsed = TaskParser.parseVoiceInput(state.recognizedText);
              _textController.text = parsed.title;
              
              if (parsed.dateTime != null) {
                setState(() => _selectedDateTime = parsed.dateTime);
              } else {
                // Automatically prompt for date/time if not parsed and not already set
                if (_selectedDateTime == null) {
                  _pickDateTime();
                }
              }
            } else if (state is VoiceErrorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage), backgroundColor: colorScheme.error),
              );
            } else if (state is VoicePermissionDeniedState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.reason),
                  backgroundColor: colorScheme.secondaryContainer,
                  action: SnackBarAction(
                    label: state.isPermanentlyDenied ? 'Settings' : 'Grant',
                    textColor: colorScheme.onSecondaryContainer,
                    onPressed: () {
                      if (state.isPermanentlyDenied) {
                        context.read<VoiceBloc>().add(const OpenVoiceSettingsEvent());
                      } else {
                        context.read<VoiceBloc>().add(const RequestVoicePermissionEvent());
                      }
                    },
                  ),
                ),
              );
            }
          },
        ),
        BlocListener<TaskBloc, TaskState>(
          listener: (context, state) {
            if (state is TaskAdded && mounted) {
              Navigator.pop(context);
            } else if (state is TaskError && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: colorScheme.error),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<VoiceBloc, VoiceState>(
        builder: (context, voiceState) {
          final isListening = voiceState is VoiceListeningState;
          
          return BlocBuilder<TaskBloc, TaskState>(
            builder: (context, taskState) {
              final isLoading = taskState is TaskOperationInProgress;

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  title: Text(
                    'Voice Input',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                body: Column(
                  children: [
                    if (isLoading)
                      LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        color: colorScheme.primary,
                        minHeight: 3,
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 22),
                            // Editable transcription box
                            TextField(
                              controller: _textController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'Speak or type your task...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colorScheme.primary),
                                ),
                                fillColor: theme.cardColor,
                                filled: true,
                              ),
                              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                            ),

                            const SizedBox(height: 48),

                            // Mic button with animation
                            GestureDetector(
                              onTap: isLoading ? null : () => _toggleListening(isListening),
                              child: AnimatedBuilder(
                                animation: _scaleAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: isListening ? _scaleAnimation.value : 1.0,
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: isListening
                                            ? colorScheme.primary.withValues(alpha: 0.1)
                                            : (isDark ? Colors.grey[900] : Colors.grey[100]),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isListening
                                              ? colorScheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        isListening ? Icons.stop : Icons.mic,
                                        size: 36,
                                        color: isListening
                                            ? colorScheme.primary
                                            : colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isListening ? 'Listening...' : 'Tap mic to start',
                              style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),

                            const SizedBox(height: 48),

                            // Date/time picker
                            GestureDetector(
                              onTap: isLoading ? null : _pickDateTime,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedDateTime != null
                                        ? colorScheme.primary
                                        : theme.dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 20,
                                      color: _selectedDateTime != null
                                          ? colorScheme.primary
                                          : colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _selectedDateTime == null
                                          ? 'Set date & time'
                                          : () {
                                              final settingsState =
                                                  context.read<SettingsBloc>().state;
                                              final settings = settingsState
                                                      is SettingsLoaded
                                                  ? settingsState.settings
                                                  : settingsState
                                                          is SettingsUpdateSuccess
                                                      ? settingsState.settings
                                                      : const SettingsModel();
                                              final use24HourFormat =
                                                  settings.show24HourTime;
                                              final timeFormat =
                                                  use24HourFormat ? 'HH:mm' : 'h:mm a';
                                              return DateFormat(
                                                      'MMM d, y  $timeFormat')
                                                  .format(_selectedDateTime!);
                                            }(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _selectedDateTime != null
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_drop_down, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _saveTask,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedDateTime == null
                                      ? (isDark ? Colors.grey[800] : Colors.grey[400])
                                      : colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: colorScheme.onPrimary,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Create Task',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

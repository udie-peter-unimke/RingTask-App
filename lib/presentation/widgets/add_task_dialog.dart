import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/blocs/voice/voice_bloc.dart';
import 'package:ringtask/blocs/voice/voice_event.dart';
import 'package:ringtask/blocs/voice/voice_state.dart';
import 'package:ringtask/utils/task_parser.dart';
import 'package:ringtask/router.dart';

class AddTaskDialog extends StatefulWidget {
  final DateTime? initialDate;
  const AddTaskDialog({super.key, this.initialDate});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  // ✅ Controllers live in StatefulWidget lifecycle — safe disposal guaranteed
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  late DateTime _selectedDateTime;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.initialDate ?? DateTime.now().add(const Duration(hours: 1));
    
    // Ensure voice is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceBloc>().add(const InitializeVoiceEvent());
    });
  }

  @override
  void dispose() {
    // ✅ Only called when widget is fully removed from tree
    // — AFTER keyboard and all animations are done
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year, date.month, date.day,
        time.hour, time.minute,
      );
    });
  }

  void _toggleVoiceListening() {
    final voiceBloc = context.read<VoiceBloc>();
    final voiceState = voiceBloc.state;

    if (voiceState is VoicePermissionDeniedState) {
      if (voiceState.isPermanentlyDenied) {
        voiceBloc.add(const OpenVoiceSettingsEvent());
      } else {
        voiceBloc.add(const RequestVoicePermissionEvent());
      }
      return;
    }

    if (_isListening) {
      voiceBloc.add(const StopListeningEvent());
    } else {
      voiceBloc.add(const StartListeningEvent());
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a task title'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newTask = TaskModel(
      id: '', // Repository will generate ID if empty
      title: title,
      description: _descController.text.trim(),
      scheduledTime: _selectedDateTime,
    );

    // ✅ Capture everything BEFORE pop
    final settingsState = context.read<SettingsBloc>().state;
    final settings = settingsState is SettingsLoaded
        ? settingsState.settings
        : settingsState is SettingsUpdateSuccess
        ? settingsState.settings
        : null;
    final taskBloc = context.read<TaskBloc>();

    Navigator.pop(context); // ← now safe to pop

    taskBloc.add(AddTask(user.uid, newTask, settings: settings)); // ← safe reference
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsState = context.watch<SettingsBloc>().state;
    final settings = settingsState is SettingsLoaded
        ? settingsState.settings
        : settingsState is SettingsUpdateSuccess
        ? settingsState.settings
        : const SettingsModel();
    final use24HourFormat = settings.show24HourTime;
    final timeFormat = use24HourFormat ? 'HH:mm' : 'h:mm a';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.add_task, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Add New Task'),
        ],
      ),
      content: MultiBlocListener(
        listeners: [
          BlocListener<VoiceBloc, VoiceState>(
            listener: (context, state) {
              if (state is VoiceListeningState) {
                setState(() => _isListening = true);
                if (state.partialResult != null) {
                  _titleController.text = state.partialResult!;
                }
              } else if (state is VoiceRecognizedState) {
                setState(() => _isListening = false);
                final parsed = TaskParser.parseVoiceInput(state.recognizedText);
                _titleController.text = parsed.title;
                if (parsed.dateTime != null) {
                  setState(() => _selectedDateTime = parsed.dateTime!);
                }
              } else if (state is VoiceStoppedState || state is VoiceErrorState || state is VoiceCancelledState) {
                setState(() => _isListening = false);
                if (state is VoiceErrorState) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage), backgroundColor: colorScheme.error),
                  );
                }
              } else if (state is VoicePermissionDeniedState) {
                setState(() => _isListening = false);
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
        ],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: false,
                decoration: InputDecoration(
                  labelText: _isListening ? 'Listening...' : 'Task Title *',
                  labelStyle: TextStyle(color: _isListening ? colorScheme.primary : null),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.title),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: _isListening ? colorScheme.error : colorScheme.primary,
                        ),
                        onPressed: _toggleVoiceListening,
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.grey),
                        onPressed: () {
                          Navigator.pushNamed(context, AppRouter.voiceRoute);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scheduled Time',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, y \'at\' $timeFormat')
                                  .format(_selectedDateTime),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          onPressed: _submit,
          child: const Text('Add Task'),
        ),
      ],
    );
  }
}
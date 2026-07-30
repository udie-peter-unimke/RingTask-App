// lib/presentation/widgets/loop_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/blocs/loop/loop_bloc.dart';
import 'package:ringtask/blocs/loop/loop_event.dart';
import 'package:ringtask/data/models/loop_model.dart';
import 'package:table_calendar/table_calendar.dart';

/// TaskLoopDialog handles the creation and editing of task loop items.
class TaskLoopDialog extends StatefulWidget {
  final TaskLoopItem? task;

  const TaskLoopDialog({super.key, this.task});

  /// Shows the task creation/editing dialog.
  static Future<void> show(BuildContext context, {TaskLoopItem? task}) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => TaskLoopDialog(task: task),
    );
  }

  @override
  State<TaskLoopDialog> createState() => _TaskLoopDialogState();
}

class _TaskLoopDialogState extends State<TaskLoopDialog> {
  static const List<Map<String, dynamic>> _weekdayOptions = [
    {'label': 'Mon', 'day': 1},
    {'label': 'Tue', 'day': 2},
    {'label': 'Wed', 'day': 3},
    {'label': 'Thu', 'day': 4},
    {'label': 'Fri', 'day': 5},
    {'label': 'Sat', 'day': 6},
    {'label': 'Sun', 'day': 7},
  ];

  late TextEditingController _titleController;
  late String _timeString;
  late String _period;
  late RecurrenceType _recurrence;
  late Set<int> _selectedWeekdays;
  DateTime? _chosenDate;
  late DateTime _dialogFocusedDay;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _timeString = task?.timeString ?? '10:00';
    _period = task?.period ?? 'AM';
    _recurrence = task?.recurrence ?? RecurrenceType.daily;
    _selectedWeekdays = task?.weekdays.toSet() ?? {};
    _chosenDate = task?.specificDate;
    _dialogFocusedDay = _chosenDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onSave() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final loopBloc = context.read<LoopBloc>();
    final taskTitle = _titleController.text.trim();
    final taskDisplay = TaskLoopItem.buildDaysDisplay(
      recurrence: _recurrence,
      weekdays: _selectedWeekdays.toList(),
      specificDate: _chosenDate,
    );

    if (_isEditing) {
      final updatedTask = widget.task!.copyWith(
        title: taskTitle,
        timeString: _timeString,
        period: _period,
        recurrence: _recurrence,
        customDaysDisplay: taskDisplay,
        weekdays: _selectedWeekdays.toList(),
        specificDate: _chosenDate,
      );
      loopBloc.add(UpdateTaskEvent(userId: user.uid, task: updatedTask));
    } else {
      loopBloc.add(
        CreateTaskEvent(
          userId: user.uid,
          title: taskTitle,
          timeString: _timeString,
          period: _period,
          recurrence: _recurrence,
          customDaysDisplay: taskDisplay,
          weekdays: _selectedWeekdays.toList(),
          specificDate: _chosenDate,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'Create New Task'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'e.g., Morning Meditation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _buildTimeInput(theme),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrence,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _recurrence = value;
                      if (_recurrence != RecurrenceType.weekly) {
                        _selectedWeekdays.clear();
                      }
                      if (_recurrence == RecurrenceType.monthly ||
                          _recurrence == RecurrenceType.oneTime) {
                        _chosenDate ??= DateTime.now();
                        _dialogFocusedDay = _chosenDate!;
                      } else {
                        _chosenDate = null;
                      }
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Recurrence',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: RecurrenceType.daily, child: Text('Daily')),
                  DropdownMenuItem(value: RecurrenceType.weekly, child: Text('Weekly')),
                  DropdownMenuItem(value: RecurrenceType.monthly, child: Text('Monthly')),
                  DropdownMenuItem(value: RecurrenceType.oneTime, child: Text('One time')),
                ],
              ),
              if (_recurrence == RecurrenceType.weekly) _buildWeeklyChips(),
              if (_recurrence == RecurrenceType.monthly) _buildMonthlyCalendar(),
              if (_recurrence == RecurrenceType.oneTime) _buildOneTimeDatePicker(),
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
          onPressed: _titleController.text.trim().isEmpty ? null : _onSave,
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildTimeInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Select Time', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: CupertinoTheme(
            data: CupertinoThemeData(brightness: theme.brightness),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: _getInitialDateTime(),
              onDateTimeChanged: (DateTime newDateTime) {
                final hour = newDateTime.hour;
                final minute = newDateTime.minute;
                final newPeriod = hour >= 12 ? 'PM' : 'AM';
                int displayHour = hour % 12;
                if (displayHour == 0) displayHour = 12;
                setState(() {
                  _timeString =
                      '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                  _period = newPeriod;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  DateTime _getInitialDateTime() {
    try {
      final parts = _timeString.split(':');
      int h = int.parse(parts[0]);
      final int m = int.parse(parts[1]);
      if (_period == 'PM' && h < 12) h += 12;
      if (_period == 'AM' && h == 12) h = 0;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, h, m);
    } catch (e) {
      return DateTime.now();
    }
  }

  Widget _buildWeeklyChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Choose days')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _weekdayOptions)
                FilterChip(
                  label: Text(entry['label'] as String),
                  selected: _selectedWeekdays.contains(entry['day'] as int),
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        _selectedWeekdays.add(entry['day'] as int);
                      } else {
                        _selectedWeekdays.remove(entry['day'] as int);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Choose day of month')),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _dialogFocusedDay,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) =>
                  _chosenDate != null && isSameDay(_chosenDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _chosenDate = selectedDay;
                  _dialogFocusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOneTimeDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _chosenDate == null
                  ? 'No date selected'
                  : DateFormat.yMMMd().format(_chosenDate!),
            ),
          ),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _chosenDate ?? now,
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) {
                setState(() => _chosenDate = picked);
              }
            },
            child: const Text('Pick date'),
          ),
        ],
      ),
    );
  }
}

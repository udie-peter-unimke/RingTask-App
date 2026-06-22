// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
import 'package:ringtask/presentation/widgets/task_card.dart';
import 'package:ringtask/presentation/screens/settings/settings_screen.dart';
import 'package:ringtask/presentation/screens/loop/loop_screen.dart';
import 'package:ringtask/presentation/widgets/add_task_dialog.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/services/sync_service.dart';
import 'package:table_calendar/table_calendar.dart';

class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({super.key});

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnimation;
  int _currentIndex = 0;
  String _selectedFilter = 'All Tasks';
  final TextEditingController _searchController = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isQuickVoiceActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 🚀 Initialize SyncService
        getIt<SyncService>().initialize(user.uid);

        final settingsState = context.read<SettingsBloc>().state;
        final settings = settingsState is SettingsLoaded
            ? settingsState.settings
            : settingsState is SettingsUpdateSuccess
            ? settingsState.settings
            : null;
        context.read<TaskBloc>().add(LoadTasks(user.uid, settings: settings));
      }
    });

    _searchController.addListener(() => setState(() {}));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _offsetAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TaskModel> _getFilteredTasks(List<TaskModel> tasks) {
    var filtered = tasks.where((task) => !task.isDeletedLocally).toList();
    if (_selectedFilter == 'In Progress') {
      filtered = filtered.where((t) => !t.isCompleted).toList();
    }
    if (_selectedFilter == 'Completed') {
      filtered = filtered.where((t) => t.isCompleted).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((task) =>
      task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showSnackBar(String message, Color color) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName?.split(' ').first ?? 'User';

    return MultiBlocListener(
      listeners: [
        BlocListener<VoiceBloc, VoiceState>(
          listener: _onVoiceStateChanged,
        ),
        BlocListener<TaskBloc, TaskState>(
          listener: (context, state) {
            if (state is TaskAdded && mounted) {
              final isSynced = state.addedTask.isSynced;
              _showSnackBar(
                  '✓ Task "${state.addedTask.title}" ${isSynced ? "synced" : "saved locally"}',
                  isSynced ? Colors.green : Colors.orange);
            } else if (state is TaskUpdated && mounted) {
              _showSnackBar(
                  '✓ Task "${state.updatedTask.title}" updated!', Colors.blue);
            } else if (state is TaskDeleted && mounted) {
              _showSnackBar('Task deleted', Colors.red);
            } else if (state is TaskError && mounted) {
              _showSnackBar(state.message, Colors.orange);
            }
          },
        ),
      ],
      child: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          final settingsState = context.watch<SettingsBloc>().state;
          final settings = settingsState is SettingsLoaded
              ? settingsState.settings
              : settingsState is SettingsUpdateSuccess
              ? settingsState.settings
              : const SettingsModel();
          final use24HourFormat = settings.show24HourTime;

          if (state is TaskLoading && state.tasks.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final tasks = _getFilteredTasks(state.tasks);
          final isOperationInProgress = state is TaskOperationInProgress;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          '${_getGreeting()}, $userName 👋',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _FilterChip(
                              label: 'All Tasks',
                              isActive: _selectedFilter == 'All Tasks',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'All Tasks'),
                            ),
                            _FilterChip(
                              label: 'In Progress',
                              isActive: _selectedFilter == 'In Progress',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'In Progress'),
                            ),
                            _FilterChip(
                              label: 'Completed',
                              isActive: _selectedFilter == 'Completed',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'Completed'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search tasks...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () => _searchController.clear(),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.mic, color: Colors.blue),
                                  onPressed: _startQuickVoiceInput,
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: tasks.isEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.task_alt,
                                    size: 80,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No tasks found'
                                      : 'No tasks yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'Try a different search'
                                      : 'Tap + to add your first task',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                              : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return _buildTaskItem(task, use24HourFormat);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  if (isOperationInProgress)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        color: Colors.blue,
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
            floatingActionButton: AnimatedBuilder(
              animation: _offsetAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _offsetAnimation.value),
                child: child,
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.blue,
                onPressed: _showAddTaskDialog,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex > 3 ? 0 : _currentIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              onTap: (index) => _onBottomNavTap(index, state.tasks),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.alarm_outlined), label: 'Loop'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onVoiceStateChanged(BuildContext context, VoiceState state) {
    if (!_isQuickVoiceActive) return;

    if (state is VoiceRecognizedState) {
      final text = state.recognizedText.trim();
      if (text.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          setState(() => _isQuickVoiceActive = false);

          final parsed = TaskParser.parseVoiceInput(text);

          final settingsState = context.read<SettingsBloc>().state;
          final settings = settingsState is SettingsLoaded
              ? settingsState.settings
              : settingsState is SettingsUpdateSuccess
              ? settingsState.settings
              : null;

          final newTask = TaskModel(
            id: '',
            title: parsed.title.isEmpty ? text : parsed.title,
            description: 'Created via quick voice',
            scheduledTime: parsed.dateTime ?? DateTime.now().add(const Duration(hours: 1)),
          );

          context.read<TaskBloc>().add(AddTask(user.uid, newTask, settings: settings));

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      }
    } else if (state is VoiceErrorState) {
      setState(() => _isQuickVoiceActive = false);
      _showSnackBar(state.errorMessage, Colors.red);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _startQuickVoiceInput() {
    if (_isQuickVoiceActive) return;

    setState(() => _isQuickVoiceActive = true);
    context.read<VoiceBloc>().add(const StartListeningEvent());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QuickVoiceOverlay(),
    ).then((_) {
      if (mounted) {
        setState(() => _isQuickVoiceActive = false);
        context.read<VoiceBloc>().add(const StopListeningEvent());
      }
    });
  }

  Widget _buildTaskItem(TaskModel task, bool use24HourFormat) {
    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => _confirmDelete(context, task),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Stack(
        children: [
          TaskCard(
            task: task,
            use24HourFormat: use24HourFormat,
            onToggle: () => _toggleTaskCompletion(task),
            onDelete: () => _deleteTask(task.id),
          ),
          if (!task.isSynced)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_off, size: 10, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TaskModel task) async {
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed == true) _deleteTask(task.id);
  }

  void _deleteTask(String taskId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    context.read<TaskBloc>().add(DeleteTask(user.uid, taskId));
  }

  void _toggleTaskCompletion(TaskModel task) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final settingsState = context.read<SettingsBloc>().state;
    final settings = settingsState is SettingsLoaded
        ? settingsState.settings
        : settingsState is SettingsUpdateSuccess
        ? settingsState.settings
        : null;
    context.read<TaskBloc>().add(
      UpdateTask(
        user.uid,
        task.copyWith(isCompleted: !task.isCompleted),
        settings: settings,
      ),
    );
  }

  void _showAddTaskDialog({DateTime? initialDate}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<TaskBloc>()),
          BlocProvider.value(value: context.read<SettingsBloc>()),
        ],
        child: AddTaskDialog(initialDate: initialDate),
      ),
    );
  }

  void _onBottomNavTap(int index, List<TaskModel> tasks) {
    if (index == 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    // Loop screen
    if (index == 1) {
      setState(() => _currentIndex = 1);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TaskLoopScreen()),
      ).then((_) {
        if (mounted) setState(() => _currentIndex = 0);
      });
      return;
    }

    // Calendar
    if (index == 2) {
      _showFullCalendar(tasks);
      return;
    }

    // Settings
    if (index == 3) {
      setState(() => _currentIndex = 3);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ).then((_) {
        if (mounted) setState(() => _currentIndex = 0);
      });
      return;
    }
  }

  void _showFullCalendar(List<TaskModel> tasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Calendar Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.month,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: (day) {
                      return tasks.where((task) => isSameDay(task.scheduledTime, day)).toList();
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setModalState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      Navigator.pop(context);
                      _showAddTaskDialog(initialDate: selectedDay);
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue
              : Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.blue,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _QuickVoiceOverlay extends StatelessWidget {
  const _QuickVoiceOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceBloc, VoiceState>(
      builder: (context, state) {
        String text = 'Listening...';
        if (state is VoiceListeningState && state.partialResult != null) {
          text = state.partialResult!;
        }

        return Container(
          height: 250,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Direct Voice Input',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: text == 'Listening...' ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                      fontStyle: text == 'Listening...' ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _RippleMicIcon(),
              const SizedBox(height: 8),
              Text(
                'Speak your task and stop to save',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RippleMicIcon extends StatefulWidget {
  const _RippleMicIcon();

  @override
  State<_RippleMicIcon> createState() => _RippleMicIconState();
}

class _RippleMicIconState extends State<_RippleMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Container(
              width: 40 + (20 * _controller.value),
              height: 40 + (20 * _controller.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.2 - (0.2 * _controller.value)),
              ),
              child: const Icon(Icons.mic, color: Colors.blue, size: 28),
            ),
          ),
        );
      },
    );
  }
}
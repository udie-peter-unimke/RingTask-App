// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/blocs/task/task_state.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/presentation/widgets/task_card.dart';
import 'package:ringtask/presentation/screens/voice_input/voice_input_screen.dart';
import 'package:ringtask/presentation/screens/settings/settings_screen.dart';
import 'package:ringtask/presentation/widgets/add_task_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<TaskBloc>().add(LoadTasks(user.uid));
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
    var filtered = tasks;
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

    return BlocConsumer<TaskBloc, TaskState>(
      listener: (context, state) {
        if (state is TaskAdded && mounted) {
          _showSnackBar('✓ Task "${state.addedTask.title}" added!', Colors.green);
        } else if (state is TaskUpdated && mounted) {
          // ✅ ADDED: show snackbar when task is updated
          _showSnackBar('✓ Task "${state.updatedTask.title}" updated!', Colors.blue);
        } else if (state is TaskDeleted && mounted) {
          _showSnackBar('Task deleted', Colors.red);
        } else if (state is TaskError && mounted) {
          _showSnackBar(state.message, Colors.orange);
        }
      },
      builder: (context, state) {
        // ✅ KEPT: full screen spinner only on initial load with no tasks yet
        if (state is TaskLoading && state.tasks.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final tasks = _getFilteredTasks(state.tasks);

        // ✅ ADDED: TaskOperationInProgress — list stays visible with subtle
        // LinearProgressIndicator at top while add/update/delete is in progress
        final isOperationInProgress = state is TaskOperationInProgress;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
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
                        style:
                        const TextStyle(fontSize: 13, color: Colors.grey),
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
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
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
                            return _buildTaskItem(task);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ ADDED: subtle LinearProgressIndicator shown at top of screen
                // only during CRUD operations — list stays fully visible below it
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
            child: FloatingActionButton.extended(
              backgroundColor: Colors.blue,
              onPressed: _showAddTaskDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Task',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            onTap: _onBottomNavTap,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.mic_none), label: 'Voice Input'),

              BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(TaskModel task) {
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
      child: TaskCard(
        task: task,
        onToggle: () => _toggleTaskCompletion(task),
        onDelete: () => _deleteTask(task.id),
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
    context.read<TaskBloc>().add(
      UpdateTask(user.uid, task.copyWith(isCompleted: !task.isCompleted)),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskBloc>(),
        child: const AddTaskDialog(),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    if (index == 0) return;

    setState(() => _currentIndex = index);

    Widget screen;
    if (index == 1) {
      screen = const VoiceInputScreen();
    } else if (index == 2) {
      screen = const SettingsScreen(); // ← was FakeCallScreen
    } else {
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) setState(() => _currentIndex = 0);
    });
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
          // ✅ FIXED: withAlpha(20) → withValues(alpha: 0.08) — not deprecated
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
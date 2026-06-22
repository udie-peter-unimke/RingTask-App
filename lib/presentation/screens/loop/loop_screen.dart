import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ringtask/blocs/loop/loop_bloc.dart';
import 'package:ringtask/blocs/loop/loop_event.dart';
import 'package:ringtask/data/models/loop_model.dart';
import 'package:ringtask/blocs/loop/loop_state.dart';

class TaskLoopScreen extends StatefulWidget {
  const TaskLoopScreen({super.key});

  @override
  State<TaskLoopScreen> createState() => _TaskLoopScreenState();
}

class _TaskLoopScreenState extends State<TaskLoopScreen> {
  @override
  void initState() {
    super.initState();
    // Load tasks when screen initializes
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<LoopBloc>().add(LoadLoopsEvent(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          'Alarm',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
            onPressed: () => _showCreateTaskDialog(context),
            tooltip: 'Add new task',
          ),
          IconButton(
            icon: Icon(Icons.cloud_upload_outlined, color: colorScheme.secondary),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                context.read<LoopBloc>().add(SeedSampleDataEvent(user.uid));
              }
            },
            tooltip: 'Seed sample data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: BlocConsumer<LoopBloc, LoopState>(
            listener: (context, state) {
              if (state is LoopError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (state is LoopLoaded && state.message != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message!),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is LoopInitial || state is LoopLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state is LoopError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            context.read<LoopBloc>().add(LoadLoopsEvent(user.uid));
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is LoopLoaded) {
                final tasks = state.tasks;

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          color: Colors.grey,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No tasks yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new task or load sample data',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreateTaskDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Task'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  context
                                      .read<LoopBloc>()
                                      .add(SeedSampleDataEvent(user.uid));
                                }
                              },
                              icon: const Icon(Icons.downloading),
                              label: const Text('Load Samples'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: tasks.length,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildTaskCard(
                        context,
                        task,
                      ),
                    );
                  },
                );
              }

              return const Center(
                child: Text('Unknown state'),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build individual task card with gestures and actions
  Widget _buildTaskCard(
      BuildContext context,
      TaskLoopItem task,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background accent on the right
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: SizedBox(
                width: 100,
                child: CustomPaint(
                  painter: CardBackgroundPainter(
                    color: colorScheme.onSurface.withValues(alpha: isDark ? 0.05 : 0.02),
                  ),
                ),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left side: task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task title/label
                      Text(
                        task.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Time display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            task.timeString,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: task.isActive ? 1.0 : 0.6,
                              ),
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.period,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: task.isActive ? 1.0 : 0.6,
                              ),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Recurrence display
                      Text(
                        task.customDaysDisplay,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side: actions
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle switch
                    Transform.scale(
                      scale: 1.1,
                      child: Switch(
                        value: task.isActive,
                        activeThumbColor: Colors.white,
                        activeTrackColor: colorScheme.primary,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: isDark ? Colors.grey[800] : const Color(0xFFDCDFE7),
                        onChanged: (bool value) {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            context.read<LoopBloc>().add(
                              ToggleTaskActiveEvent(
                                userId: user.uid,
                                task: task,
                                value: value,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _showDeleteConfirmation(context, task),
                      tooltip: 'Delete task',
                      splashRadius: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog to create a new task
  void _showCreateTaskDialog(BuildContext context) {
    String title = '';
    String timeString = '10:00';
    String period = 'AM';
    RecurrenceType recurrence = RecurrenceType.daily;
    String customDaysDisplay = 'Every Day';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title input
                TextField(
                  onChanged: (value) {
                    setDialogState(() => title = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g., Morning Meditation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Time input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setDialogState(() => timeString = value);
                        },
                        controller: TextEditingController(text: timeString),
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          hintText: 'HH:MM',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: period,
                      onChanged: (value) {
                        setDialogState(() => period = value ?? 'AM');
                      },
                      items: const [
                        DropdownMenuItem(value: 'AM', child: Text('AM')),
                        DropdownMenuItem(value: 'PM', child: Text('PM')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Recurrence dropdown
                DropdownButtonFormField<RecurrenceType>(
                  initialValue: recurrence,
                  onChanged: (value) {
                    setDialogState(() => recurrence = value ?? RecurrenceType.daily);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Recurrence',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RecurrenceType.daily,
                      child: Text('Daily'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceType.weekly,
                      child: Text('Weekly'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceType.monthly,
                      child: Text('Monthly'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: title.isEmpty
                  ? null
                  : () {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  context.read<LoopBloc>().add(
                    CreateTaskEvent(
                      userId: user.uid,
                      title: title,
                      timeString: timeString,
                      period: period,
                      recurrence: recurrence,
                      customDaysDisplay: customDaysDisplay,
                    ),
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, TaskLoopItem task) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                context.read<LoopBloc>().add(DeleteTaskEvent(
                  userId: user.uid,
                  taskId: task.id,
                ));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for card background accent
class CardBackgroundPainter extends CustomPainter {
  final Color color;

  CardBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width * 0.3, 0);
    path.lineTo(size.width, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
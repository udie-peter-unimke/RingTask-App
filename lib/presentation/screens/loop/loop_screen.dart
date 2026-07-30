// lib/presentation/screens/loop/loop_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:ringtask/blocs/loop/loop_bloc.dart';
import 'package:ringtask/blocs/loop/loop_event.dart';
import 'package:ringtask/data/models/loop_model.dart';
import 'package:ringtask/blocs/loop/loop_state.dart';
import 'package:ringtask/presentation/widgets/loop_dialog.dart';

class TaskLoopScreen extends StatefulWidget {
  const TaskLoopScreen({super.key});

  @override
  State<TaskLoopScreen> createState() => _TaskLoopScreenState();
}

class _TaskLoopScreenState extends State<TaskLoopScreen> {
  @override
  void initState() {
    super.initState();
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
            onPressed: () => TaskLoopDialog.show(context),
            tooltip: 'Add new task',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            onPressed: () => _showClearAllConfirmation(context),
            tooltip: 'Clear all tasks',
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              } else if (state is LoopLoaded && state.message != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                });
              }
            },
            builder: (context, state) {
              if (state is LoopInitial || state is LoopLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is LoopError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
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
                        const Icon(Icons.inbox_outlined, color: Colors.grey, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No tasks yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new task or load sample data',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => TaskLoopDialog.show(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Task'),
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
                      key: ValueKey(task.id),
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: LoopTaskCard(
                        task: task,
                        onDelete: () => _showDeleteConfirmation(context, task),
                      ),
                    );
                  },
                );
              }

              return const Center(child: Text('Unknown state'));
            },
          ),
        ),
      ),
    );
  }

  void _showClearAllConfirmation(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Tasks'),
        content: const Text(
          'Are you sure you want to completely erase all alarms? This operation cannot be reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<LoopBloc>().add(ClearAllTasksEvent(user.uid));
              Navigator.pop(dialogContext);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TaskLoopItem task) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to drop "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<LoopBloc>().add(DeleteTaskEvent(userId: user.uid, taskId: task.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class LoopTaskCard extends StatelessWidget {
  final TaskLoopItem task;
  final VoidCallback onDelete;

  const LoopTaskCard({super.key, required this.task, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          onPressed: () => TaskLoopDialog.show(context, task: task),
                          tooltip: 'Edit task',
                          splashRadius: 24,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: onDelete,
                          tooltip: 'Delete task',
                          splashRadius: 24,
                        ),
                      ],
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
}

class CardBackgroundPainter extends CustomPainter {
  final Color color;
  const CardBackgroundPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CardBackgroundPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

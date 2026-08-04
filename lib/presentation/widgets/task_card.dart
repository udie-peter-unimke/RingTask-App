import 'package:flutter/material.dart';
//import 'package:intl/intl.dart'; // 🔥 ADDED for perfect date formatting
import 'package:ringtask/data/models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback? onDelete; // Added onDelete
  final bool use24HourFormat;

  const TaskCard({
    required this.task,
    required this.onToggle,
    this.onDelete, // Added onDelete
    this.use24HourFormat = true,
    super.key,
  });

  bool get isOverdue {
    return task.isOverdue; // 🔥 Use TaskModel's built-in method
  }

  String get formattedTime {
    return task.displayScheduledTimeFormatted(
        use24HourFormat: use24HourFormat); // 🔥 Use TaskModel's perfect formatting
  }

  String get timeUntil {
    return task.timeUntilString; // 🔥 Use TaskModel's smart formatting
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: task.isUrgent
            ? Border.all(color: Colors.blueGrey, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // 🔥 Fixed opacity
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          /// 🔥 PERFECT Checkbox/Icon Toggle
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                task.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.isCompleted
                    ? Colors.green
                    : Colors.grey.shade400,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          /// 🔥 MAIN CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title
                /// Title
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough  // ✅ FIXED!
                        : null,
                    color: task.isCompleted
                        ? Colors.grey.shade500        // ✅ Bonus: gray out completed
                        : null,
                  ),
                ),


                /// Description
                if (task.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                /// Date/Time + Status
                if (task.scheduledTime != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isOverdue ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isOverdue ? Colors.red : Colors.blue,
                            ),
                          ),
                        ),

                        /// 🔥 Time Until / Urgent Badge
                        if (task.isUrgent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (timeUntil.isNotEmpty)
                          Text(
                            timeUntil,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isOverdue ? Colors.red : Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          /// 🔥 DELETE BUTTON
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.withAlpha(200), size: 22),
              onPressed: onDelete,
              tooltip: 'Delete Task',
            ),
        ],
      ),
    );
  }
}

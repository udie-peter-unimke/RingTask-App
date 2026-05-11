import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/blocs/task/task_bloc.dart';
import 'package:ringtask/blocs/task/task_event.dart';
import 'package:ringtask/data/models/task_model.dart';

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  // ✅ Controllers live in StatefulWidget lifecycle — safe disposal guaranteed
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));

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

  void _submit() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final taskDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc();

    final newTask = TaskModel(
      id: taskDocRef.id,
      title: title,
      description: _descController.text.trim(),
      scheduledTime: _selectedDateTime,
    );

    // ✅ Pop first, then dispatch — dialog out of tree before BlocConsumer reacts
    Navigator.pop(context);
    context.read<TaskBloc>().add(AddTask(user.uid, newTask));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.add_task, color: Colors.blue),
          SizedBox(width: 8),
          Text('Add New Task'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: false,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
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
                  border: Border.all(color: Colors.blue.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blue),
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
                            DateFormat('MMM d, y \'at\' HH:mm')
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Add Task'),
        ),
      ],
    );
  }
}
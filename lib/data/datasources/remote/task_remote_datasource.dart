import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/utils/logger.dart';

/// ------------------------------------------------------------
/// REMOTE TASK DATA SOURCE (FIRESTORE)
/// ------------------------------------------------------------
///
/// RESPONSIBILITIES:
/// - CRUD operations for tasks
/// - User-scoped task storage
/// - Server timestamp handling
///
/// Firestore structure:
/// users/{uid}/tasks/{taskId}
/// ------------------------------------------------------------
abstract class TaskRemoteDataSource {
  Future<void> createTask(TaskModel task);
  Future<void> updateTask(TaskModel task);
  Future<void> deleteTask(String taskId);
  Future<List<TaskModel>> fetchTasks();
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskRemoteDataSourceImpl(
      this._firestore,
      this._auth,
      );

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-authenticated',
        message: 'User must be authenticated to access tasks',
      );
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _taskCollection =>
      _firestore.collection('users').doc(_userId).collection('tasks');

  // ------------------------------------------------------------
  // CREATE TASK
  // ------------------------------------------------------------
  @override
  Future<void> createTask(TaskModel task) async {
    try {
      await _taskCollection.doc(task.id).set(
        task.toJson()
          ..addAll({
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }),
      );
    } catch (e, s) {
      AppLogger.error(
        'Failed to create task',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // UPDATE TASK
  // ------------------------------------------------------------
  @override
  Future<void> updateTask(TaskModel task) async {
    try {
      await _taskCollection.doc(task.id).update(
        task.toJson()
          ..addAll({
            'updatedAt': FieldValue.serverTimestamp(),
          }),
      );
    } catch (e, s) {
      AppLogger.error(
        'Failed to update task',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // DELETE TASK
  // ------------------------------------------------------------
  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _taskCollection.doc(taskId).delete();
    } catch (e, s) {
      AppLogger.error(
        'Failed to delete task',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // FETCH TASKS
  // ------------------------------------------------------------
  @override
  Future<List<TaskModel>> fetchTasks() async {
    try {
      final snapshot = await _taskCollection
          .orderBy('scheduledTime')
          .get();

      return snapshot.docs
          .map((doc) => TaskModel.fromJson(doc.data()))
          .toList();
    } catch (e, s) {
      AppLogger.error(
        'Failed to fetch tasks',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }
}

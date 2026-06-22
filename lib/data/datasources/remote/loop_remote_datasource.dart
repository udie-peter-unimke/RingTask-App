import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/loop_model.dart';

/// Remote data source for Firestore interactions
class LoopRemoteDataSource {
  final FirebaseFirestore _firestore;
  static const String _collectionName = 'task_loops';

  LoopRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _getCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection(_collectionName);

  /// Get a stream of all tasks, ordered by update time
  Stream<List<TaskLoopItem>> getTasksStream(String userId) {
    return _getCollection(userId).orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
          .map((doc) => TaskLoopItem.fromDoc(doc))
          .toList(),
    );
  }

  /// Get all tasks once (non-streaming)
  Future<List<TaskLoopItem>> getTasks(String userId) async {
    try {
      final snapshot = await _getCollection(userId).orderBy('updatedAt', descending: true).get();
      return snapshot.docs.map((doc) => TaskLoopItem.fromDoc(doc)).toList();
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch tasks: $e');
    }
  }

  /// Create a new task
  Future<String> createTask(String userId, TaskLoopItem task) async {
    try {
      final docRef = _getCollection(userId).doc();
      final taskWithId = task.copyWith(id: docRef.id);
      await docRef.set(taskWithId.toMap());
      return docRef.id;
    } catch (e) {
      throw RemoteDataSourceException('Failed to create task: $e');
    }
  }

  /// Update an existing task
  Future<void> updateTask(String userId, TaskLoopItem task) async {
    try {
      await _getCollection(userId).doc(task.id).set(
        task.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw RemoteDataSourceException('Failed to update task: $e');
    }
  }

  /// Update only the active status of a task
  Future<void> updateTaskActiveStatus(String userId, String taskId, bool isActive) async {
    try {
      await _getCollection(userId).doc(taskId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw RemoteDataSourceException('Failed to update task status: $e');
    }
  }

  /// Delete a task
  Future<void> deleteTask(String userId, String taskId) async {
    try {
      await _getCollection(userId).doc(taskId).delete();
    } catch (e) {
      throw RemoteDataSourceException('Failed to delete task: $e');
    }
  }

  /// Batch create multiple tasks
  Future<void> batchCreateTasks(String userId, List<TaskLoopItem> tasks) async {
    try {
      final batch = _firestore.batch();
      for (final task in tasks) {
        final docRef = _getCollection(userId).doc();
        final taskWithId = task.copyWith(id: docRef.id);
        batch.set(docRef, taskWithId.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw RemoteDataSourceException('Failed to batch create tasks: $e');
    }
  }

  /// Clear all tasks (use with caution)
  Future<void> clearAllTasks(String userId) async {
    try {
      final docs = await _getCollection(userId).get();
      final batch = _firestore.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw RemoteDataSourceException('Failed to clear tasks: $e');
    }
  }

  /// Get a single task by ID
  Future<TaskLoopItem?> getTaskById(String userId, String taskId) async {
    try {
      final doc = await _getCollection(userId).doc(taskId).get();
      if (!doc.exists) return null;
      return TaskLoopItem.fromDoc(doc);
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch task by ID: $e');
    }
  }
}

/// Custom exception for remote data source errors
class RemoteDataSourceException implements Exception {
  final String message;

  RemoteDataSourceException(this.message);

  @override
  String toString() => 'RemoteDataSourceException: $message';
}
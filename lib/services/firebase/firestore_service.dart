import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/core/constants/firestore_collections.dart';

/// ------------------------------------------------------------
/// FIRESTORE SERVICE CONTRACT
/// ------------------------------------------------------------
abstract class IFirestoreService {
  // ==================== User Operations ====================
  Future<Map<String, dynamic>?> getUserData(String userId);
  Future<void> createUserData(String userId, Map<String, dynamic> userData);
  Future<void> updateUserData(String userId, Map<String, dynamic> userData);
  Future<void> deleteUserData(String userId);

  // ==================== Task Operations ====================
  Future<List<Map<String, dynamic>>> getAllUserTasks(String userId);
  Future<Map<String, dynamic>?> getUserTask(String userId, String taskId);
  Future<void> createUserTask(
      String userId,
      String taskId,
      Map<String, dynamic> taskData,
      );
  Future<void> updateUserTask(
      String userId,
      String taskId,
      Map<String, dynamic> taskData,
      );
  Future<void> deleteUserTask(String userId, String taskId);
  Future<void> deleteAllUserTasks(String userId);

  // ==================== Settings Operations ====================
  Future<Map<String, dynamic>?> getUserSettings(String userId);
  Future<void> updateUserSettings(String userId, Map<String, dynamic> settings);

  // ==================== Batch Operations ====================
  Future<void> batchUpdateTasks(
      String userId,
      List<String> taskIds,
      Map<String, dynamic> updateData,
      );

  // ✅ NEW: Batch delete operation for performance
  Future<void> batchDeleteUserTasks(String userId, List<String> taskIds);

  // ==================== Query Operations ====================
  Future<List<Map<String, dynamic>>> queryTasks(
      String userId,
      String field,
      dynamic value,
      );

  // ✅ NEW: Expose batch operations support flag
  bool get supportsBatchOperations;
}

/// ------------------------------------------------------------
/// FIRESTORE SERVICE IMPLEMENTATION
/// ------------------------------------------------------------
class FirestoreService implements IFirestoreService {
  // 🔹 Firestore collection constants
  static const String usersCollection = FirestoreCollections.users;
  static const String tasksCollection = FirestoreCollections.tasks;
  static const String settingsCollection = FirestoreCollections.settings;

  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ✅ NEW: Indicate batch operations are supported
  @override
  bool get supportsBatchOperations => true;

  // ==================== USER OPERATIONS ====================

  @override
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      AppLogger.info('Fetching user data: $userId');

      final doc =
      await _firestore.collection(usersCollection).doc(userId).get();

      return doc.data();
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error fetching user data: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> createUserData(
      String userId,
      Map<String, dynamic> userData,
      ) async {
    try {
      AppLogger.info('Creating user: $userId');

      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(userData);
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error creating user: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> updateUserData(
      String userId,
      Map<String, dynamic> userData,
      ) async {
    try {
      AppLogger.info('Updating user: $userId');

      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .update(userData);
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error updating user: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> deleteUserData(String userId) async {
    try {
      AppLogger.info('Deleting user: $userId');

      await _firestore.collection(usersCollection).doc(userId).delete();
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error deleting user: ${e.message}');
      rethrow;
    }
  }

  // ==================== TASK OPERATIONS ====================
  @override
  Future<List<Map<String, dynamic>>> getAllUserTasks(String userId) async {
    try {
      AppLogger.info('Fetching all tasks for user: $userId');

      final snapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .get();

      // ✅ Map the document ID to the 'id' field
      final tasks = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensures the ID survives a cache clear
        return data;
      }).toList();

      AppLogger.info('Retrieved ${tasks.length} tasks for user: $userId');
      return tasks;

    } catch (e) {
      AppLogger.error('Error fetching tasks for user $userId: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getUserTask(
      String userId,
      String taskId,
      ) async {
    try {
      AppLogger.info('Fetching task: $taskId for user: $userId');

      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .doc(taskId)
          .get();

      final data = doc.data();
      if (data != null) {
        data['id'] = doc.id; // Ensure ID is included
      }

      return data;
    } catch (e) {
      AppLogger.error('Error fetching task $taskId for user $userId: $e');
      return null;
    }
  }

  @override
  Future<void> createUserTask(
      String userId,
      String taskId,
      Map<String, dynamic> taskData,
      ) async {
    try {
      AppLogger.info('Creating task: $taskId for user: $userId');

      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .doc(taskId)
          .set(taskData, SetOptions(merge: true)); // ✅ Merge to protect data integrity

      AppLogger.info('✅ Task created: $taskId');
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error creating task: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> updateUserTask(
      String userId,
      String taskId,
      Map<String, dynamic> taskData,
      ) async {
    try {
      AppLogger.info('Updating task: $taskId for user: $userId');

      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .doc(taskId)
          .update(taskData);

      AppLogger.info('✅ Task updated: $taskId');
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error updating task: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> deleteUserTask(String userId, String taskId) async {
    try {
      AppLogger.info('Deleting task: $taskId for user: $userId');

      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .doc(taskId)
          .delete();

      AppLogger.info('✅ Task deleted: $taskId');
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error deleting task: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> deleteAllUserTasks(String userId) async {
    try {
      AppLogger.info('Deleting all tasks for user: $userId');

      final snapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .get();

      // ✅ Use batch delete for better performance
      if (snapshot.docs.isNotEmpty) {
        final taskIds = snapshot.docs.map((doc) => doc.id).toList();
        await batchDeleteUserTasks(userId, taskIds);
      }

      AppLogger.info('✅ All tasks deleted for user: $userId');
    } catch (e) {
      AppLogger.error('Error deleting all tasks for user $userId: $e');
      rethrow;
    }
  }

  // ==================== SETTINGS OPERATIONS ====================

  @override
  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    try {
      AppLogger.info('Fetching settings for user: $userId');

      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(settingsCollection)
          .doc('preferences')
          .get();

      return doc.data();
    } catch (e) {
      AppLogger.error('Error fetching settings for user $userId: $e');
      return null;
    }
  }

  @override
  Future<void> updateUserSettings(
      String userId,
      Map<String, dynamic> settings,
      ) async {
    try {
      AppLogger.info('Updating settings for user: $userId');

      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(settingsCollection)
          .doc('preferences')
          .set(settings, SetOptions(merge: true));

      AppLogger.info('✅ Settings updated for user: $userId');
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error updating settings: ${e.message}');
      rethrow;
    }
  }

  // ==================== BATCH OPERATIONS ====================

  @override
  Future<void> batchUpdateTasks(
      String userId,
      List<String> taskIds,
      Map<String, dynamic> updateData,
      ) async {
    try {
      if (taskIds.isEmpty) {
        AppLogger.warning('batchUpdateTasks called with empty task list');
        return;
      }

      AppLogger.info('Batch updating ${taskIds.length} tasks for user: $userId');

      // Firestore batch can handle up to 500 operations
      const batchSize = 500;

      for (var i = 0; i < taskIds.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < taskIds.length) ? i + batchSize : taskIds.length;
        final batchTaskIds = taskIds.sublist(i, end);

        for (final taskId in batchTaskIds) {
          final ref = _firestore
              .collection(usersCollection)
              .doc(userId)
              .collection(tasksCollection)
              .doc(taskId);

          batch.update(ref, updateData);
        }

        await batch.commit();
        AppLogger.info('✅ Batch updated ${batchTaskIds.length} tasks');
      }

      AppLogger.info('✅ Successfully batch updated ${taskIds.length} tasks');
    } catch (e) {
      AppLogger.error('Error batch updating tasks for user $userId: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Atomic batch deletion for performance optimization
  @override
  Future<void> batchDeleteUserTasks(String userId, List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) {
        AppLogger.warning('batchDeleteUserTasks called with empty task list');
        return;
      }

      AppLogger.info('Batch deleting ${taskIds.length} tasks for user: $userId');

      // Firestore batch can handle up to 500 operations
      const batchSize = 500;

      for (var i = 0; i < taskIds.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < taskIds.length) ? i + batchSize : taskIds.length;
        final batchTaskIds = taskIds.sublist(i, end);

        for (final taskId in batchTaskIds) {
          final docRef = _firestore
              .collection(usersCollection)
              .doc(userId)
              .collection(tasksCollection)
              .doc(taskId);

          batch.delete(docRef);
        }

        // Commit the batch
        await batch.commit();
        AppLogger.info('✅ Batch deleted ${batchTaskIds.length} tasks');
      }

      AppLogger.info('✅ Successfully batch deleted ${taskIds.length} tasks for user: $userId');
    } catch (e, stack) {
      AppLogger.error(
        'Error in batch delete operation for user $userId',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ==================== QUERY OPERATIONS ====================

  @override
  Future<List<Map<String, dynamic>>> queryTasks(
      String userId,
      String field,
      dynamic value,
      ) async {
    try {
      AppLogger.info('Querying tasks for user: $userId where $field == $value');

      final snapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .where(field, isEqualTo: value)
          .get();

      // ✅ Include document ID in results
      final tasks = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      AppLogger.info('Query returned ${tasks.length} tasks');
      return tasks;
    } catch (e) {
      AppLogger.error('Error querying tasks for user $userId: $e');
      return [];
    }
  }

  // ==================== REAL-TIME STREAMS ====================

  /// Stream of all user tasks
  Stream<QuerySnapshot<Map<String, dynamic>>> userTasksStream(String userId) {
    AppLogger.info('Starting real-time stream for user tasks: $userId');

    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .collection(tasksCollection)
        .snapshots();
  }

  /// Stream of user data
  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String userId) {
    AppLogger.info('Starting real-time stream for user data: $userId');

    return _firestore.collection(usersCollection).doc(userId).snapshots();
  }

  /// ✅ NEW: Stream of specific task
  Stream<DocumentSnapshot<Map<String, dynamic>>> taskStream(
      String userId,
      String taskId,
      ) {
    AppLogger.info('Starting real-time stream for task: $taskId');

    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .collection(tasksCollection)
        .doc(taskId)
        .snapshots();
  }

  // ==================== UTILITY METHODS ====================

  /// ✅ NEW: Check if a task exists
  Future<bool> taskExists(String userId, String taskId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .doc(taskId)
          .get();

      return doc.exists;
    } catch (e) {
      AppLogger.error('Error checking if task exists: $e');
      return false;
    }
  }

  /// ✅ NEW: Get task count for user
  Future<int> getUserTaskCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(tasksCollection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      AppLogger.error('Error getting task count: $e');
      return 0;
    }
  }
}
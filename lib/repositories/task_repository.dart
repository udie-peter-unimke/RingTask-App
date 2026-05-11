import 'package:ringtask/data/datasources/local/cache_manager.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/utils/logger.dart';

abstract class ITaskRepository {
  Future<List<TaskModel>> getAllTasks(String userId);
  Future<TaskModel?> getTaskById(String userId, String taskId);
  Future<bool> createTask(String userId, TaskModel task);
  Future<bool> updateTask(String userId, String taskId, TaskModel task);
  Future<bool> deleteTask(String userId, String taskId);
  Future<List<TaskModel>> getActiveTasks(String userId);
  Future<List<TaskModel>> getUpcomingTasks(String userId);
  Future<bool> markTaskAsCompleted(String userId, String taskId);
  Future<bool> deleteAllCompletedTasks(String userId);
}

class TaskRepository implements ITaskRepository {
  final FirestoreService _firestoreService;
  final CacheManager _cacheManager;

  TaskRepository(this._firestoreService, this._cacheManager);

  /// 🔥 FIXED: Matches FirestoreService List<Map> return type
  @override
  Future<List<TaskModel>> getAllTasks(String userId) async {
    try {
      AppLogger.info('🔄 Loading tasks for: $userId');

      // ✅ FirestoreService returns List<Map<String, dynamic>>
      final taskDataList = await _firestoreService.getAllUserTasks(userId);
      final tasks = taskDataList.map((data) {
        final taskId = data['id'] as String;
        return TaskModel.fromFirestore(taskId, data);
      }).toList();

      await _cacheManager.cacheTasks(userId, tasks);
      AppLogger.info('✅ Loaded ${tasks.length} tasks');
      return tasks;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Firestore failed', error: e, stackTrace: stackTrace);
      return await _cacheManager.getCachedTasks(userId) ?? [];
    }
  }

  @override
  Future<TaskModel?> getTaskById(String userId, String taskId) async {
    try {
      final data = await _firestoreService.getUserTask(userId, taskId);
      if (data != null) {
        return TaskModel.fromFirestore(taskId, data);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Get task failed: $taskId', error: e);
      return null;
    }
  }

  /// 🔥 FIXED: FirestoreService returns void → convert to bool
  @override
  Future<bool> createTask(String userId, TaskModel task) async {
    try {
      final taskId = task.id.isEmpty ? _generateDocId() : task.id;
      final taskToSave = task.copyWith(id: taskId);

      AppLogger.info('➕ Creating: "${task.title}" → $taskId');

      // 🔥 FirestoreService.void → Wrap in try-catch = success
      await _firestoreService.createUserTask(
          userId,
          taskId,
          taskToSave.toFirestore()
      );

      // ✅ Cache success
      await _cacheManager.cacheSingleTask(userId, taskToSave);
      AppLogger.info('✅ CREATED: $taskId');

      return true; // 🔥 Since no exception = success
    } catch (e, stackTrace) {
      AppLogger.error('❌ Create FAILED', error: e, stackTrace: stackTrace);
      return false; // 🔥 Exception = failure
    }
  }

  /// 🔥 FIXED: Same pattern for update
  @override
  Future<bool> updateTask(String userId, String taskId, TaskModel task) async {
    try {
      AppLogger.info('✏️ Updating: $taskId');

      await _firestoreService.updateUserTask(
          userId,
          taskId,
          task.toFirestore()
      );

      await _cacheManager.cacheSingleTask(userId, task);
      AppLogger.info('✅ UPDATED: $taskId');

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Update FAILED: $taskId', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 🔥 FIXED: Same pattern for delete
  @override
  Future<bool> deleteTask(String userId, String taskId) async {
    try {
      AppLogger.info('🗑️ Deleting: $taskId');

      await _firestoreService.deleteUserTask(userId, taskId);

      await _cacheManager.removeTaskFromCache(userId, taskId);
      AppLogger.info('✅ DELETED: $taskId');

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Delete FAILED: $taskId', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<List<TaskModel>> getActiveTasks(String userId) async {
    final tasks = await getAllTasks(userId);
    return tasks.where((t) => !t.isCompleted).toList();
  }

  @override
  Future<List<TaskModel>> getUpcomingTasks(String userId) async {
    final tasks = await getAllTasks(userId);
    final now = DateTime.now();
    return tasks
        .where((t) => !t.isCompleted && t.scheduledTime != null && t.scheduledTime!.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
  }

  @override
  Future<bool> markTaskAsCompleted(String userId, String taskId) async {
    try {
      final task = await getTaskById(userId, taskId);
      if (task == null) return false;

      final completedTask = task.copyWith(isCompleted: true);
      return await updateTask(userId, taskId, completedTask);
    } catch (e) {
      AppLogger.error('❌ Complete FAILED: $taskId', error: e);
      return false;
    }
  }

  @override
  Future<bool> deleteAllCompletedTasks(String userId) async {
    try {
      final tasks = await getAllTasks(userId);
      final completed = tasks.where((t) => t.isCompleted).toList();

      if (completed.isEmpty) return false;

      final results = await Future.wait(
          completed.map((t) => deleteTask(userId, t.id))
      );

      return results.every((success) => success);
    } catch (e) {
      AppLogger.error('❌ Bulk delete FAILED', error: e);
      return false;
    }
  }

  /// 🔥 Simple unique ID generator
  String _generateDocId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

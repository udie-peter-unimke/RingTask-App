import 'dart:async';
import 'package:ringtask/data/datasources/local/cache_manager.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/utils/logger.dart';

abstract class ITaskRepository {
  Stream<List<TaskModel>> getTasksStream(String userId);
  Future<List<TaskModel>> getAllTasks(String userId);
  Future<List<TaskModel>?> getCachedTasks(String userId);
  Future<TaskModel?> getTaskById(String userId, String taskId);
  Future<TaskModel?> createTask(String userId, TaskModel task);
  Future<TaskModel?> updateTask(String userId, String taskId, TaskModel task);
  Future<bool> deleteTask(String userId, String taskId);
  Future<List<TaskModel>> getActiveTasks(String userId);
  Future<List<TaskModel>> getUpcomingTasks(String userId);
  Future<bool> markTaskAsCompleted(String userId, String taskId);
  Future<bool> deleteAllCompletedTasks(String userId);

  /// 🆕 NEW
  Future<void> syncPendingTasks(String userId);
}

class TaskRepository implements ITaskRepository {
  final FirestoreService _firestoreService;
  final CacheManager _cacheManager;
  final _tasksController = StreamController<List<TaskModel>>.broadcast();

  TaskRepository({
    required FirestoreService firestoreService,
    required CacheManager cacheManager,
  })  : _firestoreService = firestoreService,
        _cacheManager = cacheManager;

  @override
  Stream<List<TaskModel>> getTasksStream(String userId) {
    _refreshStream(userId);
    return _tasksController.stream;
  }

  Future<void> _refreshStream(String userId) async {
    final tasks = await _cacheManager.getCachedTasks(userId) ?? [];
    _tasksController.add(tasks);
  }

  // =========================
  // 🔥 GET ALL TASKS (FETCH FRESH)
  // =========================
  @override
  Future<List<TaskModel>> getAllTasks(String userId) async {
    try {
      AppLogger.info('☁️ Fetching fresh tasks from Firestore');

      // 1. Fetch from Firestore
      final taskDataList = await _firestoreService.getAllUserTasks(userId);

      final remoteTasks = taskDataList.map((data) {
        final taskId = data['id'] as String;
        return TaskModel.fromFirestore(taskId, data);
      }).toList();

      // 2. Get local tasks to merge
      final localTasks = await _cacheManager.getCachedTasks(userId) ?? [];

      // 3. Merge (Local unsynced wins)
      final merged = _mergeTasks(localTasks, remoteTasks);

      // 4. Update cache
      await _cacheManager.cacheTasks(userId, merged);
      _refreshStream(userId);

      return merged;
    } catch (e) {
      AppLogger.error('⚠️ Firestore fetch failed, returning cache', error: e);
      return await _cacheManager.getCachedTasks(userId) ?? [];
    }
  }

  // =========================
  // 🔥 MERGE (LOCAL UNSYNCED WINS)
  // =========================
  List<TaskModel> _mergeTasks(
      List<TaskModel> local,
      List<TaskModel> remote,
      ) {
    final map = <String, TaskModel>{};

    // 1. Start with remote tasks
    for (final r in remote) {
      map[r.id] = r;
    }

    // 2. Overwrite with local tasks ONLY if they are pending sync or deleted locally
    for (final l in local) {
      if (!l.isSynced || l.isDeletedLocally) {
        map[l.id] = l;
      }
    }

    return map.values.toList();
  }

  // =========================
  // 🔥 CREATE TASK (OFFLINE-FIRST)
  // =========================
  @override
  Future<TaskModel?> createTask(String userId, TaskModel task) async {
    final taskId = task.id.isEmpty ? _generateDocId() : task.id;

    var localTask = task.copyWith(
      id: taskId,
      isSynced: false,
    );

    try {
      // 1. CACHE IMMEDIATELY
      await _cacheManager.cacheSingleTask(userId, localTask);
      _refreshStream(userId);
      AppLogger.info('📦 Task cached locally: $taskId');

      // 2. FIRE AND FORGET SYNC
      _backgroundSyncCreate(userId, localTask);

      // Return immediately so UI can show the new task
      return localTask;
    } catch (e) {
      AppLogger.error('❌ Local create failed', error: e);
      return null;
    }
  }

  Future<void> _backgroundSyncCreate(String userId, TaskModel task) async {
    try {
      await _firestoreService
          .createUserTask(userId, task.id, task.toFirestore())
          .timeout(const Duration(seconds: 5));

      final synced = task.copyWith(isSynced: true);
      await _cacheManager.cacheSingleTask(userId, synced);
      _refreshStream(userId);
      AppLogger.info('☁️ Task synced to Firestore: ${task.id}');
    } catch (e) {
      AppLogger.warning('⚠️ Background sync (create) failed for ${task.id}. Will retry later.', error: e);
    }
  }

  // =========================
  // 🔥 UPDATE TASK (OFFLINE-FIRST)
  // =========================
  @override
  Future<TaskModel?> updateTask(
      String userId,
      String taskId,
      TaskModel task,
      ) async {
    var localTask = task.copyWith(
      id: taskId,
      isSynced: false,
    );

    try {
      // 1. CACHE IMMEDIATELY
      await _cacheManager.cacheSingleTask(userId, localTask);
      _refreshStream(userId);
      AppLogger.info('📦 Task update cached locally: $taskId');

      // 2. FIRE AND FORGET SYNC
      _backgroundSyncUpdate(userId, taskId, localTask);

      return localTask;
    } catch (e) {
      AppLogger.error('❌ Local update failed', error: e);
      return null;
    }
  }

  Future<void> _backgroundSyncUpdate(String userId, String taskId, TaskModel task) async {
    try {
      await _firestoreService
          .updateUserTask(userId, taskId, task.toFirestore())
          .timeout(const Duration(seconds: 5));

      final synced = task.copyWith(isSynced: true);
      await _cacheManager.cacheSingleTask(userId, synced);
      _refreshStream(userId);
      AppLogger.info('☁️ Task update synced to Firestore: $taskId');
    } catch (e) {
      AppLogger.warning('⚠️ Background sync (update) failed for $taskId. Will retry later.', error: e);
    }
  }

  // =========================
  // 🔥 DELETE TASK (OFFLINE-AWARE)
  // =========================
  @override
  Future<bool> deleteTask(String userId, String taskId) async {
    try {
      final cached = await _cacheManager.getCachedTasks(userId) ?? [];
      final task = cached.cast<TaskModel?>().firstWhere((t) => t?.id == taskId, orElse: () => null);

      if (task == null) return true; // Already gone or never existed

      // 1. MARK AS DELETED LOCALLY
      final deletedLocally = task.copyWith(
        isDeletedLocally: true,
        isSynced: false,
      );
      await _cacheManager.cacheSingleTask(userId, deletedLocally);
      _refreshStream(userId);
      AppLogger.info('📦 Task marked as deleted locally: $taskId');

      // 2. FIRE AND FORGET SYNC
      _backgroundSyncDelete(userId, taskId);

      return true;
    } catch (e) {
      AppLogger.error('❌ Delete failed', error: e);
      return false;
    }
  }

  Future<void> _backgroundSyncDelete(String userId, String taskId) async {
    try {
      await _firestoreService
          .deleteUserTask(userId, taskId)
          .timeout(const Duration(seconds: 5));

      await _cacheManager.removeTaskFromCache(userId, taskId);
      _refreshStream(userId);
      AppLogger.info('☁️ Task deletion synced to Firestore: $taskId');
    } catch (e) {
      AppLogger.warning('⚠️ Background sync (delete) failed for $taskId. Will retry later.', error: e);
    }
  }

  // =========================
  // 🔥 SYNC PENDING TASKS (NEW)
  // =========================
  @override
  Future<void> syncPendingTasks(String userId) async {
    try {
      final cached = await _cacheManager.getCachedTasks(userId) ?? [];

      final pending = cached.where((t) => !t.isSynced).toList();

      for (final task in pending) {
        try {
          if (task.isDeletedLocally) {
            await _firestoreService.deleteUserTask(userId, task.id);
            await _cacheManager.removeTaskFromCache(userId, task.id);
          } else {
            await _firestoreService.createUserTask(
              userId,
              task.id,
              task.toFirestore(),
            );

            final synced = task.copyWith(isSynced: true);
            await _cacheManager.cacheSingleTask(userId, synced);
          }
        } catch (e) {
          AppLogger.error('⚠️ Sync failed for ${task.id}', error: e);
        }
      }

      _refreshStream(userId);
      AppLogger.info('✅ Pending sync completed');
    } catch (e) {
      AppLogger.error('❌ syncPendingTasks failed', error: e);
    }
  }

  // =========================
  // 🔥 OTHER METHODS (UNCHANGED LOGIC)
  // =========================

  @override
  Future<List<TaskModel>?> getCachedTasks(String userId) async {
    return await _cacheManager.getCachedTasks(userId);
  }

  @override
  Future<TaskModel?> getTaskById(String userId, String taskId) async {
    try {
      // 1. Try cache first
      final cached = await _cacheManager.getCachedTasks(userId) ?? [];
      final task = cached.cast<TaskModel?>().firstWhere((t) => t?.id == taskId, orElse: () => null);
      if (task != null) return task;

      // 2. Try Firestore
      final data =
      await _firestoreService.getUserTask(userId, taskId);
      if (data != null) {
        return TaskModel.fromFirestore(taskId, data);
      }
      return null;
    } catch (e) {
      return null;
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
        .where((t) =>
    !t.isCompleted &&
        t.scheduledTime != null &&
        t.scheduledTime!.isAfter(now))
        .toList()
      ..sort((a, b) =>
          a.scheduledTime!.compareTo(b.scheduledTime!));
  }

  @override
  Future<bool> markTaskAsCompleted(
      String userId,
      String taskId,
      ) async {
    final task = await getTaskById(userId, taskId);
    if (task == null) return false;

    final updated = task.copyWith(isCompleted: true);
    final result = await updateTask(userId, taskId, updated);
    return result != null;
  }

  @override
  Future<bool> deleteAllCompletedTasks(String userId) async {
    final tasks = await getAllTasks(userId);
    final completed = tasks.where((t) => t.isCompleted).toList();

    for (final task in completed) {
      await deleteTask(userId, task.id);
    }

    return true;
  }

  String _generateDocId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
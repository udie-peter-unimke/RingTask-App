import '../data/datasources/local/loop_local_datasource.dart';
import '../data/models/loop_model.dart';
import '../data/datasources/remote/loop_remote_datasource.dart';

/// Repository pattern for managing task data
/// Handles offline-first caching and remote synchronization
class LoopRepository {
  final LoopLocalDataSource _localDataSource;
  final LoopRemoteDataSource _remoteDataSource;

  LoopRepository({
    required LoopLocalDataSource localDataSource,
    required LoopRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Get stream of tasks with fallback to cache if offline
  Stream<List<TaskLoopItem>> getTasksStream(String userId) {
    return _remoteDataSource.getTasksStream(userId).handleError(
          (error) async* {
        // On error, emit cached tasks
        final cachedTasks = await _localDataSource.getCachedTasks();
        yield cachedTasks;
      },
    );
  }

  /// Create a new task locally and remotely
  Future<String> createTask(String userId, TaskLoopItem task) async {
    try {
      // Create remotely first
      final id = await _remoteDataSource.createTask(userId, task);

      // Update local cache
      final taskWithId = task.copyWith(id: id);
      await _localDataSource.cacheTask(taskWithId);

      return id;
    } catch (e) {
      // On remote failure, cache locally for later sync
      await _localDataSource.cacheTask(task);
      rethrow;
    }
  }

  /// Update a task locally and remotely
  Future<void> updateTask(String userId, TaskLoopItem task) async {
    try {
      // Update locally first for immediate feedback
      await _localDataSource.cacheTask(task);

      // Then update remotely
      await _remoteDataSource.updateTask(userId, task);
    } catch (e) {
      // Local update succeeds, remote queued for retry
      rethrow;
    }
  }

  /// Toggle task active status
  Future<void> toggleTaskActive(String userId, TaskLoopItem task, bool isActive) async {
    try {
      // Update locally first
      await _localDataSource.updateTaskActiveStatus(task.id, isActive);

      // Then update remotely
      await _remoteDataSource.updateTaskActiveStatus(userId, task.id, isActive);
    } catch (e) {
      // Local update succeeds, remote queued for retry
      rethrow;
    }
  }

  /// Delete a task locally and remotely
  Future<void> deleteTask(String userId, String taskId) async {
    try {
      // Remove locally first
      await _localDataSource.removeTaskFromCache(taskId);

      // Then delete remotely
      await _remoteDataSource.deleteTask(userId, taskId);
    } catch (e) {
      // Local delete succeeds, remote queued for retry
      rethrow;
    }
  }

  /// Batch create multiple tasks
  Future<void> batchCreateTasks(String userId, List<TaskLoopItem> tasks) async {
    try {
      // Cache locally first
      await _localDataSource.cacheTasks(tasks);

      // Then create remotely
      await _remoteDataSource.batchCreateTasks(userId, tasks);
    } catch (e) {
      // Local cache succeeds, remote queued for retry
      rethrow;
    }
  }

  /// Get cached tasks (for immediate access)
  Future<List<TaskLoopItem>> getCachedTasks() async {
    return _localDataSource.getCachedTasks();
  }

  /// Check if cache is still valid
  Future<bool> isCacheValid({Duration staleDuration = const Duration(hours: 24)}) async {
    return _localDataSource.isCacheValid(staleDuration: staleDuration);
  }

  /// Clear local cache
  Future<void> clearLocalCache() async {
    return _localDataSource.clearCache();
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    return _localDataSource.getLastSyncTime();
  }
}
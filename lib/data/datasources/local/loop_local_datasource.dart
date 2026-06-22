// lib/data/datasources/local/loop_local_datasource.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringtask/utils/logger.dart';
import '../../models/loop_model.dart';

/// Local data source for caching loop tasks.
/// Uses SharedPreferences for offline-first persistence.
class LoopLocalDataSource {
  static const String _tasksKey = 'loop_tasks_cache';
  static const String _lastSyncKey = 'loop_last_sync';

  final SharedPreferences _prefs;

  LoopLocalDataSource({required SharedPreferences prefs}) : _prefs = prefs;

  // ---------------------------------------------------------------------------
  // Cache write
  // ---------------------------------------------------------------------------

  /// Cache tasks locally.
  ///
  /// Serialises via [TaskLoopItem.toJson] — the single canonical source of
  /// truth for JSON field names and types. Previously maintained a duplicate
  /// [_taskToJson] here; removed to eliminate drift risk.
  Future<void> cacheTasks(List<TaskLoopItem> tasks) async {
    try {
      final jsonList = tasks.map((task) => task.toJson()).toList();
      await _prefs.setString(_tasksKey, jsonEncode(jsonList));
      await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      throw CacheException('Failed to cache tasks: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cache read
  // ---------------------------------------------------------------------------

  /// Retrieve cached tasks from local storage.
  ///
  /// Handles two failure modes that the original implementation did not:
  ///
  /// 1. **Corrupt JSON string** — [jsonDecode] throws [FormatException] when
  ///    the stored bytes are not valid JSON (e.g. truncated write, OS-level
  ///    corruption). Previously this re-threw as [CacheException], causing a
  ///    permanent crash loop on every app resume. Now the corrupt entry is
  ///    cleared and `[]` is returned so the app falls through to a Firestore
  ///    fetch.
  ///
  /// 2. **Bad individual item** — a single malformed task map no longer
  ///    aborts the entire list. Bad items are skipped with a log; valid tasks
  ///    are returned normally.
  ///
  /// Field-level coercion (null/wrong-type/missing-colon timeString, etc.) is
  /// handled inside [TaskLoopItem.fromJson] via the same [_safeTimeString] /
  /// [_safePeriod] helpers used by [TaskLoopItem.fromDoc].
  Future<List<TaskLoopItem>> getCachedTasks() async {
    try {
      final jsonString = _prefs.getString(_tasksKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      // ── Corrupt JSON guard ─────────────────────────────────────────────────
      // jsonDecode throws FormatException on invalid JSON. Re-throwing would
      // leave the cache in a broken state and crash every subsequent read.
      // Clearing and returning [] lets the app recover via a Firestore fetch.
      final List<dynamic> jsonList;
      try {
        jsonList = jsonDecode(jsonString) as List<dynamic>;
      } on FormatException catch (e) {
        AppLogger.error(
          '[LoopLocalDataSource] Corrupt cache JSON — clearing and recovering. '
              'Error: $e',
        );
        await clearCache();
        return [];
      }

      // ── Per-item recovery ──────────────────────────────────────────────────
      // A single bad entry must not prevent the rest of the list from loading.
      final tasks = <TaskLoopItem>[];
      for (int i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        if (item is! Map<String, dynamic>) {
          AppLogger.warning(
            '[LoopLocalDataSource] Skipping cache entry [$i]: '
                'expected Map<String, dynamic>, got ${item.runtimeType}',
          );
          continue;
        }
        // TaskLoopItem.fromJson applies _safeTimeString, _safePeriod, etc. —
        // no corrupt field value can reach split(':') downstream.
        tasks.add(TaskLoopItem.fromJson(item));
      }
      return tasks;
    } catch (e) {
      throw CacheException('Failed to retrieve cached tasks: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Metadata
  // ---------------------------------------------------------------------------

  /// Get the last sync timestamp.
  Future<DateTime?> getLastSyncTime() async {
    try {
      final timestamp = _prefs.getInt(_lastSyncKey);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      throw CacheException('Failed to get last sync time: $e');
    }
  }

  /// Check if cache exists and is valid.
  Future<bool> isCacheValid({
    Duration staleDuration = const Duration(hours: 24),
  }) async {
    try {
      final lastSync = await getLastSyncTime();
      if (lastSync == null) return false;
      return DateTime.now().difference(lastSync) < staleDuration;
    } catch (e) {
      throw CacheException('Failed to check cache validity: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cache mutation helpers
  // ---------------------------------------------------------------------------

  /// Clear all cached data.
  Future<void> clearCache() async {
    try {
      await _prefs.remove(_tasksKey);
      await _prefs.remove(_lastSyncKey);
    } catch (e) {
      throw CacheException('Failed to clear cache: $e');
    }
  }

  /// Save a single task to cache (upsert by id).
  Future<void> cacheTask(TaskLoopItem task) async {
    try {
      final tasks = await getCachedTasks();
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        tasks[index] = task;
      } else {
        tasks.add(task);
      }
      await cacheTasks(tasks);
    } catch (e) {
      throw CacheException('Failed to cache individual task: $e');
    }
  }

  /// Remove a task from cache by id.
  Future<void> removeTaskFromCache(String taskId) async {
    try {
      final tasks = await getCachedTasks();
      tasks.removeWhere((t) => t.id == taskId);
      await cacheTasks(tasks);
    } catch (e) {
      throw CacheException('Failed to remove task from cache: $e');
    }
  }

  /// Update task active status in cache.
  Future<void> updateTaskActiveStatus(String taskId, bool isActive) async {
    try {
      final tasks = await getCachedTasks();
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        tasks[index] = tasks[index].copyWith(isActive: isActive);
        await cacheTasks(tasks);
      }
    } catch (e) {
      throw CacheException('Failed to update task active status: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Thrown by [LoopLocalDataSource] for any cache-layer failure.
class CacheException implements Exception {
  final String message;

  const CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/utils/logger.dart';

/// Local cache manager using SharedPreferences
/// Handles caching of tasks, settings, and user data
class CacheManager {
  final SharedPreferences _prefs;

  // ============================================================================
  // CACHE KEYS
  // ============================================================================

  static const String _tasksKeyPrefix = 'cached_tasks_'; // 🔥 FIX
  static const String _settingsKey = 'cached_settings';
  static const String _userKey = 'cached_user';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _deviceIdKey = 'device_id';

  CacheManager({required SharedPreferences prefs}) : _prefs = prefs;

  String _tasksKey(String userId) => '$_tasksKeyPrefix$userId';

  // ============================================================================
  // TASK CACHING (USER-SCOPED)
  // ============================================================================

  /// Cache list of tasks
  Future<bool> cacheTasks(String userId, List<TaskModel> tasks) async {
    try {
      final tasksJson = tasks.map((task) => task.toJson()).toList();
      final encoded = jsonEncode(tasksJson);
      final result = await _prefs.setString(_tasksKey(userId), encoded);

      if (result) {
        AppLogger.info('Cached ${tasks.length} tasks for user $userId');
      }

      return result;
    } catch (e) {
      AppLogger.error('Error caching tasks', error: e);
      return false;
    }
  }

  /// Get cached tasks
  Future<List<TaskModel>?> getCachedTasks(String userId) async {
    try {
      final encoded = _prefs.getString(_tasksKey(userId));

      if (encoded == null || encoded.isEmpty) {
        AppLogger.info('No cached tasks found for user $userId');
        return null;
      }

      final List<dynamic> decoded = jsonDecode(encoded);
      final tasks = decoded
          .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Retrieved ${tasks.length} cached tasks for user $userId');
      return tasks;
    } catch (e) {
      AppLogger.error('Error retrieving cached tasks', error: e);
      return null;
    }
  }

  /// Cache a single task (add or update)
  Future<bool> cacheSingleTask(String userId, TaskModel task) async {
    try {
      final tasks = await getCachedTasks(userId) ?? [];
      tasks.removeWhere((t) => t.id == task.id);
      tasks.add(task);
      return await cacheTasks(userId, tasks);
    } catch (e) {
      AppLogger.error('Error caching single task', error: e);
      return false;
    }
  }

  /// Remove a task from cache
  Future<bool> removeTaskFromCache(String userId, String taskId) async {
    try {
      final tasks = await getCachedTasks(userId) ?? [];
      tasks.removeWhere((t) => t.id == taskId);
      return await cacheTasks(userId, tasks);
    } catch (e) {
      AppLogger.error('Error removing task from cache', error: e);
      return false;
    }
  }

  /// Clear all cached tasks for a user
  Future<bool> clearCachedTasks(String userId) async {
    try {
      final result = await _prefs.remove(_tasksKey(userId));
      if (result) {
        AppLogger.info('Cleared cached tasks for user $userId');
      }
      return result;
    } catch (e) {
      AppLogger.error('Error clearing cached tasks', error: e);
      return false;
    }
  }

  // ============================================================================
  // SETTINGS CACHING (UNCHANGED)
  // ============================================================================

  Future<bool> cacheSettings(SettingsModel settings) async {
    try {
      final encoded = jsonEncode(settings.toJson());
      return await _prefs.setString(_settingsKey, encoded);
    } catch (e) {
      AppLogger.error('Error caching settings', error: e);
      return false;
    }
  }

  Future<SettingsModel?> getCachedSettings() async {
    try {
      final encoded = _prefs.getString(_settingsKey);
      if (encoded == null || encoded.isEmpty) return null;
      return SettingsModel.fromJson(jsonDecode(encoded));
    } catch (e) {
      AppLogger.error('Error retrieving cached settings', error: e);
      return null;
    }
  }

  Future<bool> clearCachedSettings() async {
    try {
      return await _prefs.remove(_settingsKey);
    } catch (e) {
      AppLogger.error('Error clearing cached settings', error: e);
      return false;
    }
  }

  // ============================================================================
  // USER DATA CACHING (UNCHANGED)
  // ============================================================================

  Future<bool> cacheUser(Map<String, dynamic> userData) async {
    try {
      return await _prefs.setString(_userKey, jsonEncode(userData));
    } catch (e) {
      AppLogger.error('Error caching user data', error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    try {
      final encoded = _prefs.getString(_userKey);
      if (encoded == null || encoded.isEmpty) return null;
      return jsonDecode(encoded);
    } catch (e) {
      AppLogger.error('Error retrieving cached user data', error: e);
      return null;
    }
  }

  Future<bool> clearCachedUser() async {
    try {
      return await _prefs.remove(_userKey);
    } catch (e) {
      AppLogger.error('Error clearing cached user data', error: e);
      return false;
    }
  }

  // ============================================================================
  // SYNC METADATA (UNCHANGED)
  // ============================================================================

  Future<bool> saveLastSyncTimestamp(DateTime timestamp) async {
    try {
      return await _prefs.setString(
        _lastSyncKey,
        timestamp.toIso8601String(),
      );
    } catch (e) {
      AppLogger.error('Error saving last sync timestamp', error: e);
      return false;
    }
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      final value = _prefs.getString(_lastSyncKey);
      return value == null ? null : DateTime.parse(value);
    } catch (e) {
      AppLogger.error('Error retrieving last sync timestamp', error: e);
      return null;
    }
  }

  // ============================================================================
  // DEVICE ID (UNCHANGED)
  // ============================================================================

  Future<bool> saveDeviceId(String deviceId) async {
    try {
      return await _prefs.setString(_deviceIdKey, deviceId);
    } catch (e) {
      AppLogger.error('Error saving device ID', error: e);
      return false;
    }
  }

  Future<String?> getDeviceId() async {
    try {
      return _prefs.getString(_deviceIdKey);
    } catch (e) {
      AppLogger.error('Error retrieving device ID', error: e);
      return null;
    }
  }

  // ============================================================================
  // GENERIC STORAGE + CLEAR ALL (UNCHANGED)
  // ============================================================================

  Future<bool> clearCache() async {
    try {
      return await _prefs.clear();
    } catch (e) {
      AppLogger.error('Error clearing all cache', error: e);
      return false;
    }
  }
}

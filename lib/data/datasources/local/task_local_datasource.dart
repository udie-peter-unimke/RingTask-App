import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/utils/logger.dart';

/// ------------------------------------------------------------
/// LOCAL TASK DATA SOURCE
/// ------------------------------------------------------------
abstract class TaskLocalDataSource {
  Future<void> cacheTasks(List<TaskModel> tasks);
  Future<List<TaskModel>> getCachedTasks();
  Future<void> clearCachedTasks();
}

class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  static const String _cacheKey = 'cached_tasks';

  final SharedPreferences _prefs;

  TaskLocalDataSourceImpl(this._prefs);

  // ------------------------------------------------------------
  // SAVE TASKS LOCALLY
  // ------------------------------------------------------------
  @override
  Future<void> cacheTasks(List<TaskModel> tasks) async {
    try {
      final jsonList = tasks.map((task) => task.toJson()).toList();
      final encoded = jsonEncode(jsonList);

      await _prefs.setString(_cacheKey, encoded);
    } catch (e, s) {
      AppLogger.error(
        'Failed to cache tasks locally',
        error: e,
        stackTrace: s,
      );
    }
  }

  // ------------------------------------------------------------
  // GET CACHED TASKS
  // ------------------------------------------------------------
  @override
  Future<List<TaskModel>> getCachedTasks() async {
    try {
      final cached = _prefs.getString(_cacheKey);
      if (cached == null || cached.isEmpty) return [];

      final decoded = jsonDecode(cached) as List<dynamic>;

      return decoded
          .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      AppLogger.error(
        'Failed to read cached tasks',
        error: e,
        stackTrace: s,
      );
      return [];
    }
  }

  // ------------------------------------------------------------
  // CLEAR CACHE
  // ------------------------------------------------------------
  @override
  Future<void> clearCachedTasks() async {
    try {
      await _prefs.remove(_cacheKey);
    } catch (e, s) {
      AppLogger.error(
        'Failed to clear task cache',
        error: e,
        stackTrace: s,
      );
    }
  }
}

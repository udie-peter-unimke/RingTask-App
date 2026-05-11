import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ringtask/data/datasources/local/cache_manager.dart';
import 'package:ringtask/data/models/task_model.dart';
import 'package:ringtask/data/models/settings_model.dart';
import 'package:ringtask/utils/logger.dart';

/// Service responsible for synchronizing data between devices
/// Handles bidirectional sync between local cache and Firestore
class DeviceSyncService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CacheManager _cacheManager;
  final DeviceInfoPlugin _deviceInfo;

  static const String _tasksCollection = 'tasks';
  static const String _settingsCollection = 'settings';
  static const String _devicesCollection = 'devices';
  static const String _syncMetadataCollection = 'sync_metadata';

  DeviceSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    required CacheManager cacheManager,
    DeviceInfoPlugin? deviceInfo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _cacheManager = cacheManager,
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  bool get isAuthenticated => _userId != null;

  // ============================================================================
  // DEVICE REGISTRATION & MANAGEMENT
  // ============================================================================

  /// Register current device for sync tracking
  Future<void> registerDevice() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final deviceId = await _getDeviceId();
      final deviceInfo = await _getDeviceInfo();

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_devicesCollection)
          .doc(deviceId)
          .set({
        'deviceId': deviceId,
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'osVersion': deviceInfo['osVersion'],
        'appVersion': '1.0.0',
        'lastSyncAt': FieldValue.serverTimestamp(),
        'registeredAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      AppLogger.info('Device registered successfully: $deviceId');
    } catch (e) {
      AppLogger.error('Error registering device: $e');
      rethrow;
    }
  }

  /// Unregister current device
  Future<void> unregisterDevice() async {
    try {
      if (!isAuthenticated) return;

      final deviceId = await _getDeviceId();

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_devicesCollection)
          .doc(deviceId)
          .update({
        'isActive': false,
        'unregisteredAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Device unregistered: $deviceId');
    } catch (e) {
      AppLogger.error('Error unregistering device: $e');
    }
  }

  /// Get all registered devices for current user
  Future<List<Map<String, dynamic>>> getRegisteredDevices() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_devicesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      AppLogger.error('Error getting registered devices: $e');
      return [];
    }
  }

  // ============================================================================
  // TASK SYNCHRONIZATION
  // ============================================================================

  /// Sync tasks from Firestore to local cache
  Future<List<TaskModel>> syncTasksFromRemote() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_tasksCollection)
          .orderBy('scheduledTime', descending: false)
          .get();

      final tasks = snapshot.docs
          .map((doc) {
        try {
          return TaskModel.fromJson({...doc.data(), 'id': doc.id});
        } catch (e) {
          AppLogger.error('Error parsing task ${doc.id}: $e');
          return null;
        }
      })
          .whereType<TaskModel>()
          .toList();

      // ✅ FIXED: Pass userId and tasks to cacheTasks
      await _cacheManager.cacheTasks(_userId!, tasks);

      AppLogger.info('Synced ${tasks.length} tasks from remote');
      return tasks;
    } catch (e) {
      AppLogger.error('Error syncing tasks from remote: $e');
      rethrow;
    }
  }

  /// Sync tasks from local cache to Firestore
  Future<void> syncTasksToRemote(List<TaskModel> tasks) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      if (tasks.isEmpty) {
        AppLogger.info('No tasks to sync');
        return;
      }

      final batch = _firestore.batch();

      for (final task in tasks) {
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection(_tasksCollection)
            .doc(task.id);

        batch.set(docRef, task.toJson(), SetOptions(merge: true));
      }

      await batch.commit();
      await _updateSyncMetadata('tasks');
      await _updateDeviceSyncTimestamp();

      AppLogger.info('Synced ${tasks.length} tasks to remote');
    } catch (e) {
      AppLogger.error('Error syncing tasks to remote: $e');
      rethrow;
    }
  }

  /// Sync a single task to remote
  Future<void> syncSingleTaskToRemote(TaskModel task) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_tasksCollection)
          .doc(task.id)
          .set(task.toJson(), SetOptions(merge: true));

      await _updateSyncMetadata('tasks');

      AppLogger.info('Synced task to remote: ${task.id}');
    } catch (e) {
      AppLogger.error('Error syncing single task: $e');
      rethrow;
    }
  }

  /// Delete task from remote
  Future<void> deleteTaskFromRemote(String taskId) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_tasksCollection)
          .doc(taskId)
          .delete();

      AppLogger.info('Deleted task from remote: $taskId');
    } catch (e) {
      AppLogger.error('Error deleting task from remote: $e');
      rethrow;
    }
  }

  /// Listen to real-time task changes
  Stream<List<TaskModel>> listenToTaskChanges() {
    if (!isAuthenticated) {
      return Stream.error(Exception('User not authenticated'));
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_tasksCollection)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      try {
        return TaskModel.fromJson({...doc.data(), 'id': doc.id});
      } catch (e) {
        AppLogger.error('Error parsing task ${doc.id}: $e');
        return null;
      }
    })
        .whereType<TaskModel>()
        .toList())
        .handleError((error) {
      AppLogger.error('Error in task stream: $error');
    });
  }

  // ============================================================================
  // SETTINGS SYNCHRONIZATION
  // ============================================================================

  /// Sync settings from Firestore to local cache
  Future<SettingsModel?> syncSettingsFromRemote() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_settingsCollection)
          .doc('user_settings')
          .get();

      if (!doc.exists || doc.data() == null) {
        AppLogger.info('No remote settings found');
        return null;
      }

      final settings = SettingsModel.fromJson(doc.data()!);
      await _cacheManager.cacheSettings(settings);

      AppLogger.info('Synced settings from remote');
      return settings;
    } catch (e) {
      AppLogger.error('Error syncing settings from remote: $e');
      rethrow;
    }
  }

  /// Sync settings from local to Firestore
  Future<void> syncSettingsToRemote(SettingsModel settings) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_settingsCollection)
          .doc('user_settings')
          .set(settings.toJson(), SetOptions(merge: true));

      await _updateSyncMetadata('settings');

      AppLogger.info('Synced settings to remote');
    } catch (e) {
      AppLogger.error('Error syncing settings to remote: $e');
      rethrow;
    }
  }

  /// Listen to real-time settings changes
  Stream<SettingsModel?> listenToSettingsChanges() {
    if (!isAuthenticated) {
      return Stream.error(Exception('User not authenticated'));
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_settingsCollection)
        .doc('user_settings')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return SettingsModel.fromJson(snapshot.data()!);
    }).handleError((error) {
      AppLogger.error('Error in settings stream: $error');
    });
  }

  // ============================================================================
  // FULL SYNC & CONFLICT RESOLUTION
  // ============================================================================

  /// Perform full bidirectional sync
  Future<void> performFullSync() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      AppLogger.info('Starting full sync...');

      // Register/update device
      await registerDevice();

      // Sync tasks from remote
      await syncTasksFromRemote();

      // Sync settings from remote
      await syncSettingsFromRemote();

      // Update device sync timestamp
      await _updateDeviceSyncTimestamp();

      AppLogger.info('Full sync completed successfully');
    } catch (e) {
      AppLogger.error('Error performing full sync: $e');
      rethrow;
    }
  }

  /// Force sync with conflict resolution (Last-Write-Wins strategy)
  Future<void> forceSyncWithConflictResolution() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      AppLogger.info('Starting force sync with conflict resolution...');

      // ✅ FIXED: Pass userId to getCachedTasks
      final localTasks = await _cacheManager.getCachedTasks(_userId!) ?? [];

      // Get remote tasks
      final remoteSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_tasksCollection)
          .get();

      final remoteTasks = remoteSnapshot.docs
          .map((doc) {
        try {
          return TaskModel.fromJson({...doc.data(), 'id': doc.id});
        } catch (e) {
          AppLogger.error('Error parsing task ${doc.id}: $e');
          return null;
        }
      })
          .whereType<TaskModel>()
          .toList();

      // Resolve conflicts using Last-Write-Wins
      final mergedTasks = _resolveConflicts(localTasks, remoteTasks);

      // ✅ FIXED: Pass userId and tasks to cacheTasks
      await _cacheManager.cacheTasks(_userId!, mergedTasks);
      await syncTasksToRemote(mergedTasks);

      AppLogger.info('Force sync completed: ${mergedTasks.length} tasks merged');
    } catch (e) {
      AppLogger.error('Error in force sync: $e');
      rethrow;
    }
  }

  /// Resolve conflicts between local and remote tasks
  /// Strategy: Last-Write-Wins based on scheduledTime (newer tasks win)
  List<TaskModel> _resolveConflicts(
      List<TaskModel> localTasks,
      List<TaskModel> remoteTasks,
      ) {
    final Map<String, TaskModel> taskMap = {};

    // Add all local tasks first
    for (final task in localTasks) {
      taskMap[task.id] = task;
    }

    // Override with remote tasks (remote wins for simplicity)
    for (final remoteTask in remoteTasks) {
      final localTask = taskMap[remoteTask.id];

      if (localTask == null) {
        // Task only exists remotely - add it
        taskMap[remoteTask.id] = remoteTask;
      } else {
        // Both exist - compare scheduled times (keep the later one)
        if (remoteTask.scheduledTime != null && localTask.scheduledTime != null) {
          if (remoteTask.scheduledTime!.isAfter(localTask.scheduledTime!)) {
            taskMap[remoteTask.id] = remoteTask;
          }
          // Otherwise keep local task
        } else {
          // If one doesn't have scheduledTime, prefer the one that does
          taskMap[remoteTask.id] = remoteTask.scheduledTime != null
              ? remoteTask
              : localTask;
        }
      }
    }

    return taskMap.values.toList();
  }

  // ============================================================================
  // SYNC STATUS & METADATA
  // ============================================================================

  /// Get sync status and metadata
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_syncMetadataCollection)
          .doc('sync_info')
          .get();

      if (!doc.exists || doc.data() == null) {
        return {
          'lastSyncAt': null,
          'tasksLastSyncAt': null,
          'settingsLastSyncAt': null,
          'deviceCount': 0,
        };
      }

      final data = doc.data()!;

      // Get device count
      final devices = await getRegisteredDevices();

      return {
        ...data,
        'deviceCount': devices.length,
      };
    } catch (e) {
      AppLogger.error('Error getting sync status: $e');
      return {};
    }
  }

  /// Check if sync is needed (compare local and remote timestamps)
  Future<bool> isSyncNeeded() async {
    try {
      if (!isAuthenticated) return false;

      final syncStatus = await getSyncStatus();
      final lastSyncAt = syncStatus['lastSyncAt'] as Timestamp?;

      if (lastSyncAt == null) return true;

      // Check if last sync was more than 5 minutes ago
      final lastSyncTime = lastSyncAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(lastSyncTime);

      return difference.inMinutes > 5;
    } catch (e) {
      AppLogger.error('Error checking sync status: $e');
      return true; // Assume sync is needed on error
    }
  }

  /// Update sync metadata
  Future<void> _updateSyncMetadata(String type) async {
    try {
      if (!isAuthenticated) return;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_syncMetadataCollection)
          .doc('sync_info')
          .set({
        'lastSyncAt': FieldValue.serverTimestamp(),
        '${type}LastSyncAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error updating sync metadata: $e');
    }
  }

  /// Update device last sync timestamp
  Future<void> _updateDeviceSyncTimestamp() async {
    try {
      if (!isAuthenticated) return;

      final deviceId = await _getDeviceId();

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_devicesCollection)
          .doc(deviceId)
          .update({
        'lastSyncAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error updating device sync timestamp: $e');
    }
  }

  // ============================================================================
  // DEVICE INFORMATION
  // ============================================================================

  /// Get unique device identifier
  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor}';
      } else {
        return 'unknown_${_userId}_${defaultTargetPlatform.name}';
      }
    } catch (e) {
      AppLogger.error('Error getting device ID: $e');
      return 'fallback_${_userId}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get detailed device information
  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'deviceName': androidInfo.model,
          'platform': 'Android',
          'model': androidInfo.model,
          'osVersion': 'Android ${androidInfo.version.release}',
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'deviceName': iosInfo.name,
          'platform': 'iOS',
          'model': iosInfo.model,
          'osVersion': 'iOS ${iosInfo.systemVersion}',
          'manufacturer': 'Apple',
        };
      } else {
        return {
          'deviceName': 'Unknown Device',
          'platform': defaultTargetPlatform.name,
          'model': 'Unknown',
          'osVersion': 'Unknown',
          'manufacturer': 'Unknown',
        };
      }
    } catch (e) {
      AppLogger.error('Error getting device info: $e');
      return {
        'deviceName': 'Unknown Device',
        'platform': defaultTargetPlatform.name,
        'model': 'Unknown',
        'osVersion': 'Unknown',
        'manufacturer': 'Unknown',
      };
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Clear all sync data for current device
  Future<void> clearSyncData() async {
    try {
      if (!isAuthenticated) return;

      final deviceId = await _getDeviceId();

      // Remove device registration
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_devicesCollection)
          .doc(deviceId)
          .delete();

      // Clear local cache
      await _cacheManager.clearCache();

      AppLogger.info('Sync data cleared for device: $deviceId');
    } catch (e) {
      AppLogger.error('Error clearing sync data: $e');
      rethrow;
    }
  }

  /// Clear all user data (tasks, settings, devices)
  Future<void> clearAllUserData() async {
    try {
      if (!isAuthenticated) return;

      final batch = _firestore.batch();

      // Delete all tasks
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_tasksCollection)
          .get();

      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all devices
      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(_devicesCollection)
          .get();

      for (final doc in devicesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete settings
      batch.delete(
        _firestore
            .collection('users')
            .doc(_userId)
            .collection(_settingsCollection)
            .doc('user_settings'),
      );

      // Delete sync metadata
      batch.delete(
        _firestore
            .collection('users')
            .doc(_userId)
            .collection(_syncMetadataCollection)
            .doc('sync_info'),
      );

      await batch.commit();

      AppLogger.info('All user data cleared from Firestore');
    } catch (e) {
      AppLogger.error('Error clearing all user data: $e');
      rethrow;
    }
  }

  /// Dispose and cleanup
  void dispose() {
    AppLogger.info('DeviceSyncService disposed');
  }
}
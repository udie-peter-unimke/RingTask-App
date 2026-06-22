import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ringtask/repositories/task_repository.dart';
import 'package:ringtask/utils/logger.dart';

class SyncService {
  final ITaskRepository _repository;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  SyncService(this._repository, this._connectivity);

  /// 🚀 Initialize sync listener
  void initialize(String userId) {
    AppLogger.info('🔄 SyncService initialized');

    // 1. Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(
          (List<ConnectivityResult> results) async {
        // If any result in the list is not 'none', we are online
        final isOnline = results.any((result) => result != ConnectivityResult.none);
        
        if (isOnline) {
          AppLogger.info('🌐 Online detected → syncing tasks');
          await _repository.syncPendingTasks(userId);
        }
      },
    );

    // 2. Optional: run sync on startup
    _runInitialSync(userId);
  }

  /// 🚀 Sync once on app start
  Future<void> _runInitialSync(String userId) async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOnline = results.any((result) => result != ConnectivityResult.none);

      if (isOnline) {
        AppLogger.info('🚀 Initial sync triggered');
        await _repository.syncPendingTasks(userId);
      }
    } catch (e) {
      AppLogger.error('❌ Initial sync failed', error: e);
    }
  }

  /// 🧹 IMPORTANT: prevent memory leaks
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permission_handler/permission_handler.dart' show Permission;
import 'package:ringtask/utils/logger.dart';

abstract class IPermissionService {
  Future<bool> checkMicrophonePermission();
  Future<bool> requestMicrophonePermission();
  Future<bool> checkCameraPermission();
  Future<bool> requestCameraPermission();
  Future<bool> checkNotificationPermission();
  Future<bool> requestNotificationPermission();
  Future<bool> checkSpeechRecognitionPermission();
  Future<bool> requestSpeechRecognitionPermission();
  Future<bool> checkSystemAlertWindowPermission();
  Future<bool> requestSystemAlertWindowPermission();
  Future<bool> isMicrophonePermissionPermanentlyDenied();
  Future<Map<Permission, ph.PermissionStatus>> requestMultiplePermissions(
      List<Permission> permissions,
      );
  Future<void> openAppSettings();
}

class PermissionService implements IPermissionService {
  PermissionService();

  /// Check if microphone permission is granted
  @override
  Future<bool> checkMicrophonePermission() async {
    try {
      AppLogger.info('Checking microphone permission');
      final status = await Permission.microphone.status;

      AppLogger.debug('Microphone permission status: ${status.name}');

      final isGranted = status.isGranted;
      AppLogger.info('Microphone permission granted: $isGranted');

      return isGranted;
    } catch (e) {
      AppLogger.error('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission from user
  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      AppLogger.info('Requesting microphone permission');

      final status = await Permission.microphone.request();

      AppLogger.debug('Microphone permission request result: ${status.name}');

      return _handlePermissionStatus(status, 'microphone');
    } catch (e) {
      AppLogger.error('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if camera permission is granted
  @override
  Future<bool> checkCameraPermission() async {
    try {
      AppLogger.info('Checking camera permission');
      final status = await Permission.camera.status;

      AppLogger.debug('Camera permission status: ${status.name}');

      final isGranted = status.isGranted;
      AppLogger.info('Camera permission granted: $isGranted');

      return isGranted;
    } catch (e) {
      AppLogger.error('Error checking camera permission: $e');
      return false;
    }
  }

  /// Request camera permission from user
  @override
  Future<bool> requestCameraPermission() async {
    try {
      AppLogger.info('Requesting camera permission');

      final status = await Permission.camera.request();

      AppLogger.debug('Camera permission request result: ${status.name}');

      return _handlePermissionStatus(status, 'camera');
    } catch (e) {
      AppLogger.error('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted
  @override
  Future<bool> checkNotificationPermission() async {
    try {
      AppLogger.info('Checking notification permission');
      final status = await Permission.notification.status;

      AppLogger.debug('Notification permission status: ${status.name}');

      final isGranted = status.isGranted;
      AppLogger.info('Notification permission granted: $isGranted');

      return isGranted;
    } catch (e) {
      AppLogger.error('Error checking notification permission: $e');
      return false;
    }
  }

  /// Request notification permission from user
  @override
  Future<bool> requestNotificationPermission() async {
    try {
      AppLogger.info('Requesting notification permission');

      final status = await Permission.notification.request();

      AppLogger.debug('Notification permission request result: ${status.name}');

      return _handlePermissionStatus(status, 'notification');
    } catch (e) {
      AppLogger.error('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Check if speech recognition permission is granted
  @override
  Future<bool> checkSpeechRecognitionPermission() async {
    try {
      AppLogger.info('Checking speech recognition permission');
      final status = await Permission.speech.status;
      AppLogger.debug('Speech recognition permission status: ${status.name}');
      final isGranted = status.isGranted;
      AppLogger.info('Speech recognition permission granted: $isGranted');
      return isGranted;
    } catch (e) {
      AppLogger.error('Error checking speech recognition permission: $e');
      return false;
    }
  }

  /// Request speech recognition permission from user
  @override
  Future<bool> requestSpeechRecognitionPermission() async {
    try {
      AppLogger.info('Requesting speech recognition permission');
      final status = await Permission.speech.request();
      AppLogger.debug('Speech recognition permission request result: ${status.name}');
      return _handlePermissionStatus(status, 'speech recognition');
    } catch (e) {
      AppLogger.error('Error requesting speech recognition permission: $e');
      return false;
    }
  }

  /// Check if system alert window (overlay) permission is granted
  @override
  Future<bool> checkSystemAlertWindowPermission() async {
    try {
      AppLogger.info('Checking system alert window permission');
      final status = await Permission.systemAlertWindow.status;

      AppLogger.debug('System alert window permission status: ${status.name}');

      final isGranted = status.isGranted;
      AppLogger.info('System alert window permission granted: $isGranted');

      return isGranted;
    } catch (e) {
      AppLogger.error('Error checking system alert window permission: $e');
      return false;
    }
  }

  /// Request system alert window (overlay) permission from user
  @override
  Future<bool> requestSystemAlertWindowPermission() async {
    try {
      AppLogger.info('Requesting system alert window permission');

      final status = await Permission.systemAlertWindow.request();

      AppLogger.debug('System alert window permission request result: ${status.name}');

      return _handlePermissionStatus(status, 'system alert window');
    } catch (e) {
      AppLogger.error('Error requesting system alert window permission: $e');
      return false;
    }
  }

  @override
  Future<bool> isMicrophonePermissionPermanentlyDenied() async {
    try {
      final status = await Permission.microphone.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      AppLogger.error('Error checking if microphone permission is permanently denied: $e');
      return false;
    }
  }

  /// Request multiple permissions at once
  @override
  Future<Map<Permission, ph.PermissionStatus>> requestMultiplePermissions(
      List<Permission> permissions,
      ) async {
    try {
      AppLogger.info('Requesting ${permissions.length} permission(s)');

      final statuses = await permissions.request();

      AppLogger.debug('Multiple permission request completed');

      for (final entry in statuses.entries) {
        AppLogger.debug('${entry.key.toString()}: ${entry.value.name}');
      }

      return statuses;
    } catch (e) {
      AppLogger.error('Error requesting multiple permissions: $e');
      return {};
    }
  }

  /// Open app settings to allow user to grant permissions manually
  @override
  Future<void> openAppSettings() async {
    try {
      AppLogger.info('Opening app settings');
      await ph.openAppSettings();
      AppLogger.info('App settings opened successfully');
    } catch (e) {
      AppLogger.error('Error opening app settings: $e');
      rethrow;
    }
  }

  /// Handle permission status and return whether to proceed
  bool _handlePermissionStatus(ph.PermissionStatus status, String permissionName) {
    if (status.isGranted) {
      AppLogger.info('$permissionName permission granted');
      return true;
    } else if (status.isDenied) {
      AppLogger.warning('$permissionName permission was denied by user');
      return false;
    } else if (status.isRestricted) {
      AppLogger.warning('$permissionName permission is restricted');
      return false;
    } else if (status.isLimited) {
      AppLogger.warning('$permissionName permission is limited');
      return true;
    } else if (status.isProvisional) {
      AppLogger.warning('$permissionName permission is provisional');
      return false;
    } else if (status.isPermanentlyDenied) {
      AppLogger.warning('$permissionName permission is permanently denied');
      return false;
    }
    return false;
  }

  /// Get human-readable permission status
  String getPermissionStatusString(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
        return 'Permission granted';
      case ph.PermissionStatus.denied:
        return 'Permission denied';
      case ph.PermissionStatus.restricted:
        return 'Permission restricted';
      case ph.PermissionStatus.limited:
        return 'Permission limited';
      case ph.PermissionStatus.provisional:
        return 'Permission provisional';
      case ph.PermissionStatus.permanentlyDenied:
        return 'Permission permanently denied';
    }
  }

  /// Request microphone and notification permissions together
  Future<bool> requestVoiceAndNotificationPermissions() async {
    try {
      AppLogger.info('Requesting voice and notification permissions');

      final statuses = await requestMultiplePermissions([
        Permission.microphone,
        Permission.speech,
        Permission.notification,
      ]);

      final microphoneGranted =
          statuses[Permission.microphone]?.isGranted ?? false;
      final speechGranted =
          statuses[Permission.speech]?.isGranted ?? false;
      final notificationGranted =
          statuses[Permission.notification]?.isGranted ?? false;

      AppLogger.info(
        'Voice permissions - Microphone: $microphoneGranted, '
            'Speech: $speechGranted, '
            'Notification: $notificationGranted',
      );

      return microphoneGranted && speechGranted && notificationGranted;
    } catch (e) {
      AppLogger.error('Error requesting voice and notification permissions: $e');
      return false;
    }
  }
}
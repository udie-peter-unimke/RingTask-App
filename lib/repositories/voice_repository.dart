import 'package:ringtask/services/firebase/voice_service.dart';
import 'package:ringtask/services/firebase/permission_service.dart';
import 'package:ringtask/utils/logger.dart';



abstract class IVoiceRepository {
  Future<bool> isVoiceAvailable();
  Future<bool> checkMicrophonePermission();
  Future<bool> requestMicrophonePermission();
  Future<bool> isMicrophonePermissionPermanentlyDenied();
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    required Function(String) onPartialResult,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  Future<void> openAppSettings();
}

class VoiceRepository implements IVoiceRepository {
  final VoiceService voiceService;
  final PermissionService permissionService;

  VoiceRepository({
    required this.voiceService,
    required this.permissionService,
  });

  /// Check if voice recognition is available on the device
  @override
  Future<bool> isVoiceAvailable() async {
    try {
      AppLogger.info('Checking if voice is available');
      final isAvailable = await voiceService.isVoiceAvailable();
      AppLogger.info('Voice availability: $isAvailable');
      return isAvailable;
    } catch (e) {
      AppLogger.error('Error checking voice availability: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  @override
  Future<bool> checkMicrophonePermission() async {
    try {
      AppLogger.info('Checking microphone permission');
      final hasPermission = await permissionService.checkMicrophonePermission();
      AppLogger.info('Microphone permission status: $hasPermission');
      return hasPermission;
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
      final permissionGranted = await permissionService.requestMicrophonePermission();
      AppLogger.info('Microphone permission granted: $permissionGranted');
      return permissionGranted;
    } catch (e) {
      AppLogger.error('Error requesting microphone permission: $e');
      return false;
    }
  }

  @override
  Future<bool> isMicrophonePermissionPermanentlyDenied() async {
    try {
      return await permissionService.isMicrophonePermissionPermanentlyDenied();
    } catch (e) {
      AppLogger.error('Error checking permanent denial: $e');
      return false;
    }
  }

  /// Start listening for voice input with callbacks
  @override
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    required Function(String) onPartialResult,
  }) async {
    try {
      AppLogger.info('Starting voice listening');

      // Check permission before starting
      final hasPermission = await checkMicrophonePermission();
      if (!hasPermission) {
        AppLogger.warning('Microphone permission not granted');
        onError('Microphone permission is required to use voice input');
        return;
      }

      // Check if voice is available
      final isAvailable = await isVoiceAvailable();
      if (!isAvailable) {
        AppLogger.warning('Voice recognition is not available');
        onError('Voice recognition is not available on this device');
        return;
      }

      await voiceService.startListening(
        onResult: (recognizedText) {
          AppLogger.info('Voice result received: $recognizedText');
          onResult(recognizedText);
        },
        onError: (errorMessage) {
          AppLogger.error('Voice error: $errorMessage');
          onError(errorMessage);
        },
        onPartialResult: (partialText) {
          AppLogger.debug('Partial voice result: $partialText');
          onPartialResult(partialText);
        },
      );
    } catch (e) {
      AppLogger.error('Error starting voice listening: $e');
      onError('Failed to start voice listening: $e');
    }
  }

  /// Stop listening for voice input
  @override
  Future<void> stopListening() async {
    try {
      AppLogger.info('Stopping voice listening');
      await voiceService.stopListening();
      AppLogger.info('Voice listening stopped successfully');
    } catch (e) {
      AppLogger.error('Error stopping voice listening: $e');
      rethrow;
    }
  }

  /// Cancel voice recognition
  @override
  Future<void> cancelListening() async {
    try {
      AppLogger.info('Cancelling voice listening');
      await voiceService.cancelListening();
      AppLogger.info('Voice listening cancelled successfully');
    } catch (e) {
      AppLogger.error('Error cancelling voice listening: $e');
      rethrow;
    }
  }

  /// Open app settings
  @override
  Future<void> openAppSettings() async {
    try {
      await permissionService.openAppSettings();
    } catch (e) {
      AppLogger.error('Error opening app settings in repository: $e');
      rethrow;
    }
  }
}

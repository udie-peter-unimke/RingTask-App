// lib/utils/ringtone_file_helper.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ringtask/utils/logger.dart';

class RingtoneFileHelper {
  /// Copies a content:// URI to internal storage and returns the absolute path.
  /// If the path is already absolute, returns it as-is.
  /// Returns null on failure so callers can fall back to the default ringtone.
  static Future<String?> resolveToAbsolutePath(String? uriOrPath) async {
    if (uriOrPath == null || uriOrPath.isEmpty) return null;

    // Already an absolute file path — no copy needed
    if (uriOrPath.startsWith('/') && !uriOrPath.startsWith('/android_asset')) {
      return uriOrPath;
    }

    // content:// URI — copy to internal storage
    if (uriOrPath.startsWith('content://')) {
      try {
        const channel = MethodChannel('ringtask/file_utils');
        final bytes = await channel.invokeMethod<Uint8List>(
          'readContentUri',
          {'uri': uriOrPath},
        );

        if (bytes == null || bytes.isEmpty) return null;

        final dir = await getApplicationSupportDirectory();
        final ringtonesDir = Directory('${dir.path}/ringtones');
        if (!await ringtonesDir.exists()) await ringtonesDir.create(recursive: true);

        // Use a hash of the URI as the filename so the same ringtone
        // isn't copied twice across sessions
        final hash = uriOrPath.hashCode.abs();
        final dest = File('${ringtonesDir.path}/ringtone_$hash.mp3');

        if (!await dest.exists()) {
          await dest.writeAsBytes(bytes);
          AppLogger.info('Ringtone copied to: ${dest.path}');
        }

        return dest.path;
      } catch (e) {
        AppLogger.error('Failed to copy ringtone from content URI: $e');
        return null;
      }
    }

    return null;
  }
}
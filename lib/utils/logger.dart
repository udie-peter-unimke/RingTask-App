import 'package:flutter/foundation.dart';

/// Enum for log levels
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal,
}

/// Logger utility class for application-wide logging
class AppLogger {
  static const String _tag = 'RingTask';
  static LogLevel _logLevel = LogLevel.debug;
  static bool _isInitialized = false;

  /// Initialize the logger
  static void initialize({
    LogLevel logLevel = LogLevel.debug,
    bool enableLogging = true,
  }) {
    _logLevel = logLevel;
    _isInitialized = enableLogging;
    if (_isInitialized) {
      _printLog(
        level: LogLevel.info,
        tag: _tag,
        message: 'Logger initialized with log level: ${logLevel.name}',
      );
    }
  }

  /// Log verbose message
  static void verbose(
      String message, {
        String? tag,
        dynamic error,
        StackTrace? stackTrace,
      }) {
    if (_shouldLog(LogLevel.verbose)) {
      _printLog(
        level: LogLevel.verbose,
        tag: tag ?? _tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log debug message
  static void debug(
      String message, {
        String? tag,
        dynamic error,
        StackTrace? stackTrace,
      }) {
    if (_shouldLog(LogLevel.debug)) {
      _printLog(
        level: LogLevel.debug,
        tag: tag ?? _tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log info message
  static void info(
      String message, {
        String? tag,
        dynamic error,
        StackTrace? stackTrace,
      }) {
    if (_shouldLog(LogLevel.info)) {
      _printLog(
        level: LogLevel.info,
        tag: tag ?? _tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log warning message
  static void warning(
      String message, {
        String? tag,
        dynamic error,
        StackTrace? stackTrace,
      }) {
    if (_shouldLog(LogLevel.warning)) {
      _printLog(
        level: LogLevel.warning,
        tag: tag ?? _tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log error message
  static void error(
      String message, {
        String? tag,
        dynamic error,
        StackTrace? stackTrace,
      }) {
    if (_shouldLog(LogLevel.error)) {
      _printLog(
        level: LogLevel.error,
        tag: tag ?? _tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log fatal message
  static void fatal(
      String message, {
        String? tag,
        dynamic error,
        StackTrace? stackTrace,
      }) {
    if (_shouldLog(LogLevel.fatal)) {
      _printLog(
        level: LogLevel.fatal,
        tag: tag ?? _tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if a particular log level should be logged
  static bool _shouldLog(LogLevel level) {
    if (!_isInitialized) return false;
    return level.index >= _logLevel.index;
  }

  /// Internal method to print logs
  static void _printLog({
    required LogLevel level,
    required String tag,
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final timestamp = _getTimestamp();
    final levelName = _getLevelName(level);
    final logMessage = '[$timestamp] [$levelName] [$tag] $message';

    if (kDebugMode) {
      // Use print in debug mode
      print(logMessage);

      if (error != null) {
        print('Error: $error');
      }

      if (stackTrace != null) {
        print('StackTrace:\n$stackTrace');
      }
    }

    // You can add remote logging services here (e.g., Firebase Crashlytics, Sentry)
    _sendToRemoteLoggingService(
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Get formatted timestamp
  static String _getTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${_padZero(now.month)}-${_padZero(now.day)} '
        '${_padZero(now.hour)}:${_padZero(now.minute)}:${_padZero(now.second)}.${_padZero(now.millisecond)}';
  }

  /// Get level name with emoji
  static String _getLevelName(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return '🔍 VERBOSE';
      case LogLevel.debug:
        return '🐛 DEBUG';
      case LogLevel.info:
        return 'ℹ️  INFO';
      case LogLevel.warning:
        return '⚠️  WARNING';
      case LogLevel.error:
        return '❌ ERROR';
      case LogLevel.fatal:
        return '💥 FATAL';
    }
  }

  /// Pad single digit with zero
  static String _padZero(int value) {
    return value.toString().padLeft(2, '0');
  }

  /// Send logs to remote logging service (e.g., Firebase Crashlytics, Sentry)
  static void _sendToRemoteLoggingService({
    required LogLevel level,
    required String tag,
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // TODO: Implement remote logging based on your analytics platform
    // Example with Firebase Crashlytics:
    // if (level == LogLevel.error || level == LogLevel.fatal) {
    //   FirebaseCrashlytics.instance.recordError(
    //     error,
    //     stackTrace,
    //     reason: message,
    //     fatal: level == LogLevel.fatal,
    //   );
    // }

    // Example with Sentry:
    // if (level == LogLevel.error || level == LogLevel.fatal) {
    //   Sentry.captureException(
    //     error,
    //     stackTrace: stackTrace,
    //   );
    // }
  }

  /// Clear all logs (useful for testing)
  static void clear() {
    // Implement if you're storing logs locally
  }

  /// Get current log level
  static LogLevel getCurrentLogLevel() {
    return _logLevel;
  }

  /// Set log level
  static void setLogLevel(LogLevel logLevel) {
    _logLevel = logLevel;
    info('Log level changed to: ${logLevel.name}');
  }

  /// Check if logger is initialized
  static bool isInitialized() {
    return _isInitialized;
  }
}
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  static void d(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  static void i(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  static void w(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;

    final prefix = tag != null ? '[$tag] ' : '';
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);

    switch (level) {
      case LogLevel.debug:
        debugPrint('[$timestamp] $prefix$message');
        break;
      case LogLevel.info:
        debugPrint('[$timestamp] $prefix$message');
        break;
      case LogLevel.warning:
        debugPrint('[$timestamp] WARN: $prefix$message');
        break;
      case LogLevel.error:
        debugPrint('[$timestamp] ERROR: $prefix$message');
        if (error != null) {
          debugPrint('[$timestamp] ERROR: ${prefix}Error: $error');
        }
        if (stackTrace != null) {
          debugPrint('[$timestamp] ERROR: ${prefix}StackTrace: $stackTrace');
        }
        break;
    }
  }
}
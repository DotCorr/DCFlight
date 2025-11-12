/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:logger/logger.dart' as logger_pkg;

/// Log levels for DCFlight framework
enum DCFLogLevel {
  /// No logging output
  none,
  
  /// Only error messages
  error,
  
  /// Errors and warnings
  warning,
  
  /// Errors, warnings, and info messages
  info,
  
  /// All messages including debug information
  debug,
  
  /// All messages including verbose information
  verbose,
}

/// Custom LogOutput that appends DCFLOG marker for CLI detection
/// The logger package's PrettyPrinter already formats everything beautifully
/// We just need to mark each line so the CLI can filter it
class DCFLogOutput extends logger_pkg.LogOutput {
  @override
  void output(logger_pkg.OutputEvent event) {
    // The logger package's PrettyPrinter already handles colors, emojis, formatting
    for (var line in event.lines) {
      // Prepend DCFLOG: to each line so CLI can easily detect and show these logs
      // Use print() which goes to stdout - CLI reads from Flutter process stdout/stderr
      // Note: ANSI codes should work fine with print() - the issue was in CLI processing
      print('DCFLOG: $line');
    }
  }
}

/// Centralized logging system for DCFlight
/// Uses the logger package under the hood for beautiful formatting
class DCFLogger {
  static logger_pkg.Logger? _logger;
  static DCFLogLevel _currentLevel = DCFLogLevel.info;
  static String? _instanceId;
  static String? _projectId;
  
  /// Set instance ID for log isolation (kept for API compatibility)
  static void setInstanceId(String id) {
    _instanceId = id;
  }
  
  /// Set project ID for log isolation (kept for API compatibility)
  static void setProjectId(String id) {
    _projectId = id;
  }
  
  /// Get or create the logger instance
  static logger_pkg.Logger get _instance {
    _logger ??= logger_pkg.Logger(
      filter: _DCFLogFilter(),
      printer: logger_pkg.PrettyPrinter(
        methodCount: 0, // No stack trace for normal logs (info, debug, warning)
        errorMethodCount: 8, // Full stack trace (8 lines) for errors
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: logger_pkg.DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: DCFLogOutput(),
      level: logger_pkg.Level.trace, // Always log everything, our filter handles levels
    );
    return _logger!;
  }
  
  /// Set the global log level
  static void setLevel(DCFLogLevel level) {
    _currentLevel = level;
    // Don't log the level change - it creates a circular dependency and the logger might not be ready yet
  }
  
  /// Get the current log level
  static DCFLogLevel get currentLevel => _currentLevel;
  
  /// Normalize tag to ensure it has DCF prefix for custom tags
  static String _normalizeTag(String tag) {
    // Default tag stays as is
    if (tag == 'DCFlight') {
      return tag;
    }
    // If tag already has DCF: prefix, return as is
    if (tag.startsWith('DCF:')) {
      return tag;
    }
    // Otherwise, add DCF: prefix for custom tags
    return 'DCF:$tag';
  }
  
  /// Log an error message
  static void error(String message, {Object? error, StackTrace? stackTrace, String tag = 'DCFlight'}) {
    final normalizedTag = _normalizeTag(tag);
    final fullMessage = '[$normalizedTag] $message';
    _instance.e(fullMessage, error: error, stackTrace: stackTrace);
  }
  
  /// Log a warning message
  static void warning(String message, [String tag = 'DCFlight']) {
    final normalizedTag = _normalizeTag(tag);
    final fullMessage = '[$normalizedTag] $message';
    _instance.w(fullMessage);
  }
  
  /// Log an info message
  static void info(String message, [String tag = 'DCFlight']) {
    final normalizedTag = _normalizeTag(tag);
    final fullMessage = '[$normalizedTag] $message';
    _instance.i(fullMessage);
  }
  
  /// Log a debug message
  static void debug(String message, [String tag = 'DCFlight']) {
    final normalizedTag = _normalizeTag(tag);
    final fullMessage = '[$normalizedTag] $message';
    _instance.d(fullMessage);
  }
  
  /// Log a verbose message (internal development)
  static void verbose(String message, [String tag = 'DCFlight']) {
    final normalizedTag = _normalizeTag(tag);
    final fullMessage = '[$normalizedTag] $message';
    _instance.t(fullMessage);
    }
  }
  
/// Custom LogFilter that respects DCFLogLevel
class _DCFLogFilter extends logger_pkg.LogFilter {
  bool shouldLog(logger_pkg.LogEvent event) {
    final dcfLevel = _mapLoggerLevelToDCFLevel(event.level);
    return dcfLevel.index <= DCFLogger._currentLevel.index;
  }
  
  DCFLogLevel _mapLoggerLevelToDCFLevel(logger_pkg.Level level) {
    switch (level) {
      case logger_pkg.Level.trace:
        return DCFLogLevel.verbose;
      case logger_pkg.Level.debug:
        return DCFLogLevel.debug;
      case logger_pkg.Level.info:
        return DCFLogLevel.info;
      case logger_pkg.Level.warning:
        return DCFLogLevel.warning;
      case logger_pkg.Level.error:
        return DCFLogLevel.error;
      case logger_pkg.Level.fatal:
        return DCFLogLevel.error;
      case logger_pkg.Level.nothing:
        return DCFLogLevel.none;
      default:
        return DCFLogLevel.none;
    }
  }
}

/// Convenience methods for common DCFlight components
class DCFLoggerTags {
  static void layout(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error(message, tag: 'Layout');
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning(message, 'Layout');
        break;
      case DCFLogLevel.info:
        DCFLogger.info(message, 'Layout');
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug(message, 'Layout');
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose(message, 'Layout');
        break;
      case DCFLogLevel.none:
        break;
    }
  }
  
  static void animation(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error(message, tag: 'Animation');
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning(message, 'Animation');
        break;
      case DCFLogLevel.info:
        DCFLogger.info(message, 'Animation');
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug(message, 'Animation');
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose(message, 'Animation');
        break;
      case DCFLogLevel.none:
        break;
    }
  }
  
  static void component(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error(message, tag: 'Component');
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning(message, 'Component');
        break;
      case DCFLogLevel.info:
        DCFLogger.info(message, 'Component');
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug(message, 'Component');
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose(message, 'Component');
        break;
      case DCFLogLevel.none:
        break;
    }
  }
  
  static void bridge(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error(message, tag: 'Bridge');
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning(message, 'Bridge');
        break;
      case DCFLogLevel.info:
        DCFLogger.info(message, 'Bridge');
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug(message, 'Bridge');
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose(message, 'Bridge');
        break;
      case DCFLogLevel.none:
        break;
    }
  }
}

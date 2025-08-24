/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

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
  
  /// Extremely verbose logging (internal development only)
  verbose,
}

/// Centralized logging system for DCFlight
class DCFLogger {
  static DCFLogLevel _currentLevel = DCFLogLevel.warning;
  
  /// Set the global log level
  static void setLevel(DCFLogLevel level) {
    _currentLevel = level;
    _log(DCFLogLevel.info, 'DCFLogger', 'Log level set to: ${level.name}');
  }
  
  /// Get the current log level
  static DCFLogLevel get currentLevel => _currentLevel;
  
  /// Log an error message
  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (_shouldLog(DCFLogLevel.error)) {
      _log(DCFLogLevel.error, tag, message);
      if (error != null) {
        _log(DCFLogLevel.error, tag, 'Error: $error');
      }
      if (stackTrace != null) {
        _log(DCFLogLevel.error, tag, 'Stack trace:\n$stackTrace');
      }
    }
  }
  
  /// Log a warning message
  static void warning(String tag, String message) {
    if (_shouldLog(DCFLogLevel.warning)) {
      _log(DCFLogLevel.warning, tag, message);
    }
  }
  
  /// Log an info message
  static void info(String tag, String message) {
    if (_shouldLog(DCFLogLevel.info)) {
      _log(DCFLogLevel.info, tag, message);
    }
  }
  
  /// Log a debug message
  static void debug(String tag, String message) {
    if (_shouldLog(DCFLogLevel.debug)) {
      _log(DCFLogLevel.debug, tag, message);
    }
  }
  
  /// Log a verbose message (internal development)
  static void verbose(String tag, String message) {
    if (_shouldLog(DCFLogLevel.verbose)) {
      _log(DCFLogLevel.verbose, tag, message);
    }
  }
  
  /// Check if we should log at this level
  static bool _shouldLog(DCFLogLevel level) {
    return level.index <= _currentLevel.index;
  }
  
  /// Internal logging implementation
  static void _log(DCFLogLevel level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final levelIcon = _getLevelIcon(level);
    final levelName = level.name.toUpperCase().padRight(7);
    
    // Format: [TIMESTAMP] LEVEL_ICON LEVEL TAG: MESSAGE
    print('[$timestamp] $levelIcon $levelName $tag: $message');
  }
  
  /// Get emoji icon for log level
  static String _getLevelIcon(DCFLogLevel level) {
    switch (level) {
      case DCFLogLevel.none:
        return '🔇';
      case DCFLogLevel.error:
        return '❌';
      case DCFLogLevel.warning:
        return '⚠️';
      case DCFLogLevel.info:
        return '✅';
      case DCFLogLevel.debug:
        return '🐛';
      case DCFLogLevel.verbose:
        return '🔍';
    }
  }
}

/// Convenience methods for common DCFlight components
class DCFLoggerTags {
  static void layout(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error('Layout', message);
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning('Layout', message);
        break;
      case DCFLogLevel.info:
        DCFLogger.info('Layout', message);
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug('Layout', message);
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose('Layout', message);
        break;
      case DCFLogLevel.none:
        break;
    }
  }
  
  static void animation(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error('Animation', message);
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning('Animation', message);
        break;
      case DCFLogLevel.info:
        DCFLogger.info('Animation', message);
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug('Animation', message);
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose('Animation', message);
        break;
      case DCFLogLevel.none:
        break;
    }
  }
  
  static void component(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error('Component', message);
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning('Component', message);
        break;
      case DCFLogLevel.info:
        DCFLogger.info('Component', message);
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug('Component', message);
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose('Component', message);
        break;
      case DCFLogLevel.none:
        break;
    }
  }
  
  static void bridge(String message, [DCFLogLevel level = DCFLogLevel.debug]) {
    switch (level) {
      case DCFLogLevel.error:
        DCFLogger.error('Bridge', message);
        break;
      case DCFLogLevel.warning:
        DCFLogger.warning('Bridge', message);
        break;
      case DCFLogLevel.info:
        DCFLogger.info('Bridge', message);
        break;
      case DCFLogLevel.debug:
        DCFLogger.debug('Bridge', message);
        break;
      case DCFLogLevel.verbose:
        DCFLogger.verbose('Bridge', message);
        break;
      case DCFLogLevel.none:
        break;
    }
  }
}

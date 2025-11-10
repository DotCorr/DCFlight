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
  static String? _instanceId;
  static String? _projectId;
  
  /// Set the global log level
  static void setLevel(DCFLogLevel level) {
    _currentLevel = level;
    _log(DCFLogLevel.info, 'DCFLogger', 'Log level set to: ${level.name}');
  }
  
  /// Set instance ID for log isolation
  static void setInstanceId(String id) {
    _instanceId = id;
  }
  
  /// Set project ID for log isolation
  static void setProjectId(String id) {
    _projectId = id;
  }
  
  /// Get the current log level
  static DCFLogLevel get currentLevel => _currentLevel;
  
  /// Log an error message
  static void error(String message, {Object? error, StackTrace? stackTrace, String tag = 'DCFlight'}) {
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
  static void warning(String message, [String tag = 'DCFlight']) {
    if (_shouldLog(DCFLogLevel.warning)) {
      _log(DCFLogLevel.warning, tag, message);
    }
  }
  
  /// Log an info message
  static void info(String message, [String tag = 'DCFlight']) {
    if (_shouldLog(DCFLogLevel.info)) {
      _log(DCFLogLevel.info, tag, message);
    }
  }
  
  /// Log a debug message
  static void debug(String message, [String tag = 'DCFlight']) {
    if (_shouldLog(DCFLogLevel.debug)) {
      _log(DCFLogLevel.debug, tag, message);
    }
  }
  
  /// Log a verbose message (internal development)
  static void verbose(String message, [String tag = 'DCFlight']) {
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
    
    final identifiers = <String>[];
    if (_projectId != null) identifiers.add('P:$_projectId');
    if (_instanceId != null) identifiers.add('I:$_instanceId');
    final idString = identifiers.isNotEmpty ? '[${identifiers.join('|')}]' : '';
    
    print('[$timestamp]$idString $levelIcon $levelName $tag: $message');
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


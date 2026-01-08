/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:developer' as developer;

import 'package:dcflight/src/components/component_node.dart';

import 'component.dart';

/// Component that catches errors in its subtree
abstract class ErrorBoundary extends DCFStatefulComponent {
  ErrorBoundary({super.key});

  /// Current error state
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;

  /// Handle error in child component
  void handleError(Object error, StackTrace stackTrace) {
    _error = error;
    _stackTrace = stackTrace;
    _hasError = true;

    developer.log('Error caught by ErrorBoundary: $error',
        name: 'ErrorBoundary', error: error, stackTrace: stackTrace);

    scheduleUpdate();
  }

  /// Reset error state
  void resetError() {
    _error = null;
    _stackTrace = null;
    _hasError = false;

    scheduleUpdate();
  }

  /// Get whether there's an error
  bool get hasError => _hasError;

  /// Get current error
  Object? get error => _error;

  /// Get error stack trace
  StackTrace? get stackTrace => _stackTrace;

  /// Render fallback UI when error occurs
  DCFComponentNode renderFallback(Object error, StackTrace? stackTrace);

  @override
  DCFComponentNode render() {
    if (_hasError) {
      return renderFallback(_error!, _stackTrace);
    }

    return renderContent();
  }

  /// Render content when no error
  DCFComponentNode renderContent();
}

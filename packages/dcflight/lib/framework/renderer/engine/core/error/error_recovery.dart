/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';

/// Error recovery strategies 
enum ErrorRecoveryStrategy {
  /// Retry the operation immediately
  immediateRetry,
  
  /// Retry with exponential backoff
  exponentialBackoff,
  
  /// Fallback to safe state
  fallbackToSafeState,
  
  /// Skip operation and continue
  skipAndContinue,
  
  /// Force full remount
  forceRemount,
}

/// Error recovery manager
class ErrorRecoveryManager {
  final Map<String, int> _retryCounts = {};
  final Map<String, DateTime> _lastRetryTimes = {};
  final int maxRetries;
  final Duration retryDelay;
  final Duration maxRetryDelay;

  ErrorRecoveryManager({
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 100),
    this.maxRetryDelay = const Duration(seconds: 5),
  });

  /// Attempt recovery with strategy
  Future<T?> attemptRecovery<T>({
    required String operationId,
    required Future<T> Function() operation,
    required ErrorRecoveryStrategy strategy,
    T? fallbackValue,
    Future<void> Function()? onRetry,
  }) async {
    int attempts = 0;
    Duration currentDelay = retryDelay;

    while (attempts < maxRetries) {
      try {
        final result = await operation();
        _resetRetryCount(operationId);
        return result;
      } catch (error, stackTrace) {
        attempts++;
        _recordRetry(operationId);

        if (attempts >= maxRetries) {
          // Max retries reached, use fallback strategy
          return _handleMaxRetriesReached<T>(
            operationId: operationId,
            strategy: strategy,
            error: error,
            stackTrace: stackTrace,
            fallbackValue: fallbackValue,
          );
        }

        // Apply retry strategy
        switch (strategy) {
          case ErrorRecoveryStrategy.immediateRetry:
            // Retry immediately
            break;

          case ErrorRecoveryStrategy.exponentialBackoff:
            // Wait with exponential backoff
            await Future.delayed(currentDelay);
            currentDelay = Duration(
              milliseconds: (currentDelay.inMilliseconds * 2)
                  .clamp(0, maxRetryDelay.inMilliseconds),
            );
            break;

          case ErrorRecoveryStrategy.fallbackToSafeState:
            // Return fallback value
            return fallbackValue;

          case ErrorRecoveryStrategy.skipAndContinue:
            // Skip operation
            return fallbackValue;

          case ErrorRecoveryStrategy.forceRemount:
            // Force remount (handled by caller)
            rethrow;
        }

        // Call retry callback if provided
        if (onRetry != null) {
          await onRetry();
        }
      }
    }

    return fallbackValue;
  }

  T? _handleMaxRetriesReached<T>({
    required String operationId,
    required ErrorRecoveryStrategy strategy,
    required dynamic error,
    required StackTrace stackTrace,
    T? fallbackValue,
  }) {
    switch (strategy) {
      case ErrorRecoveryStrategy.fallbackToSafeState:
      case ErrorRecoveryStrategy.skipAndContinue:
        return fallbackValue;

      case ErrorRecoveryStrategy.forceRemount:
        // Let error propagate to trigger remount
        throw error;

      case ErrorRecoveryStrategy.immediateRetry:
      case ErrorRecoveryStrategy.exponentialBackoff:
        // Return fallback after max retries
        return fallbackValue;
    }
  }

  void _recordRetry(String operationId) {
    _retryCounts[operationId] = (_retryCounts[operationId] ?? 0) + 1;
    _lastRetryTimes[operationId] = DateTime.now();
  }

  void _resetRetryCount(String operationId) {
    _retryCounts.remove(operationId);
    _lastRetryTimes.remove(operationId);
  }

  /// Get retry count for operation
  int getRetryCount(String operationId) => _retryCounts[operationId] ?? 0;

  /// Check if operation should be retried
  bool shouldRetry(String operationId) {
    final count = _retryCounts[operationId] ?? 0;
    return count < maxRetries;
  }

  /// Clear all retry state
  void clear() {
    _retryCounts.clear();
    _lastRetryTimes.clear();
  }
}


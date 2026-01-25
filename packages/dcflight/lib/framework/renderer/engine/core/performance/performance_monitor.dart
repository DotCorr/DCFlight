/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


/// Performance metrics for VDOM operations
class PerformanceMetrics {
  /// Total render operations
  int totalRenders = 0;

  /// Total reconciliation operations
  int totalReconciliations = 0;

  /// Total layout calculations
  int totalLayoutCalculations = 0;

  /// Average render time (ms)
  double averageRenderTime = 0.0;

  /// Average reconciliation time (ms)
  double averageReconciliationTime = 0.0;

  /// Average layout time (ms)
  double averageLayoutTime = 0.0;

  /// Peak render time (ms)
  double peakRenderTime = 0.0;

  /// Peak reconciliation time (ms)
  double peakReconciliationTime = 0.0;

  /// Memory usage (bytes) - approximate
  int estimatedMemoryUsage = 0;

  /// Cache hit rate (0.0 to 1.0)
  double cacheHitRate = 0.0;

  /// Error count
  int errorCount = 0;

  /// Recovery success rate (0.0 to 1.0)
  double recoverySuccessRate = 0.0;

  Map<String, dynamic> toMap() => {
        'totalRenders': totalRenders,
        'totalReconciliations': totalReconciliations,
        'totalLayoutCalculations': totalLayoutCalculations,
        'averageRenderTime': averageRenderTime,
        'averageReconciliationTime': averageReconciliationTime,
        'averageLayoutTime': averageLayoutTime,
        'peakRenderTime': peakRenderTime,
        'peakReconciliationTime': peakReconciliationTime,
        'estimatedMemoryUsage': estimatedMemoryUsage,
        'cacheHitRate': cacheHitRate,
        'errorCount': errorCount,
        'recoverySuccessRate': recoverySuccessRate,
      };
}

/// Performance monitor for VDOM operations
class PerformanceMonitor {
  final PerformanceMetrics _metrics = PerformanceMetrics();
  final Map<String, Stopwatch> _activeTimers = {};
  final List<Duration> _renderTimes = [];
  final List<Duration> _reconciliationTimes = [];
  final List<Duration> _layoutTimes = [];
  final int _maxSamples = 1000;

  /// Start timing an operation
  void startTiming(String operationId) {
    _activeTimers[operationId] = Stopwatch()..start();
  }

  /// End timing an operation and record metrics
  void endTiming(String operationId) {
    final timer = _activeTimers.remove(operationId);
    if (timer == null) return;

    timer.stop();
    final duration = timer.elapsed;

    switch (operationId) {
      case 'render':
        _recordRenderTime(duration);
        break;
      case 'reconcile':
        _recordReconciliationTime(duration);
        break;
      case 'layout':
        _recordLayoutTime(duration);
        break;
    }
  }

  void _recordRenderTime(Duration duration) {
    final ms = duration.inMicroseconds / 1000.0;
    _metrics.totalRenders++;
    _renderTimes.add(duration);
    if (_renderTimes.length > _maxSamples) {
      _renderTimes.removeAt(0);
    }

    _metrics.averageRenderTime = _renderTimes
        .map((d) => d.inMicroseconds / 1000.0)
        .reduce((a, b) => a + b) /
        _renderTimes.length;

    if (ms > _metrics.peakRenderTime) {
      _metrics.peakRenderTime = ms;
    }
  }

  void _recordReconciliationTime(Duration duration) {
    final ms = duration.inMicroseconds / 1000.0;
    _metrics.totalReconciliations++;
    _reconciliationTimes.add(duration);
    if (_reconciliationTimes.length > _maxSamples) {
      _reconciliationTimes.removeAt(0);
    }

    _metrics.averageReconciliationTime = _reconciliationTimes
        .map((d) => d.inMicroseconds / 1000.0)
        .reduce((a, b) => a + b) /
        _reconciliationTimes.length;

    if (ms > _metrics.peakReconciliationTime) {
      _metrics.peakReconciliationTime = ms;
    }
  }

  void _recordLayoutTime(Duration duration) {
    _metrics.totalLayoutCalculations++;
    _layoutTimes.add(duration);
    if (_layoutTimes.length > _maxSamples) {
      _layoutTimes.removeAt(0);
    }

    _metrics.averageLayoutTime = _layoutTimes
        .map((d) => d.inMicroseconds / 1000.0)
        .reduce((a, b) => a + b) /
        _layoutTimes.length;
  }

  /// Record cache hit
  void recordCacheHit() {
    // Update cache hit rate (simplified)
    _metrics.cacheHitRate = (_metrics.cacheHitRate * 0.9) + (1.0 * 0.1);
  }

  /// Record cache miss
  void recordCacheMiss() {
    // Update cache hit rate (simplified)
    _metrics.cacheHitRate = (_metrics.cacheHitRate * 0.9) + (0.0 * 0.1);
  }

  /// Record error
  void recordError() {
    _metrics.errorCount++;
  }

  /// Record successful recovery
  void recordRecoverySuccess() {
    // Update recovery success rate
    _metrics.recoverySuccessRate = (_metrics.recoverySuccessRate * 0.9) + (1.0 * 0.1);
  }

  /// Record failed recovery
  void recordRecoveryFailure() {
    // Update recovery success rate
    _metrics.recoverySuccessRate = (_metrics.recoverySuccessRate * 0.9) + (0.0 * 0.1);
  }

  /// Update estimated memory usage
  void updateMemoryUsage(int bytes) {
    _metrics.estimatedMemoryUsage = bytes;
  }

  /// Get current metrics
  PerformanceMetrics get metrics => _metrics;

  /// Get metrics as map
  Map<String, dynamic> getMetrics() => _metrics.toMap();

  /// Reset all metrics
  void reset() {
    _metrics.totalRenders = 0;
    _metrics.totalReconciliations = 0;
    _metrics.totalLayoutCalculations = 0;
    _metrics.averageRenderTime = 0.0;
    _metrics.averageReconciliationTime = 0.0;
    _metrics.averageLayoutTime = 0.0;
    _metrics.peakRenderTime = 0.0;
    _metrics.peakReconciliationTime = 0.0;
    _metrics.estimatedMemoryUsage = 0;
    _metrics.cacheHitRate = 0.0;
    _metrics.errorCount = 0;
    _metrics.recoverySuccessRate = 0.0;
    _renderTimes.clear();
    _reconciliationTimes.clear();
    _layoutTimes.clear();
  }
}


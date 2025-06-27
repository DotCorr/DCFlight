/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

/// 📊 PERFORMANCE MONITOR - Real-time performance tracking and analysis
/// 
/// Tracks and analyzes:
/// - Frame rates and frame times
/// - Memory usage patterns
/// - Render counts and efficiency
/// - Scroll performance metrics
/// - System resource utilization
class PerformanceMonitor {
  
  final bool _enabled;
  
  // Frame timing
  final Queue<FrameTimestamp> _frameTimes = Queue();
  DateTime? _currentFrameStart;
  static const int _maxFrameHistory = 120; // 2 seconds at 60fps
  
  // Performance metrics
  double _currentFPS = 0;
  Duration _averageFrameTime = Duration.zero;
  Duration _maxFrameTime = Duration.zero;
  int _droppedFrameCount = 0;
  
  // Render metrics
  int _totalRenderCount = 0;
  int _recycledRenderCount = 0;
  final Queue<int> _recentRenderCounts = Queue();
  static const int _maxRenderHistory = 30;
  
  // Memory tracking
  int _currentComponentCount = 0;
  int _peakComponentCount = 0;
  final Queue<MemorySnapshot> _memorySnapshots = Queue();
  static const int _maxMemoryHistory = 60;
  
  // Scroll performance
  final Queue<ScrollMetric> _scrollMetrics = Queue();
  DateTime? _lastScrollUpdate;
  static const int _maxScrollHistory = 100;
  
  // Performance alerts
  final List<PerformanceAlert> _activeAlerts = [];
  final StreamController<PerformanceAlert> _alertController = StreamController.broadcast();
  
  PerformanceMonitor({required bool enabled}) : _enabled = enabled {
    if (_enabled) {
      _startMonitoring();
    }
  }
  
  /// Start frame timing
  void startFrame() {
    if (!_enabled) return;
    _currentFrameStart = DateTime.now();
  }
  
  /// End frame timing and record metrics
  void endFrame() {
    if (!_enabled || _currentFrameStart == null) return;
    
    final frameEnd = DateTime.now();
    final frameTime = frameEnd.difference(_currentFrameStart!);
    
    _recordFrameTime(FrameTimestamp(
      startTime: _currentFrameStart!,
      endTime: frameEnd,
      duration: frameTime,
    ));
    
    _currentFrameStart = null;
  }
  
  /// Record render count for current frame
  void recordRenderCount(int count) {
    if (!_enabled) return;
    
    _totalRenderCount += count;
    _recentRenderCounts.add(count);
    
    if (_recentRenderCounts.length > _maxRenderHistory) {
      _recentRenderCounts.removeFirst();
    }
    
    _checkRenderPerformance(count);
  }
  
  /// Record recycled render count
  void recordRecycledRender() {
    if (!_enabled) return;
    _recycledRenderCount++;
  }
  
  /// Update component count
  void updateComponentCount(int count) {
    if (!_enabled) return;
    
    _currentComponentCount = count;
    _peakComponentCount = math.max(_peakComponentCount, count);
    
    _recordMemorySnapshot();
  }
  
  /// Record scroll performance
  void recordScrollUpdate(double position, double velocity) {
    if (!_enabled) return;
    
    final now = DateTime.now();
    final timeSinceLastUpdate = _lastScrollUpdate != null 
        ? now.difference(_lastScrollUpdate!)
        : Duration.zero;
    
    _scrollMetrics.add(ScrollMetric(
      timestamp: now,
      position: position,
      velocity: velocity,
      timeSinceLastUpdate: timeSinceLastUpdate,
    ));
    
    if (_scrollMetrics.length > _maxScrollHistory) {
      _scrollMetrics.removeFirst();
    }
    
    _lastScrollUpdate = now;
    
    _checkScrollPerformance(velocity, timeSinceLastUpdate);
  }
  
  /// Record frame time and update metrics
  void _recordFrameTime(FrameTimestamp frameTime) {
    _frameTimes.add(frameTime);
    
    if (_frameTimes.length > _maxFrameHistory) {
      _frameTimes.removeFirst();
    }
    
    _updateFrameMetrics();
    _checkFramePerformance(frameTime.duration);
  }
  
  /// Update frame performance metrics
  void _updateFrameMetrics() {
    if (_frameTimes.isEmpty) return;
    
    // Calculate FPS from recent frames
    if (_frameTimes.length >= 2) {
      final timeSpan = _frameTimes.last.endTime.difference(_frameTimes.first.startTime);
      final frameCount = _frameTimes.length - 1;
      _currentFPS = frameCount / timeSpan.inMicroseconds * 1000000;
    }
    
    // Calculate average frame time
    final totalFrameTime = _frameTimes
        .map((f) => f.duration.inMicroseconds)
        .reduce((a, b) => a + b);
    _averageFrameTime = Duration(
      microseconds: totalFrameTime ~/ _frameTimes.length
    );
    
    // Find max frame time
    _maxFrameTime = _frameTimes
        .map((f) => f.duration)
        .reduce((a, b) => a > b ? a : b);
  }
  
  /// Record memory snapshot
  void _recordMemorySnapshot() {
    _memorySnapshots.add(MemorySnapshot(
      timestamp: DateTime.now(),
      componentCount: _currentComponentCount,
    ));
    
    if (_memorySnapshots.length > _maxMemoryHistory) {
      _memorySnapshots.removeFirst();
    }
  }
  
  /// Check frame performance for issues
  void _checkFramePerformance(Duration frameTime) {
    const frameTimeThreshold = Duration(milliseconds: 20); // 50 FPS threshold
    
    if (frameTime > frameTimeThreshold) {
      _droppedFrameCount++;
      _raiseAlert(PerformanceAlert(
        type: AlertType.droppedFrame,
        severity: AlertSeverity.warning,
        message: 'Frame time exceeded threshold: ${frameTime.inMilliseconds}ms',
        timestamp: DateTime.now(),
        data: {'frameTime': frameTime.inMilliseconds},
      ));
    }
  }
  
  /// Check render performance
  void _checkRenderPerformance(int renderCount) {
    const renderCountThreshold = 50;
    
    if (renderCount > renderCountThreshold) {
      _raiseAlert(PerformanceAlert(
        type: AlertType.excessiveRenders,
        severity: AlertSeverity.warning,
        message: 'High render count in single frame: $renderCount',
        timestamp: DateTime.now(),
        data: {'renderCount': renderCount},
      ));
    }
  }
  
  /// Check scroll performance
  void _checkScrollPerformance(double velocity, Duration timeSinceLastUpdate) {
    const velocityThreshold = 2000.0; // pixels per second
    const updateIntervalThreshold = Duration(milliseconds: 50);
    
    if (velocity.abs() > velocityThreshold && timeSinceLastUpdate > updateIntervalThreshold) {
      _raiseAlert(PerformanceAlert(
        type: AlertType.scrollJank,
        severity: AlertSeverity.warning,
        message: 'Scroll jank detected: velocity ${velocity.toStringAsFixed(1)}, interval ${timeSinceLastUpdate.inMilliseconds}ms',
        timestamp: DateTime.now(),
        data: {
          'velocity': velocity,
          'updateInterval': timeSinceLastUpdate.inMilliseconds,
        },
      ));
    }
  }
  
  /// Raise performance alert
  void _raiseAlert(PerformanceAlert alert) {
    _activeAlerts.add(alert);
    _alertController.add(alert);
    
    // Keep only recent alerts
    _activeAlerts.removeWhere((alert) {
      return DateTime.now().difference(alert.timestamp) > Duration(minutes: 5);
    });
  }
  
  /// Start background monitoring
  void _startMonitoring() {
    // Periodic cleanup and analysis
    Timer.periodic(Duration(seconds: 5), (_) {
      _performPeriodicAnalysis();
    });
  }
  
  /// Perform periodic analysis and cleanup
  void _performPeriodicAnalysis() {
    if (!_enabled) return;
    
    // Check overall performance trends
    if (_currentFPS < 50 && _frameTimes.length > 30) {
      _raiseAlert(PerformanceAlert(
        type: AlertType.lowFPS,
        severity: AlertSeverity.error,
        message: 'Sustained low FPS: ${_currentFPS.toStringAsFixed(1)}',
        timestamp: DateTime.now(),
        data: {'fps': _currentFPS},
      ));
    }
    
    // Check memory trends
    if (_currentComponentCount > 100) {
      _raiseAlert(PerformanceAlert(
        type: AlertType.memoryPressure,
        severity: AlertSeverity.warning,
        message: 'High component count: $_currentComponentCount',
        timestamp: DateTime.now(),
        data: {'componentCount': _currentComponentCount},
      ));
    }
  }
  
  /// Get current performance metrics
  PerformanceMetrics getMetrics() {
    final recycleRatio = _totalRenderCount > 0 
        ? _recycledRenderCount / _totalRenderCount
        : 0.0;
    
    final averageRenderCount = _recentRenderCounts.isNotEmpty
        ? _recentRenderCounts.reduce((a, b) => a + b) / _recentRenderCounts.length
        : 0.0;
    
    return PerformanceMetrics(
      currentFPS: _currentFPS,
      averageFrameTime: _averageFrameTime,
      maxFrameTime: _maxFrameTime,
      droppedFrameCount: _droppedFrameCount,
      totalRenderCount: _totalRenderCount,
      recycledRenderCount: _recycledRenderCount,
      recycleRatio: recycleRatio,
      currentComponentCount: _currentComponentCount,
      peakComponentCount: _peakComponentCount,
      averageRenderCount: averageRenderCount,
      activeAlerts: List.unmodifiable(_activeAlerts),
    );
  }
  
  /// Get detailed frame timing data
  List<FrameTimestamp> getFrameTimingData() {
    return List.unmodifiable(_frameTimes);
  }
  
  /// Get memory usage history
  List<MemorySnapshot> getMemoryHistory() {
    return List.unmodifiable(_memorySnapshots);
  }
  
  /// Get scroll performance data
  List<ScrollMetric> getScrollData() {
    return List.unmodifiable(_scrollMetrics);
  }
  
  /// Get performance alert stream
  Stream<PerformanceAlert> get alertStream => _alertController.stream;
  
  /// Reset all metrics
  void reset() {
    if (!_enabled) return;
    
    _frameTimes.clear();
    _recentRenderCounts.clear();
    _memorySnapshots.clear();
    _scrollMetrics.clear();
    _activeAlerts.clear();
    
    _currentFPS = 0;
    _averageFrameTime = Duration.zero;
    _maxFrameTime = Duration.zero;
    _droppedFrameCount = 0;
    _totalRenderCount = 0;
    _recycledRenderCount = 0;
    _currentComponentCount = 0;
    _peakComponentCount = 0;
  }
  
  /// Dispose resources
  void dispose() {
    _alertController.close();
    reset();
  }
}

/// Frame timing data
class FrameTimestamp {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  
  const FrameTimestamp({
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
}

/// Memory usage snapshot
class MemorySnapshot {
  final DateTime timestamp;
  final int componentCount;
  
  const MemorySnapshot({
    required this.timestamp,
    required this.componentCount,
  });
}

/// Scroll performance metric
class ScrollMetric {
  final DateTime timestamp;
  final double position;
  final double velocity;
  final Duration timeSinceLastUpdate;
  
  const ScrollMetric({
    required this.timestamp,
    required this.position,
    required this.velocity,
    required this.timeSinceLastUpdate,
  });
}

/// Performance alert
class PerformanceAlert {
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  
  const PerformanceAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    required this.data,
  });
  
  @override
  String toString() {
    return 'PerformanceAlert(${severity.name.toUpperCase()}: $message)';
  }
}

/// Types of performance alerts
enum AlertType {
  droppedFrame,
  lowFPS,
  excessiveRenders,
  memoryPressure,
  scrollJank,
}

/// Alert severity levels
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}

/// Complete performance metrics
class PerformanceMetrics {
  final double currentFPS;
  final Duration averageFrameTime;
  final Duration maxFrameTime;
  final int droppedFrameCount;
  final int totalRenderCount;
  final int recycledRenderCount;
  final double recycleRatio;
  final int currentComponentCount;
  final int peakComponentCount;
  final double averageRenderCount;
  final List<PerformanceAlert> activeAlerts;
  
  const PerformanceMetrics({
    required this.currentFPS,
    required this.averageFrameTime,
    required this.maxFrameTime,
    required this.droppedFrameCount,
    required this.totalRenderCount,
    required this.recycledRenderCount,
    required this.recycleRatio,
    required this.currentComponentCount,
    required this.peakComponentCount,
    required this.averageRenderCount,
    required this.activeAlerts,
  });
  
  @override
  String toString() {
    return 'PerformanceMetrics('
           'fps: ${currentFPS.toStringAsFixed(1)}, '
           'frameTime: ${averageFrameTime.inMicroseconds}μs, '
           'renders: $totalRenderCount, '
           'recycleRatio: ${(recycleRatio * 100).toStringAsFixed(1)}%, '
           'components: $currentComponentCount, '
           'alerts: ${activeAlerts.length})';
  }
}
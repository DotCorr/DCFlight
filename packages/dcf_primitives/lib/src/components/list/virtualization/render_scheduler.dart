/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'virtualization_engine.dart';

/// ⚡ RENDER SCHEDULER - Frame-budget aware rendering system
/// 
/// Ensures 60+ FPS performance by:
/// - Batching renders within frame budget (16ms)
/// - Prioritizing visible items over buffer items
/// - Spreading heavy work across multiple frames
/// - Monitoring performance and adapting batch sizes
class RenderScheduler {
  static const String _logPrefix = '[RenderScheduler]';
  
  final VirtualizationConfig _config;
  
  // Render queues with different priorities
  final Queue<RenderTask> _highPriorityQueue = Queue();
  final Queue<RenderTask> _lowPriorityQueue = Queue();
  
  // Timing and performance tracking
  DateTime? _lastFrameStart;
  Duration _averageFrameTime = Duration.zero;
  final List<Duration> _recentFrameTimes = [];
  static const int _maxFrameTimeHistory = 30;
  
  // Batch management
  bool _isProcessingBatch = false;
  int _currentBatchSize = 10;
  int _adaptiveBatchSize = 10;
  
  // Frame budget management
  late final Duration _frameBudget;
  static const Duration _targetFrameTime = Duration(milliseconds: 16); // 60 FPS
  
  RenderScheduler({required VirtualizationConfig config}) : _config = config {
    _frameBudget = config.frameBudget;
    _currentBatchSize = config.maxRenderBatchSize;
    _adaptiveBatchSize = config.maxRenderBatchSize;
  }
  
  /// Schedule an update with the current virtualization state
  void scheduleUpdate(VirtualizationState state) {
    // Clear existing tasks
    _clearQueues();
    
    // Queue high-priority tasks for visible items
    for (int i = state.visibleRange.start; i < state.visibleRange.end; i++) {
      _queueRenderTask(RenderTask(
        index: i,
        priority: RenderPriority.high,
        taskType: RenderTaskType.visible,
        scheduledAt: DateTime.now(),
      ));
    }
    
    // Queue medium-priority tasks for render buffer
    for (int i = state.renderRange.start; i < state.renderRange.end; i++) {
      if (!state.visibleRange.contains(i)) {
        _queueRenderTask(RenderTask(
          index: i,
          priority: RenderPriority.medium,
          taskType: RenderTaskType.buffer,
          scheduledAt: DateTime.now(),
        ));
      }
    }
    
    // Queue low-priority tasks for extended buffer
    for (int i = state.bufferRange.start; i < state.bufferRange.end; i++) {
      if (!state.renderRange.contains(i)) {
        _queueRenderTask(RenderTask(
          index: i,
          priority: RenderPriority.low,
          taskType: RenderTaskType.preload,
          scheduledAt: DateTime.now(),
        ));
      }
    }
    
    // Start processing if not already running
    if (!_isProcessingBatch) {
      _scheduleNextBatch();
    }
    
    if (_config.debugMode) {
      print('$_logPrefix Scheduled update - High: ${_highPriorityQueue.length}, Low: ${_lowPriorityQueue.length}');
    }
  }
  
  /// Queue a render task
  void _queueRenderTask(RenderTask task) {
    switch (task.priority) {
      case RenderPriority.high:
      case RenderPriority.medium:
        _highPriorityQueue.add(task);
        break;
      case RenderPriority.low:
        _lowPriorityQueue.add(task);
        break;
    }
  }
  
  /// Schedule next batch processing
  void _scheduleNextBatch() {
    if (_isProcessingBatch) return;
    
    // Use SchedulerBinding for optimal frame timing
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _processBatch();
    });
  }
  
  /// Process a batch of render tasks within frame budget
  Future<void> _processBatch() async {
    if (_isProcessingBatch) return;
    
    _isProcessingBatch = true;
    final batchStartTime = DateTime.now();
    _lastFrameStart = batchStartTime;
    
    int processedCount = 0;
    final stopwatch = Stopwatch()..start();
    
    try {
      // Process high-priority tasks first
      while (_highPriorityQueue.isNotEmpty && 
             stopwatch.elapsed < _frameBudget && 
             processedCount < _adaptiveBatchSize) {
        final task = _highPriorityQueue.removeFirst();
        await _processRenderTask(task);
        processedCount++;
      }
      
      // Process low-priority tasks with remaining time
      while (_lowPriorityQueue.isNotEmpty && 
             stopwatch.elapsed < _frameBudget && 
             processedCount < _adaptiveBatchSize) {
        final task = _lowPriorityQueue.removeFirst();
        await _processRenderTask(task);
        processedCount++;
      }
      
    } finally {
      stopwatch.stop();
      _isProcessingBatch = false;
      
      // Record performance metrics
      final frameTime = stopwatch.elapsed;
      _recordFrameTime(frameTime);
      _adaptBatchSize(frameTime, processedCount);
      
      if (_config.debugMode) {
        print('$_logPrefix Processed batch - Tasks: $processedCount, Time: ${frameTime.inMicroseconds}μs');
      }
      
      // Schedule next batch if tasks remain
      if (_highPriorityQueue.isNotEmpty || _lowPriorityQueue.isNotEmpty) {
        _scheduleNextBatch();
      }
    }
  }
  
  /// Process individual render task
  Future<void> _processRenderTask(RenderTask task) async {
    final taskStartTime = DateTime.now();
    
    try {
      // Task processing logic would go here
      // For now, we'll simulate the work
      await Future.delayed(Duration(microseconds: 100)); // Simulate render work
      
      task.completedAt = DateTime.now();
      task.processingTime = task.completedAt!.difference(taskStartTime);
      
    } catch (e) {
      if (_config.debugMode) {
        print('$_logPrefix Task failed - Index: ${task.index}, Error: $e');
      }
    }
  }
  
  /// Record frame time for performance tracking
  void _recordFrameTime(Duration frameTime) {
    _recentFrameTimes.add(frameTime);
    
    if (_recentFrameTimes.length > _maxFrameTimeHistory) {
      _recentFrameTimes.removeAt(0);
    }
    
    // Calculate rolling average
    if (_recentFrameTimes.isNotEmpty) {
      final totalMicroseconds = _recentFrameTimes
          .map((d) => d.inMicroseconds)
          .reduce((a, b) => a + b);
      _averageFrameTime = Duration(
        microseconds: totalMicroseconds ~/ _recentFrameTimes.length
      );
    }
  }
  
  /// Adapt batch size based on performance
  void _adaptBatchSize(Duration frameTime, int processedCount) {
    const adaptationRate = 0.1;
    
    if (frameTime > _frameBudget) {
      // Frame took too long - reduce batch size
      _adaptiveBatchSize = (_adaptiveBatchSize * 0.9).round().clamp(1, _config.maxRenderBatchSize);
    } else if (frameTime < _frameBudget * 0.7 && processedCount == _adaptiveBatchSize) {
      // Frame finished early and processed full batch - increase batch size
      _adaptiveBatchSize = (_adaptiveBatchSize * 1.1).round().clamp(1, _config.maxRenderBatchSize * 2);
    }
    
    if (_config.debugMode && _adaptiveBatchSize != _currentBatchSize) {
      print('$_logPrefix Adapted batch size: $_currentBatchSize -> $_adaptiveBatchSize');
      _currentBatchSize = _adaptiveBatchSize;
    }
  }
  
  /// Clear all queued tasks
  void _clearQueues() {
    _highPriorityQueue.clear();
    _lowPriorityQueue.clear();
  }
  
  /// Check if scheduler is busy
  bool get isBusy => _isProcessingBatch || _highPriorityQueue.isNotEmpty || _lowPriorityQueue.isNotEmpty;
  
  /// Get current queue sizes
  Map<String, int> getQueueSizes() {
    return {
      'highPriority': _highPriorityQueue.length,
      'lowPriority': _lowPriorityQueue.length,
    };
  }
  
  /// Get performance metrics
  RenderPerformanceMetrics getPerformanceMetrics() {
    final fps = _averageFrameTime.inMicroseconds > 0 
        ? 1000000 / _averageFrameTime.inMicroseconds
        : 0.0;
    
    final isDroppingFrames = _averageFrameTime > _targetFrameTime;
    
    return RenderPerformanceMetrics(
      averageFrameTime: _averageFrameTime,
      currentFPS: fps,
      adaptiveBatchSize: _adaptiveBatchSize,
      isDroppingFrames: isDroppingFrames,
      queueSizes: getQueueSizes(),
    );
  }
  
  /// Force flush all pending tasks (for testing/debugging)
  Future<void> flush() async {
    while (isBusy) {
      await _processBatch();
      await Future.delayed(Duration(milliseconds: 1));
    }
  }
}

/// Individual render task
class RenderTask {
  final int index;
  final RenderPriority priority;
  final RenderTaskType taskType;
  final DateTime scheduledAt;
  
  DateTime? completedAt;
  Duration? processingTime;
  
  RenderTask({
    required this.index,
    required this.priority,
    required this.taskType,
    required this.scheduledAt,
  });
  
  /// Get task age
  Duration get age => DateTime.now().difference(scheduledAt);
  
  /// Check if task is completed
  bool get isCompleted => completedAt != null;
  
  @override
  String toString() {
    return 'RenderTask(index: $index, priority: $priority, type: $taskType, age: ${age.inMilliseconds}ms)';
  }
}

/// Priority levels for render tasks
enum RenderPriority {
  high,    // Visible items - must render immediately
  medium,  // Buffer items - render next
  low,     // Preload items - render when time allows
}

/// Types of render tasks
enum RenderTaskType {
  visible,  // Currently visible items
  buffer,   // Buffer items for smooth scrolling
  preload,  // Extended buffer items
}

/// Performance metrics for render scheduling
class RenderPerformanceMetrics {
  final Duration averageFrameTime;
  final double currentFPS;
  final int adaptiveBatchSize;
  final bool isDroppingFrames;
  final Map<String, int> queueSizes;
  
  const RenderPerformanceMetrics({
    required this.averageFrameTime,
    required this.currentFPS,
    required this.adaptiveBatchSize,
    required this.isDroppingFrames,
    required this.queueSizes,
  });
  
  @override
  String toString() {
    return 'RenderPerformanceMetrics('
           'fps: ${currentFPS.toStringAsFixed(1)}, '
           'frameTime: ${averageFrameTime.inMicroseconds}μs, '
           'batchSize: $adaptiveBatchSize, '
           'droppingFrames: $isDroppingFrames, '
           'queues: $queueSizes)';
  }
}
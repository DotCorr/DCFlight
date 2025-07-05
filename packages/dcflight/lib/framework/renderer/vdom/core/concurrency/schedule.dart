/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:collection';
import 'package:dcflight/framework/renderer/vdom/component/component_node.dart';

/// Component priority levels for concurrent scheduling
enum ComponentPriority {
  immediate, // Text inputs, scroll events, touch interactions
  high,      // Buttons, navigation, modals
  normal,    // Regular views, text, images  
  low,       // Analytics, background tasks
  idle;      // Debug panels, dev tools

  /// Time slice limit in microseconds for this priority
  int get timeSliceLimit {
    switch (this) {
      case immediate:
        return 1000; // 1ms - very responsive
      case high:
        return 5000; // 5ms - responsive
      case normal:
        return 16000; // 16ms - one frame
      case low:
        return 50000; // 50ms - can wait
      case idle:
        return 100000; // 100ms - lowest priority
    }
  }

  /// Weight for starvation prevention (lower = higher priority)
  int get weight {
    switch (this) {
      case immediate:
        return 1;
      case high:
        return 2;
      case normal:
        return 3;
      case low:
        return 4;
      case idle:
        return 5;
    }
  }
}

/// Interface for components to declare their priority
abstract class ComponentPriorityInterface {
  ComponentPriority get priority;
}

/// Work unit for the concurrent scheduler
class ScheduledWork {
  final String componentId;
  final ComponentPriority priority;
  final Future<void> Function() work;
  final DateTime scheduledAt;
  final int estimatedDuration;
  
  int retryCount = 0;
  bool isStarted = false;
  bool isCompleted = false;
  bool isCancelled = false;

  ScheduledWork({
    required this.componentId,
    required this.priority,
    required this.work,
    required this.estimatedDuration,
  }) : scheduledAt = DateTime.now();
  
  /// Age of this work in milliseconds
  int get ageMs => DateTime.now().difference(scheduledAt).inMilliseconds;
  
  /// Whether this work should be prioritized due to age (prevent starvation)
  bool get isStarving {
    switch (priority) {
      case ComponentPriority.immediate:
        return ageMs > 5; // 5ms
      case ComponentPriority.high:
        return ageMs > 50; // 50ms
      case ComponentPriority.normal:
        return ageMs > 200; // 200ms
      case ComponentPriority.low:
        return ageMs > 1000; // 1s
      case ComponentPriority.idle:
        return ageMs > 5000; // 5s
    }
  }
  
  /// Execute the work with timeout and error handling
  Future<bool> execute() async {
    if (isCancelled || isCompleted) return false;
    
    isStarted = true;
    final stopwatch = Stopwatch()..start();
    
    try {
      // Execute with timeout based on estimated duration
      await work().timeout(Duration(microseconds: estimatedDuration * 3));
      isCompleted = true;
      return true;
    } catch (e) {
      retryCount++;
      if (retryCount < 3) {
        // Exponential backoff for retries
        await Future.delayed(Duration(milliseconds: 50 * retryCount));
        return false; // Will be retried
      } else {
        isCompleted = true; // Give up after 3 retries
        return false;
      }
    } finally {
      stopwatch.stop();
    }
  }
  
  void cancel() {
    isCancelled = true;
  }
}

/// Pure Dart concurrent scheduler - NO FLUTTER DEPENDENCIES
class ConcurrentScheduler {
  static final ConcurrentScheduler _instance = ConcurrentScheduler._();
  static ConcurrentScheduler get instance => _instance;
  ConcurrentScheduler._();

  /// Priority queues for different component priorities
  final Map<ComponentPriority, Queue<ScheduledWork>> _queues = {
    for (final priority in ComponentPriority.values) priority: Queue<ScheduledWork>()
  };
  
  /// Currently executing work
  ScheduledWork? _currentWork;
  
  /// Whether the scheduler is running
  bool _isRunning = false;
  
  /// Whether we should yield to other work
  bool _shouldYield = false;
  
  /// Frame budget tracking (16ms for 60fps target)
  static const int _frameBudgetMicros = 16000;
  int _frameBudgetUsed = 0;
  DateTime _frameStart = DateTime.now();
  
  /// Performance tracking
  final Map<ComponentPriority, int> _executionCount = {};
  final Map<ComponentPriority, int> _totalExecutionTime = {};

  /// Schedule work with component priority
  /// Schedule work with component priority
void scheduleWork({
  required String componentId,
  required Future<void> Function() work,
  ComponentPriority priority = ComponentPriority.normal,
  int? estimatedDuration,
}) {
  // Use priority-based default duration if not provided
  estimatedDuration ??= priority.timeSliceLimit ~/ 2;
  
  final scheduledWork = ScheduledWork(
    componentId: componentId,
    priority: priority,
    work: work,
    estimatedDuration: estimatedDuration,
  );
  
  // Check if we should interrupt current work
  if (_shouldInterruptCurrentWork(priority)) {
    _interruptCurrentWork();
  }
  
  // Add to appropriate priority queue
  _queues[priority]!.add(scheduledWork);
  
  // 🔥 CRITICAL FIX: Start scheduler immediately for high-priority work
  if (!_isRunning) {
    _startScheduler();
  } else if (priority == ComponentPriority.immediate || priority == ComponentPriority.high) {
    // 🔥 CRITICAL: Force immediate processing for interactive events
    Timer(Duration.zero, () => _runSchedulerLoop());
  }
}
  /// Check if current work should be interrupted
  bool _shouldInterruptCurrentWork(ComponentPriority newPriority) {
    if (_currentWork == null) return false;
    
    // Always interrupt for immediate priority
    if (newPriority == ComponentPriority.immediate) return true;
    
    // Interrupt if new work has higher priority (lower enum index)
    if (newPriority.index < _currentWork!.priority.index) return true;
    
    // Interrupt if current work is starving others and new work is high priority
    if (_currentWork!.ageMs > 100 && newPriority.index <= ComponentPriority.high.index) {
      return true;
    }
    
    return false;
  }
  
  /// Interrupt current work
  void _interruptCurrentWork() {
    if (_currentWork != null) {
      _currentWork!.cancel();
      _shouldYield = true;
    }
  }
  
 /// Start the concurrent scheduler using pure Dart timers
void _startScheduler() {
  if (_isRunning) return;
  
  _isRunning = true;
  _frameStart = DateTime.now();
  _frameBudgetUsed = 0;
  
  // 🔥 FIXED: Use immediate execution instead of Timer
  scheduleMicrotask(_runSchedulerLoop); // ← IMMEDIATE EXECUTION
}
  
  /// Main scheduler loop - pure Dart implementation
  Future<void> _runSchedulerLoop() async {
    while (_isRunning && _hasWork()) {
      // Check if we should yield to prevent blocking
      if (_shouldYieldToSystem()) {
        // Yield to system and reschedule
        Timer(Duration(milliseconds: 1), _runSchedulerLoop);
        return;
      }
      
      // Get next work item based on priority and starvation
      final work = _getNextWork();
      if (work == null) break;
      
      // Execute work and track performance
      _currentWork = work;
      final startTime = DateTime.now();
      
      final success = await work.execute();
      
      final duration = DateTime.now().difference(startTime).inMicroseconds;
      _frameBudgetUsed += duration;
      
      // Update performance stats
      _updatePerformanceStats(work.priority, duration);
      
      // Handle work result
      if (!success && !work.isCancelled && work.retryCount < 3) {
        // Reschedule failed work with exponential backoff
        Timer(Duration(milliseconds: 100 * work.retryCount), () {
          _queues[work.priority]!.add(work);
        });
      }
      
      _currentWork = null;
      _shouldYield = false;
      
      // Yield occasionally to prevent blocking event loop
      if (duration > 2000) { // 2ms
        await Future.delayed(Duration.zero);
      }
    }
    
    _isRunning = false;
  }
  
  /// Check if we should yield to the system (pure Dart approach)
  bool _shouldYieldToSystem() {
    // Yield if we've used most of our frame budget
    if (_frameBudgetUsed > _frameBudgetMicros * 0.8) return true;
    
    // Yield if we've been running for too long
    final runTime = DateTime.now().difference(_frameStart).inMicroseconds;
    if (runTime > _frameBudgetMicros) return true;
    
    // Yield if we have pending microtasks (other async work)
    // This is a heuristic - in practice the event loop will handle this
    return false;
  }
  
  /// Get the next work item based on priority and starvation prevention
  ScheduledWork? _getNextWork() {
    // First pass: check for starving work to prevent priority inversion
    for (final priority in ComponentPriority.values) {
      final queue = _queues[priority]!;
      if (queue.isNotEmpty && queue.first.isStarving) {
        return queue.removeFirst();
      }
    }
    
    // Second pass: check in strict priority order
    for (final priority in ComponentPriority.values) {
      final queue = _queues[priority]!;
      if (queue.isNotEmpty) {
        return queue.removeFirst();
      }
    }
    
    return null;
  }
  
  /// Check if there's any work to do
  bool _hasWork() {
    return _queues.values.any((queue) => queue.isNotEmpty);
  }
  
  /// Update performance statistics
  void _updatePerformanceStats(ComponentPriority priority, int durationMicros) {
    _executionCount[priority] = (_executionCount[priority] ?? 0) + 1;
    _totalExecutionTime[priority] = (_totalExecutionTime[priority] ?? 0) + durationMicros;
  }
  
  /// Cancel all work for a specific component
  void cancelWork(String componentId) {
    for (final queue in _queues.values) {
      queue.removeWhere((work) {
        if (work.componentId == componentId) {
          work.cancel();
          return true;
        }
        return false;
      });
    }
    
    // Cancel current work if it matches
    if (_currentWork?.componentId == componentId) {
      _currentWork!.cancel();
      _shouldYield = true;
    }
  }
  
  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final priority in ComponentPriority.values) {
      final count = _executionCount[priority] ?? 0;
      final totalTime = _totalExecutionTime[priority] ?? 0;
      final avgTime = count > 0 ? totalTime / count : 0.0;
      
      stats[priority.name] = {
        'queueLength': _queues[priority]!.length,
        'executionCount': count,
        'totalExecutionTime': totalTime,
        'averageExecutionTime': avgTime.round(),
      };
    }
    
    stats['scheduler'] = {
      'isRunning': _isRunning,
      'frameBudgetUsed': _frameBudgetUsed,
      'frameBudgetPercent': (_frameBudgetUsed / _frameBudgetMicros * 100).round(),
      'currentWork': _currentWork?.componentId,
      'currentWorkPriority': _currentWork?.priority.name,
    };
    
    return stats;
  }
  
  /// Reset frame budget (call this on each frame)
  void resetFrameBudget() {
    _frameStart = DateTime.now();
    _frameBudgetUsed = 0;
  }
  
  /// Clear all queues and reset state (for testing)
  void clear() {
    for (final queue in _queues.values) {
      for (final work in queue) {
        work.cancel();
      }
      queue.clear();
    }
    
    _currentWork?.cancel();
    _currentWork = null;
    _isRunning = false;
    _shouldYield = false;
    _frameBudgetUsed = 0;
    _executionCount.clear();
    _totalExecutionTime.clear();
  }
  
  /// Get component priority from component (if it implements the interface)
  ComponentPriority getComponentPriority(DCFComponentNode component) {
    if (component is ComponentPriorityInterface) {
      return component.priority;
    }
    
    // Default priority for components without explicit priority
    return ComponentPriority.normal;
  }
  
  /// Force scheduler to yield (for testing or manual control)
  void forceYield() {
    _shouldYield = true;
  }
  
  /// Get queue lengths for monitoring
  Map<ComponentPriority, int> getQueueLengths() {
    return Map.fromEntries(
      _queues.entries.map((entry) => MapEntry(entry.key, entry.value.length))
    );
  }
}
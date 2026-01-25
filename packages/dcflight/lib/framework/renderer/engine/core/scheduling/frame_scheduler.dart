/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';

/// Frame scheduler for deadline-based work scheduling
/// Equivalent to React Fiber's requestIdleCallback/requestAnimationFrame
class FrameScheduler {
  static final FrameScheduler _instance = FrameScheduler._();
  static FrameScheduler get instance => _instance;
  
  FrameScheduler._();

  /// High priority work queue (animations, user input)
  final List<_ScheduledWork> _highPriorityQueue = [];
  
  /// Low priority work queue (background updates)
  final List<_ScheduledWork> _lowPriorityQueue = [];
  
  bool _isScheduling = false;
  Timer? _frameTimer;
  
  /// Schedule high priority work (equivalent to requestAnimationFrame)
  void scheduleHighPriorityWork(Future<void> Function(Deadline) work) {
    _highPriorityQueue.add(_ScheduledWork(
      work: work,
      priority: WorkPriority.high,
      scheduledAt: DateTime.now(),
    ));
    _startScheduling();
  }
  
  /// Schedule low priority work (equivalent to requestIdleCallback)
  void scheduleLowPriorityWork(Future<void> Function(Deadline) work) {
    _lowPriorityQueue.add(_ScheduledWork(
      work: work,
      priority: WorkPriority.low,
      scheduledAt: DateTime.now(),
    ));
    _startScheduling();
  }
  
  void _startScheduling() {
    if (_isScheduling) return;
    _isScheduling = true;
    _scheduleFrame();
  }
  
  void _scheduleFrame() {
    _frameTimer?.cancel();
    
    // Schedule for next frame (16ms for 60fps)
    _frameTimer = Timer(const Duration(milliseconds: 16), () {
      _processFrame();
    });
  }
  
  Future<void> _processFrame() async {
    final frameStart = DateTime.now();
    final frameDeadline = frameStart.add(const Duration(milliseconds: 16));
    
    // Process high priority work first
    while (_highPriorityQueue.isNotEmpty) {
      final deadline = Deadline(
        timeRemaining: () {
          final remaining = frameDeadline.difference(DateTime.now());
          return remaining.inMilliseconds > 0 ? remaining.inMilliseconds : 0;
        },
        didTimeout: false,
      );
      
      if (deadline.timeRemaining() <= 0) break;
      
      final work = _highPriorityQueue.removeAt(0);
      try {
        await work.work(deadline);
      } catch (e) {
        print('Error in high priority work: $e');
      }
    }
    
    // Process low priority work if time remains
    while (_lowPriorityQueue.isNotEmpty) {
      final deadline = Deadline(
        timeRemaining: () {
          final remaining = frameDeadline.difference(DateTime.now());
          return remaining.inMilliseconds > 0 ? remaining.inMilliseconds : 0;
        },
        didTimeout: false,
      );
      
      if (deadline.timeRemaining() <= 0) {
        // Schedule remaining work for next frame
        _scheduleFrame();
        return;
      }
      
      final work = _lowPriorityQueue.removeAt(0);
      try {
        await work.work(deadline);
      } catch (e) {
        print('Error in low priority work: $e');
      }
    }
    
    // If queues are empty, stop scheduling
    if (_highPriorityQueue.isEmpty && _lowPriorityQueue.isEmpty) {
      _isScheduling = false;
    } else {
      // Schedule next frame
      _scheduleFrame();
    }
  }
  
  /// Cancel all scheduled work
  void cancelAll() {
    _highPriorityQueue.clear();
    _lowPriorityQueue.clear();
    _frameTimer?.cancel();
    _isScheduling = false;
  }
}

enum WorkPriority {
  high,
  low,
}

class _ScheduledWork {
  final Future<void> Function(Deadline) work;
  final WorkPriority priority;
  final DateTime scheduledAt;
  
  _ScheduledWork({
    required this.work,
    required this.priority,
    required this.scheduledAt,
  });
}

class Deadline {
  final int Function() timeRemaining;
  final bool didTimeout;
  
  Deadline({
    required this.timeRemaining,
    required this.didTimeout,
  });
}


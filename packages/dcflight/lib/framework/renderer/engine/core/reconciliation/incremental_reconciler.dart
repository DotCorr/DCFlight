/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'package:dcflight/framework/components/component_node.dart';
import 'package:dcflight/framework/renderer/engine/core/scheduling/frame_scheduler.dart';

/// Unit of work for incremental reconciliation
class ReconciliationWork {
  final DCFComponentNode oldNode;
  final DCFComponentNode newNode;
  final Future<void> Function(DCFComponentNode, DCFComponentNode) reconcileFn;
  final Future<void> Function(DCFComponentNode, DCFComponentNode) replaceFn;
  
  ReconciliationWork({
    required this.oldNode,
    required this.newNode,
    required this.reconcileFn,
    required this.replaceFn,
  });
}

/// Incremental reconciler that can pause/resume work
class IncrementalReconciler {
  final List<ReconciliationWork> _workQueue = [];
  ReconciliationWork? _currentWork;
  bool _isPaused = false;
  bool _shouldAbort = false;
  
  /// Add work to queue
  void enqueueWork(ReconciliationWork work) {
    _workQueue.add(work);
  }
  
  /// Process work incrementally with deadline
  Future<bool> processWork(Deadline deadline) async {
    if (_shouldAbort) {
      _workQueue.clear();
      _currentWork = null;
      _shouldAbort = false;
      return false;
    }
    
    while (_workQueue.isNotEmpty && deadline.timeRemaining() > 0) {
      _currentWork = _workQueue.removeAt(0);
      
      try {
        await _currentWork!.reconcileFn(
          _currentWork!.oldNode,
          _currentWork!.newNode,
        );
      } catch (e) {
        print('Error in reconciliation work: $e');
        // Try replace as fallback
        try {
          await _currentWork!.replaceFn(
            _currentWork!.oldNode,
            _currentWork!.newNode,
          );
        } catch (e2) {
          print('Error in replace fallback: $e2');
        }
      }
      
      _currentWork = null;
      
      // Check if we should pause
      if (_isPaused || deadline.timeRemaining() <= 0) {
        return true; // More work remaining
      }
    }
    
    return _workQueue.isNotEmpty; // Return true if more work remains
  }
  
  /// Pause reconciliation
  void pause() {
    _isPaused = true;
  }
  
  /// Resume reconciliation
  void resume() {
    _isPaused = false;
  }
  
  /// Abort all work
  void abort() {
    _shouldAbort = true;
    _workQueue.clear();
    _currentWork = null;
  }
  
  /// Check if work is complete
  bool get isComplete => _workQueue.isEmpty && _currentWork == null;
  
  /// Get remaining work count
  int get remainingWork => _workQueue.length + (_currentWork != null ? 1 : 0);
}


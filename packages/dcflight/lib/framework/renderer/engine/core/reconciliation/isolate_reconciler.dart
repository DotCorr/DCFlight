/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:isolate';
import 'package:dcflight/framework/components/component_node.dart';

/// Reconciliation diff result from isolate
class ReconciliationDiff {
  final List<DiffChange> changes;
  final Map<String, dynamic> metrics;
  
  ReconciliationDiff({
    required this.changes,
    required this.metrics,
  });
}

/// Single change in reconciliation diff
class DiffChange {
  final String action; // 'create', 'update', 'delete', 'replace'
  final String? nodeId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final Map<String, dynamic>? propsDiff;
  
  DiffChange({
    required this.action,
    this.nodeId,
    this.oldData,
    this.newData,
    this.propsDiff,
  });
}

/// Isolate-based reconciler for parallel tree diffing
class IsolateReconciler {
  final List<Isolate> _isolates = [];
  final List<SendPort> _ports = [];
  final List<bool> _available = [];
  final ReceivePort _mainReceivePort = ReceivePort();
  final Map<String, Completer<ReconciliationDiff>> _pendingTasks = {};
  int _taskCounter = 0;
  final int _maxIsolates;
  
  IsolateReconciler({int maxIsolates = 4}) : _maxIsolates = maxIsolates;
  
  /// Initialize worker isolates
  Future<void> initialize() async {
    for (int i = 0; i < _maxIsolates; i++) {
      await _spawnIsolate();
    }
    
    _mainReceivePort.listen((message) {
      _handleIsolateResponse(message);
    });
  }
  
  Future<void> _spawnIsolate() async {
    final completer = Completer<SendPort>();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _mainReceivePort.sendPort,
    );
    
    _isolates.add(isolate);
    _available.add(true);
    
    // Wait for isolate to send its port
    _mainReceivePort.listen((message) {
      if (message is SendPort) {
        _ports.add(message);
        completer.complete(message);
      }
    });
    
    await completer.future;
  }
  
  /// Reconcile trees in parallel using isolates
  Future<ReconciliationDiff> reconcileTrees(
    Map<String, dynamic> oldTree,
    Map<String, dynamic> newTree,
  ) async {
    if (_ports.isEmpty) {
      throw StateError('Isolates not initialized');
    }
    
    // Find available isolate
    int isolateIndex = -1;
    for (int i = 0; i < _available.length; i++) {
      if (_available[i]) {
        isolateIndex = i;
        break;
      }
    }
    
    if (isolateIndex == -1) {
      // All busy, use first one (will queue)
      isolateIndex = 0;
    }
    
    final taskId = 'task_${_taskCounter++}';
    final completer = Completer<ReconciliationDiff>();
    _pendingTasks[taskId] = completer;
    
    _available[isolateIndex] = false;
    
    _ports[isolateIndex].send({
      'type': 'reconcile',
      'id': taskId,
      'oldTree': oldTree,
      'newTree': newTree,
    });
    
    return completer.future;
  }
  
  void _handleIsolateResponse(dynamic message) {
    if (message is! Map<String, dynamic>) return;
    
    final taskId = message['id'] as String?;
    if (taskId == null) return;
    
    final completer = _pendingTasks.remove(taskId);
    if (completer == null) return;
    
    if (message['success'] == true) {
      final data = message['data'] as Map<String, dynamic>;
      final changes = (data['changes'] as List)
          .map((c) => DiffChange(
                action: c['action'] as String,
                nodeId: c['nodeId'] as String?,
                oldData: c['oldData'] as Map<String, dynamic>?,
                newData: c['newData'] as Map<String, dynamic>?,
                propsDiff: c['propsDiff'] as Map<String, dynamic>?,
              ))
          .toList();
      
      completer.complete(ReconciliationDiff(
        changes: changes,
        metrics: data['metrics'] as Map<String, dynamic>,
      ));
    } else {
      completer.completeError(Exception(message['error'] as String? ?? 'Unknown error'));
    }
    
    // Mark isolate as available
    for (int i = 0; i < _available.length; i++) {
      if (!_available[i]) {
        _available[i] = true;
        break;
      }
    }
  }
  
  /// Shutdown all isolates
  Future<void> shutdown() async {
    for (final isolate in _isolates) {
      isolate.kill();
    }
    _isolates.clear();
    _ports.clear();
    _available.clear();
    _pendingTasks.clear();
  }
  
  /// Isolate entry point
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);
    
    receivePort.listen((message) async {
      if (message is! Map<String, dynamic>) return;
      
      final taskId = message['id'] as String;
      final oldTree = message['oldTree'] as Map<String, dynamic>?;
      final newTree = message['newTree'] as Map<String, dynamic>;
      
      try {
        final result = _reconcileInIsolate(oldTree, newTree);
        mainSendPort.send({
          'type': 'result',
          'id': taskId,
          'success': true,
          'data': result,
        });
      } catch (e) {
        mainSendPort.send({
          'type': 'result',
          'id': taskId,
          'success': false,
          'error': e.toString(),
        });
      }
    });
  }
  
  /// Reconcile trees in isolate (pure computation)
  static Map<String, dynamic> _reconcileInIsolate(
    Map<String, dynamic>? oldTree,
    Map<String, dynamic> newTree,
  ) {
    final changes = <Map<String, dynamic>>[];
    
    if (oldTree == null) {
      return {
        'changes': [
          {
            'action': 'create',
            'newData': newTree,
          }
        ],
        'metrics': {
          'nodesProcessed': _countNodes(newTree),
          'complexity': 'simple',
        }
      };
    }
    
    // Compare types
    final oldType = oldTree['type'] as String?;
    final newType = newTree['type'] as String?;
    
    if (oldType != newType) {
      changes.add({
        'action': 'replace',
        'oldData': oldTree,
        'newData': newTree,
      });
    } else {
      // Same type - check props
      final oldProps = oldTree['props'] as Map<String, dynamic>? ?? {};
      final newProps = newTree['props'] as Map<String, dynamic>? ?? {};
      final propsDiff = _computePropsDiff(oldProps, newProps);
      
      if (propsDiff.isNotEmpty) {
        changes.add({
          'action': 'update',
          'nodeId': newTree['id'] as String?,
          'propsDiff': propsDiff,
        });
      }
      
      // Reconcile children
      final oldChildren = oldTree['children'] as List<dynamic>? ?? [];
      final newChildren = newTree['children'] as List<dynamic>? ?? [];
      final childrenChanges = _reconcileChildren(oldChildren, newChildren);
      changes.addAll(childrenChanges);
    }
    
    return {
      'changes': changes,
      'metrics': {
        'nodesProcessed': _countNodes(newTree),
        'changesCount': changes.length,
        'complexity': changes.length > 10 ? 'complex' : 'simple',
      }
    };
  }
  
  static List<Map<String, dynamic>> _reconcileChildren(
    List<dynamic> oldChildren,
    List<dynamic> newChildren,
  ) {
    final changes = <Map<String, dynamic>>[];
    
    // Simple matching by index and type
    final maxLen = oldChildren.length > newChildren.length 
        ? oldChildren.length 
        : newChildren.length;
    
    for (int i = 0; i < maxLen; i++) {
      if (i >= oldChildren.length) {
        // New child
        changes.add({
          'action': 'create',
          'newData': newChildren[i] as Map<String, dynamic>,
        });
      } else if (i >= newChildren.length) {
        // Removed child
        changes.add({
          'action': 'delete',
          'oldData': oldChildren[i] as Map<String, dynamic>,
        });
      } else {
        final oldChild = oldChildren[i] as Map<String, dynamic>;
        final newChild = newChildren[i] as Map<String, dynamic>;
        
        if (oldChild['type'] != newChild['type']) {
          changes.add({
            'action': 'replace',
            'oldData': oldChild,
            'newData': newChild,
            'index': i, // Include index for efficient child lookup
          });
        } else {
          final oldProps = oldChild['props'] as Map<String, dynamic>? ?? {};
          final newProps = newChild['props'] as Map<String, dynamic>? ?? {};
          final propsDiff = _computePropsDiff(oldProps, newProps);
          
          if (propsDiff.isNotEmpty) {
            changes.add({
              'action': 'update',
              'nodeId': newChild['id'] as String?,
              'propsDiff': propsDiff,
              'index': i, // Include index for efficient child lookup
            });
          }
        }
      }
    }
    
    return changes;
  }
  
  static Map<String, dynamic> _computePropsDiff(
    Map<String, dynamic> oldProps,
    Map<String, dynamic> newProps,
  ) {
    final diff = <String, dynamic>{};
    
    for (final key in newProps.keys) {
      if (!oldProps.containsKey(key) || oldProps[key] != newProps[key]) {
        diff[key] = newProps[key];
      }
    }
    
    return diff;
  }
  
  static int _countNodes(Map<String, dynamic> tree) {
    int count = 1;
    final children = tree['children'] as List<dynamic>? ?? [];
    for (final child in children) {
      if (child is Map<String, dynamic>) {
        count += _countNodes(child);
      }
    }
    return count;
  }
}


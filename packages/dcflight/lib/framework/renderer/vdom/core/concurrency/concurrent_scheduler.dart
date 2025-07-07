/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:dcflight/framework/renderer/vdom/core/concurrency/priority.dart';

/// Message types for isolate communication
enum ConcurrentMessageType {
  processUpdate,
  processUpdateBatch,
  reconcileTree,
  computeDiff,
  renderPrepare,
  result,
  error,
  shutdown,
}

/// Message structure for isolate communication
class ConcurrentMessage {
  final ConcurrentMessageType type;
  final String id;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ConcurrentMessage({
    required this.type,
    required this.id,
    required this.data,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'data': data,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ConcurrentMessage.fromJson(Map<String, dynamic> json) {
    return ConcurrentMessage(
      type: ConcurrentMessageType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      id: json['id'],
      data: Map<String, dynamic>.from(json['data']),
    );
  }
}

/// Result of concurrent processing
class ConcurrentResult {
  final String id;
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final Duration processingTime;

  ConcurrentResult({
    required this.id,
    required this.success,
    this.data,
    this.error,
    required this.processingTime,
  });
}

/// Concurrent update scheduler that uses isolates for parallel processing
class ConcurrentScheduler {
  /// Maximum number of worker isolates
  static const int maxWorkers = 4;

  /// Minimum batch size to warrant isolate processing
  static const int minBatchSize = 3;

  /// Worker isolates pool
  final List<Isolate> _workers = [];
  final List<SendPort> _workerPorts = [];
  final List<ReceivePort> _workerReceivePorts = [];
  final List<bool> _workerAvailable = [];

  /// Pending operations tracking
  final Map<String, Completer<ConcurrentResult>> _pendingOperations = {};
  final Queue<ConcurrentMessage> _taskQueue = Queue();

  /// Statistics and monitoring
  int _totalTasksProcessed = 0;
  int _totalTasksParallel = 0;
  int _totalTasksSerial = 0;
  final Map<ComponentPriority, int> _tasksByPriority = {};

  /// Initialization state
  bool _initialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Singleton instance
  static final ConcurrentScheduler _instance = ConcurrentScheduler._internal();
  factory ConcurrentScheduler() => _instance;
  ConcurrentScheduler._internal();

  /// Initialize the concurrent scheduler
  Future<void> initialize() async {
    if (_initialized) return;

    developer.log('ConcurrentScheduler: Initializing with $maxWorkers workers');

    try {
      // Create worker isolates
      for (int i = 0; i < maxWorkers; i++) {
        final receivePort = ReceivePort();
        final isolate = await Isolate.spawn(
          _isolateEntryPoint,
          receivePort.sendPort,
          debugName: 'VDomWorker-$i',
        );

        _workers.add(isolate);
        _workerReceivePorts.add(receivePort);
        _workerAvailable.add(true);

        // Listen for messages from worker
        receivePort.listen((message) {
          _handleWorkerMessage(i, message);
        });

        // Get worker's send port
        final Completer<SendPort> portCompleter = Completer<SendPort>();
        receivePort.first.then((sendPort) {
          portCompleter.complete(sendPort as SendPort);
        });

        _workerPorts.add(await portCompleter.future);
      }

      _initialized = true;
      _initCompleter.complete();

      developer.log('ConcurrentScheduler: Initialized successfully');
    } catch (e) {
      developer.log('ConcurrentScheduler: Initialization failed: $e');
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  /// Ensure scheduler is ready
  Future<void> get ready => _initCompleter.future;

  /// Process a single component update with concurrency consideration
  Future<ConcurrentResult> processComponentUpdate({
    required String componentId,
    required ComponentPriority priority,
    required Map<String, dynamic> componentData,
    bool forceParallel = false,
  }) async {
    await ready;

    final taskId = _generateTaskId();
    final startTime = DateTime.now();

    // For immediate priority, always process on main thread
    if (priority == ComponentPriority.immediate && !forceParallel) {
      return _processUpdateOnMainThread(
        taskId,
        componentId,
        componentData,
        startTime,
      );
    }

    // Check if we have available workers
    final availableWorker = _findAvailableWorker();
    if (availableWorker == -1) {
      // No workers available, process on main thread
      return _processUpdateOnMainThread(
        taskId,
        componentId,
        componentData,
        startTime,
      );
    }

    // Process on worker isolate
    return _processUpdateOnWorker(
      availableWorker,
      taskId,
      componentId,
      componentData,
      priority,
      startTime,
    );
  }

  /// Process a batch of component updates with parallel processing
  Future<List<ConcurrentResult>> processUpdateBatch({
    required List<String> componentIds,
    required Map<String, ComponentPriority> priorities,
    required Map<String, Map<String, dynamic>> componentData,
  }) async {
    await ready;

    if (componentIds.length < minBatchSize) {
      // Small batch, process serially
      final results = <ConcurrentResult>[];
      for (final componentId in componentIds) {
        final priority = priorities[componentId] ?? ComponentPriority.normal;
        final data = componentData[componentId] ?? {};
        final result = await processComponentUpdate(
          componentId: componentId,
          priority: priority,
          componentData: data,
        );
        results.add(result);
      }
      return results;
    }

    // Large batch, process in parallel
    return _processBatchInParallel(componentIds, priorities, componentData);
  }

  /// Process tree reconciliation concurrently
  Future<ConcurrentResult> reconcileTree({
    required String treeId,
    required Map<String, dynamic> oldTree,
    required Map<String, dynamic> newTree,
    ComponentPriority priority = ComponentPriority.normal,
  }) async {
    await ready;

    final taskId = _generateTaskId();
    final startTime = DateTime.now();

    // For large trees, use worker isolate
    final treeSize = _estimateTreeSize(newTree);
    if (treeSize > 10) {
      final availableWorker = _findAvailableWorker();
      if (availableWorker != -1) {
        return _reconcileTreeOnWorker(
          availableWorker,
          taskId,
          treeId,
          oldTree,
          newTree,
          startTime,
        );
      }
    }

    // Process on main thread for small trees or no available workers
    return _reconcileTreeOnMainThread(
      taskId,
      treeId,
      oldTree,
      newTree,
      startTime,
    );
  }

  /// Compute component diff concurrently
  Future<ConcurrentResult> computeDiff({
    required String componentId,
    required Map<String, dynamic> oldProps,
    required Map<String, dynamic> newProps,
  }) async {
    await ready;

    final taskId = _generateTaskId();
    final startTime = DateTime.now();

    // Simple diff computation can be done on main thread
    final diff = _computePropsDeep(oldProps, newProps);
    final processingTime = DateTime.now().difference(startTime);

    return ConcurrentResult(
      id: taskId,
      success: true,
      data: {'diff': diff, 'componentId': componentId},
      processingTime: processingTime,
    );
  }

  /// Get scheduler statistics
  Map<String, dynamic> getStats() {
    return {
      'initialized': _initialized,
      'totalWorkers': _workers.length,
      'availableWorkers':
          _workerAvailable.where((available) => available).length,
      'totalTasksProcessed': _totalTasksProcessed,
      'totalTasksParallel': _totalTasksParallel,
      'totalTasksSerial': _totalTasksSerial,
      'tasksByPriority': _tasksByPriority,
      'pendingOperations': _pendingOperations.length,
      'queuedTasks': _taskQueue.length,
    };
  }

  /// Shutdown the scheduler and clean up workers
  Future<void> shutdown() async {
    developer.log('ConcurrentScheduler: Shutting down');

    // Kill all worker isolates
    for (int i = 0; i < _workers.length; i++) {
      try {
        _workers[i].kill();
        _workerReceivePorts[i].close();
      } catch (e) {
        developer.log('ConcurrentScheduler: Error killing worker $i: $e');
      }
    }

    // Clear all collections
    _workers.clear();
    _workerPorts.clear();
    _workerReceivePorts.clear();
    _workerAvailable.clear();
    _pendingOperations.clear();
    _taskQueue.clear();

    _initialized = false;
    developer.log('ConcurrentScheduler: Shutdown complete');
  }

  /// PRIVATE METHODS

  /// Find an available worker isolate
  int _findAvailableWorker() {
    for (int i = 0; i < _workerAvailable.length; i++) {
      if (_workerAvailable[i]) {
        return i;
      }
    }
    return -1;
  }

  /// Generate unique task ID
  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Process update on main thread
  Future<ConcurrentResult> _processUpdateOnMainThread(
    String taskId,
    String componentId,
    Map<String, dynamic> componentData,
    DateTime startTime,
  ) async {
    try {
      // Simulate component processing
      await Future.delayed(Duration(milliseconds: 1));

      final processingTime = DateTime.now().difference(startTime);
      _totalTasksSerial++;
      _totalTasksProcessed++;

      return ConcurrentResult(
        id: taskId,
        success: true,
        data: {
          'componentId': componentId,
          'processed': true,
          'thread': 'main',
        },
        processingTime: processingTime,
      );
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);
      return ConcurrentResult(
        id: taskId,
        success: false,
        error: e.toString(),
        processingTime: processingTime,
      );
    }
  }

  /// Process update on worker isolate
  Future<ConcurrentResult> _processUpdateOnWorker(
    int workerId,
    String taskId,
    String componentId,
    Map<String, dynamic> componentData,
    ComponentPriority priority,
    DateTime startTime,
  ) async {
    _workerAvailable[workerId] = false;

    try {
      final completer = Completer<ConcurrentResult>();
      _pendingOperations[taskId] = completer;

      final message = ConcurrentMessage(
        type: ConcurrentMessageType.processUpdate,
        id: taskId,
        data: {
          'componentId': componentId,
          'componentData': componentData,
          'priority': priority.name,
        },
      );

      _workerPorts[workerId].send(message.toJson());

      final result = await completer.future;
      _totalTasksParallel++;
      _totalTasksProcessed++;

      return result;
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);
      return ConcurrentResult(
        id: taskId,
        success: false,
        error: e.toString(),
        processingTime: processingTime,
      );
    } finally {
      _workerAvailable[workerId] = true;
      _pendingOperations.remove(taskId);
    }
  }

  /// Process batch in parallel across multiple workers
  Future<List<ConcurrentResult>> _processBatchInParallel(
    List<String> componentIds,
    Map<String, ComponentPriority> priorities,
    Map<String, Map<String, dynamic>> componentData,
  ) async {
    final results = <ConcurrentResult>[];
    final futures = <Future<ConcurrentResult>>[];

    // Distribute tasks across available workers
    for (int i = 0; i < componentIds.length; i++) {
      final componentId = componentIds[i];
      final priority = priorities[componentId] ?? ComponentPriority.normal;
      final data = componentData[componentId] ?? {};

      final future = processComponentUpdate(
        componentId: componentId,
        priority: priority,
        componentData: data,
        forceParallel: true,
      );

      futures.add(future);
    }

    // Wait for all tasks to complete
    final completedResults = await Future.wait(futures);
    results.addAll(completedResults);

    return results;
  }

  /// Reconcile tree on worker isolate
  Future<ConcurrentResult> _reconcileTreeOnWorker(
    int workerId,
    String taskId,
    String treeId,
    Map<String, dynamic> oldTree,
    Map<String, dynamic> newTree,
    DateTime startTime,
  ) async {
    _workerAvailable[workerId] = false;

    try {
      final completer = Completer<ConcurrentResult>();
      _pendingOperations[taskId] = completer;

      final message = ConcurrentMessage(
        type: ConcurrentMessageType.reconcileTree,
        id: taskId,
        data: {
          'treeId': treeId,
          'oldTree': oldTree,
          'newTree': newTree,
        },
      );

      _workerPorts[workerId].send(message.toJson());

      final result = await completer.future;
      _totalTasksParallel++;
      _totalTasksProcessed++;

      return result;
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);
      return ConcurrentResult(
        id: taskId,
        success: false,
        error: e.toString(),
        processingTime: processingTime,
      );
    } finally {
      _workerAvailable[workerId] = true;
      _pendingOperations.remove(taskId);
    }
  }

  /// Reconcile tree on main thread
  Future<ConcurrentResult> _reconcileTreeOnMainThread(
    String taskId,
    String treeId,
    Map<String, dynamic> oldTree,
    Map<String, dynamic> newTree,
    DateTime startTime,
  ) async {
    try {
      // Simulate tree reconciliation
      final diff = _computeTreeDiff(oldTree, newTree);
      await Future.delayed(Duration(milliseconds: 5));

      final processingTime = DateTime.now().difference(startTime);
      _totalTasksSerial++;
      _totalTasksProcessed++;

      return ConcurrentResult(
        id: taskId,
        success: true,
        data: {
          'treeId': treeId,
          'diff': diff,
          'thread': 'main',
        },
        processingTime: processingTime,
      );
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);
      return ConcurrentResult(
        id: taskId,
        success: false,
        error: e.toString(),
        processingTime: processingTime,
      );
    }
  }

  /// Handle messages from worker isolates
  void _handleWorkerMessage(int workerId, dynamic message) {
    try {
      final Map<String, dynamic> messageData = message as Map<String, dynamic>;
      final concurrentMessage = ConcurrentMessage.fromJson(messageData);

      final completer = _pendingOperations[concurrentMessage.id];
      if (completer == null) {
        developer.log(
            'ConcurrentScheduler: No pending operation for task ${concurrentMessage.id}');
        return;
      }

      if (concurrentMessage.type == ConcurrentMessageType.result) {
        final result = ConcurrentResult(
          id: concurrentMessage.id,
          success: concurrentMessage.data['success'] ?? false,
          data: concurrentMessage.data['data'],
          error: concurrentMessage.data['error'],
          processingTime: Duration(
            milliseconds: concurrentMessage.data['processingTimeMs'] ?? 0,
          ),
        );
        completer.complete(result);
      } else if (concurrentMessage.type == ConcurrentMessageType.error) {
        final result = ConcurrentResult(
          id: concurrentMessage.id,
          success: false,
          error: concurrentMessage.data['error'] ?? 'Unknown error',
          processingTime: Duration(
            milliseconds: concurrentMessage.data['processingTimeMs'] ?? 0,
          ),
        );
        completer.complete(result);
      }
    } catch (e) {
      developer.log('ConcurrentScheduler: Error handling worker message: $e');
    }
  }

  /// Estimate tree size for processing decision
  int _estimateTreeSize(Map<String, dynamic> tree) {
    int size = 1;
    for (final value in tree.values) {
      if (value is Map<String, dynamic>) {
        size += _estimateTreeSize(value);
      } else if (value is List) {
        size += value.length;
      }
    }
    return size;
  }

  /// Compute props diff
  Map<String, dynamic> _computePropsDeep(
    Map<String, dynamic> oldProps,
    Map<String, dynamic> newProps,
  ) {
    final diff = <String, dynamic>{};

    // Check for changed or new props
    for (final key in newProps.keys) {
      if (!oldProps.containsKey(key) || oldProps[key] != newProps[key]) {
        diff[key] = {
          'old': oldProps[key],
          'new': newProps[key],
          'action': oldProps.containsKey(key) ? 'changed' : 'added',
        };
      }
    }

    // Check for removed props
    for (final key in oldProps.keys) {
      if (!newProps.containsKey(key)) {
        diff[key] = {
          'old': oldProps[key],
          'new': null,
          'action': 'removed',
        };
      }
    }

    return diff;
  }

  /// Compute tree diff
  Map<String, dynamic> _computeTreeDiff(
    Map<String, dynamic> oldTree,
    Map<String, dynamic> newTree,
  ) {
    // Simplified tree diff computation
    return {
      'hasChanges': oldTree != newTree,
      'oldSize': _estimateTreeSize(oldTree),
      'newSize': _estimateTreeSize(newTree),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

/// Entry point for worker isolates
void _isolateEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    try {
      final Map<String, dynamic> messageData = message as Map<String, dynamic>;
      final concurrentMessage = ConcurrentMessage.fromJson(messageData);

      final startTime = DateTime.now();
      Map<String, dynamic> result;

      switch (concurrentMessage.type) {
        case ConcurrentMessageType.processUpdate:
          result = await _processUpdateInIsolate(concurrentMessage.data);
          break;
        case ConcurrentMessageType.reconcileTree:
          result = await _reconcileTreeInIsolate(concurrentMessage.data);
          break;
        case ConcurrentMessageType.computeDiff:
          result = await _computeDiffInIsolate(concurrentMessage.data);
          break;
        case ConcurrentMessageType.shutdown:
          receivePort.close();
          return;
        default:
          throw Exception('Unknown message type: ${concurrentMessage.type}');
      }

      final processingTime = DateTime.now().difference(startTime);

      final response = ConcurrentMessage(
        type: ConcurrentMessageType.result,
        id: concurrentMessage.id,
        data: {
          'success': true,
          'data': result,
          'processingTimeMs': processingTime.inMilliseconds,
        },
      );

      mainSendPort.send(response.toJson());
    } catch (e) {
      final response = ConcurrentMessage(
        type: ConcurrentMessageType.error,
        id: (message as Map<String, dynamic>)['id'] ?? 'unknown',
        data: {
          'success': false,
          'error': e.toString(),
          'processingTimeMs': 0,
        },
      );

      mainSendPort.send(response.toJson());
    }
  });
}

/// Process component update in isolate
Future<Map<String, dynamic>> _processUpdateInIsolate(
    Map<String, dynamic> data) async {
  final componentId = data['componentId'] as String;
  // final componentData = data['componentData'] as Map<String, dynamic>;
  final priority = data['priority'] as String;

  // Simulate component processing work
  await Future.delayed(Duration(milliseconds: 2));

  return {
    'componentId': componentId,
    'processed': true,
    'priority': priority,
    'thread': 'isolate',
    'isolateId': Isolate.current.debugName,
  };
}

/// Reconcile tree in isolate
Future<Map<String, dynamic>> _reconcileTreeInIsolate(
    Map<String, dynamic> data) async {
  final treeId = data['treeId'] as String;
  final oldTree = data['oldTree'] as Map<String, dynamic>;
  final newTree = data['newTree'] as Map<String, dynamic>;

  // Simulate tree reconciliation work
  await Future.delayed(Duration(milliseconds: 10));

  return {
    'treeId': treeId,
    'reconciled': true,
    'hasChanges': oldTree != newTree,
    'thread': 'isolate',
    'isolateId': Isolate.current.debugName,
  };
}

/// Compute diff in isolate
Future<Map<String, dynamic>> _computeDiffInIsolate(
    Map<String, dynamic> data) async {
  // Simulate diff computation work
  await Future.delayed(Duration(milliseconds: 1));

  return {
    'diffComputed': true,
    'thread': 'isolate',
    'isolateId': Isolate.current.debugName,
  };
}

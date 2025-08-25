/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:dcflight/framework/renderer/engine/core/concurrency/priority.dart';
import 'package:dcflight/framework/renderer/engine/debug/engine_logger.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';
import 'package:dcflight/framework/renderer/interface/interface.dart'
    show PlatformInterface;
import 'package:dcflight/framework/renderer/engine/component/component.dart';
import 'package:dcflight/framework/renderer/engine/component/error_boundary.dart';
import 'package:dcflight/framework/renderer/engine/component/dcf_element.dart';
import 'package:dcflight/framework/renderer/engine/component/component_node.dart';
import 'package:dcflight/framework/renderer/engine/component/fragment.dart';

/// Enhanced Virtual DOM with priority-based update scheduling
class DCFEngine {
  /// Native bridge for UI operations
  final PlatformInterface _nativeBridge;

  /// Whether the VDom is ready for use
  final Completer<void> _readyCompleter = Completer<void>();

  /// Counter for generating unique view IDs - O(1) access
  int _viewIdCounter = 1;

  /// Map of view IDs to their associated VDomNodes - O(1) lookup
  final Map<String, DCFComponentNode> _nodesByViewId = {};

  /// Component tracking maps - O(1) access
  final Map<String, StatefulComponent> _statefulComponents = {};
  final Map<String, StatelessComponent> _statelessComponents = {};
  final Map<String, DCFComponentNode> _previousRenderedNodes = {};

  /// Priority-based update system
  final Set<String> _pendingUpdates = {}; // O(1) add/remove
  final Map<String, ComponentPriority> _componentPriorities = {}; // O(1) lookup
  Timer? _updateTimer;
  bool _isUpdateScheduled = false;
  bool _batchUpdateInProgress = false;

  /// Root component and error boundaries
  DCFComponentNode? rootComponent;
  final Map<String, ErrorBoundary> _errorBoundaries = {};

  /// Effect phase management
  final Set<String> _componentsWaitingForLayout = {};
  final Set<String> _componentsWaitingForInsertion = {};
  bool _isTreeComplete = false;

  /// Concurrent processing features
  static const int _concurrentThreshold = 5;
  bool _concurrentEnabled = false;
  final List<Isolate> _workerIsolates = [];
  final List<SendPort> _workerPorts = [];
  final List<bool> _workerAvailable = [];
  final int _maxWorkers = 4;

  /// Performance tracking
  final Map<String, dynamic> _performanceStats = {
    'totalConcurrentUpdates': 0,
    'totalSerialUpdates': 0,
    'averageConcurrentTime': 0.0,
    'averageSerialTime': 0.0,
    'concurrentEfficiency': 0.0,
  };

  DCFEngine(this._nativeBridge) {
    EngineDebugLogger.log('VDOM_INIT', 'Creating new VDom instance');
    _initialize();
  }

  /// O(1) - Initialize the VDom with the native bridge
  Future<void> _initialize() async {
    EngineDebugLogger.log('VDOM_INIT', 'Starting VDom initialization');

    try {
      final success = await _nativeBridge.initialize();
      if (!success) {
        throw Exception('Failed to initialize native bridge');
      }

      _nativeBridge.setEventHandler(_handleNativeEvent);

      // Initialize concurrent processing
      await _initializeConcurrentProcessing();

      _readyCompleter.complete();
      EngineDebugLogger.log(
          'VDOM_INIT', 'VDom initialization completed successfully');
    } catch (e) {
      EngineDebugLogger.log(
          'VDOM_INIT_ERROR', 'VDom initialization failed: $e');
      _readyCompleter.completeError(e);
    }
  }

  /// Initialize concurrent processing capabilities
  Future<void> _initializeConcurrentProcessing() async {
    // This must be set to true before using this feature
    // But this is not ready. It would be delegated to app layer if developers
    // try {
    //   // Try to create worker isolates
    //   for (int i = 0; i < _maxWorkers; i++) {
    //     final receivePort = ReceivePort();
    //     final isolate = await Isolate.spawn(
    //       _workerIsolateEntry,
    //       receivePort.sendPort,
    //       debugName: 'VDomWorker-$i',
    //     );

    //     _workerIsolates.add(isolate);
    //     _workerAvailable.add(true);

    //     // Get the worker's send port
    //     final sendPort = await receivePort.first as SendPort;
    //     _workerPorts.add(sendPort);
    //   }

    //   _concurrentEnabled = true;
    //   EngineDebugLogger.log('VDOM_CONCURRENT',
    //       'Concurrent processing enabled with $_maxWorkers workers');
    // } catch (e) {
    //   EngineDebugLogger.log('VDOM_CONCURRENT_ERROR',
    //       'Failed to initialize concurrent processing: $e');
    //   _concurrentEnabled = false;
    //   // Continue without concurrent processing
    // }
  }

  Future<void> get isReady => _readyCompleter.future;

  /// O(1) - Generate a unique view ID
  String _generateViewId() {
    final viewId = (_viewIdCounter++).toString();
    EngineDebugLogger.log('VIEW_ID_GENERATE', 'Generated view ID: $viewId');
    return viewId;
  }

  /// O(1) - Get node key with automatic fallback to instanceId
  String _getNodeKey(DCFComponentNode node, int index) {
    if (node.key != null) {
      return node.key!;
    }

    if (node is StatefulComponent) {
      return node.instanceId;
    } else if (node is StatelessComponent) {
      return node.instanceId;
    }

    return 'index_$index';
  }

  /// O(1) - Register a component in the VDOM
  void registerComponent(DCFComponentNode component) {
    EngineDebugLogger.logMount(component, context: 'registerComponent');

    if (component is StatefulComponent) {
      _statefulComponents[component.instanceId] = component;
      component.scheduleUpdate = () => _scheduleComponentUpdate(component);
      EngineDebugLogger.log('COMPONENT_REGISTER',
          'Registered StatefulComponent: ${component.instanceId}');
    } else if (component is StatelessComponent) {
      _statelessComponents[component.instanceId] = component;
      EngineDebugLogger.log('COMPONENT_REGISTER',
          'Registered StatelessComponent: ${component.instanceId}');
    }

    if (component is ErrorBoundary) {
      _errorBoundaries[component.instanceId] = component;
      EngineDebugLogger.log('ERROR_BOUNDARY_REGISTER',
          'Registered ErrorBoundary: ${component.instanceId}');
    }
  }

  /// O(1) - Handle a native event by finding the appropriate component
  void _handleNativeEvent(
      String viewId, String eventType, Map<dynamic, dynamic> eventData) {
    EngineDebugLogger.log(
        'NATIVE_EVENT', 'Received event: $eventType for view: $viewId',
        extra: {'EventData': eventData.toString()});

    final node = _nodesByViewId[viewId]; // O(1) lookup
    if (node == null) {
      EngineDebugLogger.log(
          'NATIVE_EVENT_ERROR', 'No node found for view ID: $viewId');
      return;
    }

    if (node is DCFElement) {
      // O(1) - Try multiple event handler formats
      final eventHandlerKeys = [
        eventType,
        'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}',
        eventType.toLowerCase(),
        'on${eventType.toLowerCase().substring(0, 1).toUpperCase()}${eventType.toLowerCase().substring(1)}'
      ];

      for (final key in eventHandlerKeys) {
        if (node.props.containsKey(key) && node.props[key] is Function) {
          EngineDebugLogger.log('EVENT_HANDLER_FOUND',
              'Found handler for $eventType using key: $key');
          _executeEventHandler(node.props[key], eventData);
          return;
        }
      }

      EngineDebugLogger.log(
          'EVENT_HANDLER_NOT_FOUND', 'No handler found for event: $eventType',
          extra: {'AvailableProps': node.props.keys.toList()});
    }
  }

  /// O(1) - Execute an event handler with flexible signatures
  void _executeEventHandler(Function handler, Map<dynamic, dynamic> eventData) {
    EngineDebugLogger.log('EVENT_HANDLER_EXECUTE', 'Executing event handler',
        extra: {'HandlerType': handler.runtimeType.toString()});

    try {
      if (eventData.isNotEmpty) {
        Function.apply(handler, [eventData]);
      } else {
        Function.apply(handler, []);
      }
      EngineDebugLogger.log(
          'EVENT_HANDLER_SUCCESS', 'Event handler executed successfully');
      return;
    } catch (e) {
      EngineDebugLogger.log(
          'EVENT_HANDLER_RETRY', 'Retrying with different signature');
    }

    // O(1) - Handle special event types
    if (eventData.containsKey('width') && eventData.containsKey('height')) {
      try {
        final width = eventData['width'] as double? ?? 0.0;
        final height = eventData['height'] as double? ?? 0.0;
        Function.apply(handler, [width, height]);
        EngineDebugLogger.log(
            'EVENT_HANDLER_SUCCESS', 'Content size change handler executed');
        return;
      } catch (e) {
        // Continue to next pattern
      }
    }

    // O(1) - Try with no parameters
    try {
      Function.apply(handler, []);
      EngineDebugLogger.log(
          'EVENT_HANDLER_SUCCESS', 'Parameter-less handler executed');
      return;
    } catch (e) {
      // Continue to final fallback
    }

    // O(1) - Final fallback
    try {
      (handler as dynamic)(eventData);
      EngineDebugLogger.log(
          'EVENT_HANDLER_SUCCESS', 'Dynamic handler executed');
    } catch (e) {
      EngineDebugLogger.log(
          'EVENT_HANDLER_ERROR', 'All handler execution attempts failed',
          extra: {'Error': e.toString()});
      throw Exception(
          'Failed to execute event handler for $handler with data $eventData: $e');
    }
  }

  /// O(props count) - Check if two components are semantically equal
  bool _componentsAreEqual(
      DCFComponentNode oldComponent, DCFComponentNode newComponent) {
    if (oldComponent.runtimeType != newComponent.runtimeType) {
      return false;
    }

    if (oldComponent.key != newComponent.key) {
      return false;
    }

    if (oldComponent is StatelessComponent &&
        newComponent is StatelessComponent) {
      // MORE STRICT: Only reuse if they're actually equal AND same instanceId
      return oldComponent == newComponent &&
          oldComponent.instanceId == newComponent.instanceId;
    }

    if (oldComponent is StatefulComponent &&
        newComponent is StatefulComponent) {
      return identical(oldComponent, newComponent);
    }

    return false;
  }

  /// O(1) - Schedule a component update with priority handling
  void _scheduleComponentUpdate(StatefulComponent component) {
    EngineDebugLogger.logUpdate(component, 'State change triggered update');

    // O(1) - Check for custom state change handler
    final customHandler = VDomExtensionRegistry.instance
        .getStateChangeHandler(component.runtimeType);
    if (customHandler != null) {
      EngineDebugLogger.log('CUSTOM_STATE_HANDLER',
          'Using custom state change handler for ${component.runtimeType}');

      final context = VDomStateChangeContext(
        scheduleUpdate: () => _scheduleComponentUpdateInternal(component),
        skipUpdate: () => EngineDebugLogger.log(
            'STATE_CHANGE_SKIP', 'Custom handler skipped update'),
        partialUpdate: (node) => _partialUpdateNode(node),
      );

      if (customHandler.shouldHandle(component, null)) {
        customHandler.handleStateChange(component, null, null, context);
        return;
      }
    }

    _scheduleComponentUpdateInternal(component);
  }

  /// O(1) - Internal method for scheduling component updates with priority
  void _scheduleComponentUpdateInternal(StatefulComponent component) {
    EngineDebugLogger.log('SCHEDULE_UPDATE',
        'Scheduling priority-based update for component: ${component.instanceId}');

    // O(1) - Verify component is still registered
    if (!_statefulComponents.containsKey(component.instanceId)) {
      EngineDebugLogger.log('COMPONENT_REREGISTER',
          'Re-registering untracked component: ${component.instanceId}');
      registerComponent(component);
    }

    // O(1) - Calculate priority and add to update queue
    final priority = PriorityUtils.getComponentPriority(component);
    _componentPriorities[component.instanceId] = priority;
    final wasEmpty = _pendingUpdates.isEmpty;
    _pendingUpdates.add(component.instanceId);

    EngineDebugLogger.log(
        'UPDATE_QUEUE', 'Added component to priority-based update queue',
        extra: {
          'ComponentId': component.instanceId,
          'Priority': priority.name,
          'QueueSize': _pendingUpdates.length,
          'WasEmpty': wasEmpty
        });

    // O(1) - Schedule update with priority-based timing
    if (!_isUpdateScheduled) {
      _isUpdateScheduled = true;
      EngineDebugLogger.log(
          'BATCH_SCHEDULE', 'Scheduling priority-based batch update');

      final delay = Duration(milliseconds: priority.delayMs);
      _updateTimer?.cancel();
      _updateTimer = Timer(delay, _processPendingUpdates);
    } else {
      // O(1) - Check if we should interrupt current scheduling for higher priority
      final currentHighestPriority = PriorityUtils.getHighestPriority(
          _componentPriorities.values.toList());
      if (PriorityUtils.shouldInterrupt(priority, currentHighestPriority)) {
        EngineDebugLogger.log(
            'BATCH_INTERRUPT', 'Interrupting for higher priority update');
        _updateTimer?.cancel();
        final newDelay = Duration(milliseconds: priority.delayMs);
        _updateTimer = Timer(newDelay, _processPendingUpdates);
      }
    }
  }

  /// O(1) - Partial update for specific node (used by extensions)
  void _partialUpdateNode(DCFComponentNode node) {
    EngineDebugLogger.log('PARTIAL_UPDATE', 'Performing partial update',
        component: node.runtimeType.toString());

    if (node.effectiveNativeViewId != null) {
      EngineDebugLogger.log('PARTIAL_UPDATE_NATIVE',
          'Triggering native update for view: ${node.effectiveNativeViewId}');
    }
  }

  /// O(n log n) - Process all pending component updates in priority order
  Future<void> _processPendingUpdates() async {
    EngineDebugLogger.log(
        'BATCH_START', 'Starting priority-based batch update processing',
        extra: {
          'PendingCount': _pendingUpdates.length,
          'BatchInProgress': _batchUpdateInProgress
        });

    if (_batchUpdateInProgress) {
      EngineDebugLogger.log(
          'BATCH_SKIP', 'Batch already in progress, skipping');
      return;
    }

    _batchUpdateInProgress = true;
    _updateTimer?.cancel();

    try {
      if (_pendingUpdates.isEmpty) {
        EngineDebugLogger.log('BATCH_EMPTY', 'No pending updates to process');
        _isUpdateScheduled = false;
        _batchUpdateInProgress = false;
        return;
      }

      final updateCount = _pendingUpdates.length;
      final startTime = DateTime.now();

      // Decide whether to use concurrent processing
      if (_concurrentEnabled && updateCount >= _concurrentThreshold) {
        await _processPendingUpdatesConcurrently();
      } else {
        await _processPendingUpdatesSerially();
      }

      // Track performance
      final processingTime = DateTime.now().difference(startTime);
      _updatePerformanceStats(
          updateCount >= _concurrentThreshold, processingTime);

      // O(1) - Check if new updates were scheduled during processing
      if (_pendingUpdates.isNotEmpty) {
        EngineDebugLogger.log('BATCH_NEW_UPDATES',
            'New updates scheduled during batch, processing in next cycle',
            extra: {'NewUpdatesCount': _pendingUpdates.length});
        _isUpdateScheduled = false;

        // O(1) - Schedule next batch with highest priority delay
        final nextHighestPriority = PriorityUtils.getHighestPriority(
            _componentPriorities.values.toList());
        final delay = Duration(milliseconds: nextHighestPriority.delayMs);
        _updateTimer = Timer(delay, _processPendingUpdates);
        _isUpdateScheduled = true;
      } else {
        EngineDebugLogger.log('BATCH_COMPLETE',
            'Priority-based batch processing completed, no new updates');
        _isUpdateScheduled = false;
      }
    } finally {
      _batchUpdateInProgress = false;
    }
  }

  /// Process updates using concurrent processing
  Future<void> _processPendingUpdatesConcurrently() async {
    EngineDebugLogger.log(
        'BATCH_CONCURRENT', 'Processing updates concurrently');

    // O(n log n) - Sort updates by priority
    final sortedUpdates = PriorityUtils.sortByPriority(
        _pendingUpdates.toList(), _componentPriorities);

    _pendingUpdates.clear(); // O(n)
    _componentPriorities.clear(); // O(n)

    EngineDebugLogger.log('BATCH_PRIORITY_SORTED',
        'Sorted ${sortedUpdates.length} updates by priority');

    // O(1) - Start batch update in native layer
    EngineDebugLogger.logBridge('START_BATCH', 'root');
    await _nativeBridge.startBatchUpdate();

    try {
      // Process updates in parallel batches
      final batchSize =
          (_maxWorkers * 2); // Process more than workers to keep them busy
      for (int i = 0; i < sortedUpdates.length; i += batchSize) {
        final batchEnd = (i + batchSize < sortedUpdates.length)
            ? i + batchSize
            : sortedUpdates.length;
        final batch = sortedUpdates.sublist(i, batchEnd);

        // Process batch concurrently
        final futures = <Future>[];
        for (final componentId in batch) {
          futures.add(_updateComponentById(componentId));
        }

        // Wait for all in batch to complete
        await Future.wait(futures);
      }

      // O(1) - Commit all batched updates at once
      EngineDebugLogger.logBridge('COMMIT_BATCH', 'root');
      await _nativeBridge.commitBatchUpdate();
      EngineDebugLogger.log('BATCH_COMMIT_SUCCESS',
          'Successfully committed concurrent batch updates');

      _performanceStats['totalConcurrentUpdates'] =
          (_performanceStats['totalConcurrentUpdates'] as int) +
              sortedUpdates.length;
    } catch (e) {
      // O(1) - Cancel batch if there's an error
      EngineDebugLogger.logBridge('CANCEL_BATCH', 'root',
          data: {'Error': e.toString()});
      await _nativeBridge.cancelBatchUpdate();
      EngineDebugLogger.log(
          'BATCH_ERROR', 'Concurrent batch update failed, cancelled',
          extra: {'Error': e.toString()});
      rethrow;
    }
  }

  /// Process updates serially (original behavior)
  Future<void> _processPendingUpdatesSerially() async {
    EngineDebugLogger.log('BATCH_SERIAL', 'Processing updates serially');

    // O(n log n) - Sort updates by priority
    final sortedUpdates = PriorityUtils.sortByPriority(
        _pendingUpdates.toList(), _componentPriorities);

    _pendingUpdates.clear(); // O(n)
    _componentPriorities.clear(); // O(n)

    EngineDebugLogger.log('BATCH_PRIORITY_SORTED',
        'Sorted ${sortedUpdates.length} updates by priority');

    // O(1) - Start batch update in native layer
    EngineDebugLogger.logBridge('START_BATCH', 'root');
    await _nativeBridge.startBatchUpdate();

    try {
      // O(n * m) where n = updates, m = average update complexity
      for (final componentId in sortedUpdates) {
        EngineDebugLogger.log(
            'BATCH_PROCESS_COMPONENT', 'Processing update for: $componentId');
        await _updateComponentById(componentId);
      }

      // O(1) - Commit all batched updates at once
      EngineDebugLogger.logBridge('COMMIT_BATCH', 'root');
      await _nativeBridge.commitBatchUpdate();
      EngineDebugLogger.log('BATCH_COMMIT_SUCCESS',
          'Successfully committed serial batch updates');

      _performanceStats['totalSerialUpdates'] =
          (_performanceStats['totalSerialUpdates'] as int) +
              sortedUpdates.length;
    } catch (e) {
      // O(1) - Cancel batch if there's an error
      EngineDebugLogger.logBridge('CANCEL_BATCH', 'root',
          data: {'Error': e.toString()});
      await _nativeBridge.cancelBatchUpdate();
      EngineDebugLogger.log(
          'BATCH_ERROR', 'Serial batch update failed, cancelled',
          extra: {'Error': e.toString()});
      rethrow;
    }
  }

  /// O(m) where m = component tree depth - Update a component by its ID
  Future<void> _updateComponentById(String componentId) async {
    EngineDebugLogger.log('COMPONENT_UPDATE_START',
        'Starting update for component: $componentId');

    // O(1) - Component lookup
    final component =
        _statefulComponents[componentId] ?? _statelessComponents[componentId];
    if (component == null) {
      EngineDebugLogger.log(
          'COMPONENT_UPDATE_NOT_FOUND', 'Component not found: $componentId');
      return;
    }

    try {
      // O(1) - Call lifecycle interceptor before update
      final lifecycleInterceptor = VDomExtensionRegistry.instance
          .getLifecycleInterceptor(component.runtimeType);
      if (lifecycleInterceptor != null) {
        EngineDebugLogger.log(
            'LIFECYCLE_INTERCEPTOR', 'Calling beforeUpdate interceptor');
        final context = VDomLifecycleContext(
          scheduleUpdate: () =>
              _scheduleComponentUpdateInternal(component as StatefulComponent),
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isUpdating': true},
        );
        lifecycleInterceptor.beforeUpdate(component, context);
      }

      // O(1) - Perform component-specific update preparation
      if (component is StatefulComponent) {
        EngineDebugLogger.log(
            'COMPONENT_PREPARE', 'Preparing StatefulComponent for render');
        component.prepareForRender();
      }

      // O(1) - Store the previous rendered node before re-rendering
      final oldRenderedNode = component.renderedNode;
      EngineDebugLogger.log('COMPONENT_OLD_NODE', 'Stored old rendered node',
          extra: {'HasOldNode': oldRenderedNode != null});

      if (oldRenderedNode != null) {
        _previousRenderedNodes[componentId] = oldRenderedNode;
      }

      // O(component render complexity) - Force re-render by clearing cached rendered node
      component.renderedNode = null;
      final newRenderedNode = component.renderedNode;

      if (newRenderedNode == null) {
        EngineDebugLogger.log('COMPONENT_UPDATE_NULL',
            'Component rendered null, skipping update');
        return;
      }

      EngineDebugLogger.log('COMPONENT_NEW_NODE', 'Generated new rendered node',
          component: newRenderedNode.runtimeType.toString());

      // O(1) - Set parent relationship for the new rendered node
      newRenderedNode.parent = component;

      // O(tree depth) - Reconcile trees to apply minimal changes
      final previousRenderedNode = _previousRenderedNodes[componentId];
      if (previousRenderedNode != null) {
        EngineDebugLogger.log(
            'RECONCILE_START', 'Starting reconciliation with previous node');

        final parentViewId = _findParentViewId(component); // O(depth)

        if (previousRenderedNode.effectiveNativeViewId == null ||
            parentViewId == null) {
          EngineDebugLogger.log('RECONCILE_FALLBACK',
              'Using fallback reconciliation due to missing IDs');
          await _reconcile(
              previousRenderedNode, newRenderedNode); // O(tree size)

          if (previousRenderedNode.effectiveNativeViewId != null) {
            component.contentViewId =
                previousRenderedNode.effectiveNativeViewId;
          }
        } else {
          EngineDebugLogger.log(
              'RECONCILE_NORMAL', 'Performing normal reconciliation');
          await _reconcile(
              previousRenderedNode, newRenderedNode); // O(tree size)
          component.contentViewId = previousRenderedNode.effectiveNativeViewId;
        }

        _previousRenderedNodes.remove(componentId); // O(1)
        EngineDebugLogger.log(
            'RECONCILE_CLEANUP', 'Cleaned up previous rendered node reference');
      } else {
        EngineDebugLogger.log('RENDER_FROM_SCRATCH',
            'No previous rendering, creating from scratch');
        final parentViewId = _findParentViewId(component); // O(depth)
        if (parentViewId != null) {
          final newViewId = await renderToNative(newRenderedNode,
              parentViewId: parentViewId); // O(tree size)
          if (newViewId != null) {
            component.contentViewId = newViewId;
            EngineDebugLogger.log('RENDER_NEW_SUCCESS',
                'Successfully rendered new component view: $newViewId');
          }
        } else {
          EngineDebugLogger.log(
              'RENDER_NO_PARENT', 'No parent view ID found for rendering');
        }
      }

      // O(hooks count) - Run lifecycle methods with phased effects
      if (component is StatefulComponent) {
        EngineDebugLogger.log(
            'LIFECYCLE_DID_UPDATE', 'Calling componentDidUpdate');
        component.componentDidUpdate({});

        EngineDebugLogger.log(
            'LIFECYCLE_EFFECTS_IMMEDIATE', 'Running immediate effects');
        component.runEffectsAfterRender();

        if (_isTreeComplete) {
          EngineDebugLogger.log(
              'LIFECYCLE_EFFECTS_LAYOUT', 'Running layout effects');
          component.runLayoutEffects();
        }

        if (_isTreeComplete) {
          EngineDebugLogger.log(
              'LIFECYCLE_EFFECTS_INSERTION', 'Running insertion effects');
          component.runInsertionEffects();
        }
      }

      // O(1) - Call lifecycle interceptor after update
      if (lifecycleInterceptor != null) {
        EngineDebugLogger.log(
            'LIFECYCLE_INTERCEPTOR', 'Calling afterUpdate interceptor');
        final context = VDomLifecycleContext(
          scheduleUpdate: () =>
              _scheduleComponentUpdateInternal(component as StatefulComponent),
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isUpdating': false},
        );
        lifecycleInterceptor.afterUpdate(component, context);
      }

      EngineDebugLogger.log('COMPONENT_UPDATE_SUCCESS',
          'Component update completed successfully: $componentId');
    } catch (e) {
      EngineDebugLogger.log('COMPONENT_UPDATE_ERROR', 'Component update failed',
          extra: {'ComponentId': componentId, 'Error': e.toString()});
    }
  }

  /// O(tree depth + children count) - Enhanced render to native with phased effects
  Future<String?> renderToNative(DCFComponentNode node,
      {String? parentViewId, int? index}) async {
    await isReady;

    EngineDebugLogger.logRender('START', node,
        viewId: node.effectiveNativeViewId, parentId: parentViewId);

    try {
      // O(children count) - Handle Fragment nodes
      if (node is DCFFragment) {
        EngineDebugLogger.log('RENDER_FRAGMENT', 'Rendering fragment node');

        // O(1) - Call lifecycle interceptor before mount
        final lifecycleInterceptor = VDomExtensionRegistry.instance
            .getLifecycleInterceptor(node.runtimeType);
        if (lifecycleInterceptor != null) {
          final context = VDomLifecycleContext(
            scheduleUpdate: () {},
            forceUpdate: (node) => _partialUpdateNode(node),
            vdomState: {'isMounting': true},
          );
          lifecycleInterceptor.beforeMount(node, context);
        }

        // O(1) - Mount the fragment
        if (!node.isMounted) {
          EngineDebugLogger.logMount(node, context: 'Fragment mounting');
          node.mount(node.parent);
        }

        // O(1) - Check if this fragment is a portal placeholder
        if (node.metadata != null &&
            node.metadata!['isPortalPlaceholder'] == true) {
          EngineDebugLogger.log(
              'PORTAL_PLACEHOLDER', 'Rendering portal placeholder fragment');
          final targetId = node.metadata!['targetId'] as String?;
          final portalId = node.metadata!['portalId'] as String?;

          if (targetId != null && portalId != null) {
            EngineDebugLogger.log(
                'PORTAL_PLACEHOLDER_DETAILS', 'Portal placeholder details',
                extra: {'TargetId': targetId, 'PortalId': portalId});
            return null; // Portal placeholders have no native view
          }
        }

        // O(1) - Check if this fragment is a portal target
        if (node.metadata != null && node.metadata!['isPortalTarget'] == true) {
          final targetId = node.metadata!['targetId'] as String?;
          EngineDebugLogger.log(
              'PORTAL_TARGET', 'Rendering portal target fragment',
              extra: {'TargetId': targetId});
        }

        // O(children count * render complexity) - Regular fragment - render children directly to parent
        int childIndex = index ?? 0;
        final childIds = <String>[];

        EngineDebugLogger.log('FRAGMENT_CHILDREN',
            'Rendering ${node.children.length} fragment children');
        for (final child in node.children) {
          final childId = await renderToNative(child,
              parentViewId: parentViewId, index: childIndex++);

          if (childId != null && childId.isNotEmpty) {
            childIds.add(childId);
          }
        }

        // O(1) - Store child IDs for cleanup later
        node.childViewIds = childIds;
        EngineDebugLogger.log(
            'FRAGMENT_CHILDREN_COMPLETE', 'Fragment children rendered',
            extra: {'ChildCount': childIds.length, 'ChildIds': childIds});

        // O(1) - Call lifecycle interceptor after mount
        if (lifecycleInterceptor != null) {
          final context = VDomLifecycleContext(
            scheduleUpdate: () {},
            forceUpdate: (node) => _partialUpdateNode(node),
            vdomState: {'isMounting': false},
          );
          lifecycleInterceptor.afterMount(node, context);
        }

        return null; // Fragments don't have their own native view ID
      }

      // O(component render complexity + children render complexity) - Handle Component nodes with enhanced phased effects
      if (node is StatefulComponent || node is StatelessComponent) {
        EngineDebugLogger.log('RENDER_COMPONENT', 'Rendering component node',
            component: node.runtimeType.toString());

        try {
          // O(1) - Call lifecycle interceptor before mount
          final lifecycleInterceptor = VDomExtensionRegistry.instance
              .getLifecycleInterceptor(node.runtimeType);
          if (lifecycleInterceptor != null) {
            final context = VDomLifecycleContext(
              scheduleUpdate: () =>
                  _scheduleComponentUpdateInternal(node as StatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': true},
            );
            lifecycleInterceptor.beforeMount(node, context);
          }

          // O(1) - Register the component
          registerComponent(node);

          // O(component render complexity) - Get the rendered content
          final renderedNode = node.renderedNode;
          if (renderedNode == null) {
            EngineDebugLogger.logRender('ERROR', node,
                error: 'Component rendered null');
            throw Exception('Component rendered null');
          }

          EngineDebugLogger.log(
              'COMPONENT_RENDERED_NODE', 'Component rendered content',
              extra: {'RenderedType': renderedNode.runtimeType.toString()});

          // O(1) - Set parent relationship
          renderedNode.parent = node;

          // O(rendered tree complexity) - Render the content
          final viewId = await renderToNative(renderedNode,
              parentViewId: parentViewId, index: index);

          // O(1) - Store the view ID
          node.contentViewId = viewId;
          EngineDebugLogger.log(
              'COMPONENT_VIEW_ID', 'Component view ID assigned',
              extra: {'ViewId': viewId});

          // O(hooks count) - Enhanced: Mount component with phased effects
          if (node is StatefulComponent && !node.isMounted) {
            EngineDebugLogger.log('LIFECYCLE_DID_MOUNT',
                'Calling componentDidMount for StatefulComponent');
            node.componentDidMount();

            EngineDebugLogger.log(
                'LIFECYCLE_EFFECTS_IMMEDIATE', 'Running immediate effects');
            node.runEffectsAfterRender();

            // O(1) - Queue for later effect phases
            _componentsWaitingForLayout.add(node.instanceId);
            _componentsWaitingForInsertion.add(node.instanceId);

            _scheduleLayoutEffects(node);
          } else if (node is StatelessComponent && !node.isMounted) {
            EngineDebugLogger.log('LIFECYCLE_DID_MOUNT',
                'Calling componentDidMount for StatelessComponent');
            node.componentDidMount();
          }

          // O(1) - Call lifecycle interceptor after mount
          if (lifecycleInterceptor != null) {
            final context = VDomLifecycleContext(
              scheduleUpdate: () =>
                  _scheduleComponentUpdateInternal(node as StatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': false},
            );
            lifecycleInterceptor.afterMount(node, context);
          }

          EngineDebugLogger.logRender('SUCCESS', node, viewId: viewId);
          return viewId;
        } catch (error, stackTrace) {
          EngineDebugLogger.logRender('ERROR', node, error: error.toString());

          // O(tree depth) - Try to find nearest error boundary
          final errorBoundary = _findNearestErrorBoundary(node);
          if (errorBoundary != null) {
            EngineDebugLogger.log('ERROR_BOUNDARY_HANDLE',
                'Error handled by boundary: ${errorBoundary.instanceId}');
            errorBoundary.handleError(error, stackTrace);
            return null; // Error handled by boundary
          }

          EngineDebugLogger.log('ERROR_BOUNDARY_NOT_FOUND',
              'No error boundary found, propagating error');
          rethrow;
        }
      }
      // O(element render complexity + children render complexity) - Handle Element nodes
      else if (node is DCFElement) {
        EngineDebugLogger.log('RENDER_ELEMENT', 'Rendering element node',
            extra: {'ElementType': node.type});
        return await _renderElementToNative(node,
            parentViewId: parentViewId, index: index);
      }
      // O(1) - Handle EmptyVDomNode
      else if (node is EmptyVDomNode) {
        EngineDebugLogger.log('RENDER_EMPTY', 'Rendering empty node');
        return null; // Empty nodes don't create native views
      }

      EngineDebugLogger.logRender('UNKNOWN', node, error: 'Unknown node type');
      return null;
    } catch (e) {
      EngineDebugLogger.logRender('ERROR', node, error: e.toString());
      return null;
    }
  }

  /// O(1) - Schedule layout effects to run after children are mounted
  void _scheduleLayoutEffects(StatefulComponent component) {
    Future.microtask(() {
      if (_componentsWaitingForLayout.contains(component.instanceId)) {
        EngineDebugLogger.log('LIFECYCLE_EFFECTS_LAYOUT',
            'Running layout effects for component: ${component.instanceId}');
        component.runLayoutEffects();
        _componentsWaitingForLayout.remove(component.instanceId);
      }
    });
  }

  /// O(1) - Set root component and trigger tree completion
  void setRootComponent(DCFComponentNode component) {
    rootComponent = component;
    EngineDebugLogger.log(
        'ROOT_COMPONENT_SET', 'Root component set: ${component.runtimeType}');

    Future.microtask(() {
      _markTreeComplete();
    });
  }

  /// O(component count) - Mark the component tree as complete and run insertion effects
  void _markTreeComplete() {
    if (_isTreeComplete) return;

    _isTreeComplete = true;
    EngineDebugLogger.log('TREE_COMPLETE', 'Component tree marked as complete');

    // O(waiting components count) - Run insertion effects for all waiting components
    for (final componentId in _componentsWaitingForInsertion) {
      final component = _statefulComponents[componentId];
      if (component != null) {
        EngineDebugLogger.log('LIFECYCLE_EFFECTS_INSERTION',
            'Running insertion effects for component: $componentId');
        component.runInsertionEffects();
      }
    }
    _componentsWaitingForInsertion.clear();
  }

  /// O(1) - Get debug information about effect phases
  Map<String, dynamic> getEffectPhaseDebugInfo() {
    return {
      'isTreeComplete': _isTreeComplete,
      'componentsWaitingForLayout': _componentsWaitingForLayout.length,
      'componentsWaitingForInsertion': _componentsWaitingForInsertion.length,
      'layoutQueue': _componentsWaitingForLayout.toList(),
      'insertionQueue': _componentsWaitingForInsertion.toList(),
    };
  }

  /// O(children count + event types count) - Render an element to native UI
  Future<String?> _renderElementToNative(DCFElement element,
      {String? parentViewId, int? index}) async {
    EngineDebugLogger.log('ELEMENT_RENDER_START', 'Starting element render',
        extra: {
          'ElementType': element.type,
          'ParentViewId': parentViewId,
          'Index': index
        });

    // O(1) - Use existing view ID or generate a new one
    final viewId = element.nativeViewId ?? _generateViewId();

    // O(1) - Store map from view ID to node
    _nodesByViewId[viewId] = element;
    element.nativeViewId = viewId;
    EngineDebugLogger.log('ELEMENT_VIEW_MAPPING', 'Mapped element to view ID',
        extra: {'ViewId': viewId, 'ElementType': element.type});

    // O(1) - Create the view
    EngineDebugLogger.logBridge('CREATE_VIEW', viewId, data: {
      'ElementType': element.type,
      'Props': element.props.keys.toList()
    });
    final success =
        await _nativeBridge.createView(viewId, element.type, element.props);
    if (!success) {
      EngineDebugLogger.log(
          'ELEMENT_CREATE_FAILED', 'Failed to create native view',
          extra: {'ViewId': viewId, 'ElementType': element.type});
      return null;
    }

    // O(1) - If parent is specified, attach to parent
    if (parentViewId != null) {
      EngineDebugLogger.logBridge('ATTACH_VIEW', viewId,
          data: {'ParentViewId': parentViewId, 'Index': index ?? 0});
      await _nativeBridge.attachView(viewId, parentViewId, index ?? 0);
    }

    // O(event types count) - Register event listeners
    final eventTypes = element.eventTypes;
    if (eventTypes.isNotEmpty) {
      EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', viewId,
          data: {'EventTypes': eventTypes});
      await _nativeBridge.addEventListeners(viewId, eventTypes);
    }

    // O(children count * child render complexity) - Render children
    final childIds = <String>[];
    EngineDebugLogger.log('ELEMENT_CHILDREN_START',
        'Rendering ${element.children.length} children');

    for (var i = 0; i < element.children.length; i++) {
      final childId = await renderToNative(element.children[i],
          parentViewId: viewId, index: i);
      if (childId != null && childId.isNotEmpty) {
        childIds.add(childId);
      }
    }

    // O(children count) - Set children order
    if (childIds.isNotEmpty) {
      EngineDebugLogger.logBridge('SET_CHILDREN', viewId,
          data: {'ChildIds': childIds});
      await _nativeBridge.setChildren(viewId, childIds);
    }

    EngineDebugLogger.log('ELEMENT_RENDER_SUCCESS', 'Element render completed',
        extra: {'ViewId': viewId, 'ChildCount': childIds.length});
    return viewId;
  }

  /// O(tree size) - Reconcile two nodes by efficiently updating only what changed
  Future<void> _reconcile(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    EngineDebugLogger.logReconcile('START', oldNode, newNode,
        reason: 'Beginning reconciliation');

    // O(1) - Check for custom reconciliation handler first
    final customHandler = VDomExtensionRegistry.instance
        .getReconciliationHandler(newNode.runtimeType);
    if (customHandler != null && customHandler.shouldHandle(oldNode, newNode)) {
      EngineDebugLogger.log(
          'CUSTOM_RECONCILE', 'Using custom reconciliation handler',
          component: newNode.runtimeType.toString());

      final context = VDomReconciliationContext(
        defaultReconcile: (old, new_) => _reconcile(old, new_),
        replaceNode: (old, new_) => _replaceNode(old, new_),
        mountNode: (node) => node.mount(node.parent),
        unmountNode: (node) => node.unmount(),
      );

      await customHandler.reconcile(oldNode, newNode, context);
      EngineDebugLogger.logReconcile('CUSTOM_COMPLETE', oldNode, newNode,
          reason: 'Custom reconciliation completed');
      return;
    }

    // O(1) - Transfer important parent reference first
    newNode.parent = oldNode.parent;

    // O(1) - If the node types are completely different, replace the node entirely
    if (oldNode.runtimeType != newNode.runtimeType) {
      EngineDebugLogger.logReconcile('REPLACE_TYPE', oldNode, newNode,
          reason: 'Different node types');
      await _replaceNode(oldNode, newNode);
      return;
    }

    // O(1) - Critical hot reload fix: If the keys are different, replace the component entirely
    if (oldNode.key != newNode.key) {
      EngineDebugLogger.logReconcile('REPLACE_KEY', oldNode, newNode,
          reason: 'Different keys - hot reload fix');
      await _replaceNode(oldNode, newNode);
      return;
    }

    // O(element reconciliation complexity) - Handle different node types
    if (oldNode is DCFElement && newNode is DCFElement) {
      if (oldNode.type != newNode.type) {
        EngineDebugLogger.logReconcile('REPLACE_ELEMENT_TYPE', oldNode, newNode,
            reason: 'Different element types');
        await _replaceNode(oldNode, newNode);
      } else {
        EngineDebugLogger.logReconcile('UPDATE_ELEMENT', oldNode, newNode,
            reason: 'Same element type - updating props and children');
        await _reconcileElement(oldNode, newNode);
      }
    }
    // O(component reconciliation complexity) - Handle component nodes
    else if (oldNode is StatefulComponent && newNode is StatefulComponent) {
      // ✅ ADD EQUALITY CHECK BEFORE RECONCILIATION
      if (_componentsAreEqual(oldNode, newNode)) {
        EngineDebugLogger.logReconcile('SKIP_STATEFUL_EQUAL', oldNode, newNode,
            reason: 'StatefulComponents are equal - skipping reconciliation');

        // Transfer essential properties without triggering re-render
        newNode.nativeViewId = oldNode.nativeViewId;
        newNode.contentViewId = oldNode.contentViewId;
        newNode.parent = oldNode.parent;
        newNode.renderedNode =
            oldNode.renderedNode; // ✅ Keep existing rendered content

        // Update tracking but preserve the component state
        _statefulComponents[newNode.instanceId] = newNode;
        newNode.scheduleUpdate = () => _scheduleComponentUpdate(newNode);

        return; // ✅ EARLY EXIT - No reconciliation needed
      }

      EngineDebugLogger.logReconcile('UPDATE_STATEFUL', oldNode, newNode,
          reason: 'Reconciling StatefulComponent');

      // O(1) - Transfer important properties between nodes
      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      // O(1) - Update component tracking
      _statefulComponents[newNode.instanceId] = newNode;
      newNode.scheduleUpdate = () => _scheduleComponentUpdate(newNode);

      // O(1) - Register the new component instance
      registerComponent(newNode);

      // O(rendered tree size) - Handle reconciliation of the rendered trees
      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;

      await _reconcile(oldRenderedNode, newRenderedNode);
    }
    // Handle stateless components
    else if (oldNode is StatelessComponent && newNode is StatelessComponent) {
      // print("🔍 StatelessComponent reconciliation:");
      // print("  oldNode: ${oldNode.runtimeType}");
      // print("  newNode: ${newNode.runtimeType}");

      // ✅ Use _componentsAreEqual FIRST before any transfers
      if (_componentsAreEqual(oldNode, newNode)) {
        // print("  🟢 SKIPPING reconciliation - components are equal");
        EngineDebugLogger.logReconcile('SKIP_STATELESS_EQUAL', oldNode, newNode,
            reason: 'StatelessComponents are equal - skipping reconciliation');

        // Transfer essential properties without triggering re-render
        newNode.nativeViewId = oldNode.nativeViewId;
        newNode.contentViewId = oldNode.contentViewId;
        newNode.parent = oldNode.parent;
        newNode.renderedNode =
            oldNode.renderedNode; // ✅ Reuse existing rendered content

        // Update tracking but preserve the component state
        _statelessComponents[newNode.instanceId] = newNode;

        return; // ✅ EARLY EXIT - No reconciliation needed
      }

      // print("  🔴 CONTINUING reconciliation - components are different");
      EngineDebugLogger.logReconcile('UPDATE_STATELESS', oldNode, newNode,
          reason: 'StatelessComponent needs reconciliation - props changed');

      // Transfer IDs for reconciliation
      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      // Update component tracking
      _statelessComponents[newNode.instanceId] = newNode;

      // Handle reconciliation of the rendered trees
      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;
      await _reconcile(oldRenderedNode, newRenderedNode);
    }

    // O(fragment children reconciliation) - Handle Fragment nodes
    else if (oldNode is DCFFragment && newNode is DCFFragment) {
      EngineDebugLogger.logReconcile('UPDATE_FRAGMENT', oldNode, newNode,
          reason: 'Reconciling Fragment');

      // O(1) - Transfer children relationships
      newNode.parent = oldNode.parent;
      newNode.childViewIds = oldNode.childViewIds;

      // O(children reconciliation complexity) - Reconcile fragment children directly
      if (oldNode.children.isNotEmpty || newNode.children.isNotEmpty) {
        final parentViewId = _findParentViewId(oldNode); // O(tree depth)
        if (parentViewId != null) {
          EngineDebugLogger.log(
              'FRAGMENT_CHILDREN_RECONCILE', 'Reconciling fragment children',
              extra: {
                'ParentViewId': parentViewId,
                'OldChildCount': oldNode.children.length,
                'NewChildCount': newNode.children.length
              });
          await _reconcileFragmentChildren(
              parentViewId, oldNode.children, newNode.children);
        }
      }
    }
    // O(1) - Handle empty nodes
    else if (oldNode is EmptyVDomNode && newNode is EmptyVDomNode) {
      EngineDebugLogger.logReconcile('SKIP_EMPTY', oldNode, newNode,
          reason: 'Both nodes are empty');
      return;
    }

    EngineDebugLogger.logReconcile('COMPLETE', oldNode, newNode,
        reason: 'Reconciliation completed successfully');
  }

  /// O(tree depth + disposal complexity) - Replace a node entirely
  Future<void> _replaceNode(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    EngineDebugLogger.log('REPLACE_NODE_START', 'Starting node replacement',
        extra: {
          'OldNodeType': oldNode.runtimeType.toString(),
          'NewNodeType': newNode.runtimeType.toString(),
          'OldViewId': oldNode.effectiveNativeViewId
        });

    // O(1) - Call lifecycle interceptor before unmount
    final lifecycleInterceptor = VDomExtensionRegistry.instance
        .getLifecycleInterceptor(oldNode.runtimeType);
    if (lifecycleInterceptor != null) {
      final context = VDomLifecycleContext(
        scheduleUpdate: () {},
        forceUpdate: (node) => _partialUpdateNode(node),
        vdomState: {'isUnmounting': true},
      );
      lifecycleInterceptor.beforeUnmount(oldNode, context);
    }

    // O(disposal complexity) - Properly dispose of old component instances
    await _disposeOldComponent(oldNode);

    // O(1) - Can't replace if the old node has no view ID
    if (oldNode.effectiveNativeViewId == null) {
      EngineDebugLogger.log(
          'REPLACE_NODE_NO_VIEW_ID', 'Old node has no view ID, cannot replace');
      return;
    }

    // O(tree depth) - Find parent info for placing the new node
    final parentViewId = _findParentViewId(oldNode);
    if (parentViewId == null) {
      EngineDebugLogger.log(
          'REPLACE_NODE_NO_PARENT', 'No parent view ID found');
      return;
    }

    // O(siblings count) - Find index of node in parent
    final index = _findNodeIndexInParent(oldNode);
    EngineDebugLogger.log('REPLACE_NODE_POSITION', 'Found replacement position',
        extra: {'ParentViewId': parentViewId, 'Index': index});

    // O(1) - Temporarily exit batch mode to ensure atomic delete+create
    final wasBatchMode = _batchUpdateInProgress;
    if (wasBatchMode) {
      EngineDebugLogger.log('REPLACE_BATCH_PAUSE',
          'Temporarily pausing batch mode for atomic replacement');
      await _nativeBridge.commitBatchUpdate();
      _batchUpdateInProgress = false;
    }

    try {
      // O(1) - Store the old view ID and event types for reuse
      final oldViewId = oldNode.effectiveNativeViewId!;
      final oldEventTypes =
          (oldNode is DCFElement) ? oldNode.eventTypes : <String>[];
      final newEventTypes =
          (newNode is DCFElement) ? newNode.eventTypes : <String>[];

      EngineDebugLogger.log('REPLACE_EVENT_TYPES', 'Comparing event types',
          extra: {'OldEvents': oldEventTypes, 'NewEvents': newEventTypes});

      // O(tree render complexity) - Special case: component that renders a fragment
      if (newNode is StatefulComponent || newNode is StatelessComponent) {
        final renderedNode = newNode.renderedNode;
        if (renderedNode is DCFFragment) {
          EngineDebugLogger.log('REPLACE_COMPONENT_TO_FRAGMENT',
              'Replacing component with fragment renderer');
          EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
          await _nativeBridge.deleteView(oldViewId);
          _nodesByViewId.remove(oldViewId);

          await renderToNative(newNode,
              parentViewId: parentViewId, index: index);
          return;
        }
      }

      // O(1) - Reuse the same view ID to preserve native event listener connections
      newNode.nativeViewId = oldViewId;
      EngineDebugLogger.log(
          'REPLACE_REUSE_VIEW_ID', 'Reusing view ID for event preservation',
          extra: {'ViewId': oldViewId});

      // O(1) - Update the mapping to point to the new node immediately
      _nodesByViewId[oldViewId] = newNode;

      // O(event types count) - Only update event listeners if they changed
      final oldEventSet = Set<String>.from(oldEventTypes);
      final newEventSet = Set<String>.from(newEventTypes);

      if (oldEventSet.length != newEventSet.length ||
          !oldEventSet.containsAll(newEventSet)) {
        EngineDebugLogger.log(
            'REPLACE_UPDATE_EVENTS', 'Updating event listeners');

        // O(removed events count) - Remove old event listeners that are no longer needed
        final eventsToRemove = oldEventSet.difference(newEventSet);
        if (eventsToRemove.isNotEmpty) {
          EngineDebugLogger.logBridge('REMOVE_EVENT_LISTENERS', oldViewId,
              data: {'EventTypes': eventsToRemove.toList()});
          await _nativeBridge.removeEventListeners(
              oldViewId, eventsToRemove.toList());
        }

        // O(added events count) - Add new event listeners
        final eventsToAdd = newEventSet.difference(oldEventSet);
        if (eventsToAdd.isNotEmpty) {
          EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', oldViewId,
              data: {'EventTypes': eventsToAdd.toList()});
          await _nativeBridge.addEventListeners(
              oldViewId, eventsToAdd.toList());
        }
      }

      // O(1) - Delete the old view completely
      EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
      await _nativeBridge.deleteView(oldViewId);

      // O(tree render complexity) - Create the new view with the preserved view ID
      final newViewId = await renderToNative(newNode,
          parentViewId: parentViewId, index: index);

      if (newViewId != null && newViewId.isNotEmpty) {
        EngineDebugLogger.log(
            'REPLACE_NODE_SUCCESS', 'Node replacement completed successfully',
            extra: {'NewViewId': newViewId});
      } else {
        EngineDebugLogger.log('REPLACE_NODE_FAILED',
            'Node replacement failed - no view ID returned');
      }
    } finally {
      // O(1) - Resume batch mode if we were previously in batch mode
      if (wasBatchMode) {
        EngineDebugLogger.log('REPLACE_BATCH_RESUME', 'Resuming batch mode');
        await _nativeBridge.startBatchUpdate();
        _batchUpdateInProgress = true;
      }
    }

    // O(1) - Call lifecycle interceptor after unmount
    if (lifecycleInterceptor != null) {
      final context = VDomLifecycleContext(
        scheduleUpdate: () {},
        forceUpdate: (node) => _partialUpdateNode(node),
        vdomState: {'isUnmounting': false},
      );
      lifecycleInterceptor.afterUnmount(oldNode, context);
    }
  }

  /// O(tree size) - Dispose of old component instance and clean up its state
  Future<void> _disposeOldComponent(DCFComponentNode oldNode) async {
    EngineDebugLogger.logUnmount(oldNode, context: 'Disposing old component');

    try {
      // O(1) - Call lifecycle interceptor before unmount
      final lifecycleInterceptor = VDomExtensionRegistry.instance
          .getLifecycleInterceptor(oldNode.runtimeType);
      if (lifecycleInterceptor != null) {
        final context = VDomLifecycleContext(
          scheduleUpdate: () {},
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isDisposing': true},
        );
        lifecycleInterceptor.beforeUnmount(oldNode, context);
      }

      // O(hooks count) - Handle StatefulComponent disposal
      if (oldNode is StatefulComponent) {
        EngineDebugLogger.log('DISPOSE_STATEFUL', 'Disposing StatefulComponent',
            extra: {'InstanceId': oldNode.instanceId});

        // O(1) - Remove from component tracking first to prevent further updates
        _statefulComponents.remove(oldNode.instanceId);
        _pendingUpdates.remove(oldNode.instanceId);
        _previousRenderedNodes.remove(oldNode.instanceId);
        _componentPriorities.remove(oldNode.instanceId);

        // O(1) - Remove from effect queues
        _componentsWaitingForLayout.remove(oldNode.instanceId);
        _componentsWaitingForInsertion.remove(oldNode.instanceId);

        // O(hooks count) - Call lifecycle cleanup
        try {
          oldNode.componentWillUnmount();
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT',
              'Called componentWillUnmount for StatefulComponent');
        } catch (e) {
          EngineDebugLogger.log(
              'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
              extra: {'Error': e.toString()});
        }

        // O(rendered tree size) - Recursively dispose rendered content
        await _disposeOldComponent(oldNode.renderedNode);
      }
      // O(1) - Handle StatelessComponent disposal
      else if (oldNode is StatelessComponent) {
        EngineDebugLogger.log(
            'DISPOSE_STATELESS', 'Disposing StatelessComponent',
            extra: {'InstanceId': oldNode.instanceId});

        // O(1) - Remove from component tracking
        _statelessComponents.remove(oldNode.instanceId);

        // O(1) - Call lifecycle cleanup
        try {
          oldNode.componentWillUnmount();
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT',
              'Called componentWillUnmount for StatelessComponent');
        } catch (e) {
          EngineDebugLogger.log(
              'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
              extra: {'Error': e.toString()});
        }

        // O(rendered tree size) - Recursively dispose rendered content
        await _disposeOldComponent(oldNode.renderedNode);
      }
      // O(children count * disposal complexity) - Handle DCFElement disposal
      else if (oldNode is DCFElement) {
        EngineDebugLogger.log('DISPOSE_ELEMENT', 'Disposing DCFElement',
            extra: {
              'ElementType': oldNode.type,
              'ChildCount': oldNode.children.length
            });

        // Recursively dispose child components
        for (final child in oldNode.children) {
          await _disposeOldComponent(child);
        }
      }

      // O(1) - Remove from view tracking
      if (oldNode.effectiveNativeViewId != null) {
        _nodesByViewId.remove(oldNode.effectiveNativeViewId);
        EngineDebugLogger.log(
            'DISPOSE_VIEW_TRACKING', 'Removed from view tracking',
            extra: {'ViewId': oldNode.effectiveNativeViewId});
      }

      // O(1) - Call lifecycle interceptor after unmount
      if (lifecycleInterceptor != null) {
        final context = VDomLifecycleContext(
          scheduleUpdate: () {},
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isDisposing': false},
        );
        lifecycleInterceptor.afterUnmount(oldNode, context);
      }
    } catch (e) {
      EngineDebugLogger.log('DISPOSE_ERROR', 'Error during component disposal',
          extra: {
            'Error': e.toString(),
            'NodeType': oldNode.runtimeType.toString()
          });
    }
  }

  /// O(tree render complexity) - Create the root component for the application
  Future<void> createRoot(DCFComponentNode component) async {
    EngineDebugLogger.log('CREATE_ROOT_START', 'Creating root component',
        component: component.runtimeType.toString());

    // O(tree disposal complexity) - On hot restart, tear down old VDOM state
    if (rootComponent != null && rootComponent != component) {
      EngineDebugLogger.log('CREATE_ROOT_HOT_RESTART',
          'Hot restart detected. Tearing down old VDOM state.');

      await _disposeOldComponent(rootComponent!);

      // O(n) - Clear all VDOM tracking maps
      _statefulComponents.clear();
      _statelessComponents.clear();
      _nodesByViewId.clear();
      _previousRenderedNodes.clear();
      _pendingUpdates.clear();
      _componentPriorities.clear();
      _errorBoundaries.clear();

      // O(1) - Clear effect queues
      _componentsWaitingForLayout.clear();
      _componentsWaitingForInsertion.clear();
      _isTreeComplete = false;

      EngineDebugLogger.log(
          'VDOM_STATE_CLEARED', 'All VDOM tracking maps have been cleared.');
      EngineDebugLogger.reset();

      rootComponent = component;
      await renderToNative(component, parentViewId: "root");
      setRootComponent(component);

      EngineDebugLogger.log('CREATE_ROOT_COMPLETE',
          'Root component re-created successfully after hot restart.');
    } else {
      EngineDebugLogger.log(
          'CREATE_ROOT_FIRST', 'Creating first root component');
      rootComponent = component;

      final viewId = await renderToNative(component, parentViewId: "root");
      setRootComponent(component);

      EngineDebugLogger.log(
          'CREATE_ROOT_COMPLETE', 'Root component created successfully',
          extra: {'ViewId': viewId});
    }
  }

  /// O(tree depth) - Find a node's parent view ID
  String? _findParentViewId(DCFComponentNode node) {
    DCFComponentNode? current = node.parent;

    // Find the first parent with a native view ID
    while (current != null) {
      final viewId = current.effectiveNativeViewId;
      if (viewId != null && viewId.isNotEmpty) {
        EngineDebugLogger.log('PARENT_VIEW_FOUND', 'Found parent view ID',
            extra: {
              'ParentViewId': viewId,
              'ParentType': current.runtimeType.toString()
            });
        return viewId;
      }
      current = current.parent;
    }

    EngineDebugLogger.log(
        'PARENT_VIEW_DEFAULT', 'No parent view found, using root');
    return "root"; // Default to root if no parent found
  }

  /// Enhanced find node index that works for components too
  int _findNodeIndexInParent(DCFComponentNode node) {
    if (node.parent == null) {
      return 0;
    }

    // Handle different parent types
    if (node.parent is DCFElement) {
      final parent = node.parent as DCFElement;
      return parent.children.indexOf(node);
    } else if (node.parent is DCFFragment) {
      final parent = node.parent as DCFFragment;
      return parent.children.indexOf(node);
    } else if (node.parent is StatefulComponent ||
        node.parent is StatelessComponent) {
      // Component is the direct child of another component
      // In this case, it takes the place of its parent's rendered content
      return _findNodeIndexInParent(node.parent!);
    }

    return 0;
  }

  /// O(props count + event types count) - Reconcile an element - update props and children
  Future<void> _reconcileElement(
      DCFElement oldElement, DCFElement newElement) async {
    EngineDebugLogger.log(
        'RECONCILE_ELEMENT_START', 'Starting element reconciliation', extra: {
      'ElementType': oldElement.type,
      'ViewId': oldElement.nativeViewId
    });

    // O(props count + event types count + children reconciliation) - Update properties if the element has a native view
    if (oldElement.nativeViewId != null) {
      // O(1) - Copy native view ID to new element for tracking
      newElement.nativeViewId = oldElement.nativeViewId;

      // O(1) - Always update the tracking map to maintain event handler lookup
      _nodesByViewId[oldElement.nativeViewId!] = newElement;
      EngineDebugLogger.log(
          'RECONCILE_UPDATE_TRACKING', 'Updated node tracking map');

      // O(event types count) - Handle event registration changes during reconciliation
      final oldEventTypes = oldElement.eventTypes;
      final newEventTypes = newElement.eventTypes;

      final oldEventSet = Set<String>.from(oldEventTypes);
      final newEventSet = Set<String>.from(newEventTypes);

      if (oldEventSet.length != newEventSet.length ||
          !oldEventSet.containsAll(newEventSet)) {
        EngineDebugLogger.log('RECONCILE_UPDATE_EVENTS',
            'Event types changed, updating listeners',
            extra: {'OldEvents': oldEventTypes, 'NewEvents': newEventTypes});

        final eventsToRemove = oldEventSet.difference(newEventSet);
        if (eventsToRemove.isNotEmpty) {
          EngineDebugLogger.logBridge(
              'REMOVE_EVENT_LISTENERS', oldElement.nativeViewId!,
              data: {'EventTypes': eventsToRemove.toList()});
          await _nativeBridge.removeEventListeners(
              oldElement.nativeViewId!, eventsToRemove.toList());
        }

        final eventsToAdd = newEventSet.difference(oldEventSet);
        if (eventsToAdd.isNotEmpty) {
          EngineDebugLogger.logBridge(
              'ADD_EVENT_LISTENERS', oldElement.nativeViewId!,
              data: {'EventTypes': eventsToAdd.toList()});
          await _nativeBridge.addEventListeners(
              oldElement.nativeViewId!, eventsToAdd.toList());
        }
      }

      // O(props count) - Find changed props using proper diffing algorithm
      final changedProps =
          _diffProps(oldElement.type, oldElement.props, newElement.props);

      // O(1) - Update props if there are changes
      if (changedProps.isNotEmpty) {
        EngineDebugLogger.logBridge('UPDATE_VIEW', oldElement.nativeViewId!,
            data: {'ChangedProps': changedProps.keys.toList()});
        await _nativeBridge.updateView(oldElement.nativeViewId!, changedProps);
      } else {
        EngineDebugLogger.log(
            'RECONCILE_NO_PROP_CHANGES', 'No prop changes detected');
      }

      // O(children reconciliation complexity) - Reconcile children with the most efficient algorithm
      EngineDebugLogger.log(
          'RECONCILE_CHILDREN_START', 'Starting children reconciliation',
          extra: {
            'OldChildCount': oldElement.children.length,
            'NewChildCount': newElement.children.length
          });
      await _reconcileChildren(oldElement, newElement);
    }

    EngineDebugLogger.log(
        'RECONCILE_ELEMENT_COMPLETE', 'Element reconciliation completed');
  }

  /// O(props count) - Compute differences between two prop maps
  Map<String, dynamic> _diffProps(String elementType,
      Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    var changedProps = <String, dynamic>{};
    int addedCount = 0;
    int changedCount = 0;
    int removedCount = 0;

    // O(new props count) - Find added or changed props
    for (final entry in newProps.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Function) continue; // Skip function handlers

      if (!oldProps.containsKey(key)) {
        changedProps[key] = value;
        addedCount++;
      } else if (oldProps[key] != value) {
        changedProps[key] = value;
        changedCount++;
      }
    }

    // O(old props count) - Find removed props
    for (final key in oldProps.keys) {
      if (!newProps.containsKey(key) && oldProps[key] is! Function) {
        changedProps[key] = null;
        removedCount++;
      }
    }

    // O(old props count) - Handle event handlers - preserve them if not changed
    for (final key in oldProps.keys) {
      if (key.startsWith('on') &&
          oldProps[key] is Function &&
          !newProps.containsKey(key)) {
        changedProps[key] = oldProps[key];
      }
    }

    EngineDebugLogger.log('PROP_DIFF_COMPLETE', 'Props diffing completed',
        extra: {
          'Added': addedCount,
          'Changed': changedCount,
          'Removed': removedCount,
          'Total': changedProps.length
        });

    // ✅ GENERIC: Check for registered prop diff interceptors
    final interceptors =
        VDomExtensionRegistry.instance.getPropDiffInterceptors();
    for (final interceptor in interceptors) {
      if (interceptor.shouldHandle(elementType, oldProps, newProps)) {
        changedProps = interceptor.interceptPropDiff(
            elementType, oldProps, newProps, changedProps);
      }
    }

    return changedProps;
  }

  /// O(children reconciliation complexity) - Reconcile children with keyed optimization
  Future<void> _reconcileChildren(
      DCFElement oldElement, DCFElement newElement) async {
    final oldChildren = oldElement.children;
    final newChildren = newElement.children;

    EngineDebugLogger.log(
        'RECONCILE_CHILDREN', 'Starting children reconciliation',
        extra: {
          'OldCount': oldChildren.length,
          'NewCount': newChildren.length,
          'ViewId': oldElement.nativeViewId
        });

    // O(1) - Fast path: no children
    if (oldChildren.isEmpty && newChildren.isEmpty) {
      EngineDebugLogger.log(
          'RECONCILE_CHILDREN_EMPTY', 'No children to reconcile');
      return;
    }

    // O(children count) - Check if children have keys for optimized reconciliation
    final hasKeys = _childrenHaveKeys(newChildren);
    EngineDebugLogger.log(
        'RECONCILE_CHILDREN_STRATEGY', 'Choosing reconciliation strategy',
        extra: {'HasKeys': hasKeys});

    if (hasKeys) {
      await _reconcileKeyedChildren(
          oldElement.nativeViewId!, oldChildren, newChildren);
    } else {
      await _reconcileSimpleChildren(
          oldElement.nativeViewId!, oldChildren, newChildren);
    }
  }

  /// O(children count) - Check if any children have explicit keys
  bool _childrenHaveKeys(List<DCFComponentNode> children) {
    if (children.isEmpty) return false;

    // Only use keyed reconciliation if ALL children have keys
    for (var child in children) {
      if (child.key == null) return false;
    }

    return true;
  }

  /// O(children reconciliation complexity) - Reconcile fragment children directly without a container element
  Future<void> _reconcileFragmentChildren(
      String parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    EngineDebugLogger.log(
        'RECONCILE_FRAGMENT_CHILDREN', 'Reconciling fragment children',
        extra: {
          'ParentViewId': parentViewId,
          'OldCount': oldChildren.length,
          'NewCount': newChildren.length
        });

    final hasKeys = _childrenHaveKeys(newChildren);

    if (hasKeys) {
      await _reconcileKeyedChildren(parentViewId, oldChildren, newChildren);
    } else {
      await _reconcileSimpleChildren(parentViewId, oldChildren, newChildren);
    }
  }

  /// O(old children count + new children count + reconciliation complexity) - Reconcile children with keys for optimal reordering
  Future<void> _reconcileKeyedChildren(
      String parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    EngineDebugLogger.log(
        'RECONCILE_KEYED_START', 'Starting keyed children reconciliation',
        extra: {
          'ParentViewId': parentViewId,
          'OldCount': oldChildren.length,
          'NewCount': newChildren.length
        });

    // O(old children count) - Create map of old children by key for O(1) lookup
    final oldChildrenMap = <String?, DCFComponentNode>{};
    final oldChildOrderByKey = <String?, int>{};
    for (int i = 0; i < oldChildren.length; i++) {
      final oldChild = oldChildren[i];
      final key = _getNodeKey(oldChild, i);
      oldChildrenMap[key] = oldChild;
      oldChildOrderByKey[key] = i;
    }

    EngineDebugLogger.log('RECONCILE_KEYED_MAP', 'Created old children map',
        extra: {'KeyCount': oldChildrenMap.length});

    final updatedChildIds = <String>[];
    final processedOldChildren = <DCFComponentNode>{};
    bool hasStructuralChanges = false;

    // O(new children count * reconciliation complexity) - Process each new child
    for (int i = 0; i < newChildren.length; i++) {
      final newChild = newChildren[i];
      final key = _getNodeKey(newChild, i);
      final oldChild = oldChildrenMap[key];

      String? childViewId;

      if (oldChild != null) {
        EngineDebugLogger.log(
            'RECONCILE_KEYED_UPDATE', 'Updating existing child',
            extra: {'Key': key, 'Position': i});

        processedOldChildren.add(oldChild);
        await _reconcile(oldChild, newChild);
        childViewId = oldChild.effectiveNativeViewId;

        final oldIndex = oldChildOrderByKey[key];
        if (oldIndex != null && oldIndex != i) {
          hasStructuralChanges = true;
          EngineDebugLogger.log(
              'RECONCILE_KEYED_REORDER', 'Child position changed',
              extra: {'Key': key, 'OldIndex': oldIndex, 'NewIndex': i});
          if (childViewId != null) {
            await _moveChild(childViewId, parentViewId, i);
          }
        }
      } else {
        EngineDebugLogger.log('RECONCILE_KEYED_CREATE', 'Creating new child',
            extra: {'Key': key, 'Position': i});
        hasStructuralChanges = true;
        childViewId = await renderToNative(newChild,
            parentViewId: parentViewId, index: i);
      }

      if (childViewId != null) {
        updatedChildIds.add(childViewId);
      }
    }

    // O(unprocessed children count) - Remove old children that aren't in the new list
    for (var oldChild in oldChildren) {
      if (!processedOldChildren.contains(oldChild)) {
        hasStructuralChanges = true;
        EngineDebugLogger.log('RECONCILE_KEYED_REMOVE', 'Removing old child',
            extra: {'ChildType': oldChild.runtimeType.toString()});

        try {
          oldChild.componentWillUnmount();
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT',
              'Called componentWillUnmount for removed child');
        } catch (e) {
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT_ERROR',
              'Error in componentWillUnmount for removed child',
              extra: {'Error': e.toString()});
        }

        final viewId = oldChild.effectiveNativeViewId;
        if (viewId != null) {
          EngineDebugLogger.logBridge('DELETE_VIEW', viewId);
          await _nativeBridge.deleteView(viewId);
          _nodesByViewId.remove(viewId);
        }
      }
    }

    // O(children count) - Only call setChildren if there were structural changes
    if (hasStructuralChanges && updatedChildIds.isNotEmpty) {
      EngineDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
        'ChildIds': updatedChildIds,
        'ChildCount': updatedChildIds.length
      });
      await _nativeBridge.setChildren(parentViewId, updatedChildIds);
    }

    EngineDebugLogger.log(
        'RECONCILE_KEYED_COMPLETE', 'Keyed children reconciliation completed',
        extra: {
          'StructuralChanges': hasStructuralChanges,
          'FinalChildCount': updatedChildIds.length
        });
  }

  /// O(max(old children, new children) + reconciliation complexity) - Reconcile children without keys
  Future<void> _reconcileSimpleChildren(
      String parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    EngineDebugLogger.log(
        'RECONCILE_SIMPLE_START', 'Starting simple children reconciliation',
        extra: {
          'ParentViewId': parentViewId,
          'OldCount': oldChildren.length,
          'NewCount': newChildren.length
        });

    final updatedChildIds = <String>[];
    final commonLength = math.min(oldChildren.length, newChildren.length);
    bool hasStructuralChanges = false;

    // O(common length * reconciliation complexity) - Update common children
    for (int i = 0; i < commonLength; i++) {
      final oldChild = oldChildren[i];
      final newChild = newChildren[i];

      EngineDebugLogger.log(
          'RECONCILE_SIMPLE_UPDATE', 'Updating child at index $i');

      await _reconcile(oldChild, newChild);

      final childViewId = oldChild.effectiveNativeViewId;
      if (childViewId != null) {
        updatedChildIds.add(childViewId);
      }
    }    // O((new - common) * render complexity) - Handle length differences
    if (newChildren.length > oldChildren.length) {
      hasStructuralChanges = true;
      EngineDebugLogger.log('RECONCILE_SIMPLE_ADD',
          'Adding ${newChildren.length - commonLength} new children');

      for (int i = commonLength; i < newChildren.length; i++) {
        final childViewId = await renderToNative(newChildren[i],
            parentViewId: parentViewId, index: i);

        if (childViewId != null) {
          updatedChildIds.add(childViewId);
        }
      }
    } else if (oldChildren.length > newChildren.length) {
      // O(old - common) - Remove extra old children
      hasStructuralChanges = true;
      EngineDebugLogger.log('RECONCILE_SIMPLE_REMOVE',
          'Removing ${oldChildren.length - commonLength} old children');

      for (int i = commonLength; i < oldChildren.length; i++) {
        final oldChild = oldChildren[i];

        try {
          oldChild.componentWillUnmount();
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT',
              'Called componentWillUnmount for removed child');
        } catch (e) {
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT_ERROR',
              'Error in componentWillUnmount for removed child',
              extra: {'Error': e.toString()});
        }

        final viewId = oldChild.effectiveNativeViewId;
        if (viewId != null) {
          EngineDebugLogger.logBridge('DELETE_VIEW', viewId);
          await _nativeBridge.deleteView(viewId);
          _nodesByViewId.remove(viewId);
        }
      }
    }

    // O(children count) - Only call setChildren if there were structural changes
    if (hasStructuralChanges && updatedChildIds.isNotEmpty) {
      EngineDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
        'ChildIds': updatedChildIds,
        'ChildCount': updatedChildIds.length
      });
      await _nativeBridge.setChildren(parentViewId, updatedChildIds);
    }

    EngineDebugLogger.log(
        'RECONCILE_SIMPLE_COMPLETE', 'Simple children reconciliation completed',
        extra: {
          'StructuralChanges': hasStructuralChanges,
          'FinalChildCount': updatedChildIds.length
        });
  }

  /// O(1) - Move a child to a specific index in its parent
  Future<void> _moveChild(String childId, String parentId, int index) async {
    EngineDebugLogger.logBridge('MOVE_CHILD', childId,
        data: {'ParentId': parentId, 'NewIndex': index});

    await _nativeBridge.detachView(childId);
    await _nativeBridge.attachView(childId, parentId, index);
  }

  /// O(tree depth) - Find the nearest error boundary
  ErrorBoundary? _findNearestErrorBoundary(DCFComponentNode node) {
    DCFComponentNode? current = node;

    while (current != null) {
      if (current is ErrorBoundary) {
        EngineDebugLogger.log('ERROR_BOUNDARY_FOUND', 'Found error boundary',
            extra: {'BoundaryId': current.instanceId});
        return current;
      }
      current = current.parent;
    }

    EngineDebugLogger.log('ERROR_BOUNDARY_NOT_FOUND',
        'No error boundary found in component tree');
    return null;
  }

  /// O(1) - Create a portal container with optimized properties for portaling
  Future<String> createPortal(String portalId,
      {required String parentViewId,
      Map<String, dynamic>? props,
      int? index}) async {
    await isReady;

    EngineDebugLogger.log('CREATE_PORTAL_START', 'Creating portal container',
        extra: {
          'PortalId': portalId,
          'ParentViewId': parentViewId,
          'Index': index
        });

    final portalProps = {
      'portalId': portalId,
      'isPortalContainer': true,
      'backgroundColor': 'transparent',
      'clipsToBounds': false,
      'userInteractionEnabled': true,
      ...(props ?? {}),
    };

    try {
      EngineDebugLogger.logBridge('CREATE_PORTAL', portalId,
          data: {'Type': 'View', 'Props': portalProps.keys.toList()});
      await _nativeBridge.createView(portalId, 'View', portalProps);

      EngineDebugLogger.logBridge('ATTACH_PORTAL', portalId,
          data: {'ParentViewId': parentViewId, 'Index': index ?? 0});
      await _nativeBridge.attachView(portalId, parentViewId, index ?? 0);

      EngineDebugLogger.log(
          'CREATE_PORTAL_SUCCESS', 'Portal container created successfully',
          extra: {'PortalId': portalId});
      return portalId;
    } catch (e) {
      EngineDebugLogger.log(
          'CREATE_PORTAL_ERROR', 'Failed to create portal container',
          extra: {'PortalId': portalId, 'Error': e.toString()});
      rethrow;
    }
  }

  /// O(children count) - Get the current child view IDs of a view (for portal management)
  List<String> getCurrentChildren(String viewId) {
    EngineDebugLogger.log(
        'GET_CURRENT_CHILDREN', 'Getting current children for view',
        extra: {'ViewId': viewId});

    final node = _nodesByViewId[viewId]; // O(1) lookup
    if (node is DCFElement) {
      final childViewIds = <String>[];
      for (final child in node.children) {
        final childViewId = child.effectiveNativeViewId;
        if (childViewId != null) {
          childViewIds.add(childViewId);
        }
      }
      EngineDebugLogger.log(
          'GET_CURRENT_CHILDREN_SUCCESS', 'Retrieved child view IDs',
          extra: {'ViewId': viewId, 'ChildCount': childViewIds.length});
      return childViewIds;
    }

    EngineDebugLogger.log(
        'GET_CURRENT_CHILDREN_EMPTY', 'No children found for view',
        extra: {'ViewId': viewId});
    return [];
  }

  /// O(1) - Update children of a view (for portal management)
  Future<void> updateViewChildren(String viewId, List<String> childIds) async {
    await isReady;
    EngineDebugLogger.logBridge('UPDATE_VIEW_CHILDREN', viewId,
        data: {'ChildIds': childIds, 'ChildCount': childIds.length});
    await _nativeBridge.setChildren(viewId, childIds);
  }

  /// O(view count) - Delete views (for portal cleanup)
  Future<void> deleteViews(List<String> viewIds) async {
    await isReady;
    EngineDebugLogger.log('DELETE_VIEWS_START', 'Deleting multiple views',
        extra: {'ViewIds': viewIds, 'Count': viewIds.length});

    for (final viewId in viewIds) {
      EngineDebugLogger.logBridge('DELETE_VIEW', viewId);
      await _nativeBridge.deleteView(viewId);
      _nodesByViewId.remove(viewId); // O(1)
    }

    EngineDebugLogger.log('DELETE_VIEWS_COMPLETE', 'Successfully deleted views',
        extra: {'Count': viewIds.length});
  }

  /// O(1) - Print comprehensive VDOM statistics (for debugging)
  void printDebugStats() {
    EngineDebugLogger.printStats();

    EngineDebugLogger.log('VDOM_STATS', 'Current enhanced VDOM state', extra: {
      'StatefulComponents': _statefulComponents.length,
      'StatelessComponents': _statelessComponents.length,
      'NodesByViewId': _nodesByViewId.length,
      'PendingUpdates': _pendingUpdates.length,
      'ComponentPriorities': _componentPriorities.length,
      'ErrorBoundaries': _errorBoundaries.length,
      'HasRootComponent': rootComponent != null,
      'BatchUpdateInProgress': _batchUpdateInProgress,
      'IsUpdateScheduled': _isUpdateScheduled,
      'IsTreeComplete': _isTreeComplete,
      'ComponentsWaitingForLayout': _componentsWaitingForLayout.length,
      'ComponentsWaitingForInsertion': _componentsWaitingForInsertion.length,
    });

    // O(priorities count) - Print priority statistics
    final priorityStats = <String, int>{};
    for (final priority in _componentPriorities.values) {
      priorityStats[priority.name] = (priorityStats[priority.name] ?? 0) + 1;
    }
    EngineDebugLogger.log('PRIORITY_STATS', 'Component priority distribution',
        extra: priorityStats);
  }

  /// O(1) - Reset debug logging (for testing)
  void resetDebugLogging() {
    EngineDebugLogger.reset();
  }

  /// O(1) - Enable/disable debug logging
  void setDebugLogging(bool enabled) {
    EngineDebugLogger.enabled = enabled;
    EngineDebugLogger.log('DEBUG_LOGGING_CHANGED',
        'Debug logging ${enabled ? 'enabled' : 'disabled'}');
  }

  /// O(1) - Get priority-based performance statistics
  Map<String, dynamic> getPriorityStats() {
    final stats = <String, dynamic>{};

    // O(priorities count) - Count components by priority
    final priorityCounts = <ComponentPriority, int>{};
    for (final priority in _componentPriorities.values) {
      priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
    }

    for (final priority in ComponentPriority.values) {
      stats[priority.name] = {
        'pendingCount': priorityCounts[priority] ?? 0,
        'delayMs': priority.delayMs,
        'weight': priority.weight,
      };
    }

    stats['system'] = {
      'totalPendingUpdates': _pendingUpdates.length,
      'batchUpdateInProgress': _batchUpdateInProgress,
      'isUpdateScheduled': _isUpdateScheduled,
      'updateTimerActive': _updateTimer?.isActive ?? false,
    };

    return stats;
  }

  /// O(1) - Cancel all pending updates for a specific component (for cleanup)
  void cancelComponentUpdates(String componentId) {
    _pendingUpdates.remove(componentId); // O(1)
    _componentPriorities.remove(componentId); // O(1)
    _componentsWaitingForLayout.remove(componentId); // O(1)
    _componentsWaitingForInsertion.remove(componentId); // O(1)

    EngineDebugLogger.log('CANCEL_COMPONENT_UPDATES',
        'Cancelled all updates for component: $componentId');
  }

  /// O(priorities count) - Force immediate processing of high priority updates
  void flushHighPriorityUpdates() {
    if (_pendingUpdates.isEmpty) return;

    EngineDebugLogger.log(
        'FLUSH_HIGH_PRIORITY', 'Flushing high priority updates');

    // O(priorities count) - Check if we have high priority updates
    final hasHighPriority = _componentPriorities.values.any((priority) =>
        priority == ComponentPriority.immediate ||
        priority == ComponentPriority.high);

    if (hasHighPriority) {
      _updateTimer?.cancel();
      _updateTimer = Timer(Duration.zero, _processPendingUpdates);
      EngineDebugLogger.log('FLUSH_HIGH_PRIORITY_SCHEDULED',
          'Scheduled immediate high priority batch');
    }
  }

  /// O(n) - Clear all pending updates (for emergency cleanup)
  void clearAllPendingUpdates() {
    final clearedCount = _pendingUpdates.length;

    _pendingUpdates.clear();
    _componentPriorities.clear();
    _updateTimer?.cancel();
    _isUpdateScheduled = false;

    EngineDebugLogger.log('CLEAR_ALL_UPDATES', 'Cleared all pending updates',
        extra: {'ClearedCount': clearedCount});
  }

  /// O(1) - Check if the VDOM is currently processing updates
  bool get isProcessingUpdates => _batchUpdateInProgress;

  /// O(1) - Check if there are pending updates
  bool get hasPendingUpdates => _pendingUpdates.isNotEmpty;

  /// O(1) - Get the number of pending updates
  int get pendingUpdateCount => _pendingUpdates.length;

  /// Get the current highest priority of pending updates
  ComponentPriority? get currentHighestPriority {
    if (_componentPriorities.isEmpty) return null;
    return PriorityUtils.getHighestPriority(
        _componentPriorities.values.toList());
  }

  /// Get concurrent processing statistics
  Map<String, dynamic> getConcurrentStats() {
    return {
      ..._performanceStats,
      'concurrentEnabled': _concurrentEnabled,
      'concurrentThreshold': _concurrentThreshold,
      'maxWorkers': _maxWorkers,
      'availableWorkers':
          _workerAvailable.where((available) => available).length,
      'totalWorkers': _workerIsolates.length,
    };
  }

  /// Update performance statistics
  void _updatePerformanceStats(bool wasConcurrent, Duration processingTime) {
    if (wasConcurrent) {
      // Update concurrent averages
      final currentAvg = _performanceStats['averageConcurrentTime'] as double;
      final totalConcurrent =
          _performanceStats['totalConcurrentUpdates'] as int;

      if (totalConcurrent > 0) {
        _performanceStats['averageConcurrentTime'] =
            ((currentAvg * totalConcurrent) + processingTime.inMilliseconds) /
                (totalConcurrent + 1);
      } else {
        _performanceStats['averageConcurrentTime'] =
            processingTime.inMilliseconds.toDouble();
      }
    } else {
      // Update serial averages
      final currentAvg = _performanceStats['averageSerialTime'] as double;
      final totalSerial = _performanceStats['totalSerialUpdates'] as int;

      if (totalSerial > 0) {
        _performanceStats['averageSerialTime'] =
            ((currentAvg * totalSerial) + processingTime.inMilliseconds) /
                (totalSerial + 1);
      } else {
        _performanceStats['averageSerialTime'] =
            processingTime.inMilliseconds.toDouble();
      }
    }

    // Calculate efficiency
    final avgConcurrent = _performanceStats['averageConcurrentTime'] as double;
    final avgSerial = _performanceStats['averageSerialTime'] as double;

    if (avgConcurrent > 0 && avgSerial > 0) {
      _performanceStats['concurrentEfficiency'] =
          ((avgSerial - avgConcurrent) / avgSerial * 100).clamp(0, 100);
    }
  }

  /// Check if concurrent processing is beneficial
  bool get isConcurrentProcessingOptimal {
    final efficiency = _performanceStats['concurrentEfficiency'] as double;
    return _concurrentEnabled && efficiency > 10.0; // 10% improvement threshold
  }

  /// Shutdown concurrent processing
  Future<void> shutdownConcurrentProcessing() async {
    if (!_concurrentEnabled) return;

    EngineDebugLogger.log(
        'VDOM_CONCURRENT_SHUTDOWN', 'Shutting down concurrent processing');

    // Kill all worker isolates
    for (final isolate in _workerIsolates) {
      try {
        isolate.kill();
      } catch (e) {
        EngineDebugLogger.log('VDOM_CONCURRENT_SHUTDOWN_ERROR',
            'Error killing worker isolate: $e');
      }
    }

    // Clear collections
    _workerIsolates.clear();
    _workerPorts.clear();
    _workerAvailable.clear();
    _concurrentEnabled = false;

    EngineDebugLogger.log(
        'VDOM_CONCURRENT_SHUTDOWN', 'Concurrent processing shutdown complete');
  }

  /// Worker isolate entry point - handles real concurrent processing
  /// ? Experimental --dead for now
  // ignore: unused_element
  static void _workerIsolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      try {
        final Map<String, dynamic> messageData =
            message as Map<String, dynamic>;
        final String taskType = messageData['type'] as String;
        final String taskId = messageData['id'] as String;
        final Map<String, dynamic> taskData =
            messageData['data'] as Map<String, dynamic>;

        Map<String, dynamic> result;
        final startTime = DateTime.now();

        switch (taskType) {
          case 'treeReconciliation':
            result = await _reconcileTreeInIsolate(taskData);
            break;
          case 'propsDiff':
            result = await _computePropsInIsolate(taskData);
            break;
          case 'listProcessing':
            result = await _processLargeListInIsolate(taskData);
            break;
          case 'componentSerialization':
            result = await _serializeComponentInIsolate(taskData);
            break;
          default:
            result = {'error': 'Unknown task type: $taskType'};
        }

        final processingTime = DateTime.now().difference(startTime);

        // Send result back to main thread
        mainSendPort.send({
          'type': 'result',
          'id': taskId,
          'success': true,
          'data': result,
          'processingTimeMs': processingTime.inMilliseconds,
        });
      } catch (e) {
        // Send error back to main thread
        final Map<String, dynamic> safeMessageData =
            message is Map<String, dynamic> ? message : {};
        mainSendPort.send({
          'type': 'error',
          'id': safeMessageData['id'] ?? 'unknown',
          'success': false,
          'error': e.toString(),
        });
      }
    });
  }

  /// Reconcile tree structure in isolate (heavy algorithmic work)
  static Future<Map<String, dynamic>> _reconcileTreeInIsolate(
      Map<String, dynamic> data) async {
    final oldTree = data['oldTree'] as Map<String, dynamic>?;
    final newTree = data['newTree'] as Map<String, dynamic>;

    if (oldTree == null) {
      return {
        'type': 'create',
        'changes': [
          {'action': 'create', 'node': newTree}
        ],
        'metrics': {'nodesProcessed': 1, 'complexity': 'simple'}
      };
    }

    // Simulate heavy tree diffing algorithm
    await Future.delayed(Duration(milliseconds: 5)); // Simulate CPU work

    final changes = <Map<String, dynamic>>[];

    // Compare tree structures
    if (oldTree['type'] != newTree['type']) {
      changes
          .add({'action': 'replace', 'oldNode': oldTree, 'newNode': newTree});
    }

    // Compare props
    final oldProps = oldTree['props'] as Map<String, dynamic>? ?? {};
    final newProps = newTree['props'] as Map<String, dynamic>? ?? {};

    final propsDiff = _computeDeepPropsDiff(oldProps, newProps);
    if (propsDiff.isNotEmpty) {
      changes.add({'action': 'updateProps', 'diff': propsDiff});
    }

    // Compare children
    final oldChildren = oldTree['children'] as List<dynamic>? ?? [];
    final newChildren = newTree['children'] as List<dynamic>? ?? [];

    final childrenChanges =
        await _computeChildrenDiff(oldChildren, newChildren);
    changes.addAll(childrenChanges);

    return {
      'type': 'update',
      'changes': changes,
      'metrics': {
        'nodesProcessed': _countNodes(newTree),
        'changesCount': changes.length,
        'complexity': changes.length > 10 ? 'complex' : 'simple'
      }
    };
  }

  /// Compute props diff in isolate (heavy comparison work)
  static Future<Map<String, dynamic>> _computePropsInIsolate(
      Map<String, dynamic> data) async {
    final oldProps = data['oldProps'] as Map<String, dynamic>;
    final newProps = data['newProps'] as Map<String, dynamic>;

    // Simulate heavy props comparison
    await Future.delayed(Duration(milliseconds: 2));

    return _computeDeepPropsDiff(oldProps, newProps);
  }

  /// Process large lists in isolate (heavy data processing)
  static Future<Map<String, dynamic>> _processLargeListInIsolate(
      Map<String, dynamic> data) async {
    final items = data['items'] as List<dynamic>;
    final operations = data['operations'] as List<String>? ?? [];

    // Simulate heavy list processing
    await Future.delayed(Duration(milliseconds: items.length ~/ 100));

    final processedItems = List<dynamic>.from(items);

    for (final operation in operations) {
      switch (operation) {
        case 'sort':
          processedItems.sort((a, b) => a.toString().compareTo(b.toString()));
          break;
        case 'filter':
          processedItems.removeWhere((item) => item == null);
          break;
        case 'dedupe':
          final seen = <dynamic>{};
          processedItems.retainWhere((item) => seen.add(item));
          break;
      }
    }

    return {
      'processedItems': processedItems,
      'statistics': {
        'originalCount': items.length,
        'processedCount': processedItems.length,
        'operationsApplied': operations.length,
      },
      'optimizations': _suggestListOptimizations(processedItems)
    };
  }

  /// Serialize component data in isolate (heavy serialization work)
  static Future<Map<String, dynamic>> _serializeComponentInIsolate(
      Map<String, dynamic> data) async {
    final component = data['component'] as Map<String, dynamic>;

    // Simulate heavy serialization work
    await Future.delayed(Duration(milliseconds: 3));

    final serialized = <String, dynamic>{};

    // Deep clone component data
    for (final entry in component.entries) {
      serialized[entry.key] = _deepCloneValue(entry.value);
    }

    return {
      'serialized': serialized,
      'metadata': {
        'size': serialized.toString().length,
        'complexity': _assessComplexity(component),
        'dependencies': _extractDependencies(component),
      }
    };
  }

  /// Helper: Compute deep props diff
  static Map<String, dynamic> _computeDeepPropsDiff(
      Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    final diff = <String, dynamic>{};

    // Check for changed or new props
    for (final key in newProps.keys) {
      if (!oldProps.containsKey(key)) {
        diff[key] = {'action': 'add', 'value': newProps[key]};
      } else if (oldProps[key] != newProps[key]) {
        diff[key] = {
          'action': 'change',
          'oldValue': oldProps[key],
          'newValue': newProps[key]
        };
      }
    }

    // Check for removed props
    for (final key in oldProps.keys) {
      if (!newProps.containsKey(key)) {
        diff[key] = {'action': 'remove', 'oldValue': oldProps[key]};
      }
    }

    return diff;
  }

  /// Helper: Compute children diff
  static Future<List<Map<String, dynamic>>> _computeChildrenDiff(
      List<dynamic> oldChildren, List<dynamic> newChildren) async {
    final changes = <Map<String, dynamic>>[];

    final maxLength = math.max(oldChildren.length, newChildren.length);

    for (int i = 0; i < maxLength; i++) {
      if (i >= oldChildren.length) {
        changes
            .add({'action': 'addChild', 'index': i, 'child': newChildren[i]});
      } else if (i >= newChildren.length) {
        changes.add(
            {'action': 'removeChild', 'index': i, 'child': oldChildren[i]});
      } else if (oldChildren[i] != newChildren[i]) {
        changes.add({
          'action': 'replaceChild',
          'index': i,
          'oldChild': oldChildren[i],
          'newChild': newChildren[i]
        });
      }
    }

    return changes;
  }

  /// Helper: Count nodes in tree
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

  /// Helper: Deep clone value
  static dynamic _deepCloneValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k, _deepCloneValue(v))));
    } else if (value is List) {
      return value.map((item) => _deepCloneValue(item)).toList();
    } else {
      return value;
    }
  }

  /// Helper: Assess complexity
  /// This has nothing to do with priority set by the component itself but rather how complex the componet is actually.
  static String _assessComplexity(Map<String, dynamic> component) {
    final props = component['props'] as Map<String, dynamic>? ?? {};
    final children = component['children'] as List<dynamic>? ?? [];

    if (props.length > 10 || children.length > 20) {
      return 'high';
    } else if (props.length > 5 || children.length > 10) {
      return 'medium';
    } else {
      return 'low';
    }
  }

  /// Helper: Extract dependencies
  static List<String> _extractDependencies(Map<String, dynamic> component) {
    final dependencies = <String>[];
    final type = component['type'] as String?;
    if (type != null) {
      dependencies.add(type);
    }
    return dependencies;
  }

  /// Helper: Suggest list optimizations
  static List<String> _suggestListOptimizations(List<dynamic> items) {
    final suggestions = <String>[];

    if (items.length > 1000) {
      suggestions.add('Consider virtualization for large lists');
    }

    if (items.length > 100) {
      suggestions.add('Consider pagination or infinite scroll');
    }

    return suggestions;
  }
}

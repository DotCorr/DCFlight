
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
import 'package:dcflight/framework/components/component.dart';
import 'package:dcflight/framework/components/error_boundary.dart';
import 'package:dcflight/framework/components/dcf_element.dart';
import 'package:dcflight/framework/components/component_node.dart';
import 'package:dcflight/framework/components/fragment.dart';

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

  /// Component tracking maps
  final Map<String, DCFStatefulComponent> _statefulComponents = {};
  final Map<String, DCFComponentNode> _previousRenderedNodes = {};
  
  /// Component instance tracking by position + type
  /// Key: "parentViewId:index:type" -> Component instance
  /// This allows instance persistence across renders
  final Map<String, DCFComponentNode> _componentInstancesByPosition = {};
  
  /// Props-based identity cache for automatic key inference
  /// Key: "parentViewId:index:type:propsHash" -> Component instance
  /// Used when components have same type at same position but different props
  final Map<String, DCFComponentNode> _componentInstancesByProps = {};
  
  /// Helper to compute props hash for identity matching
  /// Uses component identity (hashCode) since Equatable props were removed
  int _computePropsHash(DCFComponentNode node) {
    if (node is DCFElement) {
      return node.elementProps.hashCode;
    }
    // For components, use hashCode (object identity) combined with key if present
    // This is sufficient for automatic key inference since position + type is primary
    return node.key?.hashCode ?? node.hashCode;
  }

  /// Priority-based update system
  final Set<String> _pendingUpdates = {};
  final Map<String, ComponentPriority> _componentPriorities = {};
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



  }

  Future<void> get isReady => _readyCompleter.future;

  /// O(1) - Generate a unique view ID
  String _generateViewId() {
    final viewId = (_viewIdCounter++).toString();
    EngineDebugLogger.log('VIEW_ID_GENERATE', 'Generated view ID: $viewId');
    return viewId;
  }

  /// Key generation: key prop or position+type
  String _getNodeKey(DCFComponentNode node, int index) {
    return node.key ?? '$index:${node.runtimeType}';
  }

  /// Register a component in the VDOM
  void registerComponent(DCFComponentNode component) {
    EngineDebugLogger.logMount(component, context: 'registerComponent');

    if (component is DCFStatefulComponent) {
      _statefulComponents[component.instanceId] = component;
      component.scheduleUpdate = () => _scheduleComponentUpdate(component);
      EngineDebugLogger.log('COMPONENT_REGISTER',
          'Registered StatefulComponent: ${component.instanceId}');
    }

    if (component is ErrorBoundary) {
      _errorBoundaries[component.instanceId] = component;
      EngineDebugLogger.log('ERROR_BOUNDARY_REGISTER',
          'Registered ErrorBoundary: ${component.instanceId}');
    }
  }

  /// O(1) - Handle a native event by finding the appropriate component
  /// Handles native events received from the platform bridge.
  /// 
  /// Looks up the node associated with the viewId and executes the appropriate
  /// event handler. If the node is a component instead of an element, it fixes
  /// the mapping to point to the rendered element.
  void _handleNativeEvent(
      String viewId, String eventType, Map<dynamic, dynamic> eventData) {
    EngineDebugLogger.log(
        'NATIVE_EVENT', 'Received event: $eventType for view: $viewId',
        extra: {
          'EventData': eventData.toString(),
          'TotalMappings': _nodesByViewId.length,
          'AvailableViewIds': _nodesByViewId.keys.take(20).toList()
        });

    final node = _nodesByViewId[viewId]; // O(1) lookup
    if (node == null) {
      EngineDebugLogger.log(
          'NATIVE_EVENT_ERROR', 'No node found for view ID: $viewId',
          extra: {
            'AvailableViewIds': _nodesByViewId.keys.take(20).toList(),
            'TotalMappings': _nodesByViewId.length
          });
      return;
    }

    EngineDebugLogger.log('NATIVE_EVENT_NODE_FOUND',
        'Found node for view ID',
        extra: {
          'ViewId': viewId,
          'NodeType': node.runtimeType.toString(),
          'IsElement': node is DCFElement,
          'IsComponent': node is DCFStatefulComponent || node is DCFStatelessComponent
        });

    if (node is DCFElement) {
      final eventHandlerKeys = [
        eventType,
        'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}',
        eventType.toLowerCase(),
        'on${eventType.toLowerCase().substring(0, 1).toUpperCase()}${eventType.toLowerCase().substring(1)}'
      ];

      EngineDebugLogger.log('NATIVE_EVENT_ELEMENT_PROPS',
          'Element props for event lookup',
          extra: {
            'ElementType': node.type,
            'AllProps': node.elementProps.keys.toList(),
            'EventType': eventType,
            'HandlerKeys': eventHandlerKeys
          });

      for (final key in eventHandlerKeys) {
        if (node.elementProps.containsKey(key) &&
            node.elementProps[key] is Function) {
          EngineDebugLogger.log('EVENT_HANDLER_FOUND',
              'Found handler for $eventType using key: $key');
          _executeEventHandler(node.elementProps[key], eventData);
          return;
        } else if (node.elementProps.containsKey(key)) {
          EngineDebugLogger.log('EVENT_HANDLER_WRONG_TYPE',
              'Handler exists but is not a Function',
              extra: {
                'Key': key,
                'ValueType': node.elementProps[key].runtimeType.toString()
              });
        }
      }

      EngineDebugLogger.log(
          'EVENT_HANDLER_NOT_FOUND', 'No handler found for event: $eventType',
          extra: {
            'AvailableProps': node.elementProps.keys.toList(),
            'TriedKeys': eventHandlerKeys,
            'ElementType': node.type
          });
    } else {
      if (node is DCFStatefulComponent || node is DCFStatelessComponent) {
        if (node.renderedNode is DCFElement) {
          final renderedElement = node.renderedNode as DCFElement;
          
          // Fix the mapping if we find a component instead of element.
          // This can happen when SafeArea re-renders and Button components
          // get mapped instead of their rendered elements.
          final elementViewId = renderedElement.nativeViewId ?? node.contentViewId;
          if (elementViewId == viewId || node.contentViewId == viewId) {
            _nodesByViewId[viewId] = renderedElement;
            // Also ensure the rendered element has the viewId set
            if (renderedElement.nativeViewId != viewId) {
              renderedElement.nativeViewId = viewId;
            }
            // Retry handler lookup
            final handlerKeys = [
              eventType,
              'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}',
              eventType.toLowerCase(),
              'on${eventType.toLowerCase().substring(0, 1).toUpperCase()}${eventType.toLowerCase().substring(1)}'
            ];
            for (final key in handlerKeys) {
              if (renderedElement.elementProps.containsKey(key) && renderedElement.elementProps[key] is Function) {
                print('✅ EVENT: Found handler in rendered element, executing');
                _executeEventHandler(renderedElement.elementProps[key]!, eventData);
                return;
              }
            }
          }
        }
      }
      EngineDebugLogger.log('NATIVE_EVENT_WRONG_NODE_TYPE',
          'Node is not a DCFElement, cannot handle events',
          extra: {
            'NodeType': node.runtimeType.toString(),
            'ViewId': viewId
          });
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

    if (eventData.containsKey('width') && eventData.containsKey('height')) {
      try {
        final width = eventData['width'] as double? ?? 0.0;
        final height = eventData['height'] as double? ?? 0.0;
        Function.apply(handler, [width, height]);
        EngineDebugLogger.log(
            'EVENT_HANDLER_SUCCESS', 'Content size change handler executed');
        return;
      } catch (e) {
      }
    }

    try {
      Function.apply(handler, []);
      EngineDebugLogger.log(
          'EVENT_HANDLER_SUCCESS', 'Parameter-less handler executed');
      return;
    } catch (e) {
    }

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

  /// Reconciliation: when to replace vs update at same position
  /// Heuristic: Only replace if truly necessary
  /// We match by position when types are the same, even without keys
  bool _shouldReplaceAtSamePosition(
      DCFComponentNode oldChild, DCFComponentNode newChild) {
    // If keys are explicitly different, replace
    if (oldChild.key != null && newChild.key != null && oldChild.key != newChild.key) {
      return true;
    }
    
    // If one has a key and the other doesn't, be more careful
    // We still try to match by position if types match
    if ((oldChild.key != null) != (newChild.key != null)) {
      // Different key presence, but check if types match first
      if (oldChild.runtimeType == newChild.runtimeType) {
        // Same type, try to reconcile instead of replace
        if (oldChild is DCFElement && newChild is DCFElement) {
          if (oldChild.type == newChild.type) {
            // Same element type, reconcile instead of replace
            return false;
          }
        } else {
          // Same component type, reconcile instead of replace
          return false;
        }
      }
    }

    // Different runtime types = different components, must replace
    if (oldChild.runtimeType != newChild.runtimeType) {
      return true;
    }

    // Same runtime type - check element types if both are elements
    if (oldChild is DCFElement && newChild is DCFElement) {
      if (oldChild.type != newChild.type) {
        return true;
      }
      
      // Same element type - we reconcile, not replace
      // Only replace if children structure is COMPLETELY different
      // (We are more forgiving with conditional rendering)
      final oldChildCount = oldChild.children.length;
      final newChildCount = newChild.children.length;
      final countDiff = (oldChildCount - newChildCount).abs();
      
      // More forgiving threshold - only replace if structure is VERY different
        // We reconcile even with different child counts
      if (countDiff > 10 || (countDiff > 0 && countDiff >= oldChildCount)) {
        // Only replace if children count doubled or more than 10 difference
        EngineDebugLogger.log('REPLACE_CHILDREN_MISMATCH',
            'Forcing replacement due to extreme children count difference',
            extra: {
              'OldChildCount': oldChildCount,
              'NewChildCount': newChildCount,
              'CountDiff': countDiff,
              'ElementType': oldChild.type
            });
        return true;
      }
      
      // Same type, similar structure - reconcile, don't replace
      return false;
    }

    // Same component type - we reconcile, not replace
    // This is the key behavior: match by position and type
    return false;
  }

  /// O(1) - Schedule a component update with priority handling
  void _scheduleComponentUpdate(DCFStatefulComponent component) {
    EngineDebugLogger.logUpdate(component, 'State change triggered update');

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
  void _scheduleComponentUpdateInternal(DCFStatefulComponent component) {
    EngineDebugLogger.log('SCHEDULE_UPDATE',
        'Scheduling priority-based update for component: ${component.instanceId}');

    if (!_statefulComponents.containsKey(component.instanceId)) {
      EngineDebugLogger.log('COMPONENT_REREGISTER',
          'Re-registering untracked component: ${component.instanceId}');
      registerComponent(component);
    }

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

    if (!_isUpdateScheduled) {
      _isUpdateScheduled = true;
      EngineDebugLogger.log(
          'BATCH_SCHEDULE', 'Scheduling priority-based batch update');

      final delay = Duration(milliseconds: priority.delayMs);
      _updateTimer?.cancel();
      _updateTimer = Timer(delay, _processPendingUpdates);
    } else {
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

      if (_concurrentEnabled && updateCount >= _concurrentThreshold) {
        await _processPendingUpdatesConcurrently();
      } else {
        await _processPendingUpdatesSerially();
      }

      final processingTime = DateTime.now().difference(startTime);
      _updatePerformanceStats(
          updateCount >= _concurrentThreshold, processingTime);

      if (_pendingUpdates.isNotEmpty) {
        EngineDebugLogger.log('BATCH_NEW_UPDATES',
            'New updates scheduled during batch, processing in next cycle',
            extra: {'NewUpdatesCount': _pendingUpdates.length});
        _isUpdateScheduled = false;

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

    final sortedUpdates = PriorityUtils.sortByPriority(
        _pendingUpdates.toList(), _componentPriorities);

    _pendingUpdates.clear(); // O(n)
    _componentPriorities.clear(); // O(n)

    EngineDebugLogger.log('BATCH_PRIORITY_SORTED',
        'Sorted ${sortedUpdates.length} updates by priority');

    EngineDebugLogger.logBridge('START_BATCH', 'root');
    await _nativeBridge.startBatchUpdate();

    try {
      final batchSize =
          (_maxWorkers * 2); // Process more than workers to keep them busy
      for (int i = 0; i < sortedUpdates.length; i += batchSize) {
        final batchEnd = (i + batchSize < sortedUpdates.length)
            ? i + batchSize
            : sortedUpdates.length;
        final batch = sortedUpdates.sublist(i, batchEnd);

        final futures = <Future>[];
        for (final componentId in batch) {
          futures.add(_updateComponentById(componentId));
        }

        await Future.wait(futures);
      }

      EngineDebugLogger.logBridge('COMMIT_BATCH', 'root');
      await _nativeBridge.commitBatchUpdate();
      EngineDebugLogger.log('BATCH_COMMIT_SUCCESS',
          'Successfully committed concurrent batch updates');

      _performanceStats['totalConcurrentUpdates'] =
          (_performanceStats['totalConcurrentUpdates'] as int) +
              sortedUpdates.length;
    } catch (e) {
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

    final sortedUpdates = PriorityUtils.sortByPriority(
        _pendingUpdates.toList(), _componentPriorities);

    _pendingUpdates.clear(); // O(n)
    _componentPriorities.clear(); // O(n)

    EngineDebugLogger.log('BATCH_PRIORITY_SORTED',
        'Sorted ${sortedUpdates.length} updates by priority');

    EngineDebugLogger.logBridge('START_BATCH', 'root');
    await _nativeBridge.startBatchUpdate();

    try {
      for (final componentId in sortedUpdates) {
        EngineDebugLogger.log(
            'BATCH_PROCESS_COMPONENT', 'Processing update for: $componentId');
        await _updateComponentById(componentId);
      }

      EngineDebugLogger.logBridge('COMMIT_BATCH', 'root');
      await _nativeBridge.commitBatchUpdate();
      EngineDebugLogger.log('BATCH_COMMIT_SUCCESS',
          'Successfully committed serial batch updates');

      _performanceStats['totalSerialUpdates'] =
          (_performanceStats['totalSerialUpdates'] as int) +
              sortedUpdates.length;
    } catch (e) {
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

    final component = _statefulComponents[componentId];
    if (component == null) {
      EngineDebugLogger.log('COMPONENT_UPDATE_NOT_FOUND',
          'StatefulComponent not found: $componentId');
      return;
    }

    try {
      final lifecycleInterceptor = VDomExtensionRegistry.instance
          .getLifecycleInterceptor(component.runtimeType);
      if (lifecycleInterceptor != null) {
        EngineDebugLogger.log(
            'LIFECYCLE_INTERCEPTOR', 'Calling beforeUpdate interceptor');
        final context = VDomLifecycleContext(
          scheduleUpdate: () => _scheduleComponentUpdateInternal(component),
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isUpdating': true},
        );
        lifecycleInterceptor.beforeUpdate(component, context);
      }

      if (component is DCFStatefulComponent) {
        EngineDebugLogger.log(
            'COMPONENT_PREPARE', 'Preparing StatefulComponent for render');
        component.prepareForRender();
      }

      final oldRenderedNode = component.renderedNode;
      EngineDebugLogger.log('COMPONENT_OLD_NODE', 'Stored old rendered node',
          extra: {'HasOldNode': oldRenderedNode != null});

      _previousRenderedNodes[componentId] = oldRenderedNode;

      component.renderedNode = null;
      final newRenderedNode = component.renderedNode;

      EngineDebugLogger.log('COMPONENT_NEW_NODE', 'Generated new rendered node',
          component: newRenderedNode.runtimeType.toString());

      newRenderedNode.parent = component;

      final previousRenderedNode = _previousRenderedNodes[componentId];
      if (previousRenderedNode != null) {
        print('🔍 UPDATE_COMPONENT: Starting reconciliation');
        print('🔍 UPDATE_COMPONENT: Component type: ${component.runtimeType}');
        print('🔍 UPDATE_COMPONENT: Previous node type: ${previousRenderedNode.runtimeType}');
        print('🔍 UPDATE_COMPONENT: New node type: ${newRenderedNode.runtimeType}');
        
        // Comprehensive type checking - handle all valid reconciliation cases
        bool canReconcile = false;
        if (previousRenderedNode is DCFElement && newRenderedNode is DCFElement) {
          print('🔍 UPDATE_COMPONENT: Both are DCFElement!');
          print('🔍 UPDATE_COMPONENT: Previous element type: ${previousRenderedNode.type}');
          print('🔍 UPDATE_COMPONENT: New element type: ${newRenderedNode.type}');
          canReconcile = true;
        } else if (previousRenderedNode is DCFStatelessComponent && newRenderedNode is DCFStatelessComponent) {
          print('🔍 UPDATE_COMPONENT: Both are DCFStatelessComponent!');
          print('🔍 UPDATE_COMPONENT: Previous: ${previousRenderedNode.runtimeType}');
          print('🔍 UPDATE_COMPONENT: New: ${newRenderedNode.runtimeType}');
          print('🔍 UPDATE_COMPONENT: Previous renderedNode: ${previousRenderedNode.renderedNode?.runtimeType}');
          print('🔍 UPDATE_COMPONENT: New renderedNode: ${newRenderedNode.renderedNode?.runtimeType}');
          canReconcile = true;
        } else if (previousRenderedNode is DCFStatefulComponent && newRenderedNode is DCFStatefulComponent) {
          print('🔍 UPDATE_COMPONENT: Both are DCFStatefulComponent!');
          print('🔍 UPDATE_COMPONENT: Previous: ${previousRenderedNode.runtimeType}');
          print('🔍 UPDATE_COMPONENT: New: ${newRenderedNode.runtimeType}');
          canReconcile = true;
        } else {
          // Mixed types - this can happen when a component's render() returns different types
          // We can still reconcile if they're both DCFComponentNode
          if (previousRenderedNode is DCFComponentNode && newRenderedNode is DCFComponentNode) {
            canReconcile = true;
          } else {
            // Still attempt reconciliation - _reconcile will handle it
            canReconcile = true; // Allow reconciliation to proceed
          }
        }
        
        EngineDebugLogger.log(
            'RECONCILE_START', 'Starting reconciliation with previous node',
            extra: {
              'ComponentType': component.runtimeType.toString(),
              'PreviousType': previousRenderedNode.runtimeType.toString(),
              'NewType': newRenderedNode.runtimeType.toString(),
              'CanReconcile': canReconcile
            });

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
        
        // FINAL SAFEGUARD: After reconciliation, ensure the component's rendered element mapping is correct
        // This is critical for SafeArea re-renders that create new Button instances
        if (newRenderedNode is DCFElement) {
          final viewId = newRenderedNode.nativeViewId;
          if (viewId != null && viewId.isNotEmpty) {
            final mappedNode = _nodesByViewId[viewId];
            if (mappedNode != newRenderedNode) {
              _nodesByViewId[viewId] = newRenderedNode;
            }
          }
        } else if (newRenderedNode is DCFStatefulComponent || newRenderedNode is DCFStatelessComponent) {
          final renderedElement = newRenderedNode.renderedNode;
          if (renderedElement is DCFElement) {
            final viewId = renderedElement.nativeViewId;
            if (viewId != null && viewId.isNotEmpty) {
              final mappedNode = _nodesByViewId[viewId];
              if (mappedNode != renderedElement) {
                _nodesByViewId[viewId] = renderedElement;
              }
            }
          }
        }
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

      if (lifecycleInterceptor != null) {
        EngineDebugLogger.log(
            'LIFECYCLE_INTERCEPTOR', 'Calling afterUpdate interceptor');
        final context = VDomLifecycleContext(
          scheduleUpdate: () => _scheduleComponentUpdateInternal(component),
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
      if (node is DCFFragment) {
        EngineDebugLogger.log('RENDER_FRAGMENT', 'Rendering fragment node');

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

        if (!node.isMounted) {
          EngineDebugLogger.logMount(node, context: 'Fragment mounting');
          node.mount(node.parent);
        }

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

        node.childViewIds = childIds;
        EngineDebugLogger.log(
            'FRAGMENT_CHILDREN_COMPLETE', 'Fragment children rendered',
            extra: {'ChildCount': childIds.length, 'ChildIds': childIds});

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

      if (node is DCFStatefulComponent || node is DCFStatelessComponent) {
        EngineDebugLogger.log('RENDER_COMPONENT', 'Rendering component node',
            component: node.runtimeType.toString());

        try {
          final lifecycleInterceptor = VDomExtensionRegistry.instance
              .getLifecycleInterceptor(node.runtimeType);
          if (lifecycleInterceptor != null) {
            final context = VDomLifecycleContext(
              scheduleUpdate: () =>
                  _scheduleComponentUpdateInternal(node as DCFStatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': true},
            );
            lifecycleInterceptor.beforeMount(node, context);
          }

          registerComponent(node);

          final renderedNode = node.renderedNode;
          if (renderedNode == null) {
            EngineDebugLogger.logRender('ERROR', node,
                error: 'Component rendered null');
            throw Exception('Component rendered null');
          }

          print('🟡 COMPONENT RENDER: ${node.runtimeType} → ${renderedNode.runtimeType}');
          if (renderedNode is DCFElement) {
            print('🟡 COMPONENT RENDER: elementType=${renderedNode.type}, hasOnPress=${renderedNode.elementProps.containsKey('onPress')}');
          }

          EngineDebugLogger.log(
              'COMPONENT_RENDERED_NODE', 'Component rendered content',
              extra: {'RenderedType': renderedNode.runtimeType.toString()});

          renderedNode.parent = node;

          final viewId = await renderToNative(renderedNode,
              parentViewId: parentViewId, index: index);

          node.contentViewId = viewId;
          
          // CRITICAL: After rendering a component's rendered element, ensure the mapping is correct
          // This is essential for Button components inside SafeArea
          if (renderedNode is DCFElement && viewId != null && viewId.isNotEmpty) {
            final mappedNode = _nodesByViewId[viewId];
            if (mappedNode != renderedNode) {
              print('⚠️ COMPONENT RENDER FIX: viewId=$viewId, component=${node.runtimeType}, elementType=${renderedNode.type}');
              print('⚠️ COMPONENT RENDER FIX: mappedNode=${mappedNode?.runtimeType}, expected=${renderedNode.runtimeType}');
              _nodesByViewId[viewId] = renderedNode;
              print('✅ COMPONENT RENDER FIX: Fixed mapping for component\'s rendered element');
            } else {
              print('✅ COMPONENT RENDER: Mapping correct for viewId=$viewId');
            }
          }
          EngineDebugLogger.log(
              'COMPONENT_VIEW_ID', 'Component view ID assigned',
              extra: {'ViewId': viewId});

          if (node is DCFStatefulComponent && !node.isMounted) {
            EngineDebugLogger.log('LIFECYCLE_DID_MOUNT',
                'Calling componentDidMount for StatefulComponent');
            node.componentDidMount();

            EngineDebugLogger.log(
                'LIFECYCLE_EFFECTS_IMMEDIATE', 'Running immediate effects');
            node.runEffectsAfterRender();

            _componentsWaitingForLayout.add(node.instanceId);
            _componentsWaitingForInsertion.add(node.instanceId);

            _scheduleLayoutEffects(node);
          } else if (node is DCFStatelessComponent && !node.isMounted) {
            EngineDebugLogger.log('LIFECYCLE_DID_MOUNT',
                'Calling componentDidMount for StatelessComponent');
            node.componentDidMount();
          }

          if (lifecycleInterceptor != null) {
            final context = VDomLifecycleContext(
              scheduleUpdate: () =>
                  _scheduleComponentUpdateInternal(node as DCFStatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': false},
            );
            lifecycleInterceptor.afterMount(node, context);
          }

          EngineDebugLogger.logRender('SUCCESS', node, viewId: viewId);
          return viewId;
        } catch (error, stackTrace) {
          EngineDebugLogger.logRender('ERROR', node, error: error.toString());

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
      else if (node is DCFElement) {
        EngineDebugLogger.log('RENDER_ELEMENT', 'Rendering element node',
            extra: {'ElementType': node.type});
        return await _renderElementToNative(node,
            parentViewId: parentViewId, index: index);
      }
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
  void _scheduleLayoutEffects(DCFStatefulComponent component) {
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

    final viewId = element.nativeViewId ?? _generateViewId();

    print('🟣 ELEMENT RENDER: type=${element.type}, viewId=$viewId, hasOnPress=${element.elementProps.containsKey('onPress')}');
    if (element.type == 'Button') {
      print('🟣 BUTTON RENDER: viewId=$viewId, allProps=${element.elementProps.keys.toList()}');
      print('🟣 BUTTON RENDER: onPress exists=${element.elementProps.containsKey('onPress')}, isFunction=${element.elementProps['onPress'] is Function}');
    }
    _nodesByViewId[viewId] = element;
    element.nativeViewId = viewId;
    print('🟣 ELEMENT RENDER: Mapped element to viewId=$viewId');
    
    // Verify mapping immediately after setting
    final verifyMapped = _nodesByViewId[viewId];
    if (verifyMapped != element) {
      print('❌❌❌ ELEMENT RENDER MAPPING ERROR: viewId=$viewId was immediately overwritten!');
      print('❌❌❌ Expected: ${element.runtimeType}, Got: ${verifyMapped?.runtimeType}');
      _nodesByViewId[viewId] = element; // Fix it
      print('✅✅✅ ELEMENT RENDER: Fixed mapping');
    }
    EngineDebugLogger.log('ELEMENT_VIEW_MAPPING', 'Mapped element to view ID',
        extra: {'ViewId': viewId, 'ElementType': element.type});

    EngineDebugLogger.logBridge('CREATE_VIEW', viewId, data: {
      'ElementType': element.type,
      'Props': element.elementProps.keys.toList()
    });
    final success = await _nativeBridge.createView(
        viewId, element.type, element.elementProps);
    if (!success) {
      EngineDebugLogger.log(
          'ELEMENT_CREATE_FAILED', 'Failed to create native view',
          extra: {'ViewId': viewId, 'ElementType': element.type});
      return null;
    }

    if (parentViewId != null) {
      EngineDebugLogger.logBridge('ATTACH_VIEW', viewId,
          data: {'ParentViewId': parentViewId, 'Index': index ?? 0});
      await _nativeBridge.attachView(viewId, parentViewId, index ?? 0);
    }

    final eventTypes = element.eventTypes;
    if (eventTypes.isNotEmpty) {
      EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', viewId,
          data: {'EventTypes': eventTypes});
      await _nativeBridge.addEventListeners(viewId, eventTypes);
    } else {
      if (element.type == 'Button') {
        print('⚠️⚠️⚠️ BUTTON RENDER: No event types found for Button! viewId=$viewId');
        print('⚠️⚠️⚠️ BUTTON RENDER: elementProps=${element.elementProps.keys.toList()}');
      }
    }

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

    newNode.parent = oldNode.parent;

    // Component instance tracking by position + type + props
    // We maintain component instances across renders when at same position with same type
    final parentViewId = _findParentViewId(oldNode) ?? "root";
    final nodeIndex = _findNodeIndexInParent(oldNode);
    final positionKey = "$parentViewId:$nodeIndex:${newNode.runtimeType}";
    final propsHash = _computePropsHash(newNode);
    final propsKey = "$positionKey:$propsHash";
    
    // Try to find existing instance by position + type + props
    // This is automatic key inference - match by position when types/props match
    final existingByProps = _componentInstancesByProps[propsKey];
    
    // If we found an existing instance with same props, reuse it
    if (existingByProps != null && existingByProps.runtimeType == newNode.runtimeType) {
      if (existingByProps is DCFStatefulComponent && newNode is DCFStatefulComponent) {
        // Same component instance - update it instead of creating new one
        EngineDebugLogger.logReconcile('REUSE_INSTANCE_BY_PROPS', oldNode, newNode,
            reason: 'Reusing component instance by position+props');
        // Continue with reconciliation - this is the same instance
      }
    }
    
    // Track component instance by position and props (automatic key inference)
    _componentInstancesByPosition[positionKey] = newNode;
    _componentInstancesByProps[propsKey] = newNode;
    
    // Check keys first
    // Only replace if keys are explicitly different (both have keys)
    if (oldNode.key != null && newNode.key != null && oldNode.key != newNode.key) {
      EngineDebugLogger.logReconcile('REPLACE_KEY', oldNode, newNode,
          reason: 'Different keys - hot reload fix');
      await _replaceNode(oldNode, newNode);
      return;
    }
    
    // If no keys or same keys, match by position and type
    // This is automatic key inference - works in 99% of cases

    // For elements, check if they're the same element type
    if (oldNode is DCFElement && newNode is DCFElement) {
      if (oldNode.type != newNode.type) {
        print('🔍 RECONCILE: Element type changed: ${oldNode.type} → ${newNode.type}');
        print('⚛️  RECONCILE: Using full replacement (unmount + mount)');
        
        EngineDebugLogger.logReconcile('REPLACE_ELEMENT_TYPE', oldNode, newNode,
            reason: 'Different element types - full replacement');
        await _replaceNode(oldNode, newNode);
      } else {
        // Check if children differ significantly
        // We would use keys here, but we can detect structural differences
        // If children count differs significantly, it's likely conditional rendering
        // with completely different structures (e.g., theme switching)
        final oldChildCount = oldNode.children.length;
        final newChildCount = newNode.children.length;
        final countDiff = (oldChildCount - newChildCount).abs();
        
        // If children count differs by more than 3 or by 50%+, force replacement
        // This handles conditional rendering patterns where the same element type
        // returns completely different child structures
        final shouldForceReplace = countDiff > 3 || 
            (countDiff > 0 && countDiff >= (oldChildCount * 0.5).ceil());
        
        if (shouldForceReplace) {
          EngineDebugLogger.log('REPLACE_ELEMENT_CHILDREN_MISMATCH',
              'Significant children count difference - forcing replacement',
              extra: {
                'OldChildCount': oldChildCount,
                'NewChildCount': newChildCount,
                'CountDiff': countDiff,
                'ElementType': oldNode.type
              });
          EngineDebugLogger.logReconcile('REPLACE_ELEMENT_CHILDREN_MISMATCH', oldNode, newNode,
              reason: 'Significant children count difference - forcing replacement');
          await _replaceNode(oldNode, newNode);
        } else {
          EngineDebugLogger.logReconcile('UPDATE_ELEMENT', oldNode, newNode,
              reason: 'Same element type - updating props and children');
          await _reconcileElement(oldNode, newNode);
        }
      }
    }
    else if (oldNode is DCFStatefulComponent && newNode is DCFStatefulComponent) {
      // Different component classes mean different components entirely
      if (oldNode.runtimeType != newNode.runtimeType) {
        print('🔍 RECONCILE: Different StatefulComponent types: ${oldNode.runtimeType} → ${newNode.runtimeType}');
        EngineDebugLogger.logReconcile('REPLACE_COMPONENT_TYPE', oldNode, newNode,
            reason: 'Different StatefulComponent types - full replacement');
        await _replaceNode(oldNode, newNode);
        return;
      }
      
      if (identical(oldNode, newNode)) {
        print('🔍 RECONCILE: Same StatefulComponent instance - skipping');
        newNode.nativeViewId = oldNode.nativeViewId;
        newNode.contentViewId = oldNode.contentViewId;
        newNode.parent = oldNode.parent;
        newNode.renderedNode = oldNode.renderedNode;

        _statefulComponents[newNode.instanceId] = newNode;
        newNode.scheduleUpdate = () => _scheduleComponentUpdate(newNode);

        return;
      }

      print('🔍 RECONCILE: Different StatefulComponent instances (same type)');
      EngineDebugLogger.logReconcile('UPDATE_STATEFUL', oldNode, newNode,
          reason: 'Reconciling StatefulComponent');

      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      _statefulComponents[newNode.instanceId] = newNode;
      newNode.scheduleUpdate = () => _scheduleComponentUpdate(newNode);

      registerComponent(newNode);

      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;

      print('🔍 RECONCILE: Rendered nodes - old: ${oldRenderedNode.runtimeType}, new: ${newRenderedNode.runtimeType}');
      if (oldRenderedNode is DCFElement && newRenderedNode is DCFElement) {
        print('🔍 RECONCILE: Element types - old: ${oldRenderedNode.type}, new: ${newRenderedNode.type}');
      }

      await _reconcile(oldRenderedNode, newRenderedNode);
      
      // CRITICAL: After reconciling rendered nodes, ensure the mapping points to the NEW rendered element
      // This is essential for components like DCFButton that render DCFElement instances
      // When SafeArea re-renders, it creates new Button instances, and we must ensure
      // the mapping points to the new Button's rendered element (not the old one)
      if (newRenderedNode is DCFElement) {
        final renderedViewId = newRenderedNode.nativeViewId;
        if (renderedViewId != null && renderedViewId.isNotEmpty) {
          final mappedNode = _nodesByViewId[renderedViewId];
          if (mappedNode != newRenderedNode) {
            EngineDebugLogger.log('RECONCILE_STATEFUL_RENDERED_FIX',
                '⚠️ Fixed mapping for stateful component\'s rendered element',
                extra: {
                  'ViewId': renderedViewId,
                  'ElementType': newRenderedNode.type,
                  'HasOnPress': newRenderedNode.elementProps.containsKey('onPress'),
                  'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                });
            _nodesByViewId[renderedViewId] = newRenderedNode;
          }
          
          // CRITICAL: If this is a View element (like SafeArea's DCFView), ensure ALL child Button mappings are preserved
          // This is the root cause: when SafeArea re-renders, its DCFView reconciles, and Button children
          // might lose their mappings during child reconciliation
          if (newRenderedNode.type == 'View' && newRenderedNode.children.isNotEmpty) {
            for (final child in newRenderedNode.children) {
              final childViewId = child.effectiveNativeViewId;
              if (childViewId != null && childViewId.isNotEmpty) {
                if (child is DCFElement) {
                  final childMapped = _nodesByViewId[childViewId];
                  if (childMapped != child) {
                    EngineDebugLogger.log('RECONCILE_STATEFUL_VIEW_CHILD_FIX',
                        '⚠️ Fixed Button child mapping in SafeArea View',
                        extra: {
                          'ViewId': childViewId,
                          'ChildType': child.type,
                          'HasOnPress': child.elementProps.containsKey('onPress')
                        });
                    _nodesByViewId[childViewId] = child;
                  }
                } else if (child is DCFStatelessComponent || child is DCFStatefulComponent) {
                  final renderedElement = child.renderedNode;
                  if (renderedElement is DCFElement) {
                    final renderedViewId = renderedElement.nativeViewId;
                    if (renderedViewId != null && renderedViewId.isNotEmpty) {
                      final renderedMapped = _nodesByViewId[renderedViewId];
                      if (renderedMapped != renderedElement) {
                        EngineDebugLogger.log('RECONCILE_STATEFUL_VIEW_CHILD_COMPONENT_FIX',
                            '⚠️ Fixed Button component child mapping in SafeArea View',
                            extra: {
                              'RenderedViewId': renderedViewId,
                              'ElementType': renderedElement.type,
                              'HasOnPress': renderedElement.elementProps.containsKey('onPress')
                            });
                        _nodesByViewId[renderedViewId] = renderedElement;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } else if (newRenderedNode is DCFStatefulComponent || newRenderedNode is DCFStatelessComponent) {
        // For nested components, traverse to find the actual element
        DCFComponentNode? current = newRenderedNode;
        DCFElement? actualElement;
        while (current != null) {
          if (current is DCFElement) {
            actualElement = current;
            break;
          } else if (current is DCFStatefulComponent || current is DCFStatelessComponent) {
            current = current.renderedNode;
          } else {
            break;
          }
        }
        if (actualElement != null) {
          final elementViewId = actualElement.nativeViewId;
          if (elementViewId != null && elementViewId.isNotEmpty) {
            final mappedNode = _nodesByViewId[elementViewId];
            if (mappedNode != actualElement) {
              EngineDebugLogger.log('RECONCILE_STATEFUL_NESTED_ELEMENT_FIX',
                  '⚠️ Fixed mapping for nested component\'s rendered element',
                  extra: {
                    'ViewId': elementViewId,
                    'ElementType': actualElement.type,
                    'HasOnPress': actualElement.elementProps.containsKey('onPress')
                  });
              _nodesByViewId[elementViewId] = actualElement;
            }
          }
        }
      }
    }
    else if (oldNode is DCFStatelessComponent && newNode is DCFStatelessComponent) {
      // Different component classes (e.g., DCFView vs DCFScrollView) mean different components
      // We need to reconcile their RENDERED elements, not the components themselves
      if (oldNode.runtimeType != newNode.runtimeType) {
        print('🔍 RECONCILE: Different StatelessComponent types: ${oldNode.runtimeType} → ${newNode.runtimeType}');
        print('🔍 RECONCILE: Reconciling rendered elements instead');
        EngineDebugLogger.logReconcile('RECONCILE_STATELESS_VIA_ELEMENTS', oldNode, newNode,
            reason: 'Different StatelessComponent types - reconcile via rendered elements');
        
        // Instead of replacing the component, reconcile the rendered elements
        // This allows proper View → ScrollView transitions with element-level reconciliation
        final oldRenderedNode = oldNode.renderedNode;
        final newRenderedNode = newNode.renderedNode;
        
        // Transfer view IDs to new component
        newNode.nativeViewId = oldNode.nativeViewId;
        newNode.contentViewId = oldNode.contentViewId;
        
        print('🔍 RECONCILE: oldRendered: ${oldRenderedNode.runtimeType}, newRendered: ${newRenderedNode.runtimeType}');
        if (oldRenderedNode is DCFElement && newRenderedNode is DCFElement) {
          print('🔍 RECONCILE: Element types: ${oldRenderedNode.type} → ${newRenderedNode.type}');
        }
        
        // Step 1: Update this component's renderedNode to point to the new element
        print('🔄 PRE-RECONCILE: Updating ${newNode.runtimeType} renderedNode to new element');
        newNode.renderedNode = newRenderedNode;
        
        // Step 2: Update all ancestors' renderedNode to point to this NEW component
        DCFComponentNode? ancestor = newNode.parent;
        while (ancestor != null) {
          if (ancestor is DCFStatefulComponent) {
            print('🔄 PRE-RECONCILE: Updating ancestor ${ancestor.runtimeType} renderedNode to point to new component');
            ancestor.renderedNode = newNode;
            break; // Only update the direct parent, not all ancestors
          }
          ancestor = ancestor.parent;
        }
        
        await _reconcile(oldRenderedNode, newRenderedNode);
        
        if (newRenderedNode is DCFElement && newRenderedNode.nativeViewId != null) {
          final newElementViewId = newRenderedNode.nativeViewId!;
          if (newElementViewId != newNode.contentViewId) {
            print('🔄 RECONCILE: Updating component contentViewId: ${newNode.contentViewId} → $newElementViewId');
            newNode.contentViewId = newElementViewId;
          }
          
          final oldElementViewId = oldRenderedNode is DCFElement ? oldRenderedNode.nativeViewId : null;
          print('🔄 RECONCILE: Walking up tree to update ancestors (oldId: $oldElementViewId, newId: $newElementViewId)');
          
          DCFComponentNode? ancestor = newNode.parent;
          while (ancestor != null) {
            if (ancestor is DCFStatefulComponent || ancestor is DCFStatelessComponent) {
              // Always update the FIRST component ancestor (the direct parent)
              // OR update any ancestor whose nativeViewId matches the old element's ID
              if (ancestor == newNode.parent || 
                  (oldElementViewId != null && ancestor.nativeViewId == oldElementViewId)) {
                print('🔄 RECONCILE: Updating ancestor ${ancestor.runtimeType} nativeViewId: ${ancestor.nativeViewId} → $newElementViewId');
                ancestor.nativeViewId = newElementViewId;
              }
            }
            ancestor = ancestor.parent;
          }
        }
        
        return;
      }
      
      EngineDebugLogger.logReconcile('UPDATE_STATELESS', oldNode, newNode,
          reason:
              'StatelessComponent reconciliation - always check rendered content');

      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      registerComponent(newNode);

      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;

      print('🟢 STATELESS RECONCILE: ${oldNode.runtimeType} → ${newNode.runtimeType}');
      print('🟢 STATELESS RECONCILE: oldRendered=${oldRenderedNode.runtimeType}, newRendered=${newRenderedNode.runtimeType}');
      if (oldRenderedNode is DCFElement && newRenderedNode is DCFElement) {
        print('🟢 STATELESS RECONCILE: oldElement viewId=${oldRenderedNode.nativeViewId}, type=${oldRenderedNode.type}');
        print('🟢 STATELESS RECONCILE: newElement viewId=${newRenderedNode.nativeViewId}, type=${newRenderedNode.type}');
        print('🟢 STATELESS RECONCILE: oldElement hasOnPress=${oldRenderedNode.elementProps.containsKey('onPress')}');
        print('🟢 STATELESS RECONCILE: newElement hasOnPress=${newRenderedNode.elementProps.containsKey('onPress')}');
      }
      
      await _reconcile(oldRenderedNode, newRenderedNode);
      
      // CRITICAL: After reconciling rendered nodes, ensure the mapping points to the NEW rendered element
      // This is essential for components like DCFButton that render DCFElement instances
      // When SafeArea re-renders, it creates new Button instances, and we must ensure
      // the mapping points to the new Button's rendered element (not the old one)
      if (newRenderedNode is DCFElement) {
        final renderedViewId = newRenderedNode.nativeViewId;
        print('🟢 STATELESS POST-RECONCILE: renderedViewId=$renderedViewId, elementType=${newRenderedNode.type}');
        if (renderedViewId != null && renderedViewId.isNotEmpty) {
          final mappedNode = _nodesByViewId[renderedViewId];
          print('🟢 STATELESS POST-RECONCILE: mappedNode=${mappedNode?.runtimeType}, newRenderedNode=${newRenderedNode.runtimeType}');
          print('🟢 STATELESS POST-RECONCILE: mapping matches=${mappedNode == newRenderedNode}');
          if (mappedNode != newRenderedNode) {
            print('⚠️ STATELESS FIXING MAPPING: viewId=$renderedViewId');
            EngineDebugLogger.log('RECONCILE_STATELESS_RENDERED_FIX',
                '⚠️ Fixed mapping for stateless component\'s rendered element',
                extra: {
                  'ViewId': renderedViewId,
                  'ElementType': newRenderedNode.type,
                  'HasOnPress': newRenderedNode.elementProps.containsKey('onPress'),
                  'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                });
            _nodesByViewId[renderedViewId] = newRenderedNode;
            print('✅ STATELESS MAPPING FIXED: viewId=$renderedViewId now maps to ${newRenderedNode.runtimeType}');
          } else {
            print('✅ STATELESS MAPPING OK: viewId=$renderedViewId correctly mapped');
          }
        } else {
          print('❌ STATELESS NO VIEWID: renderedViewId is null or empty!');
        }
      } else if (newRenderedNode is DCFStatefulComponent || newRenderedNode is DCFStatelessComponent) {
        // For nested components, traverse to find the actual element
        DCFComponentNode? current = newRenderedNode;
        DCFElement? actualElement;
        while (current != null) {
          if (current is DCFElement) {
            actualElement = current;
            break;
          } else if (current is DCFStatefulComponent || current is DCFStatelessComponent) {
            current = current.renderedNode;
          } else {
            break;
          }
        }
        if (actualElement != null) {
          final elementViewId = actualElement.nativeViewId;
          if (elementViewId != null && elementViewId.isNotEmpty) {
            final mappedNode = _nodesByViewId[elementViewId];
            if (mappedNode != actualElement) {
              EngineDebugLogger.log('RECONCILE_STATELESS_NESTED_ELEMENT_FIX',
                  '⚠️ Fixed mapping for nested stateless component\'s rendered element',
                  extra: {
                    'ViewId': elementViewId,
                    'ElementType': actualElement.type,
                    'HasOnPress': actualElement.elementProps.containsKey('onPress')
                  });
              _nodesByViewId[elementViewId] = actualElement;
            }
            
            // CRITICAL: After fixing the View element mapping, ensure ALL Button children mappings are correct
            // This is the root cause: when SafeArea's DCFView reconciles, Button children might lose their mappings
            if (actualElement.type == 'View' && actualElement.children.isNotEmpty) {
              for (final child in actualElement.children) {
                if (child is DCFStatefulComponent || child is DCFStatelessComponent) {
                  final renderedElement = child.renderedNode;
                  if (renderedElement is DCFElement) {
                    final childViewId = renderedElement.nativeViewId;
                    if (childViewId != null && childViewId.isNotEmpty) {
                      final childMappedNode = _nodesByViewId[childViewId];
                      if (childMappedNode != renderedElement) {
                        _nodesByViewId[childViewId] = renderedElement;
                        EngineDebugLogger.log('RECONCILE_STATELESS_CHILD_BUTTON_FIX',
                            '⚠️ Fixed Button child mapping after DCFView reconciliation',
                            extra: {
                              'ViewId': childViewId,
                              'ElementType': renderedElement.type,
                              'HasOnPress': renderedElement.elementProps.containsKey('onPress')
                            });
                      }
                    }
                  }
                } else if (child is DCFElement) {
                  final childViewId = child.nativeViewId;
                  if (childViewId != null && childViewId.isNotEmpty) {
                    final childMappedNode = _nodesByViewId[childViewId];
                    if (childMappedNode != child) {
                      _nodesByViewId[childViewId] = child;
                      EngineDebugLogger.log('RECONCILE_STATELESS_CHILD_ELEMENT_FIX',
                          '⚠️ Fixed child element mapping after DCFView reconciliation',
                          extra: {
                            'ViewId': childViewId,
                            'ElementType': child.type,
                            'HasOnPress': child.elementProps.containsKey('onPress')
                          });
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    else if (oldNode is DCFFragment && newNode is DCFFragment) {
      EngineDebugLogger.logReconcile('UPDATE_FRAGMENT', oldNode, newNode,
          reason: 'Reconciling Fragment');

      newNode.parent = oldNode.parent;
      newNode.childViewIds = oldNode.childViewIds;

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

    await _disposeOldComponent(oldNode);

    if (oldNode.effectiveNativeViewId == null) {
      EngineDebugLogger.log(
          'REPLACE_NODE_NO_VIEW_ID', 'Old node has no view ID, cannot replace');
      return;
    }

    final parentViewId = _findParentViewId(oldNode);
    print('🔍 REPLACE: Parent chain for oldNode:');
    print('🔍 REPLACE: oldNode type: ${oldNode.runtimeType}, viewId: ${oldNode.effectiveNativeViewId}');
    print('🔍 REPLACE: oldNode.parent type: ${oldNode.parent?.runtimeType}, viewId: ${oldNode.parent?.effectiveNativeViewId}');
    print('🔍 REPLACE: Found parentViewId: $parentViewId');
    
    if (parentViewId == null) {
      EngineDebugLogger.log(
          'REPLACE_NODE_NO_PARENT', 'No parent view ID found');
      return;
    }

    final index = _findNodeIndexInParent(oldNode);
    EngineDebugLogger.log('REPLACE_NODE_POSITION', 'Found replacement position',
        extra: {'ParentViewId': parentViewId, 'Index': index});

    // DON'T pause batch mode - queue operations atomically instead
    final wasBatchMode = _batchUpdateInProgress;

    try {
      final oldViewId = oldNode.effectiveNativeViewId!;
      
      // Get event types from rendered elements, not components
      final oldEventTypes = <String>[];
      if (oldNode is DCFElement) {
        oldEventTypes.addAll(oldNode.eventTypes);
      } else if (oldNode is DCFStatefulComponent || oldNode is DCFStatelessComponent) {
        final oldRendered = oldNode.renderedNode;
        if (oldRendered is DCFElement) {
          oldEventTypes.addAll(oldRendered.eventTypes);
        }
      }
      
      final newEventTypes = <String>[];
      if (newNode is DCFElement) {
        newEventTypes.addAll(newNode.eventTypes);
      } else if (newNode is DCFStatefulComponent || newNode is DCFStatelessComponent) {
        // For components, we need to render first to get the rendered element
        // But we can check if it's already rendered
        final newRendered = newNode.renderedNode;
        if (newRendered is DCFElement) {
          newEventTypes.addAll(newRendered.eventTypes);
        }
      }

      EngineDebugLogger.log('REPLACE_EVENT_TYPES', 'Comparing event types',
          extra: {'OldEvents': oldEventTypes, 'NewEvents': newEventTypes});

      // Special case: Component to Fragment replacement requires full delete/recreate
      if (newNode is DCFStatefulComponent || newNode is DCFStatelessComponent) {
        final renderedNode = newNode.renderedNode;
        if (renderedNode is DCFFragment) {
          EngineDebugLogger.log('REPLACE_COMPONENT_TO_FRAGMENT',
              'Replacing component with fragment renderer - full recreate');
          
          // Ensure batch mode for atomic delete+create
          if (!wasBatchMode) {
            await _nativeBridge.startBatchUpdate();
          }
          
          EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
          await _nativeBridge.deleteView(oldViewId);
          _nodesByViewId.remove(oldViewId);

          await renderToNative(newNode,
              parentViewId: parentViewId, index: index);
          
          // Only commit if we started the batch
          if (!wasBatchMode) {
            await _nativeBridge.commitBatchUpdate();
          }
          return;
        }
      }

      // Check if this is an element type change (e.g., View → ScrollView)
      final isElementTypeChange = (oldNode is DCFElement && newNode is DCFElement) &&
          (oldNode.type != newNode.type);
      
      if (isElementTypeChange) {
        // For element type changes, we MUST generate a new view ID
        // because the old view will be deleted and we can't reuse its ID
        print('🔄 REPLACE: Element type change detected - generating new view ID');
        EngineDebugLogger.log(
            'REPLACE_NEW_VIEW_ID', 'Generating new view ID for element type change',
            extra: {'OldViewId': oldViewId, 'OldType': (oldNode as DCFElement).type, 
                    'NewType': (newNode as DCFElement).type});
        
        // Don't set nativeViewId on newNode - let renderToNative generate a new one
        _nodesByViewId.remove(oldViewId);
      } else {
        // For other replacements, reuse the view ID
        // CRITICAL: Only map ELEMENTS to _nodesByViewId, not components!
        // Events look up nodes by view ID and only work with DCFElement
        if (newNode is DCFElement) {
          newNode.nativeViewId = oldViewId;
          _nodesByViewId[oldViewId] = newNode;
        } else if (newNode is DCFStatefulComponent || newNode is DCFStatelessComponent) {
          // For components, set contentViewId but DON'T map the component itself
          // We'll map the rendered element after renderToNative creates it
          // Remove old mapping first to avoid stale references
          _nodesByViewId.remove(oldViewId);
          newNode.contentViewId = oldViewId;
        }
        EngineDebugLogger.log(
            'REPLACE_REUSE_VIEW_ID', 'Reusing view ID for in-place replacement',
            extra: {'ViewId': oldViewId, 'NodeType': newNode.runtimeType.toString()});
      }

      // Only update event listeners if we're reusing the view ID
      if (!isElementTypeChange) {
        final oldEventSet = Set<String>.from(oldEventTypes);
        final newEventSet = Set<String>.from(newEventTypes);

        if (oldEventSet.length != newEventSet.length ||
            !oldEventSet.containsAll(newEventSet)) {
          EngineDebugLogger.log(
              'REPLACE_UPDATE_EVENTS', 'Updating event listeners');

          final eventsToRemove = oldEventSet.difference(newEventSet);
          if (eventsToRemove.isNotEmpty) {
            EngineDebugLogger.logBridge('REMOVE_EVENT_LISTENERS', oldViewId,
                data: {'EventTypes': eventsToRemove.toList()});
            await _nativeBridge.removeEventListeners(
                oldViewId, eventsToRemove.toList());
          }

          final eventsToAdd = newEventSet.difference(oldEventSet);
          if (eventsToAdd.isNotEmpty) {
            EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', oldViewId,
                data: {'EventTypes': eventsToAdd.toList()});
            await _nativeBridge.addEventListeners(
                oldViewId, eventsToAdd.toList());
          }
        }
      }

      // Ensure batch mode for atomic delete+create sequence
      if (!wasBatchMode) {
        await _nativeBridge.startBatchUpdate();
      }
      
      // CRITICAL: Create the new view BEFORE deleting the old one to prevent white screen
      // This ensures there's always a view visible during the transition
      final newViewId = await renderToNative(newNode,
          parentViewId: parentViewId, index: index);
      
      // Only delete the old view after the new one is created and attached
      EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
      await _nativeBridge.deleteView(oldViewId);

      // Commit the atomic delete+create if we started the batch
      if (!wasBatchMode) {
        await _nativeBridge.commitBatchUpdate();
      }

      // CRITICAL: Ensure view ID is set IMMEDIATELY after renderToNative returns
      // This must happen before any other code tries to read effectiveNativeViewId
      if (newViewId != null && newViewId.isNotEmpty) {
        // Ensure the newNode has the view ID set correctly
        if (newNode is DCFElement) {
          newNode.nativeViewId = newViewId;
          _nodesByViewId[newViewId] = newNode;
        } else if (newNode is DCFStatefulComponent || newNode is DCFStatelessComponent) {
          // For components, set contentViewId IMMEDIATELY
          // renderToNative should have already done this, but we MUST ensure it's set
          newNode.contentViewId = newViewId;
          
          // Also ensure the rendered node has the view ID if it's an element
          // CRITICAL: We MUST map an element to _nodesByViewId for events to work
          final renderedNode = newNode.renderedNode;
          if (renderedNode != null) {
            if (renderedNode is DCFElement) {
              // Always update the rendered element's view ID to match
              renderedNode.nativeViewId = newViewId;
              _nodesByViewId[newViewId] = renderedNode;
            } else if (renderedNode is DCFStatefulComponent || renderedNode is DCFStatelessComponent) {
              // For nested components, traverse down to find the actual element
              // This ensures events can find the element even with nested components
              DCFComponentNode? current = renderedNode;
              DCFElement? actualElement;
              while (current != null) {
                if (current is DCFElement) {
                  actualElement = current;
                  break;
                } else if (current is DCFStatefulComponent || current is DCFStatelessComponent) {
                  current = current.renderedNode;
                } else {
                  break;
                }
              }
              if (actualElement != null) {
                actualElement.nativeViewId = newViewId;
                _nodesByViewId[newViewId] = actualElement;
              } else {
                // Fallback: ensure nested component's contentViewId is set
                if (renderedNode.contentViewId != newViewId) {
                  renderedNode.contentViewId = newViewId;
                }
              }
            }
          } else {
            // If renderedNode is null, log a warning but don't crash
            EngineDebugLogger.log('REPLACE_NODE_NO_RENDERED_NODE',
                '⚠️ Component has no renderedNode after renderToNative',
                extra: {'ComponentType': newNode.runtimeType.toString(), 'ViewId': newViewId});
          }
          
          // Double-check: Verify effectiveNativeViewId is now correct
          final effectiveId = newNode.effectiveNativeViewId;
          if (effectiveId != newViewId) {
            EngineDebugLogger.log('REPLACE_NODE_VIEW_ID_MISMATCH',
                '⚠️ View ID mismatch after setting - forcing correction',
                extra: {
                  'ExpectedViewId': newViewId,
                  'EffectiveViewId': effectiveId,
                  'ContentViewId': newNode.contentViewId,
                  'NativeViewId': newNode.nativeViewId
                });
            // Force set it again
            newNode.contentViewId = newViewId;
          }
          
          // 🔥 CRITICAL: Always register event listeners after renderToNative for components
          // This ensures events work after component-to-component replacement
          // renderToNative should have registered them, but we ensure it here as a safety net
          final renderedElement = newNode.renderedNode;
          if (renderedElement is DCFElement && renderedElement.eventTypes.isNotEmpty) {
            final actualEventTypes = renderedElement.eventTypes;
            // Always register - renderToNative might have done it, but double-registration is safe
            // and ensures events work even if renderToNative's registration failed
            EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', newViewId,
                data: {'EventTypes': actualEventTypes});
            await _nativeBridge.addEventListeners(newViewId, actualEventTypes);
            print('✅ REPLACE: Event listeners registered for component viewId=$newViewId, eventTypes=$actualEventTypes');
          } else if (newNode is DCFElement && newNode.eventTypes.isNotEmpty) {
            // For direct element replacement, ensure events are registered
            EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', newViewId,
                data: {'EventTypes': newNode.eventTypes});
            await _nativeBridge.addEventListeners(newViewId, newNode.eventTypes);
            print('✅ REPLACE: Event listeners registered for element viewId=$newViewId, eventTypes=${newNode.eventTypes}');
          }
        }
        
        EngineDebugLogger.log(
            'REPLACE_NODE_SUCCESS', 'Node replacement completed successfully',
            extra: {
              'NewViewId': newViewId, 
              'AtomicBatch': !wasBatchMode,
              'EffectiveViewId': newNode.effectiveNativeViewId,
              'ContentViewId': (newNode is DCFStatefulComponent || newNode is DCFStatelessComponent) 
                  ? newNode.contentViewId 
                  : null,
              'NativeViewId': (newNode is DCFElement) 
                  ? newNode.nativeViewId 
                  : null,
              'NodeType': newNode.runtimeType.toString()
            });
      } else {
        EngineDebugLogger.log('REPLACE_NODE_FAILED',
            'Node replacement failed - no view ID returned',
            extra: {
              'NodeType': newNode.runtimeType.toString(),
              'ParentViewId': parentViewId,
              'Index': index
            });
      }
    } finally {
      // DON'T restart batch - it's already running or wasn't needed
      // The original wasBatchMode state is preserved automatically
    }

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

      if (oldNode is DCFStatefulComponent) {
        EngineDebugLogger.log('DISPOSE_STATEFUL', 'Disposing StatefulComponent',
            extra: {'InstanceId': oldNode.instanceId});

        _statefulComponents.remove(oldNode.instanceId);
        _pendingUpdates.remove(oldNode.instanceId);
        _previousRenderedNodes.remove(oldNode.instanceId);
        _componentPriorities.remove(oldNode.instanceId);

        _componentsWaitingForLayout.remove(oldNode.instanceId);
        _componentsWaitingForInsertion.remove(oldNode.instanceId);

        try {
          oldNode.componentWillUnmount();
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT',
              'Called componentWillUnmount for StatefulComponent');
        } catch (e) {
          EngineDebugLogger.log(
              'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
              extra: {'Error': e.toString()});
        }

        await _disposeOldComponent(oldNode.renderedNode);
      }
      else if (oldNode is DCFStatelessComponent) {
        EngineDebugLogger.log(
            'DISPOSE_STATELESS', 'Disposing StatelessComponent',
            extra: {'ComponentType': oldNode.runtimeType.toString()});


        try {
          oldNode.componentWillUnmount();
          EngineDebugLogger.log('LIFECYCLE_WILL_UNMOUNT',
              'Called componentWillUnmount for StatelessComponent');
        } catch (e) {
          EngineDebugLogger.log(
              'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
              extra: {'Error': e.toString()});
        }

        await _disposeOldComponent(oldNode.renderedNode);
      }
      else if (oldNode is DCFElement) {
        EngineDebugLogger.log('DISPOSE_ELEMENT', 'Disposing DCFElement',
            extra: {
              'ElementType': oldNode.type,
              'ChildCount': oldNode.children.length
            });

        for (final child in oldNode.children) {
          await _disposeOldComponent(child);
        }
      }

      if (oldNode.effectiveNativeViewId != null) {
        _nodesByViewId.remove(oldNode.effectiveNativeViewId);
        EngineDebugLogger.log(
            'DISPOSE_VIEW_TRACKING', 'Removed from view tracking',
            extra: {'ViewId': oldNode.effectiveNativeViewId});
      }

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

    if (rootComponent != null && rootComponent != component) {
      EngineDebugLogger.log('CREATE_ROOT_HOT_RESTART',
          'Hot restart detected. Tearing down old VDOM state.');

      // 🔥 CRITICAL: Cancel ALL pending async work FIRST
      // This prevents timers and microtasks from firing after cleanup
      cancelAllPendingWork();
      
      // Small delay to let any in-flight timers/microtasks drain
      await Future.delayed(Duration(milliseconds: 50));

      await _disposeOldComponent(rootComponent!);

      _statefulComponents.clear();
      _nodesByViewId.clear();
      _previousRenderedNodes.clear();
      _pendingUpdates.clear();
      _componentPriorities.clear();
      _errorBoundaries.clear();
      _componentInstancesByPosition.clear();
      _componentInstancesByProps.clear();

      _componentsWaitingForLayout.clear();
      _componentsWaitingForInsertion.clear();
      _isTreeComplete = false;

      EngineDebugLogger.log(
          'VDOM_STATE_CLEARED', 'All VDOM tracking maps have been cleared.');
      EngineDebugLogger.reset();

      rootComponent = component;
      
      await _nativeBridge.startBatchUpdate();
      await renderToNative(component, parentViewId: "root");
      await _nativeBridge.commitBatchUpdate();
      
      setRootComponent(component);

      EngineDebugLogger.log('CREATE_ROOT_COMPLETE',
          'Root component re-created successfully after hot restart.');
    } else {
      EngineDebugLogger.log(
          'CREATE_ROOT_FIRST', 'Creating first root component');
      rootComponent = component;

      await _nativeBridge.startBatchUpdate();
      final viewId = await renderToNative(component, parentViewId: "root");
      await _nativeBridge.commitBatchUpdate();
      
      setRootComponent(component);

      EngineDebugLogger.log(
          'CREATE_ROOT_COMPLETE', 'Root component created successfully',
          extra: {'ViewId': viewId});
    }
  }

  /// Delete a view from the native side
  Future<void> deleteView(String viewId) async {
    await isReady;
    EngineDebugLogger.logBridge('DELETE_VIEW', viewId);
    await _nativeBridge.deleteView(viewId);
    _nodesByViewId.remove(viewId);
  }
  
  /// Start a batch update (for atomic operations)
  Future<void> startBatchUpdate() async {
    await isReady;
    if (!_batchUpdateInProgress) {
      _batchUpdateInProgress = true;
      await _nativeBridge.startBatchUpdate();
    }
  }
  
  /// Commit a batch update
  Future<void> commitBatchUpdate() async {
    await isReady;
    if (_batchUpdateInProgress) {
      _batchUpdateInProgress = false;
      await _nativeBridge.commitBatchUpdate();
    }
  }
  
  /// Force a complete re-render of the entire component tree for hot reload support
  /// This re-executes all render() methods while preserving navigation state
  Future<void> forceFullTreeReRender() async {
    if (rootComponent == null) {
      EngineDebugLogger.log(
          'HOT_RELOAD_ERROR', 'No root component to re-render');
      return;
    }

    EngineDebugLogger.log(
        'HOT_RELOAD_START', 'Starting full tree re-render for hot reload');

    try {
      for (final component in _statefulComponents.values) {
        _scheduleComponentUpdate(component);
      }

      await _processPendingUpdates();

      EngineDebugLogger.log(
          'HOT_RELOAD_COMPLETE', 'Full tree re-render completed successfully');
    } catch (e) {
      EngineDebugLogger.log(
          'HOT_RELOAD_ERROR', 'Failed to complete hot reload: $e');
      rethrow;
    }
  }

  /// O(tree depth) - Find a node's parent view ID
  /// This walks up the tree to find the actual rendered element, not cached nativeViewIds
  String? _findParentViewId(DCFComponentNode node) {
    print('🔍 PARENT_SEARCH: Starting search for parent of ${node.runtimeType} (viewId: ${node.effectiveNativeViewId})');
    final nodeViewId = node.effectiveNativeViewId;
    DCFComponentNode? current = node.parent;

    while (current != null) {
      print('🔍 PARENT_SEARCH: Checking ancestor: ${current.runtimeType}');
      
      // For components, look at their ACTUAL rendered element's ID, not the component's cached nativeViewId
      if (current is DCFStatelessComponent || current is DCFStatefulComponent) {
        // Get the component's rendered node
        final renderedNode = (current is DCFStatefulComponent) 
            ? current.renderedNode 
            : (current is DCFStatelessComponent ? current.renderedNode : null);
        
        print('🔍 PARENT_SEARCH: ${current.runtimeType} has renderedNode: ${renderedNode?.runtimeType}');
        
        if (renderedNode is DCFElement) {
          print('🔍 PARENT_SEARCH: renderedNode is DCFElement with type: ${renderedNode.type}, viewId: ${renderedNode.nativeViewId}');
        }
        
        if (renderedNode != null && renderedNode is DCFStatelessComponent) {
          print('🔍 PARENT_SEARCH: renderedNode is StatelessComponent, drilling down to its element...');
          final deepRendered = renderedNode.renderedNode;
          if (deepRendered is DCFElement) {
            print('🔍 PARENT_SEARCH: deepRendered element type: ${deepRendered.type}, nativeViewId: ${deepRendered.nativeViewId}');
            
            if (deepRendered.nativeViewId != null) {
              final deepViewId = deepRendered.nativeViewId!;
              
              if (nodeViewId != null && deepViewId == nodeViewId) {
                print('🔍 PARENT_SEARCH: Skipping deep rendered viewId ($deepViewId) - same as node');
                current = current.parent;
                continue;
              }
              
              print('🔍 PARENT_SEARCH: Found parent via DEEP rendered element: $deepViewId');
              return deepViewId;
            } else {
              print('🔍 PARENT_SEARCH: deepRendered has no nativeViewId yet, skipping this ancestor');
              current = current.parent;
              continue;
            }
          }
        }
        
        if (renderedNode is DCFElement && renderedNode.nativeViewId != null) {
          final renderedViewId = renderedNode.nativeViewId!;
          
          // Skip if this is the same view ID as the node we're looking for a parent for
          if (nodeViewId != null && renderedViewId == nodeViewId) {
            print('🔍 PARENT_SEARCH: Skipping parent with same viewId ($renderedViewId) as node');
            current = current.parent;
            continue;
          }
          
          print('🔍 PARENT_SEARCH: Found parent via rendered element: $renderedViewId (${current.runtimeType})');
          return renderedViewId;
        }
      }
      
      // For components without a rendered element with a valid nativeViewId, skip to next ancestor
      // DO NOT use effectiveNativeViewId here as it can return stale contentViewIds
      print('🔍 PARENT_SEARCH: No valid viewId for ${current.runtimeType}, moving to next ancestor');
      current = current.parent;
    }

    print('🔍 PARENT_SEARCH: Reached end of tree, using root');
    EngineDebugLogger.log(
        'PARENT_VIEW_DEFAULT', 'No parent view found, using root');
    return "root"; // Default to root if no parent found
  }

  /// Enhanced find node index that works for components too
  int _findNodeIndexInParent(DCFComponentNode node) {
    if (node.parent == null) {
      return 0;
    }

    if (node.parent is DCFElement) {
      final parent = node.parent as DCFElement;
      return parent.children.indexOf(node);
    } else if (node.parent is DCFFragment) {
      final parent = node.parent as DCFFragment;
      return parent.children.indexOf(node);
    } else if (node.parent is DCFStatefulComponent ||
        node.parent is DCFStatelessComponent) {
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

    if (oldElement.nativeViewId != null) {
      newElement.nativeViewId = oldElement.nativeViewId;

      // CRITICAL: Map the new element IMMEDIATELY before any other operations
      // This ensures events can always find the correct element with the latest handlers
      final viewId = oldElement.nativeViewId!;
      final oldMappedNode = _nodesByViewId[viewId];
      _nodesByViewId[viewId] = newElement;
      
      print('🔵 MAPPING UPDATE: viewId=$viewId, elementType=${newElement.type}');
      print('🔵 MAPPING UPDATE: oldMapped=${oldMappedNode?.runtimeType}, newMapped=${newElement.runtimeType}');
      print('🔵 MAPPING UPDATE: hasOnPress=${newElement.elementProps.containsKey('onPress')}');
      if (oldMappedNode != newElement) {
        print('⚠️ MAPPING CHANGED: viewId=$viewId changed from ${oldMappedNode?.runtimeType} to ${newElement.runtimeType}');
      }
      
      EngineDebugLogger.log(
          'RECONCILE_UPDATE_TRACKING', 'Updated node tracking map',
          extra: {
            'ViewId': viewId,
            'ElementType': newElement.type,
            'HasOnPress': newElement.elementProps.containsKey('onPress'),
            'OnPressIsFunction': newElement.elementProps['onPress'] is Function,
            'OldMappedType': oldMappedNode?.runtimeType.toString() ?? 'null',
            'NewMappedType': newElement.runtimeType.toString()
          });

      // CRITICAL: Check if event handlers changed (not just event types)
      // Event handlers are functions, so we need to compare the actual handlers
      final oldEventTypes = oldElement.eventTypes;
      final newEventTypes = newElement.eventTypes;
      
      // Check if any event handlers changed by comparing the actual function references
      bool eventHandlersChanged = false;
      for (final eventType in newEventTypes) {
        final oldHandler = oldElement.elementProps[eventType] ?? oldElement.elementProps['on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}'];
        final newHandler = newElement.elementProps[eventType] ?? newElement.elementProps['on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}'];
        if (oldHandler != newHandler) {
          eventHandlersChanged = true;
          break;
        }
      }

      final oldEventSet = Set<String>.from(oldEventTypes);
      final newEventSet = Set<String>.from(newEventTypes);

      // Update listeners if event types changed OR event handlers changed
      if (eventHandlersChanged || 
          oldEventSet.length != newEventSet.length ||
          !oldEventSet.containsAll(newEventSet)) {
        EngineDebugLogger.log('RECONCILE_UPDATE_EVENTS',
            'Event types or handlers changed, updating listeners',
            extra: {
              'OldEvents': oldEventTypes, 
              'NewEvents': newEventTypes,
              'HandlersChanged': eventHandlersChanged
            });

        // If handlers changed, remove all and re-add to ensure clean state
        if (eventHandlersChanged && oldEventSet.isNotEmpty) {
          EngineDebugLogger.logBridge(
              'REMOVE_EVENT_LISTENERS', oldElement.nativeViewId!,
              data: {'EventTypes': oldEventTypes});
          await _nativeBridge.removeEventListeners(
              oldElement.nativeViewId!, oldEventTypes);
        } else {
          final eventsToRemove = oldEventSet.difference(newEventSet);
          if (eventsToRemove.isNotEmpty) {
            EngineDebugLogger.logBridge(
                'REMOVE_EVENT_LISTENERS', oldElement.nativeViewId!,
                data: {'EventTypes': eventsToRemove.toList()});
            await _nativeBridge.removeEventListeners(
                oldElement.nativeViewId!, eventsToRemove.toList());
          }
        }

        // Re-add all new event listeners
        if (newEventSet.isNotEmpty) {
          EngineDebugLogger.logBridge(
              'ADD_EVENT_LISTENERS', oldElement.nativeViewId!,
              data: {'EventTypes': newEventTypes});
          await _nativeBridge.addEventListeners(
              oldElement.nativeViewId!, newEventTypes);
        }
      }

      final changedProps = _diffProps(
          oldElement.type, oldElement.elementProps, newElement.elementProps);

      // DEBUG: Log prop comparison for button components
      if (oldElement.type == 'Button') {
        print('🔥 RECONCILE: Button props comparison:');
        print('  Old title: ${oldElement.elementProps["title"]}');
        print('  New title: ${newElement.elementProps["title"]}');
        print('  Changed props: ${changedProps.keys.toList()}');
        print('  Changed props count: ${changedProps.length}');
        print('  Old onPress: ${oldElement.elementProps.containsKey("onPress")} (${oldElement.elementProps["onPress"] is Function})');
        print('  New onPress: ${newElement.elementProps.containsKey("onPress")} (${newElement.elementProps["onPress"] is Function})');
        print('  Mapped node type: ${_nodesByViewId[oldElement.nativeViewId!]?.runtimeType}');
        print('  Mapped node == newElement: ${_nodesByViewId[oldElement.nativeViewId!] == newElement}');
      }

      if (changedProps.isNotEmpty) {
        EngineDebugLogger.logBridge('UPDATE_VIEW', oldElement.nativeViewId!,
            data: {'ChangedProps': changedProps.keys.toList()});
        final updateSuccess = await _nativeBridge.updateView(oldElement.nativeViewId!, changedProps);
        if (!updateSuccess) {
          EngineDebugLogger.log('UPDATE_VIEW_FAILED', 'updateView failed, falling back to createView',
              extra: {'ViewId': oldElement.nativeViewId});
          final createSuccess = await _nativeBridge.createView(
              oldElement.nativeViewId!, oldElement.type, newElement.elementProps);
          if (!createSuccess) {
            EngineDebugLogger.log('CREATE_VIEW_FALLBACK_FAILED', 'createView fallback also failed',
                extra: {'ViewId': oldElement.nativeViewId});
          }
        }
        
        // CRITICAL: Re-verify mapping after update to ensure it's still correct
        // This prevents race conditions where the mapping might get overwritten
        final currentMappedNode = _nodesByViewId[oldElement.nativeViewId!];
        if (currentMappedNode != newElement) {
          EngineDebugLogger.log('RECONCILE_REMAP_ELEMENT',
              '⚠️ Mapping was overwritten, restoring correct element',
              extra: {'ViewId': oldElement.nativeViewId, 'ExpectedType': newElement.runtimeType.toString()});
          _nodesByViewId[oldElement.nativeViewId!] = newElement;
        }
      } else {
        EngineDebugLogger.log(
            'RECONCILE_NO_PROP_CHANGES', 'No prop changes detected');
      }

      EngineDebugLogger.log(
          'RECONCILE_CHILDREN_START', 'Starting children reconciliation',
          extra: {
            'OldChildCount': oldElement.children.length,
            'NewChildCount': newElement.children.length
          });
      
      // CRITICAL: Store a snapshot of child view IDs before reconciliation
      // This allows us to verify and fix mappings after children reconciliation
      final childViewIdsBeforeReconcile = <String, DCFElement>{};
      for (final child in oldElement.children) {
        final viewId = child.effectiveNativeViewId;
        if (viewId != null && viewId.isNotEmpty) {
          final mappedNode = _nodesByViewId[viewId];
          if (mappedNode is DCFElement) {
            childViewIdsBeforeReconcile[viewId] = mappedNode;
          }
        }
      }
      
      await _reconcileChildren(oldElement, newElement);
      
      // CRITICAL: After children reconciliation, verify ALL child mappings are correct
      // This fixes the root cause: when SafeArea re-renders, child reconciliation
      // can corrupt the _nodesByViewId mapping for child elements
      for (final child in newElement.children) {
        final viewId = child.effectiveNativeViewId;
        if (viewId != null && viewId.isNotEmpty) {
          final mappedNode = _nodesByViewId[viewId];
          
          if (child is DCFElement) {
            // For direct elements, ensure mapping points to the new child instance
            if (mappedNode != child) {
              EngineDebugLogger.log('RECONCILE_CHILD_MAPPING_FIX',
                  '⚠️ Child mapping corrupted during reconciliation, fixing',
                  extra: {
                    'ViewId': viewId,
                    'ChildType': child.type,
                    'HasOnPress': child.elementProps.containsKey('onPress'),
                    'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null',
                    'OldMappedHasOnPress': (mappedNode is DCFElement) ? mappedNode.elementProps.containsKey('onPress') : false
                  });
              _nodesByViewId[viewId] = child;
            } else {
              // Verify the mapped element has handlers
              if (child.type == 'Button' && !child.elementProps.containsKey('onPress')) {
                EngineDebugLogger.log('RECONCILE_CHILD_NO_HANDLERS',
                    '⚠️ Button child has no onPress handler after reconciliation!',
                    extra: {
                      'ViewId': viewId,
                      'ElementProps': child.elementProps.keys.toList()
                    });
              }
            }
          } else if (child is DCFStatefulComponent || child is DCFStatelessComponent) {
            // For components, ensure mapping points to rendered element
            final renderedElement = child.renderedNode;
            if (renderedElement is DCFElement) {
              final renderedViewId = renderedElement.nativeViewId;
              // Use effectiveNativeViewId to handle nested components
              final effectiveViewId = child.effectiveNativeViewId ?? renderedViewId;
              if (effectiveViewId == viewId) {
                if (mappedNode != renderedElement) {
                  EngineDebugLogger.log('RECONCILE_CHILD_COMPONENT_MAPPING_FIX',
                      '⚠️ Component child mapping corrupted, fixing to point to rendered element',
                      extra: {
                        'ViewId': viewId,
                        'RenderedViewId': renderedViewId,
                        'HasOnPress': renderedElement.elementProps.containsKey('onPress'),
                        'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                      });
                  _nodesByViewId[viewId] = renderedElement;
                }
              } else if (renderedViewId != null && renderedViewId.isNotEmpty && mappedNode != renderedElement) {
                // Also check if the rendered element's view ID is mapped correctly
                final renderedMappedNode = _nodesByViewId[renderedViewId];
                if (renderedMappedNode != renderedElement) {
                  EngineDebugLogger.log('RECONCILE_CHILD_RENDERED_ELEMENT_MAPPING_FIX',
                      '⚠️ Rendered element mapping corrupted, fixing',
                      extra: {
                        'RenderedViewId': renderedViewId,
                        'HasOnPress': renderedElement.elementProps.containsKey('onPress')
                      });
                  _nodesByViewId[renderedViewId] = renderedElement;
                }
              }
            }
          }
        }
      }
      
      // FINAL SAFEGUARD: Ensure parent mapping is correct after all reconciliation
      // This catches any cases where the mapping might have been corrupted
      if (newElement.nativeViewId != null) {
        final finalMappedNode = _nodesByViewId[newElement.nativeViewId!];
        if (finalMappedNode != newElement) {
          EngineDebugLogger.log('RECONCILE_FINAL_REMAP',
              '⚠️ Final mapping check failed, restoring correct element',
              extra: {
                'ViewId': newElement.nativeViewId, 
                'MappedType': finalMappedNode?.runtimeType.toString() ?? 'null',
                'ExpectedType': newElement.runtimeType.toString(),
                'NewElementHasOnPress': newElement.elementProps.containsKey('onPress'),
                'MappedNodeHasOnPress': (finalMappedNode is DCFElement) ? finalMappedNode.elementProps.containsKey('onPress') : false
              });
          _nodesByViewId[newElement.nativeViewId!] = newElement;
        } else {
          // Verify the mapped element actually has the handlers
          if (finalMappedNode is DCFElement) {
            final hasHandlers = newElement.eventTypes.isNotEmpty;
            if (!hasHandlers && newElement.type == 'Button') {
              EngineDebugLogger.log('RECONCILE_NO_HANDLERS',
                  '⚠️ Button element has no event handlers after reconciliation!',
                  extra: {
                    'ViewId': newElement.nativeViewId,
                    'ElementProps': newElement.elementProps.keys.toList()
                  });
            }
          }
        }
      }
      
      // ULTIMATE SAFEGUARD: Re-verify ALL child mappings one more time after everything
      // This is the final check to ensure no child mappings were corrupted during reconciliation
      // CRITICAL: This is especially important for SafeArea's View children (Button components)
      for (final child in newElement.children) {
        final viewId = child.effectiveNativeViewId;
        if (viewId != null && viewId.isNotEmpty) {
          final mappedNode = _nodesByViewId[viewId];
          
          if (child is DCFElement) {
            if (mappedNode != child) {
              EngineDebugLogger.log('RECONCILE_ULTIMATE_CHILD_FIX',
                  '⚠️ ULTIMATE FIX: Child mapping still corrupted after all reconciliation, fixing now',
                  extra: {
                    'ViewId': viewId,
                    'ChildType': child.type,
                    'HasOnPress': child.elementProps.containsKey('onPress'),
                    'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                  });
              _nodesByViewId[viewId] = child;
            }
            // CRITICAL: Also verify event listeners are attached for Button elements
            if (child.type == 'Button' && child.eventTypes.isNotEmpty) {
              final hasListeners = child.elementProps.containsKey('onPress') || 
                                  child.elementProps.containsKey('onClick');
              if (!hasListeners) {
                EngineDebugLogger.log('RECONCILE_ULTIMATE_BUTTON_NO_HANDLERS',
                    '⚠️ ULTIMATE CHECK: Button has eventTypes but no handlers in props!',
                    extra: {
                      'ViewId': viewId,
                      'EventTypes': child.eventTypes,
                      'ElementProps': child.elementProps.keys.toList()
                    });
              }
            }
          } else if (child is DCFStatefulComponent || child is DCFStatelessComponent) {
            final renderedElement = child.renderedNode;
            if (renderedElement is DCFElement) {
              final renderedViewId = renderedElement.nativeViewId;
              if (renderedViewId != null && renderedViewId.isNotEmpty) {
                final renderedMappedNode = _nodesByViewId[renderedViewId];
                if (renderedMappedNode != renderedElement) {
                  EngineDebugLogger.log('RECONCILE_ULTIMATE_RENDERED_FIX',
                      '⚠️ ULTIMATE FIX: Rendered element mapping still corrupted, fixing now',
                      extra: {
                        'RenderedViewId': renderedViewId,
                        'ElementType': renderedElement.type,
                        'HasOnPress': renderedElement.elementProps.containsKey('onPress')
                      });
                  _nodesByViewId[renderedViewId] = renderedElement;
                }
                // CRITICAL: Also verify event listeners for Button rendered elements
                if (renderedElement.type == 'Button' && renderedElement.eventTypes.isNotEmpty) {
                  final hasListeners = renderedElement.elementProps.containsKey('onPress') || 
                                      renderedElement.elementProps.containsKey('onClick');
                  if (!hasListeners) {
                    EngineDebugLogger.log('RECONCILE_ULTIMATE_BUTTON_RENDERED_NO_HANDLERS',
                        '⚠️ ULTIMATE CHECK: Button rendered element has eventTypes but no handlers!',
                        extra: {
                          'ViewId': renderedViewId,
                          'EventTypes': renderedElement.eventTypes,
                          'ElementProps': renderedElement.elementProps.keys.toList()
                        });
                  }
                }
              }
            }
          }
        }
      }
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

    for (final entry in newProps.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Function) continue; // Skip function handlers

      if (!oldProps.containsKey(key)) {
        changedProps[key] = value;
        addedCount++;
      } else {
        final oldValue = oldProps[key];
        // Use deep equality check for complex objects (maps, lists)
        if (oldValue is Map && value is Map) {
          if (!_mapsEqual(oldValue, value)) {
            changedProps[key] = value;
            changedCount++;
          }
        } else if (oldValue is List && value is List) {
          if (!_listsEqual(oldValue, value)) {
            changedProps[key] = value;
            changedCount++;
          }
        } else if (oldValue != value) {
          changedProps[key] = value;
          changedCount++;
        }
      }
    }

    for (final key in oldProps.keys) {
      if (!newProps.containsKey(key) && oldProps[key] is! Function) {
        changedProps[key] = null;
        removedCount++;
      }
    }

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

  /// Deep equality check for maps
  bool _mapsEqual(Map<dynamic, dynamic> map1, Map<dynamic, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      final val1 = map1[key];
      final val2 = map2[key];
      if (val1 is Map && val2 is Map) {
        if (!_mapsEqual(val1, val2)) return false;
      } else if (val1 is List && val2 is List) {
        if (!_listsEqual(val1, val2)) return false;
      } else if (val1 != val2) {
        return false;
      }
    }
    return true;
  }

  /// Deep equality check for lists
  bool _listsEqual(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      final val1 = list1[i];
      final val2 = list2[i];
      if (val1 is Map && val2 is Map) {
        if (!_mapsEqual(val1, val2)) return false;
      } else if (val1 is List && val2 is List) {
        if (!_listsEqual(val1, val2)) return false;
      } else if (val1 != val2) {
        return false;
      }
    }
    return true;
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

    if (oldChildren.isEmpty && newChildren.isEmpty) {
      EngineDebugLogger.log(
          'RECONCILE_CHILDREN_EMPTY', 'No children to reconcile');
      return;
    }

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
    bool hasReplacements = false;
    int replacementCount = 0;

    for (int i = 0; i < commonLength; i++) {
      final oldChild = oldChildren[i];
      final newChild = newChildren[i];

      EngineDebugLogger.log(
          'RECONCILE_SIMPLE_UPDATE', 'Updating child at index $i');

      // Track component instance by position for automatic key inference
      final childPositionKey = "$parentViewId:$i:${newChild.runtimeType}";
      final childPropsHash = _computePropsHash(newChild);
      final childPropsKey = "$childPositionKey:$childPropsHash";
      _componentInstancesByPosition[childPositionKey] = newChild;
      _componentInstancesByProps[childPropsKey] = newChild;

      String? childViewId;
      if (_shouldReplaceAtSamePosition(oldChild, newChild)) {
        hasReplacements = true;
        replacementCount++;
        EngineDebugLogger.log('RECONCILE_SIMPLE_REPLACE',
            'Replacing child at index $i due to conditional rendering pattern',
            extra: {
              'OldType': oldChild.runtimeType.toString(),
              'NewType': newChild.runtimeType.toString(),
              'OldViewId': oldChild.effectiveNativeViewId
            });
        
        // Store the old view ID as fallback
        final oldViewId = oldChild.effectiveNativeViewId;
        
        await _replaceNode(oldChild, newChild);
        
        // After replace, get the view ID from the new node
        childViewId = newChild.effectiveNativeViewId;
        
        // Triple-check: try multiple fallback strategies to get the view ID
        if (childViewId == null || childViewId.isEmpty) {
          // Strategy 1: Check rendered node for components
          if (newChild is DCFStatefulComponent || newChild is DCFStatelessComponent) {
            final renderedNode = newChild.renderedNode;
            if (renderedNode is DCFElement) {
              childViewId = renderedNode.nativeViewId;
              if (childViewId != null && childViewId.isNotEmpty) {
                newChild.contentViewId = childViewId;
                EngineDebugLogger.log('RECONCILE_SIMPLE_FIXED_VIEW_ID_RENDERED',
                    'Fixed missing view ID from rendered node',
                    extra: {'ViewId': childViewId, 'Index': i});
              }
            } else if (renderedNode != null && (renderedNode is DCFStatefulComponent || renderedNode is DCFStatelessComponent)) {
              // For nested components, check their contentViewId
              childViewId = renderedNode.contentViewId;
              if (childViewId != null && childViewId.isNotEmpty) {
                newChild.contentViewId = childViewId;
                EngineDebugLogger.log('RECONCILE_SIMPLE_FIXED_VIEW_ID_NESTED',
                    'Fixed missing view ID from nested component',
                    extra: {'ViewId': childViewId, 'Index': i});
              }
            }
          }
          
          // Strategy 2: Check _nodesByViewId for the new node (in case it was registered)
          if ((childViewId == null || childViewId.isEmpty) && newChild is DCFElement) {
            // Try to find the view ID by looking up the node in the registry
            for (final entry in _nodesByViewId.entries) {
              if (entry.value == newChild) {
                childViewId = entry.key;
                newChild.nativeViewId = childViewId;
                EngineDebugLogger.log('RECONCILE_SIMPLE_FIXED_VIEW_ID_REGISTRY',
                    'Fixed missing view ID from registry lookup',
                    extra: {'ViewId': childViewId, 'Index': i});
                break;
              }
            }
          }
          
          // Strategy 3: If still null and we have an old view ID, use it as last resort
          // This should only happen if the view was reused (not replaced)
          if ((childViewId == null || childViewId.isEmpty) && oldViewId != null && oldViewId.isNotEmpty) {
            // Check if the old view ID still exists in the registry
            if (_nodesByViewId.containsKey(oldViewId)) {
              final registeredNode = _nodesByViewId[oldViewId];
              if (registeredNode == newChild || 
                  (newChild is DCFStatefulComponent && registeredNode == newChild.renderedNode) ||
                  (newChild is DCFStatelessComponent && registeredNode == newChild.renderedNode)) {
                childViewId = oldViewId;
                if (newChild is DCFElement) {
                  newChild.nativeViewId = childViewId;
                } else if (newChild is DCFStatefulComponent || newChild is DCFStatelessComponent) {
                  newChild.contentViewId = childViewId;
                }
                EngineDebugLogger.log('RECONCILE_SIMPLE_FIXED_VIEW_ID_REUSED',
                    'Using old view ID as fallback (view was reused)',
                    extra: {'ViewId': childViewId, 'Index': i});
              }
            }
          }
        }
        
        EngineDebugLogger.log('RECONCILE_SIMPLE_AFTER_REPLACE',
            'After replace, checking view ID',
            extra: {
              'NewViewId': childViewId,
              'EffectiveViewId': newChild.effectiveNativeViewId,
              'ContentViewId': (newChild is DCFStatefulComponent || newChild is DCFStatelessComponent) 
                  ? newChild.contentViewId 
                  : null,
              'NativeViewId': (newChild is DCFElement) 
                  ? newChild.nativeViewId 
                  : null,
              'OldViewId': oldViewId
            });
      } else {
        await _reconcile(oldChild, newChild);
        // After reconcile, prefer new node's view ID, fallback to old
        childViewId = newChild.effectiveNativeViewId ?? oldChild.effectiveNativeViewId;
        
        // CRITICAL: After reconciling each child, IMMEDIATELY ensure the mapping points to newChild
        // This is especially important when parent components (like SafeArea) re-render
        // and create new child instances. The _reconcile call should have already
        // updated the mapping via _reconcileElement, but we verify and fix it here as a safeguard
        if (childViewId != null && childViewId.isNotEmpty) {
          final mappedNode = _nodesByViewId[childViewId];
          
          // If the mapping doesn't point to newChild (or its rendered element), fix it IMMEDIATELY
          if (newChild is DCFElement) {
            if (mappedNode != newChild) {
              // Update mapping to point to newChild which has the latest handlers
              _nodesByViewId[childViewId] = newChild;
              EngineDebugLogger.log('RECONCILE_CHILD_FIX_MAPPING',
                  '⚠️ Fixed mapping to point to new child element (immediate fix)',
                  extra: {
                    'ViewId': childViewId,
                    'ChildType': newChild.type,
                    'HasOnPress': newChild.elementProps.containsKey('onPress'),
                    'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null',
                    'OldMappedHasOnPress': (mappedNode is DCFElement) ? mappedNode.elementProps.containsKey('onPress') : false
                  });
            } else {
              // Verify the mapped element actually has the handlers
              if (newChild.type == 'Button' && !newChild.elementProps.containsKey('onPress')) {
                EngineDebugLogger.log('RECONCILE_CHILD_NO_HANDLERS_IMMEDIATE',
                    '⚠️ Button child has no onPress handler after reconciliation!',
                    extra: {
                      'ViewId': childViewId,
                      'ElementProps': newChild.elementProps.keys.toList()
                    });
              }
            }
          } else if (newChild is DCFStatefulComponent || newChild is DCFStatelessComponent) {
            // For components, ensure the mapping points to the rendered element
            final renderedElement = newChild.renderedNode;
            if (renderedElement is DCFElement) {
              final renderedViewId = renderedElement.nativeViewId;
              // Use effectiveNativeViewId to handle nested components
              final effectiveViewId = newChild.effectiveNativeViewId ?? renderedViewId;
              
              // CRITICAL: Always ensure the rendered element's view ID is mapped correctly
              // This is the root cause: when SafeArea creates new Button instances, they
              // might reuse view IDs, but the mapping must point to the NEW rendered element
              if (renderedViewId != null && renderedViewId.isNotEmpty) {
                final renderedMappedNode = _nodesByViewId[renderedViewId];
                if (renderedMappedNode != renderedElement) {
                  _nodesByViewId[renderedViewId] = renderedElement;
                  EngineDebugLogger.log('RECONCILE_CHILD_RENDERED_ELEMENT_MAPPING_FIX',
                      '⚠️ Fixed rendered element mapping (immediate fix)',
                      extra: {
                        'ViewId': childViewId,
                        'RenderedViewId': renderedViewId,
                        'ElementType': renderedElement.type,
                        'HasOnPress': renderedElement.elementProps.containsKey('onPress'),
                        'OldMappedType': renderedMappedNode?.runtimeType.toString() ?? 'null'
                      });
                }
              }
              
              // Also check if effectiveViewId matches childViewId and fix if needed
              if (effectiveViewId == childViewId && mappedNode != renderedElement) {
                _nodesByViewId[childViewId] = renderedElement;
                EngineDebugLogger.log('RECONCILE_CHILD_FIX_MAPPING_COMPONENT',
                    '⚠️ Fixed mapping to point to component\'s rendered element (immediate fix)',
                    extra: {
                      'ViewId': childViewId,
                      'RenderedViewId': renderedViewId,
                      'HasOnPress': renderedElement.elementProps.containsKey('onPress'),
                      'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                    });
              }
            }
          }
        }
      }

      if (childViewId != null && childViewId.isNotEmpty) {
        updatedChildIds.add(childViewId);
        EngineDebugLogger.log('RECONCILE_SIMPLE_VIEW_ID_ADDED',
            'Added view ID to updatedChildIds',
            extra: {'ViewId': childViewId, 'Index': i, 'TotalCount': updatedChildIds.length});
      } else {
        // CRITICAL: If we still don't have a view ID, we MUST NOT call setChildren
        // because it will remove all views and this one will be lost
        EngineDebugLogger.log('RECONCILE_SIMPLE_MISSING_VIEW_ID',
            '⚠️ CRITICAL: Child at index $i has no view ID after reconciliation - will skip setChildren',
            extra: {
              'OldType': oldChild.runtimeType.toString(),
              'NewType': newChild.runtimeType.toString(),
              'OldViewId': oldChild.effectiveNativeViewId,
              'NewViewId': newChild.effectiveNativeViewId,
              'NewContentViewId': (newChild is DCFStatefulComponent || newChild is DCFStatelessComponent) 
                  ? newChild.contentViewId 
                  : null,
              'NewNativeViewId': (newChild is DCFElement) 
                  ? newChild.nativeViewId 
                  : null,
              'Index': i,
              'Warning': 'setChildren will be skipped to prevent view loss'
            });
      }
    } // O((new - common) * render complexity) - Handle length differences
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

    // Only call setChildren if we have all the view IDs we need
    final expectedCount = newChildren.length;
    final actualCount = updatedChildIds.length;
    final hasAdditionsOrRemovals = newChildren.length != oldChildren.length;
    
    // CRITICAL: Never call setChildren if we're missing view IDs
    // setChildren does removeAllViews() which will remove views that aren't in the list
    // This would cause views to disappear permanently
    final hasAllViewIds = actualCount == expectedCount && updatedChildIds.isNotEmpty;
    
    if (!hasAllViewIds) {
      EngineDebugLogger.log('RECONCILE_SIMPLE_SET_CHILDREN_SKIPPED',
          '⚠️ CRITICAL: Skipping setChildren - missing view IDs (would cause view loss)',
          extra: {
            'ExpectedCount': expectedCount,
            'ActualCount': actualCount,
            'MissingCount': expectedCount - actualCount,
            'UpdatedChildIds': updatedChildIds,
            'HasStructuralChanges': hasStructuralChanges,
            'HasReplacements': hasReplacements,
            'ReplacementCount': replacementCount,
            'ParentViewId': parentViewId,
            'Warning': 'setChildren would call removeAllViews() and lose views without IDs'
          });
    } else {
      // Only call setChildren if:
      // 1. There are structural changes (additions/removals), OR
      // 2. There are replacements (to ensure correct order after replacement)
      if (hasStructuralChanges || hasReplacements) {
        EngineDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
          'ChildIds': updatedChildIds,
          'ChildCount': updatedChildIds.length,
          'ExpectedCount': expectedCount,
          'HasReplacements': hasReplacements,
          'ReplacementCount': replacementCount,
          'HasAdditionsOrRemovals': hasAdditionsOrRemovals,
          'Reason': hasStructuralChanges ? 'Structural changes' : 'Replacements only - ensuring correct order'
        });
        await _nativeBridge.setChildren(parentViewId, updatedChildIds);
      } else {
        EngineDebugLogger.log('RECONCILE_SIMPLE_SET_CHILDREN_SKIPPED',
            'Skipping setChildren - no structural changes or replacements',
            extra: {
              'ParentViewId': parentViewId,
              'ChildCount': updatedChildIds.length
            });
      }
    }

    EngineDebugLogger.log(
        'RECONCILE_SIMPLE_COMPLETE', 'Simple children reconciliation completed',
        extra: {
          'StructuralChanges': hasStructuralChanges,
          'FinalChildCount': updatedChildIds.length,
          'ExpectedCount': expectedCount
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

 

  /// O(1) - Print comprehensive VDOM statistics (for debugging)
  void printDebugStats() {
    EngineDebugLogger.printStats();

    EngineDebugLogger.log('VDOM_STATS', 'Current VDOM state', extra: {
      'StatefulComponents': _statefulComponents.length,
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

  /// Cancel all pending async work (for hot restart)
  /// This prevents stale timers and microtasks from firing after cleanup
  void cancelAllPendingWork() {
    EngineDebugLogger.log('CANCEL_ALL_WORK', 'Cancelling all pending async work');
    
    // Cancel Dart timers
    _updateTimer?.cancel();
    _updateTimer = null;
    _isUpdateScheduled = false;
    
    // Reset batch state
    _batchUpdateInProgress = false;
    
    // Clear all pending updates
    final pendingCount = _pendingUpdates.length;
    _pendingUpdates.clear();
    _componentPriorities.clear();
    
    // Clear effect queues (these use Future.microtask which can't be cancelled,
    // but clearing the sets prevents them from executing)
    final layoutCount = _componentsWaitingForLayout.length;
    final insertionCount = _componentsWaitingForInsertion.length;
    _componentsWaitingForLayout.clear();
    _componentsWaitingForInsertion.clear();
    
    EngineDebugLogger.log('CANCEL_ALL_WORK_COMPLETE',
        'Cancelled all pending async work',
        extra: {
          'PendingUpdates': pendingCount,
          'LayoutEffects': layoutCount,
          'InsertionEffects': insertionCount,
        });
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

    for (final isolate in _workerIsolates) {
      try {
        isolate.kill();
      } catch (e) {
        EngineDebugLogger.log('VDOM_CONCURRENT_SHUTDOWN_ERROR',
            'Error killing worker isolate: $e');
      }
    }

    _workerIsolates.clear();
    _workerPorts.clear();
    _workerAvailable.clear();
    _concurrentEnabled = false;

    EngineDebugLogger.log(
        'VDOM_CONCURRENT_SHUTDOWN', 'Concurrent processing shutdown complete');
  }

  /// Worker isolate entry point - handles real concurrent processing
  /// ? Experimental --dead for now
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

        mainSendPort.send({
          'type': 'result',
          'id': taskId,
          'success': true,
          'data': result,
          'processingTimeMs': processingTime.inMilliseconds,
        });
      } catch (e) {
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

    await Future.delayed(Duration(milliseconds: 5)); // Simulate CPU work

    final changes = <Map<String, dynamic>>[];

    if (oldTree['type'] != newTree['type']) {
      changes
          .add({'action': 'replace', 'oldNode': oldTree, 'newNode': newTree});
    }

    final oldProps = oldTree['props'] as Map<String, dynamic>? ?? {};
    final newProps = newTree['props'] as Map<String, dynamic>? ?? {};

    final propsDiff = _computeDeepPropsDiff(oldProps, newProps);
    if (propsDiff.isNotEmpty) {
      changes.add({'action': 'updateProps', 'diff': propsDiff});
    }

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

    await Future.delayed(Duration(milliseconds: 2));

    return _computeDeepPropsDiff(oldProps, newProps);
  }

  /// Process large lists in isolate (heavy data processing)
  static Future<Map<String, dynamic>> _processLargeListInIsolate(
      Map<String, dynamic> data) async {
    final items = data['items'] as List<dynamic>;
    final operations = data['operations'] as List<String>? ?? [];

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

    await Future.delayed(Duration(milliseconds: 3));

    final serialized = <String, dynamic>{};

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

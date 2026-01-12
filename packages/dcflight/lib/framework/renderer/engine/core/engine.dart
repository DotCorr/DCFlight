/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:math' as math;
import 'package:worker_manager/worker_manager.dart' as worker_manager;
import 'package:worker_manager/src/scheduling/work_priority.dart' as worker_priority show WorkPriority;

import 'package:dcflight/framework/renderer/engine/core/cache/lru_cache.dart';
import 'package:dcflight/framework/renderer/engine/core/concurrency/priority.dart';
import 'package:dcflight/framework/renderer/engine/debug/engine_logger.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';
import 'package:dcflight/framework/renderer/engine/core/error/error_recovery.dart';
import 'package:dcflight/framework/renderer/engine/core/performance/performance_monitor.dart';
import 'package:dcflight/framework/renderer/engine/core/scheduling/frame_scheduler.dart';
import 'package:dcflight/framework/renderer/engine/core/reconciliation/effect_list.dart'
    show Effect, EffectList, EffectType;
import 'package:dcflight/framework/renderer/engine/core/reconciliation/incremental_reconciler.dart'
    show IncrementalReconciler;
import 'package:dcflight/framework/renderer/interface/interface.dart'
    show PlatformInterface;
import 'package:dcflight/src/components/component.dart';
import 'package:dcflight/src/components/error_boundary.dart';
import 'package:dcflight/src/components/dcf_element.dart';
import 'package:dcflight/src/components/component_node.dart';
import 'package:dcflight/src/components/fragment.dart';
import 'package:dcflight/framework/events/event_registry.dart';
import 'package:dcflight/framework/utils/flutter_widget_renderer.dart';
import 'package:dcflight/framework/utils/widget_to_dcf_adaptor.dart';
import 'package:dcflight/framework/utils/system_state_manager.dart';

/// Enhanced Virtual DOM with priority-based update scheduling
class DCFEngine {
  /// Native bridge for UI operations
  final PlatformInterface _nativeBridge;

  /// Whether the VDom is ready for use
  final Completer<void> _readyCompleter = Completer<void>();

  /// Counter for generating unique view IDs - O(1) access
  int _viewIdCounter = 1;

  /// Map of view IDs to their associated VDomNodes - O(1) lookup
  final Map<int, DCFComponentNode> _nodesByViewId = {};

  /// Current tree (rendered and visible)
  DCFComponentNode? _currentTree;

  /// Work in progress tree (being built during reconciliation)
  DCFComponentNode? _workInProgressTree;

  /// Component tracking maps
  final Map<String, DCFStatefulComponent> _statefulComponents = {};
  final Map<String, DCFComponentNode> _previousRenderedNodes = {};

  /// Effect list for commit phase
  final EffectList _effectList = EffectList();

  /// Incremental reconciler for pause/resume
  final IncrementalReconciler _incrementalReconciler = IncrementalReconciler();

  /// Reconciliation state
  bool _isReconciling = false;
  bool _shouldPauseReconciliation = false;
  bool _incrementalReconciliationEnabled = true;
  
  /// Hot reload state - prevents worker_manager reconciliation during hot reload
  bool _isHotReloading = false;

  /// Component instance tracking by position + type
  /// Key: "parentViewId:index:type" -> Component instance
  /// This allows instance persistence across renders
  final Map<String, DCFComponentNode> _componentInstancesByPosition = {};

  /// Props-based identity cache for automatic key inference
  /// Key: "parentViewId:index:type:propsHash" -> Component instance
  /// Used when components have same type at same position but different props
  final Map<String, DCFComponentNode> _componentInstancesByProps = {};

  /// Render cycle detection to prevent infinite loops
  /// Key: componentId -> render count in current batch
  final Map<String, int> _renderCycleCount = {};
  static const int _maxRenderCycles =
      100; // Maximum renders per component per batch

  /// Track nodes currently being rendered to prevent recursive/infinite calls
  /// Key: node identity (hashCode) -> true if currently rendering
  final Set<int> _nodesBeingRendered = {};

  /// OPTIMIZED: Memoization cache for structural similarity calculations
  /// Key: "oldNodeHash:newNodeHash" -> similarity score
  /// Reduces redundant similarity calculations during reconciliation
  /// Uses LRU eviction cache strategy
  late final LRUCache<String, double> _similarityCache = LRUCache(
    maxSize: 1000,
  );

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
  
  /// 🔥 CPU THROTTLING: Track last batch processing time for rate limiting
  /// Prevents CPU from spiking above 50% during rapid stress testing
  DateTime? _lastBatchProcessTime;
  static const Duration _minBatchCooldown = Duration(milliseconds: 8); // ~120fps max processing rate
  
  /// 🔥 UI FREEZE FIX: Track rapid reconciliation to pause ALL UI thread work
  /// Universal solution - pauses ALL frame callbacks/display links during rapid reconciliation
  /// This prevents ANY heavy UI thread work from blocking during rapid state changes
  DateTime? _lastReconciliationTime;
  int _rapidReconciliationCount = 0;
  bool _uiWorkPaused = false;
  static const Duration _rapidReconciliationWindow = Duration(milliseconds: 100); // 100ms window
  static const int _rapidReconciliationThreshold = 3; // 3+ updates in 100ms = rapid

  /// Root component and error boundaries
  DCFComponentNode? rootComponent;
  final Map<String, ErrorBoundary> _errorBoundaries = {};

  /// Effect phase management
  final Set<String> _componentsWaitingForLayout = {};
  final Set<String> _componentsWaitingForInsertion = {};
  bool _isTreeComplete = false;

  /// Structural shock flag - when true, force full replacement instead of reconciliation
  /// This prevents component/prop leakage when app structure changes dramatically
  bool _isStructuralShock = false;

  /// Worker manager for parallel reconciliation (singleton instance)
  bool _workerManagerInitialized = false;
  
  /// Flag to prevent infinite loops when falling back from worker_manager
  /// When true, worker_manager will be skipped for this reconciliation
  bool _skipWorkerManagerForThisReconciliation = false;

  /// Performance tracking and monitoring
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  /// Error recovery manager with retry strategies
  final ErrorRecoveryManager _errorRecovery = ErrorRecoveryManager(
    maxRetries: 3,
    retryDelay: const Duration(milliseconds: 100),
  );

  /// Performance tracking (legacy - kept for compatibility)
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
      print('✅ DCFEngine: Event handler registered with PlatformInterface');

      // Initialize worker manager for parallel reconciliation
      _initializeWorkerManager().catchError((e) {
        EngineDebugLogger.log(
            'WORKER_MANAGER_INIT_ERROR', 'Worker manager setup failed: $e');
      });

      _readyCompleter.complete();
      EngineDebugLogger.log(
          'VDOM_INIT', 'VDom initialization completed successfully');
    } catch (e) {
      EngineDebugLogger.log(
          'VDOM_INIT_ERROR', 'VDom initialization failed: $e');
      _readyCompleter.completeError(e);
    }
  }

  /// Initialize worker manager for parallel reconciliation
  Future<void> _initializeWorkerManager() async {
    if (_workerManagerInitialized) {
      print('✅ WORKER_MANAGER: Already initialized');
      return;
    }

    try {
      print('🔄 WORKER_MANAGER: Initializing worker manager...');
      EngineDebugLogger.log('WORKER_MANAGER_INIT', 'Initializing worker manager');

      await worker_manager.workerManager.init(dynamicSpawning: true);
      _workerManagerInitialized = true;

      print('✅ WORKER_MANAGER: Initialized successfully');
          print(
          '⚡ WORKER_MANAGER: Performance mode enabled - Large trees (20+ nodes) will use parallel reconciliation');
      EngineDebugLogger.log('WORKER_MANAGER_INIT_SUCCESS',
          'Worker manager initialized successfully');
    } catch (e) {
      print('❌ WORKER_MANAGER: Initialization failed: $e');
      EngineDebugLogger.log('WORKER_MANAGER_INIT_ERROR',
          'Failed to initialize worker manager: $e');
      _workerManagerInitialized = false;
    }
  }


  Future<void> get isReady => _readyCompleter.future;

  /// O(1) - Generate a unique view ID
  int _generateViewId() {
    final viewId = _viewIdCounter++;
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

  /// O(1) - Handle a native event using centralized EventRegistry
  ///
  /// 🔥 NEW: Uses EventRegistry instead of fragile prop lookup
  /// Events are registered automatically when views are rendered
  void _handleNativeEvent(
      int viewId, String eventType, Map<dynamic, dynamic> eventData) {
    // 🔥 NEW: Use centralized EventRegistry - clean, no fallbacks
    final registry = EventRegistry();
    final handled = registry.handleEvent(viewId, eventType, Map<String, dynamic>.from(eventData));
    
    if (!handled) {
      // Event not registered - this is expected for views without handlers
      // Fail-fast: no fallback, no error - just ignore
      EngineDebugLogger.log('EVENT_NOT_REGISTERED', 
          'Event $eventType for view $viewId not registered - ignoring (fail-fast)');
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
      } catch (e) {}
    }

    try {
      Function.apply(handler, []);
      EngineDebugLogger.log(
          'EVENT_HANDLER_SUCCESS', 'Parameter-less handler executed');
      return;
    } catch (e) {}

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

  /// OPTIMIZED: Intelligent replacement heuristic with structural similarity analysis
  /// Uses structural similarity score instead of simple count differences
  /// Sophisticated reconciliation with automatic key inference
  bool _shouldReplaceAtSamePosition(
      DCFComponentNode oldChild, DCFComponentNode newChild) {
    // Early exit: If keys are explicitly different, replace
    if (oldChild.key != null &&
        newChild.key != null &&
        oldChild.key != newChild.key) {
      return true;
    }

    // Early exit: Different runtime types = different components, must replace
    if (oldChild.runtimeType != newChild.runtimeType) {
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

    // Same runtime type - check element types if both are elements
    if (oldChild is DCFElement && newChild is DCFElement) {
      if (oldChild.type != newChild.type) {
        return true;
      }

      // 🔥 CRITICAL: Check props similarity first - props/content differences indicate replacement needed
      // This prevents matching components by position/type when they have completely different content
      final propsSimilarity =
          _computePropsSimilarity(oldChild.elementProps, newChild.elementProps);
      if (propsSimilarity < 0.5) {
        EngineDebugLogger.log('REPLACE_PROPS_MISMATCH',
            'Forcing replacement due to low props similarity',
            extra: {
              'PropsSimilarity': propsSimilarity,
              'ElementType': oldChild.type,
              'OldPropsKeys': oldChild.elementProps.keys.toList(),
              'NewPropsKeys': newChild.elementProps.keys.toList(),
            });
        return true;
      }

      // OPTIMIZED: Use structural similarity instead of simple count difference
      // Intelligent matching based on position and type
      final similarity = _computeStructuralSimilarity(oldChild, newChild);

      // Only replace if structural similarity is below threshold (very different)
      // Threshold: 0.3 means less than 30% similarity = replace
      // This handles conditional rendering better than count-based heuristics
      if (similarity < 0.3) {
        EngineDebugLogger.log('REPLACE_STRUCTURAL_MISMATCH',
            'Forcing replacement due to low structural similarity',
            extra: {
              'Similarity': similarity,
              'OldChildCount': oldChild.children.length,
              'NewChildCount': newChild.children.length,
              'ElementType': oldChild.type
            });
        return true;
      }

      // Same type, similar props and structure - reconcile, don't replace
      return false;
    }

    // Same component type - we reconcile, not replace
    // This is the key behavior: match by position and type
    return false;
  }

  /// OPTIMIZED: Compute structural similarity between two nodes (0.0 to 1.0)
  /// Uses type matching, props similarity, and children structure analysis with LCS
  /// Returns 1.0 for identical structures, 0.0 for completely different
  /// Memoized for performance - same node pairs return cached results
  double _computeStructuralSimilarity(DCFElement oldNode, DCFElement newNode) {
    // Early exit: Type match is required (already checked, but for safety)
    if (oldNode.type != newNode.type) return 0.0;

    // OPTIMIZED: Memoization - check cache first
    final cacheKey = '${oldNode.hashCode}:${newNode.hashCode}';
    final cached = _similarityCache.get(cacheKey);
    if (cached != null) {
      _performanceMonitor.recordCacheHit();
      return cached;
    }
    _performanceMonitor.recordCacheMiss();

    // Early exit optimizations
    if (oldNode.children.isEmpty && newNode.children.isEmpty) {
      _similarityCache.put(cacheKey, 1.0);
      return 1.0;
    }

    if (oldNode.children.isEmpty || newNode.children.isEmpty) {
      // Empty vs non-empty: low similarity but not zero (might be conditional rendering)
      _similarityCache.put(cacheKey, 0.2);
      return 0.2;
    }

    // Compute children type similarity using LCS
    final oldChildTypes =
        oldNode.children.map((c) => _getChildTypeSignature(c)).toList();
    final newChildTypes =
        newNode.children.map((c) => _getChildTypeSignature(c)).toList();

    // Use longest common subsequence to find matching children
    final lcsLength = _computeLCSLength(oldChildTypes, newChildTypes);
    final maxLength = math.max(oldChildTypes.length, newChildTypes.length);

    // Similarity based on LCS: how many children match in order
    final childrenSimilarity = maxLength > 0 ? lcsLength / maxLength : 1.0;

    // Props similarity (simpler check - just count matching keys)
    final oldProps = oldNode.elementProps;
    final newProps = newNode.elementProps;
    final allKeys = <String>{...oldProps.keys, ...newProps.keys};
    int matchingProps = 0;
    int totalProps = allKeys.length;

    for (final key in allKeys) {
      // Skip function handlers for similarity calculation
      if (key.startsWith('on') &&
          (oldProps[key] is Function || newProps[key] is Function)) {
        totalProps--;
        continue;
      }

      if (oldProps[key] == newProps[key]) {
        matchingProps++;
      }
    }

    final propsSimilarity = totalProps > 0 ? matchingProps / totalProps : 1.0;

    // Weighted combination: children structure is more important than props
    // 70% children similarity + 30% props similarity
    final overallSimilarity =
        (childrenSimilarity * 0.7) + (propsSimilarity * 0.3);

    // Cache result for future use (LRU automatically handles eviction)
    _similarityCache.put(cacheKey, overallSimilarity);

    return overallSimilarity;
  }

  /// Get a type signature for a child node (for similarity comparison)
  String _getChildTypeSignature(DCFComponentNode node) {
    if (node is DCFElement) {
      return 'E:${node.type}';
    } else if (node is DCFStatefulComponent) {
      return 'S:${node.runtimeType}';
    } else if (node is DCFStatelessComponent) {
      return 'L:${node.runtimeType}';
    }
    return 'U:${node.runtimeType}';
  }

  /// OPTIMIZED: Compute Longest Common Subsequence length (LCS)
  /// Key optimization for optimal diffing
  /// O(n*m) time, O(min(n,m)) space with space optimization
  int _computeLCSLength(List<String> seq1, List<String> seq2) {
    final n = seq1.length;
    final m = seq2.length;

    // Early exit optimizations
    if (n == 0 || m == 0) return 0;
    if (n == 1 && m == 1 && seq1[0] == seq2[0]) return 1;

    // Space-optimized LCS: only keep current and previous row
    // This reduces space from O(n*m) to O(min(n,m))
    final shorter = n < m ? seq1 : seq2;
    final longer = n < m ? seq2 : seq1;
    final shortLen = shorter.length;
    final longLen = longer.length;

    // Use two rows for space optimization
    var prevRow = List<int>.filled(shortLen + 1, 0);
    var currRow = List<int>.filled(shortLen + 1, 0);

    for (int i = 1; i <= longLen; i++) {
      for (int j = 1; j <= shortLen; j++) {
        if (longer[i - 1] == shorter[j - 1]) {
          currRow[j] = prevRow[j - 1] + 1;
        } else {
          currRow[j] = math.max(prevRow[j], currRow[j - 1]);
        }
      }
      // Swap rows for next iteration
      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }

    return prevRow[shortLen];
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
    
    // 🔥 CRITICAL FIX: Throttle rapid updates to prevent freeze
    // If component is already in queue, don't add again (deduplicate)
    // This prevents queue from growing unbounded during rapid button presses
    if (_pendingUpdates.contains(component.instanceId)) {
      EngineDebugLogger.log('UPDATE_ALREADY_QUEUED',
          'Component ${component.instanceId} already in queue, skipping duplicate');
      return; // Already queued, skip duplicate
    }
    
    // 🔥 CRITICAL FIX: Aggressive throttling to keep CPU < 50% during stress testing
    // Lower queue size for normal stress testing (only allow large queues for extreme cases)
    const maxQueueSize = 10; // Maximum updates queued at once (lowered from 20 for better CPU control)
    if (_pendingUpdates.length >= maxQueueSize) {
      EngineDebugLogger.log('UPDATE_QUEUE_FULL',
          'Update queue full (${_pendingUpdates.length}), clearing old updates');
      // Clear all old updates and priorities - only keep the current one
      // This prevents queue from growing unbounded during rapid button presses
      final oldUpdates = _pendingUpdates.toList();
      _pendingUpdates.clear();
      for (final id in oldUpdates) {
        _componentPriorities.remove(id);
      }
    }
    
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
    
    // 🔥 UI FREEZE FIX: Detect rapid reconciliation and pause ALL UI thread work
    // Universal solution - works for animations, worklets, or any future UI thread work
    final now = DateTime.now();
    if (_lastReconciliationTime != null) {
      final timeSinceLastReconciliation = now.difference(_lastReconciliationTime!);
      if (timeSinceLastReconciliation < _rapidReconciliationWindow) {
        _rapidReconciliationCount++;
        if (_rapidReconciliationCount >= _rapidReconciliationThreshold && !_uiWorkPaused) {
          // Rapid reconciliation detected - pause ALL UI thread work (universal solution)
          print('🛑 RAPID_RECONCILIATION: Detected rapid updates, pausing ALL UI thread work');
          await _pauseAllUIWork();
          _uiWorkPaused = true;
        }
      } else {
        // Reset counter if outside window
        _rapidReconciliationCount = 1;
      }
    } else {
      _rapidReconciliationCount = 1;
    }
    _lastReconciliationTime = now;
    
    // 🔥 CPU THROTTLING: Rate limit batch processing to keep CPU < 50%
    // Enforce minimum cooldown between batches to prevent CPU spikes
    if (_lastBatchProcessTime != null) {
      final timeSinceLastBatch = now.difference(_lastBatchProcessTime!);
      if (timeSinceLastBatch < _minBatchCooldown) {
        final remainingCooldown = _minBatchCooldown - timeSinceLastBatch;
        EngineDebugLogger.log('BATCH_RATE_LIMIT',
            'Rate limiting batch processing, waiting ${remainingCooldown.inMilliseconds}ms');
        await Future.delayed(remainingCooldown);
      }
    }
    _lastBatchProcessTime = now;

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

      // Use worker_manager for concurrent processing if available
      if (_workerManagerInitialized && updateCount >= 5) {
        await _processPendingUpdatesConcurrently();
      } else {
        await _processPendingUpdatesSerially();
      }

      final processingTime = DateTime.now().difference(startTime);
      _updatePerformanceStats(
          updateCount >= 5, processingTime);

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

      // 🔥 CRITICAL: Clear render cycle counts after batch completes
      _renderCycleCount.clear();
      _nodesBeingRendered.clear(); // Clear rendering set after batch completes
      
      // 🔥 UI FREEZE FIX: Resume ALL UI thread work after reconciliation completes
      // Universal solution - resumes all frame callbacks/display links
      if (_uiWorkPaused) {
        // Wait a bit to ensure reconciliation is fully complete
        await Future.delayed(Duration(milliseconds: 50));
        print('▶️ RAPID_RECONCILIATION: Reconciliation complete, resuming ALL UI thread work');
        await _resumeAllUIWork();
        _uiWorkPaused = false;
        _rapidReconciliationCount = 0;
      }
    } finally {
      _batchUpdateInProgress = false;
    }
  }
  
  /// 🔥 UI FREEZE FIX: Pause ALL UI thread work globally (universal solution)
  /// This pauses ALL frame callbacks, display links, and any other UI thread work
  /// Works for animations, worklets, or any future UI thread operations
  Future<void> _pauseAllUIWork() async {
    try {
      await _nativeBridge.tunnel('ReanimatedView', 'pauseAllUIWork', {});
    } catch (e) {
      // Ignore errors - method might not exist or no UI work running
      EngineDebugLogger.log('UI_WORK_PAUSE_ERROR', 'Failed to pause UI work: $e');
    }
  }
  
  /// 🔥 UI FREEZE FIX: Resume ALL UI thread work globally (universal solution)
  /// This resumes ALL frame callbacks, display links, and any other UI thread work
  Future<void> _resumeAllUIWork() async {
    try {
      await _nativeBridge.tunnel('ReanimatedView', 'resumeAllUIWork', {});
    } catch (e) {
      // Ignore errors - method might not exist
      EngineDebugLogger.log('UI_WORK_RESUME_ERROR', 'Failed to resume UI work: $e');
    }
  }

  /// Process updates using concurrent processing
  /// Now supports incremental rendering with deadline-based scheduling
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

    // Use incremental reconciliation if enabled and tree is large
    if (_incrementalReconciliationEnabled && sortedUpdates.length > 50) {
      await _processUpdatesIncrementally(sortedUpdates);
      return;
    }

    try {
      final batchSize = 4; // Process in batches to keep workers busy
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
      await commitBatchUpdate();
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
  /// Now supports incremental rendering with deadline-based scheduling
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

    // Use incremental reconciliation if enabled and tree is large
    if (_incrementalReconciliationEnabled && sortedUpdates.length > 50) {
      await _processUpdatesIncrementally(sortedUpdates);
      return;
    }

    try {
      for (final componentId in sortedUpdates) {
        EngineDebugLogger.log(
            'BATCH_PROCESS_COMPONENT', 'Processing update for: $componentId');
        await _updateComponentById(componentId);
      }

      EngineDebugLogger.logBridge('COMMIT_BATCH', 'root');
      await commitBatchUpdate();
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

  /// Process updates incrementally with deadline-based scheduling
  Future<void> _processUpdatesIncrementally(List<String> sortedUpdates) async {
    EngineDebugLogger.log('BATCH_INCREMENTAL',
        'Processing ${sortedUpdates.length} updates incrementally');

    // Determine priority based on update count
    final priority =
        sortedUpdates.length > 200 ? WorkPriority.low : WorkPriority.high; // This is frame_scheduler WorkPriority, not worker_manager

    final completer = Completer<void>();
    bool hasError = false;
    String? errorMessage;

    // Schedule work with frame scheduler
    final scheduler = FrameScheduler.instance;

    if (priority == WorkPriority.high) {
      scheduler.scheduleHighPriorityWork((deadline) async {
        try {
          await _processUpdatesWithDeadline(sortedUpdates, deadline, completer);
        } catch (e) {
          hasError = true;
          errorMessage = e.toString();
          completer.completeError(e);
        }
      });
    } else {
      scheduler.scheduleLowPriorityWork((deadline) async {
        try {
          await _processUpdatesWithDeadline(sortedUpdates, deadline, completer);
        } catch (e) {
          hasError = true;
          errorMessage = e.toString();
          completer.completeError(e);
        }
      });
    }

    await completer.future;

    if (hasError) {
      EngineDebugLogger.logBridge('CANCEL_BATCH', 'root',
          data: {'Error': errorMessage});
      await _nativeBridge.cancelBatchUpdate();
      throw Exception(errorMessage);
    }

    EngineDebugLogger.logBridge('COMMIT_BATCH', 'root');
    await commitBatchUpdate();
  }

  Future<void> _processUpdatesWithDeadline(List<String> sortedUpdates,
      Deadline deadline, Completer<void> completer) async {
    int processed = 0;
    
    // 🔥 CPU THROTTLING: Process updates in smaller chunks with micro-delays
    // This prevents CPU from spiking during large batch processing
    const chunkSize = 5; // Process 5 updates at a time
    const chunkDelay = Duration(milliseconds: 1); // 1ms delay between chunks

    for (var i = 0; i < sortedUpdates.length; i++) {
      // Check deadline
      if (deadline.timeRemaining() <= 0) {
        // Schedule remaining work for next frame
        final remaining = sortedUpdates.sublist(processed);
        FrameScheduler.instance.scheduleLowPriorityWork((nextDeadline) async {
          await _processUpdatesWithDeadline(remaining, nextDeadline, completer);
        });
        return;
      }
      
      // 🔥 CPU THROTTLING: Add micro-delay every chunkSize updates
      // This spreads CPU load over time instead of spiking
      if (i > 0 && i % chunkSize == 0) {
        await Future.delayed(chunkDelay);
      }

      await _updateComponentById(sortedUpdates[i]);
      processed++;
    }

    completer.complete();
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

    // 🔥 CRITICAL: Render cycle detection to prevent infinite loops
    _renderCycleCount[componentId] = (_renderCycleCount[componentId] ?? 0) + 1;
    if (_renderCycleCount[componentId]! > _maxRenderCycles) {
      final errorMsg =
          '❌ INFINITE RENDER LOOP DETECTED: Component $componentId (${component.runtimeType}) '
          'has rendered ${_renderCycleCount[componentId]} times in this batch. '
          'This usually indicates:\n'
          '1. Invalid style/layout keys (e.g., styles[\'\'] instead of styles[\'section\'])\n'
          '2. State updates inside render() method\n'
          '3. Circular dependencies in component tree\n'
          'Check your component\'s render() method and ensure all style/layout keys are valid.';
      print(errorMsg);
      EngineDebugLogger.log('INFINITE_RENDER_LOOP', errorMsg);
      throw Exception(errorMsg);
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
        // Comprehensive type checking - handle all valid reconciliation cases
        bool canReconcile = false;
        if (previousRenderedNode is DCFElement &&
            newRenderedNode is DCFElement) {
          canReconcile = true;
        } else if (previousRenderedNode is DCFStatelessComponent &&
            newRenderedNode is DCFStatelessComponent) {
          canReconcile = true;
        } else if (previousRenderedNode is DCFStatefulComponent &&
            newRenderedNode is DCFStatefulComponent) {
          canReconcile = true;
        } else {
          // Mixed types - this can happen when a component's render() returns different types
          // We can still reconcile if they're both DCFComponentNode
          if (previousRenderedNode is DCFComponentNode &&
              newRenderedNode is DCFComponentNode) {
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
          try {
            await _reconcile(
                previousRenderedNode, newRenderedNode); // O(tree size)
          } catch (e, stackTrace) {
            EngineDebugLogger.log('RECONCILE_ERROR', 'Reconciliation failed: $e');
            rethrow;
          }
          component.contentViewId = previousRenderedNode.effectiveNativeViewId;
        }

        // CRITICAL: Store the reconciled node back as the component's rendered node
        // This ensures the next update uses the reconciled node as the previous node
        // IMPORTANT: Ensure the viewId is preserved from the previous node
        if (previousRenderedNode.effectiveNativeViewId != null &&
            newRenderedNode.effectiveNativeViewId == null) {
          // Transfer viewId if it wasn't already transferred during reconciliation
          if (previousRenderedNode is DCFElement &&
              newRenderedNode is DCFElement) {
            newRenderedNode.nativeViewId = previousRenderedNode.nativeViewId;
            newRenderedNode.contentViewId = previousRenderedNode.contentViewId;
          } else if (previousRenderedNode is DCFStatefulComponent &&
              newRenderedNode is DCFStatefulComponent) {
            newRenderedNode.nativeViewId = previousRenderedNode.nativeViewId;
            newRenderedNode.contentViewId = previousRenderedNode.contentViewId;
          }
        }
        component.renderedNode = newRenderedNode;

        _previousRenderedNodes.remove(componentId); // O(1)
        EngineDebugLogger.log(
            'RECONCILE_CLEANUP', 'Cleaned up previous rendered node reference');

        // FINAL SAFEGUARD: After reconciliation, ensure the component's rendered element mapping is correct
        // This is critical for SafeArea re-renders that create new Button instances
        if (newRenderedNode is DCFElement) {
          final viewId = newRenderedNode.nativeViewId;
          if (viewId != null) {
            final mappedNode = _nodesByViewId[viewId];
            if (mappedNode != newRenderedNode) {
              _nodesByViewId[viewId] = newRenderedNode;
            }
          }
        } else if (newRenderedNode is DCFStatefulComponent ||
            newRenderedNode is DCFStatelessComponent) {
          final renderedElement = newRenderedNode.renderedNode;
          if (renderedElement is DCFElement) {
            final viewId = renderedElement.nativeViewId;
            if (viewId != null) {
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
        // CRITICAL: Store the rendered node for the next update
        component.renderedNode = newRenderedNode;
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
  Future<int?> renderToNative(DCFComponentNode node,
      {int? parentViewId, int? index}) async {
    await isReady;

    // 🔥 CRITICAL: Guard against infinite render loops
    // Use identityHashCode for reliable instance tracking (not hashCode which can collide)
    final nodeIdentity = identityHashCode(node);
    
    // Guard against infinite render loops
    if (_nodesBeingRendered.contains(nodeIdentity)) {
      final errorMsg =
          '❌ INFINITE RENDER LOOP DETECTED: Node ${node.runtimeType} (identity: $nodeIdentity) '
          'is already being rendered. This indicates a recursive render call. '
          'Check for state updates in render() methods or effects that trigger re-renders.';
      EngineDebugLogger.log('INFINITE_RENDER_LOOP', errorMsg);
      throw Exception(errorMsg);
    }

    // Mark this node as being rendered
    _nodesBeingRendered.add(nodeIdentity);

    try {
    EngineDebugLogger.logRender('START', node,
        viewId: node.effectiveNativeViewId, parentId: parentViewId);
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
        final childIds = <int>[];

        EngineDebugLogger.log('FRAGMENT_CHILDREN',
            'Rendering ${node.children.length} fragment children');
        for (final child in node.children) {
          final childId = await renderToNative(child,
              parentViewId: parentViewId, index: childIndex++);

          if (childId != null) {
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
              scheduleUpdate: () => _scheduleComponentUpdateInternal(
                  node as DCFStatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': true},
            );
            lifecycleInterceptor.beforeMount(node, context);
          }

          // 🔥 CRITICAL: Get renderedNode BEFORE registering component
          // This prevents scheduleUpdate from being set up before render() completes
          // If render() triggers any state updates, scheduleUpdate is still a no-op
          final renderedNode = node.renderedNode;
          
          // Now register component after render() has completed safely
          registerComponent(node);
          if (renderedNode == null) {
            EngineDebugLogger.logRender('ERROR', node,
                error: 'Component rendered null');
            throw Exception('Component rendered null');
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
          if (renderedNode is DCFElement && viewId != null) {
            final mappedNode = _nodesByViewId[viewId];
            if (mappedNode != renderedNode) {
              _nodesByViewId[viewId] = renderedNode;
            }
          }
          EngineDebugLogger.log(
              'COMPONENT_VIEW_ID', 'Component view ID assigned',
              extra: {'ViewId': viewId});

          if (node is DCFStatefulComponent && !node.isMounted) {
            // CRITICAL: Reset effects BEFORE componentDidMount to ensure they run on first mount
            // This fixes the issue where effects don't run after hot restart
            // We need to reset effects while isMounted is still false
            EngineDebugLogger.log(
                'LIFECYCLE_EFFECTS_RESET', 'Resetting effects for first mount');
            node.resetEffectsForFirstMount();
            
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
              scheduleUpdate: () => _scheduleComponentUpdateInternal(
                  node as DCFStatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': false},
            );
            lifecycleInterceptor.afterMount(node, context);
          }

          EngineDebugLogger.logRender('SUCCESS', node, viewId: viewId);
          return viewId;
        } catch (error, stackTrace) {
          _performanceMonitor.recordError();
          EngineDebugLogger.logRender('ERROR', node, error: error.toString());

          // Attempt error recovery with exponential backoff
          final viewId = await _errorRecovery.attemptRecovery(
            operationId: 'render_${node.runtimeType}_${node.hashCode}',
            operation: () async {
              // Retry render operation
              return await renderToNative(node,
                  parentViewId: parentViewId, index: index);
            },
            strategy: ErrorRecoveryStrategy.exponentialBackoff,
            fallbackValue: null,
            onRetry: () async {
              EngineDebugLogger.log('ERROR_RECOVERY_RETRY',
                  'Retrying render operation after error');
            },
          );

          if (viewId != null) {
            _performanceMonitor.recordRecoverySuccess();
            return viewId;
          }

          _performanceMonitor.recordRecoveryFailure();

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
      } else if (node is DCFElement) {
        EngineDebugLogger.log('RENDER_ELEMENT', 'Rendering element node',
            extra: {'ElementType': node.type});
        return await _renderElementToNative(node,
            parentViewId: parentViewId, index: index);
      } else if (node is EmptyVDomNode) {
        EngineDebugLogger.log('RENDER_EMPTY', 'Rendering empty node');
        return null; // Empty nodes don't create native views
      }

      EngineDebugLogger.logRender('UNKNOWN', node, error: 'Unknown node type');
      return null;
    } catch (e) {
      EngineDebugLogger.logRender('ERROR', node, error: e.toString());
      return null;
    } finally {
      // Always remove from rendering set when done (even on error)
      _nodesBeingRendered.remove(nodeIdentity);
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
  Future<int?> _renderElementToNative(DCFElement element,
      {int? parentViewId, int? index}) async {
    EngineDebugLogger.log('ELEMENT_RENDER_START', 'Starting element render',
        extra: {
          'ElementType': element.type,
          'ParentViewId': parentViewId,
          'Index': index
        });

    final viewId = element.nativeViewId ?? _generateViewId();

    _nodesByViewId[viewId] = element;
    element.nativeViewId = viewId;

    // Verify mapping immediately after setting
    final verifyMapped = _nodesByViewId[viewId];
    if (verifyMapped != element) {
      _nodesByViewId[viewId] = element; // Fix it
    }
    EngineDebugLogger.log('ELEMENT_VIEW_MAPPING', 'Mapped element to view ID',
        extra: {'ViewId': viewId, 'ElementType': element.type});

    EngineDebugLogger.logBridge('CREATE_VIEW', viewId, data: {
      'ElementType': element.type,
      'Props': element.elementProps.keys.toList()
    });
    try {
      final success = await _nativeBridge
          .createView(viewId, element.type, element.elementProps)
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return false;
        },
      );
      if (!success) {
        EngineDebugLogger.log(
            'ELEMENT_CREATE_FAILED', 'Failed to create native view',
            extra: {'ViewId': viewId, 'ElementType': element.type});
        return null;
      }
    } catch (e, stackTrace) {
      EngineDebugLogger.log('ELEMENT_CREATE_ERROR', 'Error creating view: $e');
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
      
      // 🔥 NEW: Register events in centralized EventRegistry
      // No prefix guessing - use exact event names from element props
      // Native side queries the registry to know what events are available
      final eventHandlers = element.eventHandlers;
      
      if (eventHandlers.isNotEmpty) {
        final registry = EventRegistry();
        registry.register(viewId, eventHandlers);
        EngineDebugLogger.log('EVENT_REGISTRY', 
            'Registered ${eventHandlers.length} events for view $viewId: ${eventHandlers.keys.join(", ")}');
      }
    }

    final childIds = <int>[];
    EngineDebugLogger.log('ELEMENT_CHILDREN_START',
        'Rendering ${element.children.length} children');

    // 🔥 UI THREAD YIELDING: Yield every 3 children to prevent UI freeze
    const yieldInterval = 3;
    for (var i = 0; i < element.children.length; i++) {
      // Yield control back to UI thread every few children
      if (i > 0 && i % yieldInterval == 0) {
        await Future.delayed(Duration.zero); // Yield to event loop
      }
      
      try {
        final childId = await renderToNative(element.children[i],
            parentViewId: viewId, index: i);
        if (childId != null) {
          childIds.add(childId);
        }
      } catch (e, stackTrace) {
        EngineDebugLogger.log('ELEMENT_CHILD_ERROR', 'Error rendering child: $e');
        rethrow;
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
  /// Supports incremental rendering with pause/resume and isolate-based parallel diffing
  Future<void> _reconcile(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    EngineDebugLogger.logReconcile('START', oldNode, newNode,
        reason: 'Beginning reconciliation');

    // Set work in progress tree
    _workInProgressTree = newNode;

    // CRITICAL: Only use isolate reconciliation for updates to existing trees
    // Never use it for initial render - initial render must happen synchronously
    // on the main thread to ensure proper UI synchronization
    final isInitialRender = oldNode.effectiveNativeViewId == null;

    // Use worker_manager for parallel reconciliation (but NOT for initial render)
    // 🔥 CRITICAL: Disable worker_manager reconciliation during hot reload to prevent issues
    bool usedIsolate = false;
    final shouldSkipWorkerManager = _skipWorkerManagerForThisReconciliation;
    
    if (!isInitialRender &&
        !_isHotReloading &&
        !shouldSkipWorkerManager &&
        _workerManagerInitialized &&
        _shouldUseIsolateReconciliation(oldNode, newNode)) {
      try {
        await _reconcileWithIsolate(oldNode, newNode);
        usedIsolate = true;
        // Reset flag only on success
        _skipWorkerManagerForThisReconciliation = false;
      } catch (e) {
        EngineDebugLogger.logReconcile(
            'WORKER_MANAGER_FALLBACK_ERROR', oldNode, newNode,
            reason: 'Worker_manager reconciliation failed, falling back: $e');
        // Set flag to prevent re-entering worker_manager in nested reconciliations
        _skipWorkerManagerForThisReconciliation = true;
        // Continue with regular reconciliation
      }
    } else {
      // Reset flag when not using worker_manager
      _skipWorkerManagerForThisReconciliation = false;
      
      if (!isInitialRender) {
      // Log why isolates weren't used (for debugging)
      final nodeCount =
          _countNodeChildren(oldNode) + _countNodeChildren(newNode);
      if (nodeCount < 50) {
        // Tree too small - this is normal, don't log
      }
      // Note: No need to log about missing workers - they will be spawned on demand
      }
    }

    // If isolate reconciliation completed, we're done
    if (usedIsolate) {
      return;
    }
    
    // 🚀 OPTIMIZATION: For very large trees that are completely different, use direct replace
    // This makes navigation instant instead of slow reconciliation
    if (!isInitialRender) {
      final nodeCount = _countNodeChildren(oldNode) + _countNodeChildren(newNode);
      if (nodeCount >= 100) {
        // Large tree - check if structures are completely different
        // Only check similarity for elements (structural similarity function requires elements)
        double? structuralSimilarity;
        if (oldNode is DCFElement && newNode is DCFElement) {
          structuralSimilarity = _computeStructuralSimilarity(oldNode, newNode);
        } else {
          // For components, check if rendered elements are different
          final oldRendered = oldNode is DCFStatefulComponent || oldNode is DCFStatelessComponent
              ? oldNode.renderedNode
              : oldNode;
          final newRendered = newNode is DCFStatefulComponent || newNode is DCFStatelessComponent
              ? newNode.renderedNode
              : newNode;
          
          if (oldRendered is DCFElement && newRendered is DCFElement) {
            structuralSimilarity = _computeStructuralSimilarity(oldRendered, newRendered);
          } else {
            // Can't compute similarity - assume different and use replace for large trees
            structuralSimilarity = 0.0;
          }
        }
        
        if (structuralSimilarity != null && structuralSimilarity < 0.2) {
          // Trees are very different (< 20% similar) - use direct replace for instant navigation
          EngineDebugLogger.logReconcile(
              'REPLACE_LARGE_TREE', oldNode, newNode,
              reason: 'Large tree with low structural similarity - direct replace');
          await _replaceNode(oldNode, newNode);
          return;
        }
      }
    }
    
    // 🔥 CRITICAL: Check structural shock flag FIRST, before any position key computation
    // This prevents position-based matching from incorrectly matching old components
    if (_isStructuralShock) {
      EngineDebugLogger.logReconcile(
          'REPLACE_STRUCTURAL_SHOCK', oldNode, newNode,
          reason: 'Structural shock active - forcing full replacement');
      await _replaceNode(oldNode, newNode);
      return;
    }

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

    // 🔥 CRITICAL: Different component base types (Stateless vs Stateful) = full replacement
    // This handles cases like DCFView (Stateless) → BenchmarkApp (Stateful)
    if ((oldNode is DCFStatelessComponent && newNode is DCFStatefulComponent) ||
        (oldNode is DCFStatefulComponent && newNode is DCFStatelessComponent)) {
      print(
          '🔍 RECONCILE: Different component base types: ${oldNode.runtimeType} (${oldNode is DCFStatelessComponent ? "Stateless" : "Stateful"}) → ${newNode.runtimeType} (${newNode is DCFStatelessComponent ? "Stateless" : "Stateful"})');
      EngineDebugLogger.logReconcile(
          'REPLACE_COMPONENT_BASE_TYPE', oldNode, newNode,
          reason:
              'Different component base types (Stateless vs Stateful) - full replacement');
      await _replaceNode(oldNode, newNode);
      return;
    }

    // 🔥 CRITICAL: Skip position tracking during structural shock to prevent incorrect matching
    // Component instance tracking by position + type + props
    // We maintain component instances across renders when at same position with same type
    if (!_isStructuralShock) {
      final parentViewId = _findParentViewId(oldNode) ?? 0;
      final nodeIndex = _findNodeIndexInParent(oldNode);
      final positionKey = "$parentViewId:$nodeIndex:${newNode.runtimeType}";
      final propsHash = _computePropsHash(newNode);
      final propsKey = "$positionKey:$propsHash";

      // Try to find existing instance by position + type + props
      // This is automatic key inference - match by position when types/props match
      final existingByProps = _componentInstancesByProps[propsKey];

      // If we found an existing instance with same props, reuse it
      if (existingByProps != null &&
          existingByProps.runtimeType == newNode.runtimeType) {
        if (existingByProps is DCFStatefulComponent &&
            newNode is DCFStatefulComponent) {
          // Same component instance - update it instead of creating new one
          EngineDebugLogger.logReconcile(
              'REUSE_INSTANCE_BY_PROPS', oldNode, newNode,
              reason: 'Reusing component instance by position+props');
          // Continue with reconciliation - this is the same instance
        }
      }

      // Track component instance by position and props (automatic key inference)
      _componentInstancesByPosition[positionKey] = newNode;
      _componentInstancesByProps[propsKey] = newNode;
    }

    // Check keys first
    // Only replace if keys are explicitly different (both have keys)
    if (oldNode.key != null &&
        newNode.key != null &&
        oldNode.key != newNode.key) {
      EngineDebugLogger.logReconcile('REPLACE_KEY', oldNode, newNode,
          reason: 'Different keys - hot reload fix');
      await _replaceNode(oldNode, newNode);
      return;
    }

    // If no keys or same keys, match by position and type
    // This is automatic key inference - works in 99% of cases

    // For elements, check if they're the same element type
    if (oldNode is DCFElement && newNode is DCFElement) {
      print(
          '🔍 RECONCILE: Both are DCFElement - oldType: ${oldNode.type}, newType: ${newNode.type}');
      if (oldNode.type != newNode.type) {

        EngineDebugLogger.logReconcile('REPLACE_ELEMENT_TYPE', oldNode, newNode,
            reason: 'Different element types - full replacement');
        await _replaceNode(oldNode, newNode);
      } else {
        // 🔥 CRITICAL: Check if props/content differ significantly
        // This prevents prop leakage when components are matched by position/type
        // but have completely different content/props
        final propsSimilarity =
            _computePropsSimilarity(oldNode.elementProps, newNode.elementProps);
        if (propsSimilarity < 0.5) {
          EngineDebugLogger.log('REPLACE_ELEMENT_PROPS_MISMATCH',
              'Props/content differ significantly - forcing replacement',
              extra: {
                'ElementType': oldNode.type,
                'PropsSimilarity': propsSimilarity,
                'OldPropsKeys': oldNode.elementProps.keys.toList(),
                'NewPropsKeys': newNode.elementProps.keys.toList(),
              });
          EngineDebugLogger.logReconcile(
              'REPLACE_ELEMENT_PROPS_MISMATCH', oldNode, newNode,
              reason:
                  'Props/content differ significantly - forcing replacement');
          await _replaceNode(oldNode, newNode);
          return;
        }

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
          EngineDebugLogger.logReconcile(
              'REPLACE_ELEMENT_CHILDREN_MISMATCH', oldNode, newNode,
              reason:
                  'Significant children count difference - forcing replacement');
          await _replaceNode(oldNode, newNode);
        } else {
          EngineDebugLogger.logReconcile('UPDATE_ELEMENT', oldNode, newNode,
              reason: 'Same element type - updating props and children');

          // Add update effect
          _effectList.addEffect(Effect(
            node: newNode,
            type: EffectType.update,
            payload: {'oldNode': oldNode},
          ));

          await _reconcileElement(oldNode, newNode);
        }
      }
    } else if (oldNode is DCFStatefulComponent &&
        newNode is DCFStatefulComponent) {
      // Different component classes mean different components entirely
      if (oldNode.runtimeType != newNode.runtimeType) {
        EngineDebugLogger.logReconcile(
            'REPLACE_COMPONENT_TYPE', oldNode, newNode,
            reason: 'Different StatefulComponent types - full replacement');
        await _replaceNode(oldNode, newNode);
        return;
      }

      if (identical(oldNode, newNode)) {
        newNode.nativeViewId = oldNode.nativeViewId;
        newNode.contentViewId = oldNode.contentViewId;
        newNode.parent = oldNode.parent;
        newNode.renderedNode = oldNode.renderedNode;

        _statefulComponents[newNode.instanceId] = newNode;
        newNode.scheduleUpdate = () => _scheduleComponentUpdate(newNode);

        return;
      }
      EngineDebugLogger.logReconcile('UPDATE_STATEFUL', oldNode, newNode,
          reason: 'Reconciling StatefulComponent');

      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      _statefulComponents[newNode.instanceId] = newNode;
      newNode.scheduleUpdate = () => _scheduleComponentUpdate(newNode);

      registerComponent(newNode);

      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;

      print(
          '🔍 RECONCILE: Rendered nodes - old: ${oldRenderedNode.runtimeType}, new: ${newRenderedNode.runtimeType}');
      if (oldRenderedNode is DCFElement && newRenderedNode is DCFElement) {
        print(
            '🔍 RECONCILE: Element types - old: ${oldRenderedNode.type}, new: ${newRenderedNode.type}');
      }

      await _reconcile(oldRenderedNode, newRenderedNode);

      // CRITICAL: After reconciling rendered nodes, ensure the mapping points to the NEW rendered element
      // This is essential for components like DCFButton that render DCFElement instances
      // When SafeArea re-renders, it creates new Button instances, and we must ensure
      // the mapping points to the new Button's rendered element (not the old one)
      if (newRenderedNode is DCFElement) {
        final renderedViewId = newRenderedNode.nativeViewId;
        if (renderedViewId != null) {
          final mappedNode = _nodesByViewId[renderedViewId];
          if (mappedNode != newRenderedNode) {
            EngineDebugLogger.log('RECONCILE_STATEFUL_RENDERED_FIX',
                '⚠️ Fixed mapping for stateful component\'s rendered element',
                extra: {
                  'ViewId': renderedViewId,
                  'ElementType': newRenderedNode.type,
                  'HasOnPress':
                      newRenderedNode.elementProps.containsKey('onPress'),
                  'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                });
            _nodesByViewId[renderedViewId] = newRenderedNode;
          }

          // CRITICAL: If this is a View element (like SafeArea's DCFView), ensure ALL child Button mappings are preserved
          // This is the root cause: when SafeArea re-renders, its DCFView reconciles, and Button children
          // might lose their mappings during child reconciliation
          if (newRenderedNode.type == 'View' &&
              newRenderedNode.children.isNotEmpty) {
            for (final child in newRenderedNode.children) {
              final childViewId = child.effectiveNativeViewId;
              if (childViewId != null) {
                if (child is DCFElement) {
                  final childMapped = _nodesByViewId[childViewId];
                  if (childMapped != child) {
                    EngineDebugLogger.log('RECONCILE_STATEFUL_VIEW_CHILD_FIX',
                        '⚠️ Fixed Button child mapping in SafeArea View',
                        extra: {
                          'ViewId': childViewId,
                          'ChildType': child.type,
                          'HasOnPress':
                              child.elementProps.containsKey('onPress')
                        });
                    _nodesByViewId[childViewId] = child;
                  }
                } else if (child is DCFStatelessComponent ||
                    child is DCFStatefulComponent) {
                  final renderedElement = child.renderedNode;
                  if (renderedElement is DCFElement) {
                    final renderedViewId = renderedElement.nativeViewId;
                    if (renderedViewId != null) {
                      final renderedMapped = _nodesByViewId[renderedViewId];
                      if (renderedMapped != renderedElement) {
                        EngineDebugLogger.log(
                            'RECONCILE_STATEFUL_VIEW_CHILD_COMPONENT_FIX',
                            '⚠️ Fixed Button component child mapping in SafeArea View',
                            extra: {
                              'RenderedViewId': renderedViewId,
                              'ElementType': renderedElement.type,
                              'HasOnPress': renderedElement.elementProps
                                  .containsKey('onPress')
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
      } else if (newRenderedNode is DCFStatefulComponent ||
          newRenderedNode is DCFStatelessComponent) {
        // For nested components, traverse to find the actual element
        DCFComponentNode? current = newRenderedNode;
        DCFElement? actualElement;
        while (current != null) {
          if (current is DCFElement) {
            actualElement = current;
            break;
          } else if (current is DCFStatefulComponent ||
              current is DCFStatelessComponent) {
            current = current.renderedNode;
          } else {
            break;
          }
        }
        if (actualElement != null) {
          final elementViewId = actualElement.nativeViewId;
          if (elementViewId != null) {
            final mappedNode = _nodesByViewId[elementViewId];
            if (mappedNode != actualElement) {
              EngineDebugLogger.log('RECONCILE_STATEFUL_NESTED_ELEMENT_FIX',
                  '⚠️ Fixed mapping for nested component\'s rendered element',
                  extra: {
                    'ViewId': elementViewId,
                    'ElementType': actualElement.type,
                    'HasOnPress':
                        actualElement.elementProps.containsKey('onPress')
                  });
              _nodesByViewId[elementViewId] = actualElement;
            }
          }
        }
      }
    } else if (oldNode is DCFStatelessComponent &&
        newNode is DCFStatelessComponent) {
      // 🚀 OPTIMIZATION: Early exit for DCFSuspense when shouldRender hasn't changed
      // This prevents unnecessary reconciliation during navigation when screens haven't changed state
      if (oldNode.runtimeType == newNode.runtimeType &&
          oldNode.runtimeType.toString().contains('DCFSuspense')) {
        try {
          // Use reflection to check if shouldRender prop is the same
          final oldShouldRender = (oldNode as dynamic).shouldRender;
          final newShouldRender = (newNode as dynamic).shouldRender;
          
          if (oldShouldRender == newShouldRender) {
            // shouldRender hasn't changed - skip reconciliation entirely
            // Transfer view IDs and rendered node to preserve state
            newNode.nativeViewId = oldNode.nativeViewId;
            newNode.contentViewId = oldNode.contentViewId;
            newNode.renderedNode = oldNode.renderedNode;
            return;
          } else {
            // 🚀 CRITICAL: shouldRender changed - this is a screen replacement
            // Use direct replace strategy instead of full reconciliation for instant navigation
            // This is much faster than reconciling the entire tree
            final oldRendered = oldNode.renderedNode;
            final newRendered = newNode.renderedNode;
            
            // If both rendered nodes are DCFView (common case), use direct replace
            if (oldRendered is DCFElement && 
                newRendered is DCFElement &&
                oldRendered.type == 'View' && 
                newRendered.type == 'View') {
              // Direct replace - use _replaceNode which handles unmount/mount efficiently
              // This skips reconciliation and just replaces the view atomically
              final oldViewId = oldNode.effectiveNativeViewId;
              if (oldViewId != null) {
                // Use _replaceNode for efficient screen replacement (delete + create, no reconciliation)
                await _replaceNode(oldNode, newNode);
                return;
              }
            }
          }
        } catch (e) {
          // If reflection fails, continue with normal reconciliation
        }
      }
      
      // Different component classes (e.g., DCFView vs DCFScrollView) mean different components
      // We need to reconcile their RENDERED elements, not the components themselves
      if (oldNode.runtimeType != newNode.runtimeType) {
        EngineDebugLogger.logReconcile(
            'RECONCILE_STATELESS_VIA_ELEMENTS', oldNode, newNode,
            reason:
                'Different StatelessComponent types - reconcile via rendered elements');

        // Instead of replacing the component, reconcile the rendered elements
        // This allows proper View → ScrollView transitions with element-level reconciliation
        final oldRenderedNode = oldNode.renderedNode;
        final newRenderedNode = newNode.renderedNode;

        // Transfer view IDs to new component
        newNode.nativeViewId = oldNode.nativeViewId;
        newNode.contentViewId = oldNode.contentViewId;

        print(
            '🔍 RECONCILE: oldRendered: ${oldRenderedNode.runtimeType}, newRendered: ${newRenderedNode.runtimeType}');
        if (oldRenderedNode is DCFElement && newRenderedNode is DCFElement) {
          print(
              '🔍 RECONCILE: Element types: ${oldRenderedNode.type} → ${newRenderedNode.type}');
        }

        // Step 1: Update this component's renderedNode to point to the new element
        print(
            '🔄 PRE-RECONCILE: Updating ${newNode.runtimeType} renderedNode to new element');
        newNode.renderedNode = newRenderedNode;

        // Step 2: Update all ancestors' renderedNode to point to this NEW component
        DCFComponentNode? ancestor = newNode.parent;
        while (ancestor != null) {
          if (ancestor is DCFStatefulComponent) {
            print(
                '🔄 PRE-RECONCILE: Updating ancestor ${ancestor.runtimeType} renderedNode to point to new component');
            ancestor.renderedNode = newNode;
            break; // Only update the direct parent, not all ancestors
          }
          ancestor = ancestor.parent;
        }

        await _reconcile(oldRenderedNode, newRenderedNode);

        if (newRenderedNode is DCFElement &&
            newRenderedNode.nativeViewId != null) {
          final newElementViewId = newRenderedNode.nativeViewId!;
          if (newElementViewId != newNode.contentViewId) {
            print(
                '🔄 RECONCILE: Updating component contentViewId: ${newNode.contentViewId} → $newElementViewId');
            newNode.contentViewId = newElementViewId;
          }

          final oldElementViewId = oldRenderedNode is DCFElement
              ? oldRenderedNode.nativeViewId
              : null;
          print(
              '🔄 RECONCILE: Walking up tree to update ancestors (oldId: $oldElementViewId, newId: $newElementViewId)');

          DCFComponentNode? ancestor = newNode.parent;
          while (ancestor != null) {
            if (ancestor is DCFStatefulComponent ||
                ancestor is DCFStatelessComponent) {
              // Always update the FIRST component ancestor (the direct parent)
              // OR update any ancestor whose nativeViewId matches the old element's ID
              if (ancestor == newNode.parent ||
                  (oldElementViewId != null &&
                      ancestor.nativeViewId == oldElementViewId)) {
                print(
                    '🔄 RECONCILE: Updating ancestor ${ancestor.runtimeType} nativeViewId: ${ancestor.nativeViewId} → $newElementViewId');
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

      // 🔥 CRITICAL: Check if system state changed - if so, invalidate cache to force fresh render
      final oldRenderedNode = oldNode.renderedNode;
      if (oldRenderedNode is DCFElement) {
        final oldSystemVersion = oldRenderedNode.elementProps['_systemVersion'];
        final currentSystemVersion = SystemStateManager.version;
        if (oldSystemVersion != null && oldSystemVersion != currentSystemVersion) {
          // System state changed - clear cache to force fresh render with new _systemVersion
          print('🔄 STATELESS: System state changed ($oldSystemVersion → $currentSystemVersion), invalidating cache');
          newNode.renderedNode = null; // Clear cache using public setter
        }
      }

      final newRenderedNode = newNode.renderedNode;

      print(
          '🟢 STATELESS RECONCILE: ${oldNode.runtimeType} → ${newNode.runtimeType}');
      print(
          '🟢 STATELESS RECONCILE: oldRendered=${oldRenderedNode.runtimeType}, newRendered=${newRenderedNode.runtimeType}');
      if (oldRenderedNode is DCFElement && newRenderedNode is DCFElement) {
        print(
            '🟢 STATELESS RECONCILE: oldElement viewId=${oldRenderedNode.nativeViewId}, type=${oldRenderedNode.type}');
        print(
            '🟢 STATELESS RECONCILE: newElement viewId=${newRenderedNode.nativeViewId}, type=${newRenderedNode.type}');
        print(
            '🟢 STATELESS RECONCILE: oldElement hasOnPress=${oldRenderedNode.elementProps.containsKey('onPress')}');
        print(
            '🟢 STATELESS RECONCILE: newElement hasOnPress=${newRenderedNode.elementProps.containsKey('onPress')}');
      }

      await _reconcile(oldRenderedNode, newRenderedNode);

      // CRITICAL: After reconciling rendered nodes, ensure the mapping points to the NEW rendered element
      // This is essential for components like DCFButton that render DCFElement instances
      // When SafeArea re-renders, it creates new Button instances, and we must ensure
      // the mapping points to the new Button's rendered element (not the old one)
      if (newRenderedNode is DCFElement) {
        final renderedViewId = newRenderedNode.nativeViewId;
        if (renderedViewId != null) {
          final mappedNode = _nodesByViewId[renderedViewId];
          if (mappedNode != newRenderedNode) {
            EngineDebugLogger.log('RECONCILE_STATELESS_RENDERED_FIX',
                'Fixed mapping for stateless component\'s rendered element',
                extra: {
                  'ViewId': renderedViewId,
                  'ElementType': newRenderedNode.type,
                  'HasOnPress':
                      newRenderedNode.elementProps.containsKey('onPress'),
                  'OldMappedType': mappedNode?.runtimeType.toString() ?? 'null'
                });
            _nodesByViewId[renderedViewId] = newRenderedNode;
          }
        } else {
          print('❌ STATELESS NO VIEWID: renderedViewId is null or empty!');
        }
      } else if (newRenderedNode is DCFStatefulComponent ||
          newRenderedNode is DCFStatelessComponent) {
        // For nested components, traverse to find the actual element
        DCFComponentNode? current = newRenderedNode;
        DCFElement? actualElement;
        while (current != null) {
          if (current is DCFElement) {
            actualElement = current;
            break;
          } else if (current is DCFStatefulComponent ||
              current is DCFStatelessComponent) {
            current = current.renderedNode;
          } else {
            break;
          }
        }
        if (actualElement != null) {
          final elementViewId = actualElement.nativeViewId;
          if (elementViewId != null) {
            final mappedNode = _nodesByViewId[elementViewId];
            if (mappedNode != actualElement) {
              EngineDebugLogger.log('RECONCILE_STATELESS_NESTED_ELEMENT_FIX',
                  '⚠️ Fixed mapping for nested stateless component\'s rendered element',
                  extra: {
                    'ViewId': elementViewId,
                    'ElementType': actualElement.type,
                    'HasOnPress':
                        actualElement.elementProps.containsKey('onPress')
                  });
              _nodesByViewId[elementViewId] = actualElement;
            }

            // CRITICAL: After fixing the View element mapping, ensure ALL Button children mappings are correct
            // This is the root cause: when SafeArea's DCFView reconciles, Button children might lose their mappings
            if (actualElement.type == 'View' &&
                actualElement.children.isNotEmpty) {
              for (final child in actualElement.children) {
                if (child is DCFStatefulComponent ||
                    child is DCFStatelessComponent) {
                  final renderedElement = child.renderedNode;
                  if (renderedElement is DCFElement) {
                    final childViewId = renderedElement.nativeViewId;
                    if (childViewId != null) {
                      final childMappedNode = _nodesByViewId[childViewId];
                      if (childMappedNode != renderedElement) {
                        _nodesByViewId[childViewId] = renderedElement;
                        EngineDebugLogger.log(
                            'RECONCILE_STATELESS_CHILD_BUTTON_FIX',
                            '⚠️ Fixed Button child mapping after DCFView reconciliation',
                            extra: {
                              'ViewId': childViewId,
                              'ElementType': renderedElement.type,
                              'HasOnPress': renderedElement.elementProps
                                  .containsKey('onPress')
                            });
                      }
                    }
                  }
                } else if (child is DCFElement) {
                  final childViewId = child.nativeViewId;
                  if (childViewId != null) {
                    final childMappedNode = _nodesByViewId[childViewId];
                    if (childMappedNode != child) {
                      _nodesByViewId[childViewId] = child;
                      EngineDebugLogger.log(
                          'RECONCILE_STATELESS_CHILD_ELEMENT_FIX',
                          '⚠️ Fixed child element mapping after DCFView reconciliation',
                          extra: {
                            'ViewId': childViewId,
                            'ElementType': child.type,
                            'HasOnPress':
                                child.elementProps.containsKey('onPress')
                          });
                    }
                  }
                }
              }
            }
          }
        }
      }
    } else if (oldNode is DCFFragment && newNode is DCFFragment) {
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
              parentViewId!, oldNode.children, newNode.children);
        }
      }
    } else if (oldNode is EmptyVDomNode && newNode is EmptyVDomNode) {
      EngineDebugLogger.logReconcile('SKIP_EMPTY', oldNode, newNode,
          reason: 'Both nodes are empty');
      return;
    }

    EngineDebugLogger.logReconcile('COMPLETE', oldNode, newNode,
        reason: 'Reconciliation completed successfully');
  }

  /// Check if isolate-based reconciliation should be used
  bool _shouldUseIsolateReconciliation(
      DCFComponentNode oldNode, DCFComponentNode newNode) {
    // Use worker manager for trees with 20+ nodes
    final oldNodeCount = _countNodeChildren(oldNode);
    final newNodeCount = _countNodeChildren(newNode);
    final totalNodes = oldNodeCount + newNodeCount;

    // 🚀 OPTIMIZATION: Use worker manager for trees with 20+ nodes
    // Large component structures benefit from parallel reconciliation
    final shouldUse = totalNodes >= 20 && _workerManagerInitialized && !_isHotReloading;

    if (totalNodes >= 20) {
      if (shouldUse) {
        print(
            '⚡ WORKER_MANAGER: Large tree detected ($totalNodes nodes) - Using parallel reconciliation for optimal performance');
        print(
            '   └─ Estimated speedup: ${((totalNodes / 20) * 0.3).toStringAsFixed(1)}x');
      }
    }

    return shouldUse;
  }

  /// Count children recursively
  int _countNodeChildren(DCFComponentNode node) {
    int count = 1;
    if (node is DCFElement) {
      for (final child in node.children) {
        count += _countNodeChildren(child);
      }
    } else if (node is DCFStatefulComponent || node is DCFStatelessComponent) {
      final rendered = node.renderedNode;
      if (rendered != null) {
        count += _countNodeChildren(rendered);
      }
    }
    return count;
  }

  /// Reconcile using worker_manager for parallel diffing
  Future<void> _reconcileWithIsolate(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    if (!_workerManagerInitialized) {
      throw Exception('Worker manager not initialized');
    }

    final totalNodes =
        _countNodeChildren(oldNode) + _countNodeChildren(newNode);
    final startTime = DateTime.now();
    print('🚀 WORKER_MANAGER: Starting parallel reconciliation ($totalNodes nodes)');
    EngineDebugLogger.logReconcile('WORKER_MANAGER_START', oldNode, newNode,
        reason: 'Using worker_manager for parallel reconciliation');

    try {
      // Check if oldNode has been rendered - if not, treat as initial render
      final oldNodeRendered = oldNode.effectiveNativeViewId != null;

      // Serialize trees to maps for worker
      final serializeStart = DateTime.now();
      final oldTreeData =
          oldNodeRendered ? _serializeNodeForIsolate(oldNode) : null;
      final newTreeData = _serializeNodeForIsolate(newNode);
      final serializeTime =
          DateTime.now().difference(serializeStart).inMilliseconds;

      // Execute reconciliation in worker isolate using worker_manager
      final workerStartTime = DateTime.now();
      final result = await worker_manager.workerManager.execute<Map<String, dynamic>>(
        () => _reconcileTreeInIsolate({
          'oldTree': oldTreeData,
          'newTree': newTreeData,
        }),
        priority: worker_priority.WorkPriority.immediately,
      );
      final workerProcessingTime =
          DateTime.now().difference(workerStartTime).inMilliseconds;

      final changesCount = (result['changes'] as List?)?.length ?? 0;
      final metrics = result['metrics'] as Map<String, dynamic>? ?? {};

      print(
          '⚡ WORKER_MANAGER: Parallel diff computed in ${workerProcessingTime}ms (serialization: ${serializeTime}ms)');
      print(
          '📊 WORKER_MANAGER: Performance - Nodes: $totalNodes | Changes: $changesCount | Complexity: ${metrics['complexity'] ?? 'unknown'}');

      // If no changes detected, the diff algorithm might have missed structural changes
      // Instead of throwing, just return and let regular reconciliation handle it
      // This prevents infinite loops while still allowing proper reconciliation
      if (changesCount == 0) {
        print('⚠️ WORKER_MANAGER: No changes detected by diff algorithm, but structural changes may exist');
        print('⚠️ WORKER_MANAGER: Falling back to regular reconciliation to ensure changes are applied');
        // Don't throw - just return false to indicate we need regular reconciliation
        // The caller will handle the fallback
        throw Exception('No changes detected - fallback to regular reconciliation');
      }

      // Apply diff results
      final applyStartTime = DateTime.now();
      await _applyIsolateDiff(oldNode, newNode, result);
      final applyTime =
          DateTime.now().difference(applyStartTime).inMilliseconds;

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      final estimatedMainThreadTime =
          totalNodes * 2; // Rough estimate: ~2ms per node on main thread
      final timeSaved = estimatedMainThreadTime > totalTime
          ? estimatedMainThreadTime - totalTime
          : 0;

      print(
          '✅ WORKER_MANAGER: Diff applied in ${applyTime}ms | Total: ${totalTime}ms');
      if (timeSaved > 0) {
        print(
            '🎯 WORKER_MANAGER: Performance boost - Saved ~${timeSaved}ms by offloading to worker (${((timeSaved / estimatedMainThreadTime) * 100).toStringAsFixed(1)}% faster)');
      }
      EngineDebugLogger.logReconcile('WORKER_MANAGER_COMPLETE', oldNode, newNode,
          reason: 'Worker_manager-based reconciliation completed');
    } catch (e, stackTrace) {
      print('❌ WORKER_MANAGER: Reconciliation failed with error: $e');
      print('❌ WORKER_MANAGER: Stack trace: $stackTrace');
      EngineDebugLogger.logReconcile('WORKER_MANAGER_ERROR', oldNode, newNode,
          reason: 'Worker_manager reconciliation failed: $e');
      // CRITICAL: Rethrow to trigger fallback to regular reconciliation
      rethrow;
    }
  }

  /// Serialize node to map for isolate
  /// CRITICAL: Filters out non-serializable values (functions, closures, ReceivePorts, etc.)
  Map<String, dynamic> _serializeNodeForIsolate(DCFComponentNode node) {
    final data = <String, dynamic>{
      'type': node.runtimeType.toString(),
      'key': node.key,
      'id': node.effectiveNativeViewId?.toString(),
    };

    if (node is DCFElement) {
      data['elementType'] = node.type;
      // Filter out non-serializable props (functions, closures, etc.)
      data['props'] = _serializePropsForIsolate(node.elementProps);
      data['children'] = node.children
          .map((child) => _serializeNodeForIsolate(child))
          .toList();
    } else if (node is DCFStatefulComponent || node is DCFStatelessComponent) {
      final rendered = node.renderedNode;
      if (rendered != null) {
        data['rendered'] = _serializeNodeForIsolate(rendered);
      }
    }

    return data;
  }

  /// Serialize props for isolate - filters out non-serializable values
  Map<String, dynamic> _serializePropsForIsolate(Map<String, dynamic> props) {
    final serialized = <String, dynamic>{};

    for (final entry in props.entries) {
      final value = entry.value;

      // Skip functions, closures, and other non-serializable types
      if (value is Function) {
        // Functions can't be sent to isolates - skip them
        // The isolate diff will detect prop changes by comparing serializable props
        continue;
      }

      // Skip non-serializable types (worker_manager handles serialization)

      // Recursively serialize nested maps and lists
      if (value is Map) {
        try {
          serialized[entry.key] =
              _serializePropsForIsolate(Map<String, dynamic>.from(value));
        } catch (e) {
          // If nested map contains non-serializable values, skip it
          continue;
        }
      } else if (value is List) {
        try {
          serialized[entry.key] = value.map((item) {
            if (item is Map) {
              return _serializePropsForIsolate(Map<String, dynamic>.from(item));
            } else if (item is Function) {
              return null; // Replace non-serializable items with null
            }
            return item;
          }).toList();
        } catch (e) {
          continue;
        }
      } else {
        // Primitive types and other serializable values
        try {
          serialized[entry.key] = value;
        } catch (e) {
          // If value can't be serialized, skip it
          continue;
        }
      }
    }

    return serialized;
  }

  /// Apply diff results from isolate
  /// CRITICAL: All UI mutations happen on main thread (Dart main isolate)
  /// Isolate only computes the diff - we apply it synchronously on UI thread
  Future<void> _applyIsolateDiff(DCFComponentNode oldNode,
      DCFComponentNode newNode, Map<String, dynamic> diff) async {
    // CRITICAL: All UI operations must be on main thread
    // Dart's main isolate IS the UI thread, so we're already on it
    // But we ensure all native bridge calls happen synchronously

    print('🔍 ISOLATES: _applyIsolateDiff called with diff keys: ${diff.keys}');
    final diffType = diff['type'] as String?;
    final changes = diff['changes'] as List<dynamic>? ?? [];
    print('🔍 ISOLATES: diffType=$diffType, changes count=${changes.length}');

    // Handle initial render (entire tree needs to be created)
    // This shouldn't happen since we disabled isolate for initial render, but keep for safety
    if (diffType == 'create') {
      EngineDebugLogger.logReconcile('ISOLATE_CREATE', oldNode, newNode,
          reason: 'Initial render - creating entire tree via isolate');

      // For initial render, we need to render the entire new tree
      final parentViewId = _findParentViewId(newNode);
      await renderToNative(newNode, parentViewId: parentViewId);
      return;
    }

    // Handle updates - apply diff synchronously on main thread
    if (diffType == 'update') {
      // Ensure we're in a batch update context
      final wasBatchMode = _batchUpdateInProgress;
      if (!wasBatchMode) {
        await startBatchUpdate();
      }

      try {
        print('🔍 ISOLATES: Processing ${changes.length} changes from isolate');
        
        // If no changes detected, the diff algorithm might have missed structural changes
        // Set flag to prevent worker_manager from being used again, then throw to trigger fallback
        if (changes.isEmpty) {
          print('⚠️ ISOLATES: No changes detected by diff algorithm, but structural changes may exist');
          print('⚠️ ISOLATES: Falling back to regular reconciliation (worker_manager will be skipped)');
          
          // Set flag to prevent worker_manager from being used in the fallback reconciliation
          _skipWorkerManagerForThisReconciliation = true;
          
          // Commit batch update if we started it
          if (!wasBatchMode && _batchUpdateInProgress) {
            await commitBatchUpdate();
          }
          
          // Throw to trigger fallback to regular reconciliation
          throw Exception('No changes detected - fallback to regular reconciliation');
        }
        
        // 🔥 UI THREAD YIELDING: Yield every 5 changes to prevent UI freeze
        const yieldInterval = 5;
        for (int i = 0; i < changes.length; i++) {
          // Yield control back to UI thread every few changes
          if (i > 0 && i % yieldInterval == 0) {
            await Future.delayed(Duration.zero); // Yield to event loop
          }
          
          final change = changes[i];
          final changeMap = change as Map<String, dynamic>;
          final action = changeMap['action'] as String;
          print(
              '🔍 ISOLATES: Change $i: action=$action, keys=${changeMap.keys}');

          switch (action) {
            case 'replace':
              // Check if this is a child replacement or root replacement
              final oldData = changeMap['oldData'] as Map<String, dynamic>?;
              final newData = changeMap['newData'] as Map<String, dynamic>?;
              final changeIndex = changeMap['index'] as int?;

              print(
                  '🔍 ISOLATES: Replace action - oldData type: ${oldData?['type']}, newData type: ${newData?['type']}, index: $changeIndex');

              if (oldData != null &&
                  newData != null &&
                  oldNode is DCFElement &&
                  newNode is DCFElement) {
                // This is a CHILD replacement, not root replacement
                // The isolate reconciler matches by index, so we should use the index from the change
                // or find it by matching the serialized data
                int? childIndex = changeIndex;

                // If no index provided, try to find it
                if (childIndex == null) {
                  final oldType = oldData['type'] as String?;
                  final oldIdStr = oldData['id'] as String?;

                  for (int i = 0; i < oldNode.children.length; i++) {
                    final child = oldNode.children[i];
                    if (child is DCFElement) {
                      // Match by type first
                      if (oldType != null && child.type == oldType) {
                        // Also try to match by ID if available
                        if (oldIdStr == null ||
                            child.effectiveNativeViewId?.toString() ==
                                oldIdStr ||
                            child.hashCode.toString() == oldIdStr) {
                          childIndex = i;
                          break;
                        }
                      }
                    }
                  }
                }

                print(
                    '🔍 ISOLATES: Found childIndex: $childIndex (oldNode children: ${oldNode.children.length}, newNode children: ${newNode.children.length})');

                // If we found the index and it's valid in both trees
                if (childIndex != null &&
                    childIndex < oldNode.children.length &&
                    childIndex < newNode.children.length) {
                  final oldChild = oldNode.children[childIndex];
                  final newChild = newNode.children[childIndex];

                  print(
                      '🔍 ISOLATES: oldChild type: ${oldChild is DCFElement ? oldChild.type : oldChild.runtimeType}, newChild type: ${newChild is DCFElement ? newChild.type : newChild.runtimeType}');

                  // CRITICAL: Check if both components render to the same element type
                  // This prevents unnecessary native view recreation when components differ but rendered elements match
                  DCFElement? oldRendered;
                  DCFElement? newRendered;

                  if (oldChild is DCFStatefulComponent ||
                      oldChild is DCFStatelessComponent) {
                    // Safe cast: check if renderedNode is actually a DCFElement
                    final rendered = oldChild.renderedNode;
                    oldRendered = rendered is DCFElement ? rendered : null;
                  } else if (oldChild is DCFElement) {
                    oldRendered = oldChild;
                  }

                  if (newChild is DCFStatefulComponent ||
                      newChild is DCFStatelessComponent) {
                    // Safe cast: check if renderedNode is actually a DCFElement
                    final rendered = newChild.renderedNode;
                    newRendered = rendered is DCFElement ? rendered : null;
                  } else if (newChild is DCFElement) {
                    newRendered = newChild;
                  }

                  // If both render to the same element type, reconcile instead of replacing
                  final renderedTypesMatch = oldRendered != null &&
                      newRendered != null &&
                      oldRendered.type == newRendered.type;
                  final directTypesMatch = oldChild is DCFElement &&
                      newChild is DCFElement &&
                      oldChild.type == newChild.type;

                  if (renderedTypesMatch || directTypesMatch) {
                    final typeStr = renderedTypesMatch
                        ? 'rendered: ${oldRendered!.type}'
                        : (oldChild is DCFElement
                            ? oldChild.type
                            : 'direct match');
                    print(
                        '✅ ISOLATES: Types match ($typeStr), reconciling instead of replacing');

                    // For components that render to the same element type, reconcile their rendered nodes directly
                    // This bypasses component type checks and prevents unnecessary replacements
                    if (renderedTypesMatch &&
                        oldRendered != null &&
                        newRendered != null) {
                      print(
                          '🔍 ISOLATES: Reconciling rendered nodes directly (bypassing component type check)');
                      // Transfer view IDs from old component to new component
                      if (oldChild.effectiveNativeViewId != null) {
                        if (newChild is DCFStatefulComponent ||
                            newChild is DCFStatelessComponent) {
                          newChild.nativeViewId =
                              oldChild.effectiveNativeViewId;
                          newChild.contentViewId = oldChild.contentViewId;
                        }
                      }
                      // Update new component's renderedNode to point to the new rendered element
                      if (newChild is DCFStatefulComponent ||
                          newChild is DCFStatelessComponent) {
                        newChild.renderedNode = newRendered;
                      }
                      // CRITICAL: Transfer viewId from oldRendered to newRendered BEFORE reconciling
                      // This ensures _reconcileElement recognizes them as the same element
                      if (oldRendered.nativeViewId != null) {
                        newRendered.nativeViewId = oldRendered.nativeViewId;
                        newRendered.contentViewId = oldRendered.contentViewId;
                      }
                      // CRITICAL: Set parent on newRendered to match oldRendered's parent
                      // This ensures the reconciliation context is correct
                      newRendered.parent = oldRendered.parent;
                      // Reconcile the rendered elements directly using _reconcileElement
                      // This bypasses _reconcile's component type checks
                        await _reconcileElement(oldRendered, newRendered);
                    } else if (oldChild is DCFStatelessComponent ||
                        oldChild is DCFStatefulComponent ||
                        newChild is DCFStatelessComponent ||
                        newChild is DCFStatefulComponent) {
                      print(
                          '🔍 ISOLATES: Reconciling component - using regular reconciliation');
                        await _reconcile(oldChild, newChild);
                    } else if (newChild is DCFElement &&
                        oldChild is DCFElement) {
                      // Direct element match - update props if changed
                      final newElement = newChild as DCFElement;
                      final oldProps =
                          oldData['props'] as Map<String, dynamic>? ?? {};
                      final newProps =
                          newData['props'] as Map<String, dynamic>? ?? {};
                      final propsDiff = <String, dynamic>{};
                      for (final key in newProps.keys) {
                        if (!oldProps.containsKey(key) ||
                            oldProps[key] != newProps[key]) {
                          propsDiff[key] = newProps[key];
                        }
                      }
                      if (propsDiff.isNotEmpty) {
                        print(
                            '🔍 ISOLATES: Updating ${propsDiff.length} props: ${propsDiff.keys}');
                        for (final entry in propsDiff.entries) {
                          newElement.elementProps[entry.key] = entry.value;
                        }
                        await _updateElementProps(newElement);
                      } else {
                        print('ℹ️ ISOLATES: No prop changes, skipping update');
                      }
                    }
                  } else {
                    print(
                        '⚠️ ISOLATES: Types differ, performing actual replace');
                    // Different types - actually replace
                    await _replaceNode(oldChild, newChild);
                  }
                } else {
                  // Couldn't find matching child - this shouldn't happen, but log it
                  print(
                      '⚠️ ISOLATES: Could not find child to replace (index: $childIndex, oldChildren: ${oldNode.children.length}, newChildren: ${newNode.children.length})');
                  print(
                      '⚠️ ISOLATES: oldData: ${oldData['type']}, newData: ${newData['type']}');
                }
              } else {
                // Root-level replacement (should be rare - only if root type changes)
                print(
                    '⚠️ ISOLATES: Root-level replace detected - this should be rare');
                await _replaceNode(oldNode, newNode);
                // Replace handles its own batch commit if needed
                if (!wasBatchMode && _batchUpdateInProgress) {
                  await commitBatchUpdate();
                }
                return; // Replace is complete, no need to continue
              }
              // After handling replace, continue to next change (don't break)
              continue;
            case 'update':
            case 'updateProps':
              final propsDiff =
                  changeMap['propsDiff'] as Map<String, dynamic>? ??
                      changeMap['diff'] as Map<String, dynamic>?;
              if (propsDiff != null &&
                  propsDiff.isNotEmpty &&
                  newNode is DCFElement) {
                print(
                    '🔍 ISOLATES: Updating props for ${newNode.type} (viewId: ${newNode.effectiveNativeViewId}): ${propsDiff.keys}');
                // Update props
                for (final entry in propsDiff.entries) {
                  newNode.elementProps[entry.key] = entry.value;
                }
                await _updateElementProps(newNode);
              }
              break;
            case 'create':
            case 'addChild':
              // New child needs to be created
              final newChildData =
                  changeMap['newData'] as Map<String, dynamic>? ??
                      changeMap['node'] as Map<String, dynamic>? ??
                      changeMap['child'] as Map<String, dynamic>?;
              if (newChildData != null && newNode is DCFElement) {
                // Find the corresponding child in newNode
                final childIndex = changeMap['index'] as int?;
                if (childIndex != null &&
                    childIndex < newNode.children.length) {
                  final child = newNode.children[childIndex];
                  final parentViewId = newNode.effectiveNativeViewId;
                  if (parentViewId != null) {
                    await renderToNative(child, parentViewId: parentViewId);
                  }
                }
              }
              break;
            case 'delete':
            case 'removeChild':
              // Child needs to be deleted
              final oldChildData =
                  changeMap['oldData'] as Map<String, dynamic>? ??
                      changeMap['child'] as Map<String, dynamic>?;
              if (oldChildData != null && oldNode is DCFElement) {
                final childIdStr = oldChildData['id'] as String?;
                if (childIdStr != null) {
                  final childId = int.tryParse(childIdStr);
                  if (childId != null) {
                    await deleteView(childId);
                  }
                }
              }
              break;
            case 'replaceChild':
              // Child needs to be replaced
              final oldChildData =
                  changeMap['oldChild'] as Map<String, dynamic>?;
              final newChildData =
                  changeMap['newChild'] as Map<String, dynamic>?;
              print(
                  '🔍 ISOLATES: replaceChild - oldChild type: ${oldChildData?['type']}, newChild type: ${newChildData?['type']}');

              if (oldChildData != null &&
                  newChildData != null &&
                  oldNode is DCFElement &&
                  newNode is DCFElement) {
                final childIndex = changeMap['index'] as int?;
                if (childIndex != null &&
                    childIndex < oldNode.children.length &&
                    childIndex < newNode.children.length) {
                  final oldChild = oldNode.children[childIndex];
                  final newChild = newNode.children[childIndex];

                  print(
                      '🔍 ISOLATES: replaceChild at index $childIndex - oldChild type: ${oldChild is DCFElement ? oldChild.type : oldChild.runtimeType}, newChild type: ${newChild is DCFElement ? newChild.type : newChild.runtimeType}');

                  // CRITICAL: Check if both components render to the same element type
                  // This prevents unnecessary native view recreation when components differ but rendered elements match
                  DCFElement? oldRendered;
                  DCFElement? newRendered;

                  if (oldChild is DCFStatefulComponent ||
                      oldChild is DCFStatelessComponent) {
                    // Safe cast: check if renderedNode is actually a DCFElement
                    final rendered = oldChild.renderedNode;
                    oldRendered = rendered is DCFElement ? rendered : null;
                  } else if (oldChild is DCFElement) {
                    oldRendered = oldChild;
                  }

                  if (newChild is DCFStatefulComponent ||
                      newChild is DCFStatelessComponent) {
                    // Safe cast: check if renderedNode is actually a DCFElement
                    final rendered = newChild.renderedNode;
                    newRendered = rendered is DCFElement ? rendered : null;
                  } else if (newChild is DCFElement) {
                    newRendered = newChild;
                  }

                  // If both render to the same element type, reconcile instead of replacing
                  final renderedTypesMatch = oldRendered != null &&
                      newRendered != null &&
                      oldRendered.type == newRendered.type;

                  // Also check direct element/component type matches
                  final directTypesMatch = (oldChild is DCFElement &&
                          newChild is DCFElement &&
                          oldChild.type == newChild.type) ||
                      (oldChild.runtimeType == newChild.runtimeType);

                  if (renderedTypesMatch || directTypesMatch) {
                    final typeStr = renderedTypesMatch
                        ? 'rendered: ${oldRendered!.type}'
                        : (oldChild is DCFElement
                            ? oldChild.type
                            : oldChild.runtimeType.toString());
                    print(
                        '✅ ISOLATES: Types match ($typeStr), reconciling instead of replacing');
                    // Same type - just update props, don't replace
                    final oldProps =
                        oldChildData['props'] as Map<String, dynamic>? ?? {};
                    final newProps =
                        newChildData['props'] as Map<String, dynamic>? ?? {};
                    final propsDiff = <String, dynamic>{};
                    for (final key in newProps.keys) {
                      if (!oldProps.containsKey(key) ||
                          oldProps[key] != newProps[key]) {
                        propsDiff[key] = newProps[key];
                      }
                    }
                    // For components that render to the same element type, reconcile their rendered nodes directly
                    // This bypasses component type checks and prevents unnecessary replacements
                    if (renderedTypesMatch &&
                        oldRendered != null &&
                        newRendered != null) {
                      print(
                          '🔍 ISOLATES: Reconciling rendered nodes directly (bypassing component type check)');
                      // Transfer view IDs from old component to new component
                      if (oldChild.effectiveNativeViewId != null) {
                        if (newChild is DCFStatefulComponent ||
                            newChild is DCFStatelessComponent) {
                          newChild.nativeViewId =
                              oldChild.effectiveNativeViewId;
                          newChild.contentViewId = oldChild.contentViewId;
                        }
                      }
                      // Update new component's renderedNode to point to the new rendered element
                      if (newChild is DCFStatefulComponent ||
                          newChild is DCFStatelessComponent) {
                        newChild.renderedNode = newRendered;
                      }
                      // CRITICAL: Transfer viewId from oldRendered to newRendered BEFORE reconciling
                      // This ensures _reconcileElement recognizes them as the same element
                      if (oldRendered.nativeViewId != null) {
                        newRendered.nativeViewId = oldRendered.nativeViewId;
                        newRendered.contentViewId = oldRendered.contentViewId;
                      }
                      // CRITICAL: Set parent on newRendered to match oldRendered's parent
                      // This ensures the reconciliation context is correct
                      newRendered.parent = oldRendered.parent;
                      // Reconcile the rendered elements directly using _reconcileElement
                      // This bypasses _reconcile's component type checks
                        await _reconcileElement(oldRendered, newRendered);
                    } else if (newChild is DCFStatelessComponent ||
                        newChild is DCFStatefulComponent) {
                      // Components need reconciliation to update their rendered children
                      // CRITICAL: Use regular reconciliation (not isolate) to avoid nested isolate issues
                      // and ensure we actually detect and apply changes
                      print(
                          '🔍 ISOLATES: Reconciling component (props changed: ${propsDiff.isNotEmpty}) - using regular reconciliation');
                        await _reconcile(oldChild, newChild);
                    } else if (newChild is DCFElement &&
                        oldChild is DCFElement) {
                      // Elements only need prop updates if props changed
                      final newElement = newChild as DCFElement;
                      if (propsDiff.isNotEmpty) {
                        print(
                            '🔍 ISOLATES: Updating ${propsDiff.length} props: ${propsDiff.keys}');
                        for (final entry in propsDiff.entries) {
                          newElement.elementProps[entry.key] = entry.value;
                        }
                        await _updateElementProps(newElement);
                      } else {
                        print(
                            'ℹ️ ISOLATES: No prop changes for element, skipping update');
                      }
                    }
                  } else {
                    print(
                        '⚠️ ISOLATES: Types differ, performing actual replace');
                    final oldViewId = oldChild.effectiveNativeViewId;
                    if (oldViewId != null) {
                      await _replaceNode(oldChild, newChild);
                    } else {
                      // Old child wasn't rendered, just create new one
                      final parentViewId = newNode.effectiveNativeViewId;
                      if (parentViewId != null) {
                        await renderToNative(newChild,
                            parentViewId: parentViewId);
                      }
                    }
                  }
                } else {
                  print(
                      '⚠️ ISOLATES: replaceChild - invalid index: $childIndex (oldChildren: ${oldNode.children.length}, newChildren: ${newNode.children.length})');
                }
              }
              break;
          }
        }

        // CRITICAL: Don't reconcile children here if we've already processed changes from isolate
        // The isolate diff should have handled all necessary updates
        // Note: If changes.isEmpty, we already handled it above and returned early
        if (changes.isNotEmpty) {
          // We had changes from isolate - they should have been applied above
          // But we still need to reconcile any children that weren't covered by the diff
          // Actually, the isolate diff should cover all children, so we can skip this
          print(
              '✅ ISOLATES: Skipping regular child reconciliation - isolate diff already applied');
        }

        // Commit batch update if we started it
        // 🔥 CRITICAL: Always commit batch update, even if _reconcileElement created many views
        // This ensures all queued attach operations are processed
        if (!wasBatchMode && _batchUpdateInProgress) {
          print('✅ ISOLATES: Committing batch update after applying isolate diff');
          await commitBatchUpdate();
        }
      } catch (e, stackTrace) {
        print('❌ ISOLATES: Error in _applyIsolateDiff: $e');
        print('❌ ISOLATES: Stack trace: $stackTrace');
        // 🔥 CRITICAL: Even on error, try to commit batch update to prevent hanging
        // This ensures queued attach operations are processed even if reconciliation fails
        if (!wasBatchMode && _batchUpdateInProgress) {
          try {
            print('⚠️ ISOLATES: Attempting to commit batch update after error to prevent hanging');
            await commitBatchUpdate();
          } catch (commitError) {
            print('❌ ISOLATES: Failed to commit batch update after error: $commitError');
            // Cancel batch update as last resort
            try {
              await _nativeBridge.cancelBatchUpdate();
              _batchUpdateInProgress = false;
            } catch (cancelError) {
              print('❌ ISOLATES: Failed to cancel batch update: $cancelError');
              _batchUpdateInProgress = false;
            }
          }
        }
        rethrow;
      }
    }
  }

  /// Update element props
  Future<void> _updateElementProps(DCFElement element) async {
    final viewId = element.effectiveNativeViewId;
    if (viewId != null) {
      await _nativeBridge.updateView(viewId, element.elementProps);
    }
  }

  /// O(tree depth + disposal complexity) - Replace a node entirely
  Future<void> _replaceNode(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    // 🔧 FIX: Don't add deletion effect - we call deleteView directly
    // Adding both causes duplicate delete operations in the batch
    // The deletion effect would be processed by _commitEffects, causing a duplicate

    // Add placement effect for new node
    _effectList.addEffect(Effect(
      node: newNode,
      type: EffectType.placement,
    ));

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

    // 🔧 FIX: Skip recursive disposal of children during replacement
    // Android's deleteView will handle recursive deletion when the parent is deleted.
    // This prevents text components from being removed prematurely, causing flashing/disappearing.
    await _disposeOldComponent(oldNode, skipChildrenDisposal: true);

    if (oldNode.effectiveNativeViewId == null) {
      EngineDebugLogger.log(
          'REPLACE_NODE_NO_VIEW_ID', 'Old node has no view ID, cannot replace');
      return;
    }

    final parentViewId = _findParentViewId(oldNode);

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
      } else if (oldNode is DCFStatefulComponent ||
          oldNode is DCFStatelessComponent) {
        final oldRendered = oldNode.renderedNode;
        if (oldRendered is DCFElement) {
          oldEventTypes.addAll(oldRendered.eventTypes);
        }
      }

      final newEventTypes = <String>[];
      if (newNode is DCFElement) {
        newEventTypes.addAll(newNode.eventTypes);
      } else if (newNode is DCFStatefulComponent ||
          newNode is DCFStatelessComponent) {
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
      final isElementTypeChange =
          (oldNode is DCFElement && newNode is DCFElement) &&
              (oldNode.type != newNode.type);

      if (isElementTypeChange) {
        // For element type changes, we MUST generate a new view ID
        // because the old view will be deleted and we can't reuse its ID
        EngineDebugLogger.log('REPLACE_NEW_VIEW_ID',
            'Generating new view ID for element type change',
            extra: {
              'OldViewId': oldViewId,
              'OldType': (oldNode as DCFElement).type,
              'NewType': (newNode as DCFElement).type
            });

        // Don't set nativeViewId on newNode - let renderToNative generate a new one
        _nodesByViewId.remove(oldViewId);
      } else {
        // For other replacements, reuse the view ID
        // CRITICAL: Only map ELEMENTS to _nodesByViewId, not components!
        // Events look up nodes by view ID and only work with DCFElement
        if (newNode is DCFElement) {
          newNode.nativeViewId = oldViewId;
          _nodesByViewId[oldViewId] = newNode;
        } else if (newNode is DCFStatefulComponent ||
            newNode is DCFStatelessComponent) {
          // For components, set contentViewId but DON'T map the component itself
          // We'll map the rendered element after renderToNative creates it
          // Remove old mapping first to avoid stale references
          _nodesByViewId.remove(oldViewId);
          newNode.contentViewId = oldViewId;
        }
        EngineDebugLogger.log(
            'REPLACE_REUSE_VIEW_ID', 'Reusing view ID for in-place replacement',
            extra: {
              'ViewId': oldViewId,
              'NodeType': newNode.runtimeType.toString()
            });
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

      // 🔧 FIX: Queue delete FIRST (before renderToNative) so batch processes deletes before creates
      // This prevents both old and new views from being in the layout tree simultaneously
      // which causes the "imaginary margin" / layout shift issue
      // The delete is queued, so the old view stays in hierarchy until batch commit
      // but it will be removed from layout tree BEFORE new views are created
      EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
      await _nativeBridge.deleteView(oldViewId);

      // 🔧 FIX: Collect all child view IDs before creating new view
      // This ensures we can clean up _nodesByViewId after Android deletes the views
      final childViewIds = <int>[];
      void collectChildViewIds(DCFComponentNode node) {
        if (node is DCFElement) {
          for (final child in node.children) {
            final childViewId = child.effectiveNativeViewId;
            if (childViewId != null) {
              childViewIds.add(childViewId);
            }
            collectChildViewIds(child);
          }
        } else if (node is DCFStatefulComponent ||
            node is DCFStatelessComponent) {
          final renderedNode = node.renderedNode;
          if (renderedNode != null) {
            collectChildViewIds(renderedNode);
          }
        }
      }

      collectChildViewIds(oldNode);

      // Create the new view - delete is already queued, so batch will process delete first
      // This ensures old view is removed from layout tree before new view is added
      final newViewId = await renderToNative(newNode,
          parentViewId: parentViewId, index: index);

      // 🔧 FIX: Clean up child view IDs from _nodesByViewId after parent is deleted
      // Android's deleteView will handle recursive deletion of native views,
      // but we need to clean up our tracking map
      for (final childViewId in childViewIds) {
        _nodesByViewId.remove(childViewId);
        EngineDebugLogger.log(
            'REPLACE_CLEANUP_CHILD', 'Removed child view ID from tracking',
            extra: {'ChildViewId': childViewId});
      }

      // Commit the atomic delete+create if we started the batch
      if (!wasBatchMode) {
        await _nativeBridge.commitBatchUpdate();
      }

      // CRITICAL: Ensure view ID is set IMMEDIATELY after renderToNative returns
      // This must happen before any other code tries to read effectiveNativeViewId
      if (newViewId != null) {
        // Ensure the newNode has the view ID set correctly
        if (newNode is DCFElement) {
          newNode.nativeViewId = newViewId;
          _nodesByViewId[newViewId] = newNode;
        } else if (newNode is DCFStatefulComponent ||
            newNode is DCFStatelessComponent) {
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
            } else if (renderedNode is DCFStatefulComponent ||
                renderedNode is DCFStatelessComponent) {
              // For nested components, traverse down to find the actual element
              // This ensures events can find the element even with nested components
              DCFComponentNode? current = renderedNode;
              DCFElement? actualElement;
              while (current != null) {
                if (current is DCFElement) {
                  actualElement = current;
                  break;
                } else if (current is DCFStatefulComponent ||
                    current is DCFStatelessComponent) {
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
                extra: {
                  'ComponentType': newNode.runtimeType.toString(),
                  'ViewId': newViewId
                });
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
          if (renderedElement is DCFElement &&
              renderedElement.eventTypes.isNotEmpty) {
            final actualEventTypes = renderedElement.eventTypes;
          // Always register - renderToNative might have done it, but double-registration is safe
          // and ensures events work even if renderToNative's registration failed
          EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', newViewId,
              data: {'EventTypes': actualEventTypes});
          await _nativeBridge.addEventListeners(newViewId, actualEventTypes);
          } else if (newNode is DCFElement && newNode.eventTypes.isNotEmpty) {
            // For direct element replacement, ensure events are registered
            EngineDebugLogger.logBridge('ADD_EVENT_LISTENERS', newViewId,
                data: {'EventTypes': newNode.eventTypes});
            await _nativeBridge.addEventListeners(
                newViewId, newNode.eventTypes);
          }
        }

        EngineDebugLogger.log(
            'REPLACE_NODE_SUCCESS', 'Node replacement completed successfully',
            extra: {
              'NewViewId': newViewId,
              'AtomicBatch': !wasBatchMode,
              'EffectiveViewId': newNode.effectiveNativeViewId,
              'ContentViewId': (newNode is DCFStatefulComponent ||
                      newNode is DCFStatelessComponent)
                  ? newNode.contentViewId
                  : null,
              'NativeViewId':
                  (newNode is DCFElement) ? newNode.nativeViewId : null,
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
  /// [skipChildrenDisposal] - If true, skip recursive disposal of children.
  /// This is used during node replacement to let Android's deleteView handle
  /// recursive deletion, preventing premature removal of text components.
  Future<void> _disposeOldComponent(DCFComponentNode oldNode,
      {bool skipChildrenDisposal = false}) async {
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

        await _disposeOldComponent(oldNode.renderedNode,
            skipChildrenDisposal: skipChildrenDisposal);
      } else if (oldNode is DCFStatelessComponent) {
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

        await _disposeOldComponent(oldNode.renderedNode,
            skipChildrenDisposal: skipChildrenDisposal);
      } else if (oldNode is DCFElement) {
        EngineDebugLogger.log('DISPOSE_ELEMENT', 'Disposing DCFElement',
            extra: {
              'ElementType': oldNode.type,
              'ChildCount': oldNode.children.length,
              'SkipChildrenDisposal': skipChildrenDisposal
            });

        // 🔧 FIX: Skip recursive disposal of children during replacement
        // Android's deleteView will handle recursive deletion when the parent is deleted.
        // This prevents text components from being removed prematurely, causing flashing/disappearing.
        if (!skipChildrenDisposal) {
          for (final child in oldNode.children) {
            await _disposeOldComponent(child);
          }
        } else {
          EngineDebugLogger.log('DISPOSE_SKIP_CHILDREN',
              'Skipping recursive disposal of children - Android will handle deletion');
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

  /// Detect if root component structure changed dramatically (structural shock)
  /// Returns true if the rendered structure is significantly different
  /// This prevents component instance leakage when copy-pasting different app structures
  bool _detectStructuralShock(
      DCFComponentNode? oldRoot, DCFComponentNode newRoot) {
    if (oldRoot == null) return false;

    // If different runtime types, definitely a structural shock
    if (oldRoot.runtimeType != newRoot.runtimeType) {
      return true;
    }

    // If different instances of same class, check if structure changed
    // Access renderedNode (will call render() if needed via getter)
    final oldRendered = oldRoot.renderedNode;
    final newRendered = newRoot.renderedNode;

    // If either renderedNode is null, can't compare - assume no shock
    if (oldRendered == null || newRendered == null) {
      return false;
    }

    if (oldRendered is DCFElement && newRendered is DCFElement) {
      // Different element types = structural shock
      if (oldRendered.type != newRendered.type) {
        EngineDebugLogger.log(
            'STRUCTURAL_SHOCK_DETECTED', 'Root rendered element type changed',
            extra: {
              'OldType': oldRendered.type,
              'NewType': newRendered.type,
            });
        return true;
      }

      // 🔥 CRITICAL: Check props similarity first - props/content differences indicate structural shock
      // This catches cases where structure looks similar but content is completely different
      final propsSimilarity = _computePropsSimilarity(
          oldRendered.elementProps, newRendered.elementProps);
      if (propsSimilarity < 0.5) {
        EngineDebugLogger.log('STRUCTURAL_SHOCK_DETECTED',
            'Root component props/content changed dramatically',
            extra: {
              'PropsSimilarity': propsSimilarity,
              'OldPropsKeys': oldRendered.elementProps.keys.toList(),
              'NewPropsKeys': newRendered.elementProps.keys.toList(),
            });
        return true;
      }

      // Check structural similarity - if very different, it's a shock
      final similarity = _computeStructuralSimilarity(oldRendered, newRendered);
      if (similarity < 0.3) {
        EngineDebugLogger.log('STRUCTURAL_SHOCK_DETECTED',
            'Root component structure changed dramatically',
            extra: {
              'Similarity': similarity,
              'OldChildrenCount': oldRendered.children.length,
              'NewChildrenCount': newRendered.children.length,
            });
        return true;
      }
    } else if (oldRendered.runtimeType != newRendered.runtimeType) {
      // Different rendered node types = structural shock
      EngineDebugLogger.log(
          'STRUCTURAL_SHOCK_DETECTED', 'Root rendered node type changed',
          extra: {
            'OldType': oldRendered.runtimeType.toString(),
            'NewType': newRendered.runtimeType.toString(),
          });
      return true;
    }

    return false;
  }

  /// O(tree render complexity) - Create the root component for the application
  Future<void> createRoot(DCFComponentNode component) async {
    EngineDebugLogger.log('CREATE_ROOT_START', 'Creating root component',
        component: component.runtimeType.toString());

    // Check for structural shock even if rootComponent class is the same
    // This handles cases where copy-pasting a different app structure
    final hasStructuralShock = _detectStructuralShock(rootComponent, component);
    final isDifferentRoot = rootComponent != null && rootComponent != component;

    if (isDifferentRoot || hasStructuralShock) {
      if (hasStructuralShock && !isDifferentRoot) {
        EngineDebugLogger.log('CREATE_ROOT_STRUCTURAL_SHOCK',
            'Structural shock detected - same class but different structure. Clearing instance tracking.');
      } else {
        EngineDebugLogger.log('CREATE_ROOT_HOT_RESTART',
            'Hot restart detected. Tearing down old VDOM state.');
      }

      // 🔥 CRITICAL: Cancel ALL pending async work FIRST
      // This prevents timers and microtasks from firing after cleanup
      cancelAllPendingWork();

      // 🔥 CRITICAL: Shutdown worker manager during hot restart to prevent stale state
      // Worker manager will be reinitialized after cleanup
      await shutdownConcurrentProcessing();

      // Small delay to let any in-flight timers/microtasks drain
      await Future.delayed(Duration(milliseconds: 50));

      if (rootComponent != null) {
        await _disposeOldComponent(rootComponent!);
      }

      _statefulComponents.clear();
      _nodesByViewId.clear();
      _previousRenderedNodes.clear();
      _pendingUpdates.clear();
      _componentPriorities.clear();
      _errorBoundaries.clear();

      // 🔥 CRITICAL: Clear instance tracking maps to prevent component leakage
      // This fixes the issue where old components leak into new app structure
      _componentInstancesByPosition.clear();
      _componentInstancesByProps.clear();
      _similarityCache.clear(); // Also clear similarity cache
      _errorRecovery.clear(); // Clear error recovery state
      _nodesBeingRendered.clear(); // Clear rendering set to prevent stale state

      _componentsWaitingForLayout.clear();
      _componentsWaitingForInsertion.clear();
      _isTreeComplete = false;

      // 🔥 CRITICAL: Clear Flutter widget adaptor state during hot restart
      // This ensures Flutter widgets are disposed when native views are cleared
      try {
        FlutterWidgetRenderer.instance.clearAllForHotRestart();
        WidgetToDCFAdaptor.clearAllForHotRestart();
        widgetRegistry.clearAll();
        EngineDebugLogger.log('HOT_RESTART_FLUTTER_CLEANUP',
            'Cleared Flutter widget adaptor state');
      } catch (e) {
        EngineDebugLogger.log('HOT_RESTART_FLUTTER_CLEANUP_ERROR',
            'Failed to clear Flutter widget state: $e');
      }

      // 🔥 CRITICAL: Set structural shock flag to force full replacement
      // This prevents position-based matching from incorrectly matching old components
      _isStructuralShock = true;

      EngineDebugLogger.log(
          'VDOM_STATE_CLEARED', 'All VDOM tracking maps have been cleared.');
      EngineDebugLogger.reset();

      rootComponent = component;

      // 🔥 CRITICAL: Reinitialize worker manager after hot restart cleanup (non-blocking)
      // This ensures worker manager is in a clean state for the new app
      // Don't await - let it initialize in background, initial render must happen first
      _initializeWorkerManager().catchError((e) {
        EngineDebugLogger.log('WORKER_MANAGER_INIT_DEFERRED',
            'Worker manager initialization deferred due to error: $e');
      });

      await _nativeBridge.startBatchUpdate();
      await renderToNative(component, parentViewId: 0);
      await _nativeBridge.commitBatchUpdate();

      // Clear structural shock flag after rendering is complete
      _isStructuralShock = false;

      setRootComponent(component);

      EngineDebugLogger.log('CREATE_ROOT_COMPLETE',
          'Root component re-created successfully after ${hasStructuralShock ? "structural shock" : "hot restart"}.');
    } else {
      EngineDebugLogger.log(
          'CREATE_ROOT_FIRST', 'Creating first root component');
      rootComponent = component;

      // Clear rendering set to ensure clean state for first render
      _nodesBeingRendered.clear();

      await _nativeBridge.startBatchUpdate();
      final viewId = await renderToNative(component, parentViewId: 0);
      await _nativeBridge.commitBatchUpdate();

      setRootComponent(component);

      EngineDebugLogger.log(
          'CREATE_ROOT_COMPLETE', 'Root component created successfully',
          extra: {'ViewId': viewId});
    }
  }

  /// Delete a view from the native side
  Future<void> deleteView(int viewId) async {
    // 🔥 NEW: Unregister events when view is deleted (automatic lifecycle management)
    final registry = EventRegistry();
    registry.unregister(viewId);
    EngineDebugLogger.log('EVENT_REGISTRY', 'Unregistered events for deleted view $viewId');
    
    // 🔥 CRITICAL FIX: Native side now stops animations automatically in deleteView
    // No need to call tunnel - native handles cleanup directly using reflection/runtime checks
    
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
  /// This is the commit phase where effects are applied
  Future<void> commitBatchUpdate() async {
    await isReady;
    if (_batchUpdateInProgress) {
      _batchUpdateInProgress = false;

      // Commit phase: Process all effects
      await _commitEffects();

      // Swap workInProgress tree to current tree
      if (_workInProgressTree != null) {
        _currentTree = _workInProgressTree;
        _workInProgressTree = null;
      }

      await _nativeBridge.commitBatchUpdate();
    }
  }

  /// Commit phase: Process all side effects
  Future<void> _commitEffects() async {
    final effects = _effectList.getEffects();

    // Process deletions first
    // Note: Deletion effects from _replaceNode are skipped because _replaceNode calls deleteView directly
    // This prevents duplicate delete operations
    for (final effect in effects) {
      if (effect.type == EffectType.deletion) {
        await _commitDeletion(effect);
      }
    }

    // Process placements
    for (final effect in effects) {
      if (effect.type == EffectType.placement) {
        await _commitPlacement(effect);
      }
    }

    // Process updates
    for (final effect in effects) {
      if (effect.type == EffectType.update) {
        await _commitUpdate(effect);
      }
    }

    // Process lifecycle effects
    for (final effect in effects) {
      if (effect.type == EffectType.lifecycle) {
        await _commitLifecycle(effect);
      }
    }

    // Clear effect list
    _effectList.clear();
  }

  Future<void> _commitDeletion(Effect effect) async {
    final node = effect.node;
    if (node.effectiveNativeViewId != null) {
      await deleteView(node.effectiveNativeViewId!);
    }
  }

  Future<void> _commitPlacement(Effect effect) async {
    // Placement is handled during renderToNative
    // This is a no-op as the view is already created
  }

  Future<void> _commitUpdate(Effect effect) async {
    // Updates are handled during reconciliation
    // This is a no-op as updates are already applied
  }

  Future<void> _commitLifecycle(Effect effect) async {
    final node = effect.node;
    if (effect.payload?['method'] == 'componentDidMount') {
      node.componentDidMount();
    } else if (effect.payload?['method'] == 'componentWillUnmount') {
      node.componentWillUnmount();
    }
  }

  /// Force a complete re-render of the entire component tree for hot reload support
  /// This re-executes all render() methods while preserving navigation state
  Future<void> forceFullTreeReRender() async {
    if (rootComponent == null) {
      print('❌ HOT_RELOAD: No root component to re-render');
      EngineDebugLogger.log(
          'HOT_RELOAD_ERROR', 'No root component to re-render');
      return;
    }

    print('🔥🔥🔥 HOT_RELOAD: Starting full tree re-render 🔥🔥🔥');
    EngineDebugLogger.log(
        'HOT_RELOAD_START', 'Starting full tree re-render for hot reload');

    // 🔥 CRITICAL: Set hot reload flag to disable worker_manager during hot reload
    // This prevents infinite recursion and ensures proper reconciliation
    _isHotReloading = true;
    
    try {
      // Ensure worker manager is ready before hot reload (but won't be used during hot reload)
      if (!_workerManagerInitialized) {
        print('🔥 HOT_RELOAD: Initializing worker manager...');
        await _initializeWorkerManager();
      }
      
      // 🔥 CRITICAL: Re-render and reconcile the root component first
      // This ensures the root tree is updated before stateful components
      print('🔥 HOT_RELOAD: Re-rendering root component...');
      
      if (rootComponent is DCFStatefulComponent) {
        // Root is stateful - schedule an update
        print('🔥 HOT_RELOAD: Root is stateful, scheduling update...');
        _scheduleComponentUpdate(rootComponent as DCFStatefulComponent);
      } else if (rootComponent is DCFStatelessComponent) {
        // Root is stateless - re-render and reconcile
        final statelessRoot = rootComponent as DCFStatelessComponent;
        final oldRootRendered = statelessRoot.renderedNode;
        
        // Re-render the stateless root component
        final newRootRendered = statelessRoot.render();
        statelessRoot.renderedNode = newRootRendered;
        
        // Reconcile the old and new root trees
        if (oldRootRendered != null) {
          print('🔥 HOT_RELOAD: Reconciling root component tree...');
          await _reconcile(oldRootRendered, newRootRendered);
        } else {
          // No old tree - just render the new one
          print('🔥 HOT_RELOAD: No old root tree, rendering new root...');
          await _nativeBridge.startBatchUpdate();
          await renderToNative(newRootRendered, parentViewId: 0);
          await _nativeBridge.commitBatchUpdate();
        }
      }
      
      print('🔥 HOT_RELOAD: Scheduling updates for ${_statefulComponents.length} components...');
      for (final component in _statefulComponents.values) {
            _scheduleComponentUpdate(component);
      }

      print('🔥 HOT_RELOAD: Processing pending updates...');
      await _processPendingUpdates();

      // 🔥 CRITICAL: Ensure all batch updates are committed
      // _processPendingUpdates should handle this, but we ensure it's done
      if (_batchUpdateInProgress) {
        print('🔥 HOT_RELOAD: Committing final batch update...');
        await _nativeBridge.commitBatchUpdate();
      }
      
      // 🔥 CRITICAL: Trigger a final layout calculation to ensure views are laid out and made visible
      // After hot reload, views may have been updated but not laid out or made visible
      // Committing an empty batch will trigger layout calculation on native side
      print('🔥 HOT_RELOAD: Triggering final layout calculation...');
      await _nativeBridge.startBatchUpdate();
      await _nativeBridge.commitBatchUpdate();
      
      // 🔥 CRITICAL: On iOS, add a delay and trigger another layout to ensure visibility
      // After hot reload, the first layout calculation might fail because views aren't in the
      // layout tree yet. The delay allows the layout tree to settle, then we trigger layout again.
      // iOS's calculateLayoutNow() will retry if it fails, but we ensure it runs again.
      print('🔥 HOT_RELOAD: Ensuring views are visible (iOS retry mechanism)...');
      await Future.delayed(Duration(milliseconds: 150)); // Wait for iOS retry + buffer
      await _nativeBridge.startBatchUpdate();
      await _nativeBridge.commitBatchUpdate();

      print('✅✅✅ HOT_RELOAD: Full tree re-render completed successfully ✅✅✅');
      EngineDebugLogger.log(
          'HOT_RELOAD_COMPLETE', 'Full tree re-render completed successfully');
    } catch (e, stackTrace) {
      print('❌❌❌ HOT_RELOAD: Failed to complete hot reload: $e');
      print('❌ HOT_RELOAD: Stack trace: $stackTrace');
      EngineDebugLogger.log(
          'HOT_RELOAD_ERROR', 'Failed to complete hot reload: $e');
      rethrow;
    } finally {
      // 🔥 CRITICAL: Always reset hot reload flag, even on error
      _isHotReloading = false;
      print('🔥 HOT_RELOAD: Hot reload flag reset');
    }
  }

  /// O(tree depth) - Find a node's parent view ID
  /// This walks up the tree to find the actual rendered element, not cached nativeViewIds
  int? _findParentViewId(DCFComponentNode node) {
    final nodeViewId = node.effectiveNativeViewId;
    DCFComponentNode? current = node.parent;

    while (current != null) {
      // For components, look at their ACTUAL rendered element's ID, not the component's cached nativeViewId
      if (current is DCFStatelessComponent || current is DCFStatefulComponent) {
        // Get the component's rendered node
        final renderedNode = (current is DCFStatefulComponent)
            ? current.renderedNode
            : (current is DCFStatelessComponent ? current.renderedNode : null);

        if (renderedNode != null && renderedNode is DCFStatelessComponent) {
          final deepRendered = renderedNode.renderedNode;
          if (deepRendered is DCFElement) {
            if (deepRendered.nativeViewId != null) {
              final deepViewId = deepRendered.nativeViewId!;

              if (nodeViewId != null && deepViewId == nodeViewId) {
                current = current.parent;
                continue;
              }

              return deepViewId;
            } else {
              current = current.parent;
              continue;
            }
          }
        }

        if (renderedNode is DCFElement && renderedNode.nativeViewId != null) {
          final renderedViewId = renderedNode.nativeViewId!;

          // Skip if this is the same view ID as the node we're looking for a parent for
          if (nodeViewId != null && renderedViewId == nodeViewId) {
            current = current.parent;
            continue;
          }

          return renderedViewId;
        }
      }

      // For components without a rendered element with a valid nativeViewId, skip to next ancestor
      // DO NOT use effectiveNativeViewId here as it can return stale contentViewIds
      current = current.parent;
    }

    EngineDebugLogger.log(
        'PARENT_VIEW_DEFAULT', 'No parent view found, using root');
    return 0; // Default to root (tag 0) if no parent found
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
    print(
        '🔍 RECONCILE_ELEMENT: Starting - oldViewId: ${oldElement.nativeViewId}, newViewId: ${newElement.nativeViewId}, type: ${oldElement.type}');
    EngineDebugLogger.log(
        'RECONCILE_ELEMENT_START', 'Starting element reconciliation', extra: {
      'ElementType': oldElement.type,
      'ViewId': oldElement.nativeViewId
    });

    if (oldElement.nativeViewId != null) {
      print(
          '🔍 RECONCILE_ELEMENT: oldElement has viewId, transferring to newElement');
      newElement.nativeViewId = oldElement.nativeViewId;

      // CRITICAL: Map the new element IMMEDIATELY before any other operations
      // This ensures events can always find the correct element with the latest handlers
      final viewId = oldElement.nativeViewId!;
      final oldMappedNode = _nodesByViewId[viewId];
      _nodesByViewId[viewId] = newElement;

      if (oldMappedNode != newElement) {
        EngineDebugLogger.log(
            'MAPPING_CHANGED', 'ViewId $viewId mapping changed',
            extra: {
              'OldType': oldMappedNode?.runtimeType.toString(),
              'NewType': newElement.runtimeType.toString(),
              'ElementType': newElement.type,
            });
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
        final oldHandler = oldElement.elementProps[eventType] ??
            oldElement.elementProps[
                'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}'];
        final newHandler = newElement.elementProps[eventType] ??
            newElement.elementProps[
                'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}'];
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

      // 🔥 CRITICAL: During structural shock, send ALL props to ensure no leakage
      // This prevents old props from persisting when structure changes dramatically
      final propsToSend = _isStructuralShock
          ? Map<String, dynamic>.from(newElement.elementProps) // Send all props
          : changedProps; // Send only changed props


      if (propsToSend.isNotEmpty) {
        EngineDebugLogger.logBridge('UPDATE_VIEW', oldElement.nativeViewId!,
            data: {
              'ChangedProps': propsToSend.keys.toList(),
              'StructuralShock': _isStructuralShock,
              'SendAllProps': _isStructuralShock
            });
        final updateSuccess = await _nativeBridge.updateView(
            oldElement.nativeViewId!, propsToSend);
        if (!updateSuccess) {
          EngineDebugLogger.log('UPDATE_VIEW_FAILED',
              'updateView failed, falling back to createView',
              extra: {'ViewId': oldElement.nativeViewId});
          final createSuccess = await _nativeBridge.createView(
              oldElement.nativeViewId!,
              oldElement.type,
              newElement.elementProps);
          if (!createSuccess) {
            EngineDebugLogger.log('CREATE_VIEW_FALLBACK_FAILED',
                'createView fallback also failed',
                extra: {'ViewId': oldElement.nativeViewId});
          }
        }

        // CRITICAL: Re-verify mapping after update to ensure it's still correct
        // This prevents race conditions where the mapping might get overwritten
        final currentMappedNode = _nodesByViewId[oldElement.nativeViewId!];
        if (currentMappedNode != newElement) {
          EngineDebugLogger.log('RECONCILE_REMAP_ELEMENT',
              '⚠️ Mapping was overwritten, restoring correct element',
              extra: {
                'ViewId': oldElement.nativeViewId,
                'ExpectedType': newElement.runtimeType.toString()
              });
          _nodesByViewId[oldElement.nativeViewId!] = newElement;
        }
      } else {
        EngineDebugLogger.log(
            'RECONCILE_NO_PROP_CHANGES', 'No prop changes detected');
      }
    }
    EngineDebugLogger.log(
        'RECONCILE_CHILDREN_START', 'Starting children reconciliation',
        extra: {
          'OldChildCount': oldElement.children.length,
          'NewChildCount': newElement.children.length
        });

    // CRITICAL: Store a snapshot of child view IDs before reconciliation
    // This allows us to verify and fix mappings after children reconciliation
    final childViewIdsBeforeReconcile = <int, DCFElement>{};
    for (final child in oldElement.children) {
      final viewId = child.effectiveNativeViewId;
      if (viewId != null) {
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
      if (viewId != null) {
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
                  'OldMappedHasOnPress': (mappedNode is DCFElement)
                      ? mappedNode.elementProps.containsKey('onPress')
                      : false
                });
            _nodesByViewId[viewId] = child;
          } else {
            // Verify the mapped element has handlers
            if (child.type == 'Button' &&
                !child.elementProps.containsKey('onPress')) {
              EngineDebugLogger.log('RECONCILE_CHILD_NO_HANDLERS',
                  '⚠️ Button child has no onPress handler after reconciliation!',
                  extra: {
                    'ViewId': viewId,
                    'ElementProps': child.elementProps.keys.toList()
                  });
            }
          }
        } else if (child is DCFStatefulComponent ||
            child is DCFStatelessComponent) {
          // For components, ensure mapping points to rendered element
          final renderedElement = child.renderedNode;
          if (renderedElement is DCFElement) {
            final renderedViewId = renderedElement.nativeViewId;
            // Use effectiveNativeViewId to handle nested components
            final effectiveViewId =
                child.effectiveNativeViewId ?? renderedViewId;
            if (effectiveViewId == viewId) {
              if (mappedNode != renderedElement) {
                EngineDebugLogger.log('RECONCILE_CHILD_COMPONENT_MAPPING_FIX',
                    '⚠️ Component child mapping corrupted, fixing to point to rendered element',
                    extra: {
                      'ViewId': viewId,
                      'RenderedViewId': renderedViewId,
                      'HasOnPress':
                          renderedElement.elementProps.containsKey('onPress'),
                      'OldMappedType':
                          mappedNode?.runtimeType.toString() ?? 'null'
                    });
                _nodesByViewId[viewId] = renderedElement;
              }
            } else if (renderedViewId != null &&
                mappedNode != renderedElement) {
              // Also check if the rendered element's view ID is mapped correctly
              final renderedMappedNode = _nodesByViewId[renderedViewId];
              if (renderedMappedNode != renderedElement) {
                EngineDebugLogger.log(
                    'RECONCILE_CHILD_RENDERED_ELEMENT_MAPPING_FIX',
                    '⚠️ Rendered element mapping corrupted, fixing',
                    extra: {
                      'RenderedViewId': renderedViewId,
                      'HasOnPress':
                          renderedElement.elementProps.containsKey('onPress')
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
              'NewElementHasOnPress':
                  newElement.elementProps.containsKey('onPress'),
              'MappedNodeHasOnPress': (finalMappedNode is DCFElement)
                  ? finalMappedNode.elementProps.containsKey('onPress')
                  : false
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
      if (viewId != null) {
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
        } else if (child is DCFStatefulComponent ||
            child is DCFStatelessComponent) {
          final renderedElement = child.renderedNode;
          if (renderedElement is DCFElement) {
            final renderedViewId = renderedElement.nativeViewId;
            if (renderedViewId != null) {
              final renderedMappedNode = _nodesByViewId[renderedViewId];
              if (renderedMappedNode != renderedElement) {
                EngineDebugLogger.log('RECONCILE_ULTIMATE_RENDERED_FIX',
                    '⚠️ ULTIMATE FIX: Rendered element mapping still corrupted, fixing now',
                    extra: {
                      'RenderedViewId': renderedViewId,
                      'ElementType': renderedElement.type,
                      'HasOnPress':
                          renderedElement.elementProps.containsKey('onPress')
                    });
                _nodesByViewId[renderedViewId] = renderedElement;
              }
              // CRITICAL: Also verify event listeners for Button rendered elements
              if (renderedElement.type == 'Button' &&
                  renderedElement.eventTypes.isNotEmpty) {
                final hasListeners =
                    renderedElement.elementProps.containsKey('onPress') ||
                        renderedElement.elementProps.containsKey('onClick');
                if (!hasListeners) {
                  EngineDebugLogger.log(
                      'RECONCILE_ULTIMATE_BUTTON_RENDERED_NO_HANDLERS',
                      '⚠️ ULTIMATE CHECK: Button rendered element has eventTypes but no handlers!',
                      extra: {
                        'ViewId': renderedViewId,
                        'EventTypes': renderedElement.eventTypes,
                        'ElementProps':
                            renderedElement.elementProps.keys.toList()
                      });
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

  /// Compute props similarity (0.0 to 1.0) to detect prop leakage
  /// Returns 1.0 for identical props, 0.0 for completely different
  double _computePropsSimilarity(
      Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    // Skip function handlers for similarity calculation
    final oldNonFunctionProps = oldProps.entries
        .where((e) => !(e.key.startsWith('on') && e.value is Function))
        .toList();
    final newNonFunctionProps = newProps.entries
        .where((e) => !(e.key.startsWith('on') && e.value is Function))
        .toList();

    if (oldNonFunctionProps.isEmpty && newNonFunctionProps.isEmpty) {
      return 1.0; // Both empty
    }

    if (oldNonFunctionProps.isEmpty || newNonFunctionProps.isEmpty) {
      return 0.0; // One empty, one not = completely different
    }

    // Count matching keys and values
    final allKeys = <String>{
      ...oldNonFunctionProps.map((e) => e.key),
      ...newNonFunctionProps.map((e) => e.key)
    };
    int matchingProps = 0;
    int totalProps = allKeys.length;

    for (final key in allKeys) {
      final oldValue = oldProps[key];
      final newValue = newProps[key];

      if (oldValue == null && newValue == null) {
        matchingProps++;
      } else if (oldValue == null || newValue == null) {
        // One is null, one isn't = different
        continue;
      } else if (oldValue is Map && newValue is Map) {
        if (_mapsEqual(oldValue, newValue)) {
          matchingProps++;
        }
      } else if (oldValue is List && newValue is List) {
        if (_listsEqual(oldValue, newValue)) {
          matchingProps++;
        }
      } else if (oldValue == newValue) {
        matchingProps++;
      }
    }

    return totalProps > 0 ? matchingProps / totalProps : 1.0;
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

    // Handle case where oldElement doesn't have a viewId (e.g., when reconciling newly rendered components)
    int? parentViewId = oldElement.nativeViewId ?? newElement.nativeViewId;

    if (parentViewId == null) {
      // If neither has a viewId, try to find parent from component hierarchy
      // This can happen when reconciling components that haven't been rendered yet
      EngineDebugLogger.log('RECONCILE_CHILDREN_NO_VIEWID',
          'Both old and new elements have no viewId - cannot reconcile children without parent viewId',
          extra: {'OldType': oldElement.type, 'NewType': newElement.type});
      // Skip children reconciliation - they will be rendered when the parent is rendered
      return;
    }

    final hasKeys = _childrenHaveKeys(newChildren);
    EngineDebugLogger.log(
        'RECONCILE_CHILDREN_STRATEGY', 'Choosing reconciliation strategy',
        extra: {'HasKeys': hasKeys, 'ParentViewId': parentViewId});

    if (hasKeys) {
      await _reconcileKeyedChildren(parentViewId, oldChildren, newChildren);
    } else {
      await _reconcileSimpleChildren(parentViewId, oldChildren, newChildren);
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
      int parentViewId,
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

  /// OPTIMIZED: Reconcile children with keys using LCS-based optimal matching
  /// Sophisticated reconciliation algorithm with optimal matching
  /// O(old children count + new children count + reconciliation complexity)
  Future<void> _reconcileKeyedChildren(
      int parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    EngineDebugLogger.log('RECONCILE_KEYED_START',
        'Starting optimized keyed children reconciliation',
        extra: {
          'ParentViewId': parentViewId,
          'OldCount': oldChildren.length,
          'NewCount': newChildren.length
        });

    // OPTIMIZED: Build key maps for O(1) lookup
    final oldChildrenMap = <String?, DCFComponentNode>{};
    final oldChildOrderByKey = <String?, int>{};

    for (int i = 0; i < oldChildren.length; i++) {
      final oldChild = oldChildren[i];
      final key = _getNodeKey(oldChild, i);
      oldChildrenMap[key] = oldChild;
      oldChildOrderByKey[key] = i;
    }

    EngineDebugLogger.log(
        'RECONCILE_KEYED_MAP', 'Created optimized old children map',
        extra: {'KeyCount': oldChildrenMap.length});

    // CRITICAL: Pre-allocate updatedChildIds to match newChildren length
    // This ensures we maintain the correct order even if some children fail reconciliation
    final updatedChildIds = List<int?>.filled(newChildren.length, null);
    final processedOldChildren = <DCFComponentNode>{};
    bool hasStructuralChanges = false;

    // 🔥 UI THREAD YIELDING: Yield every 3 children to prevent UI freeze
    const yieldInterval = 3;
    for (int i = 0; i < newChildren.length; i++) {
      // Yield control back to UI thread every few children
      if (i > 0 && i % yieldInterval == 0) {
        await Future.delayed(Duration.zero); // Yield to event loop
      }
      
      final newChild = newChildren[i];
      final key = _getNodeKey(newChild, i);
      final oldChild = oldChildrenMap[key];

      int? childViewId;

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

      // CRITICAL: Store viewId at the correct index to maintain order
      if (childViewId != null) {
        updatedChildIds[i] = childViewId;
      }
    }

    // 🔥 UI THREAD YIELDING: Yield during removal loop to prevent UI freeze
    int removeIndex = 0;
    for (var oldChild in oldChildren) {
      // Yield control back to UI thread every few removals
      if (removeIndex > 0 && removeIndex % yieldInterval == 0) {
        await Future.delayed(Duration.zero); // Yield to event loop
      }
      removeIndex++;
      
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

    // CRITICAL: Filter out null values and ensure order matches newChildren
    final validChildIds = <int>[];
    final missingIndices = <int>[];
    for (int i = 0; i < updatedChildIds.length; i++) {
      if (updatedChildIds[i] != null) {
        validChildIds.add(updatedChildIds[i]!);
      } else {
        missingIndices.add(i);
      }
    }

    // CRITICAL: Only call setChildren if we have all view IDs
    // Missing view IDs would cause incorrect order
    final hasAllViewIds =
        validChildIds.length == newChildren.length && validChildIds.isNotEmpty;

    // PRODUCTION SAFEGUARD: Runtime assertion to catch any edge cases in development
    // This assertion is automatically disabled in release mode
    assert(
      validChildIds.length == newChildren.length,
      'RECONCILE_KEYED: Child order mismatch - expected ${newChildren.length} children, got ${validChildIds.length}. Missing indices: $missingIndices',
    );

    if (hasStructuralChanges && hasAllViewIds) {
      EngineDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
        'ChildIds': validChildIds,
        'ChildCount': validChildIds.length,
        'ExpectedCount': newChildren.length
      });
      await _nativeBridge.setChildren(parentViewId, validChildIds);
    } else if (hasStructuralChanges && !hasAllViewIds) {
      EngineDebugLogger.log('RECONCILE_KEYED_SET_CHILDREN_SKIPPED',
          '⚠️ CRITICAL: Skipping setChildren - missing view IDs (would cause order corruption)',
          extra: {
            'ExpectedCount': newChildren.length,
            'ActualCount': validChildIds.length,
            'MissingIndices': missingIndices,
            'HasStructuralChanges': hasStructuralChanges
          });
    }

    EngineDebugLogger.log(
        'RECONCILE_KEYED_COMPLETE', 'Keyed children reconciliation completed',
        extra: {
          'StructuralChanges': hasStructuralChanges,
          'FinalChildCount': updatedChildIds.length
        });
  }

  /// O(max(old children, new children) + reconciliation complexity) - Reconcile children without keys
  ///
  /// ALGORITHM: Two-pointer greedy matching with look-ahead
  /// - Uses independent indices (oldIndex, newIndex) to traverse both lists
  /// - Detects insertions by looking ahead in newChildren to find matching oldChild
  /// - Detects removals by looking ahead in oldChildren to find matching newChild
  /// - Matches children when types are compatible (same runtimeType/elementType)
  /// - Replaces when types don't match and no insertion/removal detected
  ///
  /// GUARANTEES:
  /// - Correctly handles single and multiple consecutive insertions
  /// - Correctly handles single and multiple consecutive removals
  /// - Maintains correct order of children in updatedChildIds
  /// - Preserves view IDs when children are matched (not replaced)
  ///
  /// LIMITATIONS:
  /// - Without keys, cannot distinguish between identical children at different positions
  /// - For optimal results with dynamic lists, use explicit keys
  /// - This algorithm is O(n*m) worst case (when many insertions/removals), but O(n+m) average case
  ///
  /// EDGE CASES HANDLED:
  /// - Insertions at beginning, middle, and end
  /// - Removals at beginning, middle, and end
  /// - Multiple consecutive insertions/removals
  /// - Mixed insertions and removals
  /// - Type mismatches (replaces correctly)
  Future<void> _reconcileSimpleChildren(
      int parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    EngineDebugLogger.log(
        'RECONCILE_SIMPLE_START', 'Starting simple children reconciliation',
        extra: {
          'ParentViewId': parentViewId,
          'OldCount': oldChildren.length,
          'NewCount': newChildren.length
        });

    // CRITICAL: Pre-allocate updatedChildIds to match newChildren length
    // This ensures we maintain the correct order even if some children fail reconciliation
    final updatedChildIds = List<int?>.filled(newChildren.length, null);
    bool hasStructuralChanges = false;
    bool hasReplacements = false;
    int replacementCount = 0;

    // CRITICAL: Use smart matching to detect insertions vs replacements
    // This prevents incorrect matching when children are added in the middle
    int oldIndex = 0;
    int newIndex = 0;
    final processedOldIndices = <int>{};
    final processedNewIndices = <int>{};

    int loopIteration = 0;
    while (oldIndex < oldChildren.length && newIndex < newChildren.length) {
      // 🔥 UI THREAD YIELDING: Yield every 3 iterations to prevent UI freeze
      if (loopIteration > 0 && loopIteration % 3 == 0) {
        await Future.delayed(Duration.zero); // Yield to event loop
      }
      loopIteration++;
      
      final oldChild = oldChildren[oldIndex];
      final newChild = newChildren[newIndex];

      // 🔥 CRITICAL: Check props similarity FIRST before any position matching
      // If props differ significantly OR types don't match, treat as replacement immediately
      // This prevents incorrect matching when structure changes dramatically
      bool propsDifferSignificantly = false;
      bool typesDontMatch = false;

      // Check if types don't match (different component types or element types)
      if (oldChild.runtimeType != newChild.runtimeType) {
        typesDontMatch = true;
      } else if (oldChild is DCFElement && newChild is DCFElement) {
        if (oldChild.type != newChild.type) {
          typesDontMatch = true;
        } else {
          // Same type - check props similarity
          final propsSimilarity = _computePropsSimilarity(
              oldChild.elementProps, newChild.elementProps);
          if (propsSimilarity < 0.5) {
            propsDifferSignificantly = true;
            EngineDebugLogger.log('RECONCILE_SIMPLE_PROPS_DIFFER',
                'Props differ significantly - forcing replacement (no position matching)',
                extra: {
                  'OldIndex': oldIndex,
                  'NewIndex': newIndex,
                  'PropsSimilarity': propsSimilarity,
                  'OldType': oldChild.type,
                  'NewType': newChild.type,
                });
          }
        }
      }

      // Check if current positions match (only if props are similar)
      final positionsMatch = !_shouldReplaceAtSamePosition(oldChild, newChild);

      // CRITICAL: Look ahead to detect insertions/removals BEFORE replacing
      // This allows the framework to handle conditional rendering without requiring explicit keys
      // We MUST check for insertions/removals even when types don't match at the same position
      int? matchingNewIndex;
      int? matchingOldIndex;

      // Look ahead if positions don't match (types/keys differ at current position)
      // AND we haven't processed this old child yet
      // This handles conditional children being inserted/removed
      if (!positionsMatch && !processedOldIndices.contains(oldIndex)) {
        // Look ahead to find where oldChild appears in newChildren (if at all)
        // This handles multiple consecutive insertions correctly, including at the beginning
        for (int lookAhead = newIndex + 1;
            lookAhead < newChildren.length;
            lookAhead++) {
          final lookAheadChild = newChildren[lookAhead];
          // Skip if already processed
          if (lookAhead < newIndex || processedNewIndices.contains(lookAhead)) continue;
          
          // Check props similarity before matching
          bool canMatch = true;
          if (oldChild is DCFElement && lookAheadChild is DCFElement) {
            final lookAheadPropsSimilarity = _computePropsSimilarity(
                oldChild.elementProps, lookAheadChild.elementProps);
            if (lookAheadPropsSimilarity < 0.5) {
              canMatch = false;
            }
          }
          // CRITICAL: Only match if types match AND props are similar
          // This prevents matching different components just because they're similar
          if (canMatch &&
              oldChild.runtimeType == lookAheadChild.runtimeType &&
              !_shouldReplaceAtSamePosition(oldChild, lookAheadChild)) {
            matchingNewIndex = lookAhead;
            break;
          }
        }

        // Look ahead to find where newChild appears in oldChildren (if at all)
        // This handles multiple consecutive removals correctly
        for (int lookAhead = oldIndex + 1;
            lookAhead < oldChildren.length;
            lookAhead++) {
          final lookAheadChild = oldChildren[lookAhead];
          // Skip if already processed
          if (processedOldIndices.contains(lookAhead)) {
            continue;
          }
          // Check props similarity before matching
          bool canMatch = true;
          if (newChild is DCFElement && lookAheadChild is DCFElement) {
            final lookAheadPropsSimilarity = _computePropsSimilarity(
                newChild.elementProps, lookAheadChild.elementProps);
            if (lookAheadPropsSimilarity < 0.5) {
              canMatch = false;
            }
          }
          // CRITICAL: Only match if types match AND props are similar
          // This prevents matching different components just because they're similar
          if (canMatch &&
              newChild.runtimeType == lookAheadChild.runtimeType &&
              !_shouldReplaceAtSamePosition(lookAheadChild, newChild)) {
            matchingOldIndex = lookAhead;
            break;
          }
        }
      }

      final isInsertion = matchingNewIndex != null && !positionsMatch;
      final isRemoval = matchingOldIndex != null && !positionsMatch;

      // If we found a match via look-ahead, handle insertion/removal instead of replacement
      if (isInsertion || isRemoval) {
        // Skip the immediate replacement logic below - we'll handle it in the insertion/removal branches
      } else if (propsDifferSignificantly || typesDontMatch) {
        // No match found via look-ahead, and types/props don't match - replace immediately
        hasReplacements = true;
        replacementCount++;
        hasStructuralChanges = true;

        EngineDebugLogger.log(
            'RECONCILE_SIMPLE_REPLACE_IMMEDIATE',
            typesDontMatch
                ? 'Replacing child immediately due to type mismatch (no look-ahead match)'
                : 'Replacing child immediately due to props mismatch (no look-ahead match)',
            extra: {
              'OldIndex': oldIndex,
              'NewIndex': newIndex,
              'OldType': oldChild.runtimeType.toString(),
              'NewType': newChild.runtimeType.toString(),
              'TypesDontMatch': typesDontMatch,
              'PropsDifferSignificantly': propsDifferSignificantly,
            });

        try {
          oldChild.componentWillUnmount();
        } catch (e) {
          EngineDebugLogger.log(
              'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
              extra: {'Error': e.toString()});
        }

        final oldViewId = oldChild.effectiveNativeViewId;
        if (oldViewId != null) {
          EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
          await _nativeBridge.deleteView(oldViewId);
          _nodesByViewId.remove(oldViewId);
        }

        final childViewId = await renderToNative(newChild,
            parentViewId: parentViewId, index: newIndex);

        if (childViewId != null) {
          updatedChildIds[newIndex] = childViewId;
        }

        oldIndex++;
        newIndex++;
        continue;
      }

      EngineDebugLogger.log('RECONCILE_SIMPLE_UPDATE', 'Processing children',
          extra: {
            'OldIndex': oldIndex,
            'NewIndex': newIndex,
            'PositionsMatch': positionsMatch,
            'IsInsertion': isInsertion,
            'IsRemoval': isRemoval
          });

      int? childViewId;
      bool wasInsertion = false;

      if (isInsertion && !positionsMatch) {
        // New child is inserted - create it
        wasInsertion = true;
        hasStructuralChanges = true;
        EngineDebugLogger.log(
            'RECONCILE_SIMPLE_INSERT', 'Inserting new child at index $newIndex',
            extra: {
              'NewType': newChild.runtimeType.toString(),
              'OldChildWillMatchAt': matchingNewIndex,
            });

        // Insert the new child
        childViewId = await renderToNative(newChild,
            parentViewId: parentViewId, index: newIndex);

        if (childViewId != null) {
          updatedChildIds[newIndex] = childViewId;
          EngineDebugLogger.log('RECONCILE_SIMPLE_VIEW_ID_ADDED',
              'Added view ID to updatedChildIds at index $newIndex',
              extra: {'ViewId': childViewId, 'Index': newIndex});
        }
        processedNewIndices.add(newIndex);

        // Now reconcile the old child with the matched new child at matchingNewIndex
        if (matchingNewIndex != null && matchingNewIndex < newChildren.length) {
          final matchedNewChild = newChildren[matchingNewIndex];
          EngineDebugLogger.log('RECONCILE_SIMPLE_MATCH_AFTER_INSERT',
              'Reconciling old child with matched new child',
              extra: {
                'OldIndex': oldIndex,
                'MatchedNewIndex': matchingNewIndex,
                'OldType': oldChild.runtimeType.toString(),
                'NewType': matchedNewChild.runtimeType.toString(),
              });

          await _reconcile(oldChild, matchedNewChild);
          final matchedViewId =
              matchedNewChild.effectiveNativeViewId ?? oldChild.effectiveNativeViewId;
          if (matchedViewId != null) {
            updatedChildIds[matchingNewIndex] = matchedViewId;
            EngineDebugLogger.log('RECONCILE_SIMPLE_MATCHED_VIEW_ID',
                'Added matched view ID to updatedChildIds',
                extra: {'ViewId': matchedViewId, 'Index': matchingNewIndex});
          }

          processedOldIndices.add(oldIndex);
          processedNewIndices.add(matchingNewIndex);
          oldIndex++; // Move to next old child
          newIndex = matchingNewIndex + 1; // Move past the matched new child
        } else {
          newIndex++; // Move to next new child, keep old index
        }
        continue;
      } else if (isRemoval && !positionsMatch) {
        // Old child is removed - unmount it
        hasStructuralChanges = true;
        EngineDebugLogger.log(
            'RECONCILE_SIMPLE_REMOVE', 'Removing old child at index $oldIndex',
            extra: {'OldType': oldChild.runtimeType.toString()});

        try {
          oldChild.componentWillUnmount();
        } catch (e) {
          EngineDebugLogger.log(
              'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
              extra: {'Error': e.toString()});
        }

        final viewId = oldChild.effectiveNativeViewId;
        if (viewId != null) {
          EngineDebugLogger.logBridge('DELETE_VIEW', viewId);
          await _nativeBridge.deleteView(viewId);
          _nodesByViewId.remove(viewId);
        }

        oldIndex++; // Move to next old child, keep new index
        continue;
      } else if (positionsMatch) {
        // Positions match - but check if props differ significantly
        // 🔥 CRITICAL: If props differ significantly, force replacement instead of reconciliation
        // This prevents prop leakage when components are matched by position/type but have different content
        bool shouldForceReplace = false;
        if (oldChild is DCFElement && newChild is DCFElement) {
          final propsSimilarity = _computePropsSimilarity(
              oldChild.elementProps, newChild.elementProps);
          if (propsSimilarity < 0.5) {
            shouldForceReplace = true;
            EngineDebugLogger.log('RECONCILE_SIMPLE_PROPS_MISMATCH',
                'Props differ significantly at same position - forcing replacement',
                extra: {
                  'OldIndex': oldIndex,
                  'NewIndex': newIndex,
                  'PropsSimilarity': propsSimilarity,
                  'OldType': oldChild.type,
                  'NewType': newChild.type,
                });
          }
        }

        if (shouldForceReplace) {
          // Force replacement instead of reconciliation
          hasReplacements = true;
          replacementCount++;
          hasStructuralChanges = true;

          EngineDebugLogger.log('RECONCILE_SIMPLE_REPLACE_PROPS',
              'Replacing child due to props mismatch',
              extra: {
                'OldIndex': oldIndex,
                'NewIndex': newIndex,
                'OldType': oldChild.runtimeType.toString(),
                'NewType': newChild.runtimeType.toString(),
              });

          try {
            oldChild.componentWillUnmount();
          } catch (e) {
            EngineDebugLogger.log(
                'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
                extra: {'Error': e.toString()});
          }

          final oldViewId = oldChild.effectiveNativeViewId;
          if (oldViewId != null) {
            EngineDebugLogger.logBridge('DELETE_VIEW', oldViewId);
            await _nativeBridge.deleteView(oldViewId);
            _nodesByViewId.remove(oldViewId);
          }

          childViewId = await renderToNative(newChild,
              parentViewId: parentViewId, index: newIndex);

          if (childViewId != null) {
            updatedChildIds[newIndex] = childViewId;
          }

          oldIndex++;
          newIndex++;
          continue;
        }

        // Positions match and props are similar - reconcile
        // 🔥 CRITICAL: Skip position tracking during structural shock to prevent incorrect matching
        if (!_isStructuralShock) {
          // Track component instance by position for automatic key inference
          final childPositionKey =
              "$parentViewId:$newIndex:${newChild.runtimeType}";
          final childPropsHash = _computePropsHash(newChild);
          final childPropsKey = "$childPositionKey:$childPropsHash";
          _componentInstancesByPosition[childPositionKey] = newChild;
          _componentInstancesByProps[childPropsKey] = newChild;
        }

        // 🔥 CRITICAL FIX: Preserve view ID BEFORE reconciliation for matched children
        // This ensures stable children (like buttons) keep their view IDs even if reconciliation
        // doesn't assign one. This makes the framework stable without requiring keys or wrappers.
        // The Button should preserve its view ID even though DotCorrLanding is replaced.
        final oldViewIdBeforeReconcile = oldChild.effectiveNativeViewId;
        
        await _reconcile(oldChild, newChild);
        childViewId =
            newChild.effectiveNativeViewId ?? oldChild.effectiveNativeViewId;
        
        // 🔥 CRITICAL: If reconciliation didn't assign a view ID but old child had one,
        // preserve it to prevent view loss. This is especially important for stable children.
        if (childViewId == null && oldViewIdBeforeReconcile != null) {
          childViewId = oldViewIdBeforeReconcile;
          if (newChild is DCFElement) {
            newChild.nativeViewId = childViewId;
          } else if (newChild is DCFStatefulComponent ||
              newChild is DCFStatelessComponent) {
            newChild.contentViewId = childViewId;
          }
          // Update mapping to point to newChild
          final nodeToMap = newChild is DCFElement
              ? newChild
              : (newChild.renderedNode is DCFElement
                  ? newChild.renderedNode as DCFElement
                  : newChild);
          _nodesByViewId[childViewId!] = nodeToMap;
          EngineDebugLogger.log('RECONCILE_SIMPLE_PRESERVED_VIEW_ID',
              '✅ PRESERVED view ID for matched child (reconciliation didn\'t assign one)',
              extra: {
                'ViewId': childViewId,
                'Index': newIndex,
                'OldType': oldChild.runtimeType.toString(),
                'NewType': newChild.runtimeType.toString(),
              });
        }

        // CRITICAL: After reconciling each child, IMMEDIATELY ensure the mapping points to newChild
        if (childViewId != null) {
          final mappedNode = _nodesByViewId[childViewId];

          if (newChild is DCFElement) {
            if (mappedNode != newChild) {
              _nodesByViewId[childViewId] = newChild;
              EngineDebugLogger.log('RECONCILE_CHILD_FIX_MAPPING',
                  '⚠️ Fixed mapping to point to new child element',
                  extra: {
                    'ViewId': childViewId,
                    'ChildType': newChild.type,
                    'HasOnPress': newChild.elementProps.containsKey('onPress'),
                  });
            }
          } else if (newChild is DCFStatefulComponent ||
              newChild is DCFStatelessComponent) {
            final renderedElement = newChild.renderedNode;
            if (renderedElement is DCFElement) {
              final renderedViewId = renderedElement.nativeViewId;
              if (renderedViewId != null) {
                final renderedMappedNode = _nodesByViewId[renderedViewId];
                if (renderedMappedNode != renderedElement) {
                  _nodesByViewId[renderedViewId] = renderedElement;
                }
              }
            }
          }
        }

        processedOldIndices.add(oldIndex);
        oldIndex++;
        newIndex++;
      } else {
        // Types don't match and it's not an insertion/removal - replace
        hasReplacements = true;
        replacementCount++;
        EngineDebugLogger.log(
            'RECONCILE_SIMPLE_REPLACE', 'Replacing child at index $newIndex',
            extra: {
              'OldType': oldChild.runtimeType.toString(),
              'NewType': newChild.runtimeType.toString(),
            });

        final oldViewId = oldChild.effectiveNativeViewId;
        await _replaceNode(oldChild, newChild);
        childViewId = newChild.effectiveNativeViewId;

        // Fallback strategies for view ID (same as before)
        if (childViewId == null) {
          if (newChild is DCFStatefulComponent ||
              newChild is DCFStatelessComponent) {
            final renderedNode = newChild.renderedNode;
            if (renderedNode is DCFElement) {
              childViewId = renderedNode.nativeViewId;
              if (childViewId != null) {
                newChild.contentViewId = childViewId;
              }
            }
          }

          if (childViewId == null && newChild is DCFElement) {
            for (final entry in _nodesByViewId.entries) {
              if (entry.value == newChild) {
                childViewId = entry.key;
                newChild.nativeViewId = childViewId;
                break;
              }
            }
          }

          if (childViewId == null && oldViewId != null) {
            if (_nodesByViewId.containsKey(oldViewId)) {
              final registeredNode = _nodesByViewId[oldViewId];
              if (registeredNode == newChild ||
                  (newChild is DCFStatefulComponent &&
                      registeredNode == newChild.renderedNode) ||
                  (newChild is DCFStatelessComponent &&
                      registeredNode == newChild.renderedNode)) {
                childViewId = oldViewId;
                if (newChild is DCFElement) {
                  newChild.nativeViewId = childViewId;
                } else if (newChild is DCFStatefulComponent ||
                    newChild is DCFStatelessComponent) {
                  newChild.contentViewId = childViewId;
                }
              }
            }
          }
        }

        processedOldIndices.add(oldIndex);
        oldIndex++;
        newIndex++;
      }

      // CRITICAL: Store viewId at the correct index to maintain order
      // Note: For reconcile/replace cases, newIndex was already incremented, so use newIndex - 1
      // For insertions, the viewId was already stored above
      if (!wasInsertion) {
        final storeIndex = newIndex - 1; // newIndex was already incremented

        // CRITICAL: If childViewId is null/empty, try to get it from the node after reconciliation
        if (childViewId == null) {
          // Try to get viewId from newChild after reconciliation
          childViewId = newChild.effectiveNativeViewId;

          // If still null, try to get it from oldChild (shouldn't happen, but safety check)
          if (childViewId == null && oldChild.effectiveNativeViewId != null) {
            childViewId = oldChild.effectiveNativeViewId;
            // Update newChild to use the old viewId
            if (newChild is DCFElement) {
              newChild.nativeViewId = childViewId;
            } else if (newChild is DCFStatefulComponent ||
                newChild is DCFStatelessComponent) {
              newChild.contentViewId = childViewId;
            }
          }

          // Final fallback: search _nodesByViewId for the node
          if (childViewId == null) {
            for (final entry in _nodesByViewId.entries) {
              if (entry.value == newChild ||
                  (newChild is DCFStatefulComponent &&
                      entry.value == newChild.renderedNode) ||
                  (newChild is DCFStatelessComponent &&
                      entry.value == newChild.renderedNode)) {
                childViewId = entry.key;
                if (newChild is DCFElement) {
                  newChild.nativeViewId = childViewId;
                } else if (newChild is DCFStatefulComponent ||
                    newChild is DCFStatelessComponent) {
                  newChild.contentViewId = childViewId;
                }
                break;
              }
            }
          }
        }

        if (childViewId != null) {
          updatedChildIds[storeIndex] = childViewId;
          EngineDebugLogger.log('RECONCILE_SIMPLE_VIEW_ID_ADDED',
              'Added view ID to updatedChildIds',
              extra: {'ViewId': childViewId, 'Index': storeIndex});
        } else {
          // CRITICAL: If we still don't have a view ID, we MUST NOT call setChildren
          // because it will remove all views and this one will be lost
          EngineDebugLogger.log('RECONCILE_SIMPLE_MISSING_VIEW_ID',
              '⚠️ CRITICAL: Child at index $storeIndex has no view ID after reconciliation - will skip setChildren',
              extra: {
                'OldType': oldChild.runtimeType.toString(),
                'NewType': newChild.runtimeType.toString(),
                'Index': storeIndex,
                'Warning': 'setChildren will be skipped to prevent view loss'
              });
        }
      }
    }

    // Handle remaining old children (removals at the end)
    int remainingLoopIteration = 0;
    while (oldIndex < oldChildren.length) {
      // 🔥 UI THREAD YIELDING: Yield every 3 iterations to prevent UI freeze
      if (remainingLoopIteration > 0 && remainingLoopIteration % 3 == 0) {
        await Future.delayed(Duration.zero); // Yield to event loop
      }
      remainingLoopIteration++;
      
      final oldChild = oldChildren[oldIndex];
      hasStructuralChanges = true;

      try {
        oldChild.componentWillUnmount();
      } catch (e) {
        EngineDebugLogger.log(
            'LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount',
            extra: {'Error': e.toString()});
      }

      final viewId = oldChild.effectiveNativeViewId;
      if (viewId != null) {
        EngineDebugLogger.logBridge('DELETE_VIEW', viewId);
        await _nativeBridge.deleteView(viewId);
        _nodesByViewId.remove(viewId);
      }

      oldIndex++;
    }

    // Handle remaining new children (insertions at the end)
    while (newIndex < newChildren.length) {
      final newChild = newChildren[newIndex];
      hasStructuralChanges = true;

      EngineDebugLogger.log('RECONCILE_SIMPLE_ADD_END',
          'Adding new child at end, index $newIndex',
          extra: {
            'ChildType': newChild.runtimeType.toString(),
            'IsLastChild': newIndex == newChildren.length - 1,
            'TotalNewChildren': newChildren.length
          });

      final childViewId = await renderToNative(newChild,
          parentViewId: parentViewId, index: newIndex);

      if (childViewId != null) {
        updatedChildIds[newIndex] = childViewId;
        EngineDebugLogger.log(
            'RECONCILE_SIMPLE_END_VIEW_ID_ADDED', 'Added view ID for end child',
            extra: {
              'ViewId': childViewId,
              'Index': newIndex,
              'IsLastChild': newIndex == newChildren.length - 1
            });
      } else {
        EngineDebugLogger.log('RECONCILE_SIMPLE_END_MISSING_VIEW_ID',
            '⚠️ CRITICAL: End child at index $newIndex has no view ID after renderToNative',
            extra: {
              'ChildType': newChild.runtimeType.toString(),
              'Index': newIndex,
              'IsLastChild': newIndex == newChildren.length - 1,
              'Warning': 'This child will be missing from setChildren'
            });
      }

      newIndex++;
    }

    // CRITICAL: Filter out null values and ensure order matches newChildren
    // This ensures updatedChildIds[i] corresponds to newChildren[i]
    final validChildIds = <int>[];
    final missingIndices = <int>[];
    for (int i = 0; i < updatedChildIds.length; i++) {
      if (updatedChildIds[i] != null) {
        validChildIds.add(updatedChildIds[i]!);
      } else {
        missingIndices.add(i);
      }
    }

    final expectedCount = newChildren.length;
    final actualCount = validChildIds.length;
    final hasAdditionsOrRemovals = newChildren.length != oldChildren.length;

    // CRITICAL: Never call setChildren if we're missing view IDs
    // setChildren does removeAllViews() which will remove views that aren't in the list
    // This would cause views to disappear permanently
    final hasAllViewIds =
        actualCount == expectedCount && validChildIds.isNotEmpty;

    // PRODUCTION SAFEGUARD: Runtime assertion to catch any edge cases in development
    // This assertion is automatically disabled in release mode
    assert(
      validChildIds.length == newChildren.length,
      'RECONCILE_SIMPLE: Child order mismatch - expected ${newChildren.length} children, got ${validChildIds.length}. Missing indices: $missingIndices',
    );

    if (!hasAllViewIds) {
      EngineDebugLogger.log('RECONCILE_SIMPLE_SET_CHILDREN_SKIPPED',
          '⚠️ CRITICAL: Skipping setChildren - missing view IDs (would cause view loss)',
          extra: {
            'ExpectedCount': expectedCount,
            'ActualCount': actualCount,
            'MissingCount': expectedCount - actualCount,
            'MissingIndices': missingIndices,
            'ValidChildIds': validChildIds,
            'HasStructuralChanges': hasStructuralChanges,
            'HasReplacements': hasReplacements,
            'ReplacementCount': replacementCount,
            'ParentViewId': parentViewId,
            'Warning':
                'setChildren would call removeAllViews() and lose views without IDs'
          });
    } else {
      // CRITICAL: Always call setChildren when there are replacements to ensure correct order
      // Even if there are no structural changes, replacements can change the order
      // Also call it when there are structural changes (additions/removals)
      if (hasStructuralChanges || hasReplacements) {
        EngineDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
          'ChildIds': validChildIds,
          'ChildCount': validChildIds.length,
          'ExpectedCount': expectedCount,
          'HasReplacements': hasReplacements,
          'ReplacementCount': replacementCount,
          'HasAdditionsOrRemovals': hasAdditionsOrRemovals,
          'Reason': hasStructuralChanges
              ? 'Structural changes'
              : 'Replacements only - ensuring correct order'
        });
        await _nativeBridge.setChildren(parentViewId, validChildIds);
      } else {
        EngineDebugLogger.log('RECONCILE_SIMPLE_SET_CHILDREN_SKIPPED',
            'Skipping setChildren - no structural changes or replacements',
            extra: {
              'ParentViewId': parentViewId,
              'ChildCount': validChildIds.length
            });
      }
    }

    EngineDebugLogger.log(
        'RECONCILE_SIMPLE_COMPLETE', 'Simple children reconciliation completed',
        extra: {
          'StructuralChanges': hasStructuralChanges,
          'HasReplacements': hasReplacements,
          'FinalChildCount': validChildIds.length,
          'ExpectedCount': expectedCount,
          'AllViewIdsPresent': hasAllViewIds
        });
  }

  /// O(1) - Move a child to a specific index in its parent
  Future<void> _moveChild(int childId, int parentId, int index) async {
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
    EngineDebugLogger.log(
        'CANCEL_ALL_WORK', 'Cancelling all pending async work');

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

    // Worker manager handles task cancellation automatically

    // Clear effect queues (these use Future.microtask which can't be cancelled,
    // but clearing the sets prevents them from executing)
    final layoutCount = _componentsWaitingForLayout.length;
    final insertionCount = _componentsWaitingForInsertion.length;
    _componentsWaitingForLayout.clear();
    _componentsWaitingForInsertion.clear();

    EngineDebugLogger.log(
        'CANCEL_ALL_WORK_COMPLETE', 'Cancelled all pending async work',
        extra: {
          'PendingUpdates': pendingCount,
          'WorkerManagerEnabled': _workerManagerInitialized,
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
      'workerManagerEnabled': _workerManagerInitialized,
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
    return _workerManagerInitialized && efficiency > 10.0; // 10% improvement threshold
  }

  /// Shutdown concurrent processing
  /// Shutdown worker manager
  Future<void> shutdownConcurrentProcessing() async {
    if (!_workerManagerInitialized) return;

    EngineDebugLogger.log(
        'WORKER_MANAGER_SHUTDOWN', 'Shutting down worker manager');

    try {
      await worker_manager.workerManager.dispose();
      _workerManagerInitialized = false;
    EngineDebugLogger.log(
          'WORKER_MANAGER_SHUTDOWN', 'Worker manager shutdown complete');
      } catch (e) {
      EngineDebugLogger.log('WORKER_MANAGER_SHUTDOWN_ERROR',
          'Error disposing worker manager: $e');
    }
  }

  /// Reconcile tree structure in isolate (heavy algorithmic work)
  static Future<Map<String, dynamic>> _reconcileTreeInIsolate(
      Map<String, dynamic> data) async {
    final treeData = data['oldTree'] as Map<String, dynamic>?;
    final oldTree = treeData;
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

    final childrenChanges = _computeChildrenDiffSync(oldChildren, newChildren);
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

    return _computeDeepPropsDiff(oldProps, newProps);
  }

  /// Process large lists in isolate (heavy data processing)
  static Future<Map<String, dynamic>> _processLargeListInIsolate(
      Map<String, dynamic> data) async {
    final items = data['items'] as List<dynamic>;
    final operations = data['operations'] as List<String>? ?? [];

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

  /// Helper: Compute children diff (synchronous for isolate)
  static List<Map<String, dynamic>> _computeChildrenDiffSync(
      List<dynamic> oldChildren, List<dynamic> newChildren) {
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

  /// Helper: Compute children diff (async version for main thread)
  static Future<List<Map<String, dynamic>>> _computeChildrenDiff(
      List<dynamic> oldChildren, List<dynamic> newChildren) async {
    return _computeChildrenDiffSync(oldChildren, newChildren);
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

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return _performanceMonitor.getMetrics();
  }

  /// Reset performance metrics
  void resetPerformanceMetrics() {
    _performanceMonitor.reset();
  }
}

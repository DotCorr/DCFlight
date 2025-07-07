# Custom State Change Handlers

Custom state change handlers allow you to intercept and control how state changes trigger component updates. This enables fine-grained optimization of the update process, custom batching strategies, and integration with external state management systems.

## When to Use State Change Handlers

State change handlers are ideal for:

- **Performance optimization** by skipping unnecessary re-renders
- **Custom batching** of multiple state changes
- **External state management** integration (Redux, MobX, etc.)
- **Selective updates** that only affect specific parts of the component tree
- **Debugging state changes** and update patterns
- **Implementing specialized update strategies** for performance-critical components

## Basic Implementation

### 1. Create Your Handler

```dart
import 'package:dcflight/framework/renderer/vdom/mutator/vdom_mutator_extension_reg.dart';

class MyStateChangeHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    // Only handle specific component types
    return component is MyOptimizedComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    // Custom state change logic
    
    if (_shouldSkipUpdate(oldState, newState)) {
      // Skip this update entirely
      context.skipUpdate();
      return;
    }
    
    if (_shouldDoPartialUpdate(oldState, newState)) {
      // Do a targeted update instead of full re-render
      final targetNode = _getTargetNode(component, newState);
      context.partialUpdate(targetNode);
      return;
    }
    
    // Use normal update flow
    context.scheduleUpdate();
  }
  
  bool _shouldSkipUpdate(dynamic oldState, dynamic newState) {
    // Your logic to determine if update should be skipped
    return oldState == newState;
  }
  
  bool _shouldDoPartialUpdate(dynamic oldState, dynamic newState) {
    // Your logic to determine if partial update is sufficient
    return _onlyUIDataChanged(oldState, newState);
  }
}
```

### 2. Register Your Handler

```dart
void initializeMyModule() {
  VDomExtensionRegistry.instance.registerStateChangeHandler<MyOptimizedComponent>(
    MyStateChangeHandler()
  );
}
```

## VDomStateChangeContext API

The context object provides control over the update process:

```dart
class VDomStateChangeContext {
  /// Schedule a normal component update
  final Function() scheduleUpdate;
  
  /// Skip this update entirely
  final Function() skipUpdate;
  
  /// Perform a partial update on a specific node
  final Function(DCFComponentNode) partialUpdate;
}
```

## Real-World Examples

### 1. Shallow Comparison Optimizer

```dart
class ShallowComparisonHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is ShallowCompareComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    // Perform shallow comparison for state objects
    if (_shallowEqual(oldState, newState)) {
      // Skip update if only deep properties changed
      context.skipUpdate();
      return;
    }
    
    // Check if only specific fields changed
    final changedFields = _getChangedFields(oldState, newState);
    
    if (_canOptimizeUpdate(changedFields)) {
      // Perform targeted update for specific fields
      _performOptimizedUpdate(component, changedFields, context);
    } else {
      // Fall back to normal update
      context.scheduleUpdate();
    }
  }
  
  bool _shallowEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || a[key] != b[key]) return false;
      }
      return true;
    }
    
    return a == b;
  }
  
  Set<String> _getChangedFields(dynamic oldState, dynamic newState) {
    final changed = <String>{};
    
    if (oldState is Map && newState is Map) {
      // Find changed keys
      for (final key in newState.keys) {
        if (!oldState.containsKey(key) || oldState[key] != newState[key]) {
          changed.add(key.toString());
        }
      }
      
      // Find removed keys
      for (final key in oldState.keys) {
        if (!newState.containsKey(key)) {
          changed.add(key.toString());
        }
      }
    }
    
    return changed;
  }
  
  bool _canOptimizeUpdate(Set<String> changedFields) {
    // Only optimize if specific UI-only fields changed
    const uiOnlyFields = {'loading', 'error', 'message', 'highlighted'};
    return changedFields.isNotEmpty && changedFields.every(uiOnlyFields.contains);
  }
  
  void _performOptimizedUpdate(
    StatefulComponent component, 
    Set<String> changedFields,
    VDomStateChangeContext context
  ) {
    // Find specific child nodes that need updating
    final targetNodes = _findTargetNodes(component, changedFields);
    
    for (final node in targetNodes) {
      context.partialUpdate(node);
    }
  }
  
  List<DCFComponentNode> _findTargetNodes(StatefulComponent component, Set<String> fields) {
    // Implementation depends on your component structure
    // This is a simplified example
    final nodes = <DCFComponentNode>[];
    
    if (fields.contains('loading') && component.loadingIndicator != null) {
      nodes.add(component.loadingIndicator!);
    }
    
    if (fields.contains('error') && component.errorDisplay != null) {
      nodes.add(component.errorDisplay!);
    }
    
    return nodes;
  }
}
```

### 2. Redux Integration Handler

```dart
class ReduxStateChangeHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is ReduxConnectedComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final reduxComponent = component as ReduxConnectedComponent;
    
    // Get selected state from Redux store
    final oldSelectedState = reduxComponent.selector(oldState);
    final newSelectedState = reduxComponent.selector(newState);
    
    // Only update if selected state actually changed
    if (!_deepEqual(oldSelectedState, newSelectedState)) {
      // Check if this is a batched Redux action
      if (ReduxBatchManager.instance.isBatching) {
        // Defer update until batch completes
        ReduxBatchManager.instance.addDeferredUpdate(() {
          context.scheduleUpdate();
        });
      } else {
        context.scheduleUpdate();
      }
    } else {
      // Selected state didn't change, skip update
      context.skipUpdate();
    }
  }
  
  bool _deepEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!_deepEqual(a[key], b[key])) return false;
      }
      return true;
    }
    
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEqual(a[i], b[i])) return false;
      }
      return true;
    }
    
    return a == b;
  }
}

class ReduxBatchManager {
  static final instance = ReduxBatchManager._();
  ReduxBatchManager._();
  
  bool _isBatching = false;
  final List<Function()> _deferredUpdates = [];
  
  bool get isBatching => _isBatching;
  
  void startBatch() {
    _isBatching = true;
  }
  
  void endBatch() {
    _isBatching = false;
    
    // Execute all deferred updates
    final updates = List.from(_deferredUpdates);
    _deferredUpdates.clear();
    
    for (final update in updates) {
      update();
    }
  }
  
  void addDeferredUpdate(Function() update) {
    _deferredUpdates.add(update);
  }
}
```

### 3. Performance Throttling Handler

```dart
class ThrottlingStateChangeHandler extends VDomStateChangeHandler {
  static final Map<String, DateTime> _lastUpdateTimes = {};
  static final Map<String, Timer> _pendingUpdates = {};
  
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is ThrottledComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final throttledComponent = component as ThrottledComponent;
    final throttleMs = throttledComponent.throttleInterval ?? 100;
    final componentId = component.instanceId;
    
    final now = DateTime.now();
    final lastUpdate = _lastUpdateTimes[componentId];
    
    if (lastUpdate == null || 
        now.difference(lastUpdate).inMilliseconds >= throttleMs) {
      // Enough time has passed, update immediately
      _lastUpdateTimes[componentId] = now;
      context.scheduleUpdate();
    } else {
      // Throttle the update
      _scheduleThrottledUpdate(componentId, throttleMs, context);
    }
  }
  
  void _scheduleThrottledUpdate(
    String componentId,
    int throttleMs,
    VDomStateChangeContext context,
  ) {
    // Cancel any existing pending update
    _pendingUpdates[componentId]?.cancel();
    
    // Schedule new update
    _pendingUpdates[componentId] = Timer(
      Duration(milliseconds: throttleMs),
      () {
        _lastUpdateTimes[componentId] = DateTime.now();
        _pendingUpdates.remove(componentId);
        context.scheduleUpdate();
      },
    );
  }
}

abstract class ThrottledComponent extends StatefulComponent {
  int? get throttleInterval; // Override to set throttle interval in ms
}
```

### 4. Debugging State Change Handler

```dart
class DebuggingStateChangeHandler extends VDomStateChangeHandler {
  static final List<StateChangeEvent> _changeHistory = [];
  static final Map<String, int> _updateCounts = {};
  
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    // Handle all components in debug mode
    return kDebugMode;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final componentId = component.instanceId;
    final componentType = component.runtimeType.toString();
    
    // Record the state change
    final event = StateChangeEvent(
      componentId: componentId,
      componentType: componentType,
      oldState: _serializeState(oldState),
      newState: _serializeState(newState),
      timestamp: DateTime.now(),
    );
    
    _changeHistory.add(event);
    _updateCounts[componentId] = (_updateCounts[componentId] ?? 0) + 1;
    
    // Log frequent updaters
    if (_updateCounts[componentId]! > 50) {
      print('🔥 Frequent updater: $componentType has updated ${_updateCounts[componentId]} times');
    }
    
    // Log state changes in debug mode
    print('🔄 State change in $componentType:');
    print('  Old: ${event.oldState}');
    print('  New: ${event.newState}');
    
    // Keep history manageable
    if (_changeHistory.length > 100) {
      _changeHistory.removeAt(0);
    }
    
    // Proceed with normal update
    context.scheduleUpdate();
  }
  
  Map<String, dynamic> _serializeState(dynamic state) {
    if (state == null) return {'type': 'null'};
    
    if (state is Map) {
      return {
        'type': 'Map',
        'keys': state.keys.map((k) => k.toString()).toList(),
        'values': state.values.map((v) => v.toString()).toList(),
      };
    }
    
    if (state is List) {
      return {
        'type': 'List',
        'length': state.length,
        'items': state.take(5).map((item) => item.toString()).toList(),
      };
    }
    
    return {
      'type': state.runtimeType.toString(),
      'value': state.toString(),
    };
  }
  
  static List<StateChangeEvent> getChangeHistory() => List.from(_changeHistory);
  static Map<String, int> getUpdateCounts() => Map.from(_updateCounts);
}

class StateChangeEvent {
  final String componentId;
  final String componentType;
  final Map<String, dynamic> oldState;
  final Map<String, dynamic> newState;
  final DateTime timestamp;
  
  StateChangeEvent({
    required this.componentId,
    required this.componentType,
    required this.oldState,
    required this.newState,
    required this.timestamp,
  });
}
```

### 5. Batch Update Handler

```dart
class BatchUpdateHandler extends VDomStateChangeHandler {
  static final Map<String, List<StateChange>> _pendingChanges = {};
  static final Map<String, Timer> _batchTimers = {};
  
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is BatchedComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final batchedComponent = component as BatchedComponent;
    final batchInterval = batchedComponent.batchInterval ?? 50;
    final componentId = component.instanceId;
    
    // Add this state change to the batch
    _pendingChanges.putIfAbsent(componentId, () => []);
    _pendingChanges[componentId]!.add(StateChange(
      oldState: oldState,
      newState: newState,
      timestamp: DateTime.now(),
    ));
    
    // Cancel existing timer
    _batchTimers[componentId]?.cancel();
    
    // Schedule batch processing
    _batchTimers[componentId] = Timer(
      Duration(milliseconds: batchInterval),
      () => _processBatch(componentId, context),
    );
  }
  
  void _processBatch(String componentId, VDomStateChangeContext context) {
    final changes = _pendingChanges.remove(componentId);
    _batchTimers.remove(componentId);
    
    if (changes == null || changes.isEmpty) return;
    
    print('📦 Processing batch of ${changes.length} state changes for component $componentId');
    
    // Process all changes as a single update
    context.scheduleUpdate();
  }
}

abstract class BatchedComponent extends StatefulComponent {
  int? get batchInterval; // Override to set batch interval in ms
}

class StateChange {
  final dynamic oldState;
  final dynamic newState;
  final DateTime timestamp;
  
  StateChange({
    required this.oldState,
    required this.newState,
    required this.timestamp,
  });
}
```

## Advanced Patterns

### 1. Conditional State Updates

```dart
class ConditionalStateChangeHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is ConditionalUpdateComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final conditionalComponent = component as ConditionalUpdateComponent;
    
    // Check component's update condition
    if (!conditionalComponent.shouldUpdate(oldState, newState)) {
      context.skipUpdate();
      return;
    }
    
    // Check global conditions
    if (_isAppInBackground() || _isLowMemory()) {
      context.skipUpdate();
      return;
    }
    
    context.scheduleUpdate();
  }
  
  bool _isAppInBackground() {
    // Check if app is in background
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused;
  }
  
  bool _isLowMemory() {
    // Implement memory check logic
    return false; // Simplified
  }
}

abstract class ConditionalUpdateComponent extends StatefulComponent {
  bool shouldUpdate(dynamic oldState, dynamic newState);
}
```

### 2. Priority-Based Updates

```dart
class PriorityStateChangeHandler extends VDomStateChangeHandler {
  static final PriorityQueue<PriorityUpdate> _updateQueue = PriorityQueue();
  static Timer? _processingTimer;
  
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is PriorityComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final priorityComponent = component as PriorityComponent;
    final priority = priorityComponent.updatePriority;
    
    // Add to priority queue
    _updateQueue.add(PriorityUpdate(
      priority: priority,
      component: component,
      context: context,
      timestamp: DateTime.now(),
    ));
    
    // Schedule processing
    _scheduleProcessing();
  }
  
  void _scheduleProcessing() {
    _processingTimer?.cancel();
    _processingTimer = Timer(Duration(milliseconds: 16), _processQueue);
  }
  
  void _processQueue() {
    while (_updateQueue.isNotEmpty) {
      final update = _updateQueue.removeFirst();
      
      // Check if update is still relevant
      if (DateTime.now().difference(update.timestamp).inMilliseconds < 100) {
        update.context.scheduleUpdate();
      }
    }
  }
}

abstract class PriorityComponent extends StatefulComponent {
  int get updatePriority; // Higher number = higher priority
}

class PriorityUpdate implements Comparable<PriorityUpdate> {
  final int priority;
  final StatefulComponent component;
  final VDomStateChangeContext context;
  final DateTime timestamp;
  
  PriorityUpdate({
    required this.priority,
    required this.component,
    required this.context,
    required this.timestamp,
  });
  
  @override
  int compareTo(PriorityUpdate other) {
    // Higher priority first
    return other.priority.compareTo(priority);
  }
}
```

## Testing State Change Handlers

### 1. Unit Testing

```dart
void testStateChangeHandler() {
  group('MyStateChangeHandler', () {
    late MyStateChangeHandler handler;
    late MockVDomStateChangeContext context;
    late TestComponent component;
    
    setUp(() {
      handler = MyStateChangeHandler();
      context = MockVDomStateChangeContext();
      component = TestComponent();
    });
    
    test('should skip update for identical states', () {
      final state = {'data': 'test'};
      
      handler.handleStateChange(component, state, state, context);
      
      verify(context.skipUpdate()).called(1);
      verifyNever(context.scheduleUpdate());
    });
    
    test('should schedule update for different states', () {
      final oldState = {'data': 'old'};
      final newState = {'data': 'new'};
      
      handler.handleStateChange(component, oldState, newState, context);
      
      verify(context.scheduleUpdate()).called(1);
      verifyNever(context.skipUpdate());
    });
    
    test('should perform partial update when appropriate', () {
      final oldState = {'ui': 'old', 'data': 'same'};
      final newState = {'ui': 'new', 'data': 'same'};
      
      handler.handleStateChange(component, oldState, newState, context);
      
      verify(context.partialUpdate(any)).called(1);
    });
  });
}
```

### 2. Integration Testing

```dart
void testHandlerIntegration() {
  group('State Change Handler Integration', () {
    test('should integrate with VDOM updates', () async {
      // Register handler
      final handler = TestStateChangeHandler();
      VDomExtensionRegistry.instance.registerStateChangeHandler<TestComponent>(
        handler
      );
      
      // Create component with state
      final component = TestComponent();
      final vdom = VDom(MockPlatformInterface());
      
      await vdom.createRoot(component);
      
      // Trigger state change
      component.setState({'data': 'updated'});
      
      // Wait for update processing
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify handler was called
      expect(handler.handleStateCalled, isTrue);
    });
    
    test('should work with multiple handlers', () async {
      // Register multiple handlers for different component types
      VDomExtensionRegistry.instance.registerStateChangeHandler<ComponentA>(
        HandlerA()
      );
      VDomExtensionRegistry.instance.registerStateChangeHandler<ComponentB>(
        HandlerB()
      );
      
      // Test that each handler only processes its own component type
      final componentA = ComponentA();
      final componentB = ComponentB();
      
      // Trigger updates
      componentA.setState({'test': 'a'});
      componentB.setState({'test': 'b'});
      
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify correct handlers were called
      expect(HandlerA.instance.callCount, 1);
      expect(HandlerB.instance.callCount, 1);
    });
  });
}
```

## Performance Considerations

### 1. Efficient State Comparison

```dart
class EfficientStateChangeHandler extends VDomStateChangeHandler {
  // Cache comparison results to avoid repeated work
  static final Map<String, bool> _comparisonCache = {};
  
  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final cacheKey = '${oldState.hashCode}_${newState.hashCode}';
    
    // Check cache first
    if (_comparisonCache.containsKey(cacheKey)) {
      if (_comparisonCache[cacheKey]!) {
        context.scheduleUpdate();
      } else {
        context.skipUpdate();
      }
      return;
    }
    
    // Perform comparison and cache result
    final shouldUpdate = _fastCompare(oldState, newState);
    _comparisonCache[cacheKey] = shouldUpdate;
    
    // Limit cache size
    if (_comparisonCache.length > 100) {
      _comparisonCache.clear();
    }
    
    if (shouldUpdate) {
      context.scheduleUpdate();
    } else {
      context.skipUpdate();
    }
  }
  
  bool _fastCompare(dynamic a, dynamic b) {
    // Implement fast comparison logic
    if (identical(a, b)) return false; // No update needed
    if (a?.hashCode == b?.hashCode) return false; // Likely same
    return true; // Different, needs update
  }
}
```

### 2. Memory-Efficient Tracking

```dart
class MemoryEfficientHandler extends VDomStateChangeHandler {
  // Use weak references to avoid memory leaks
  static final Map<String, WeakReference<StatefulComponent>> _trackedComponents = {};
  
  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final componentId = component.instanceId;
    
    // Store weak reference
    _trackedComponents[componentId] = WeakReference(component);
    
    // Clean up stale references periodically
    _cleanupStaleReferences();
    
    // Your state change logic here
    context.scheduleUpdate();
  }
  
  void _cleanupStaleReferences() {
    _trackedComponents.removeWhere((key, weakRef) => weakRef.target == null);
  }
}
```

## Best Practices

### 1. Handle Edge Cases

```dart
class RobustStateChangeHandler extends VDomStateChangeHandler {
  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    try {
      // Handle null states
      if (oldState == null && newState == null) {
        context.skipUpdate();
        return;
      }
      
      // Handle component disposal
      if (!component.isMounted) {
        context.skipUpdate();
        return;
      }
      
      // Your main logic here
      _performStateChangeLogic(component, oldState, newState, context);
      
    } catch (e, stackTrace) {
      // Log error and fall back to safe behavior
      print('State change handler error: $e');
      print('Stack trace: $stackTrace');
      
      // Default to normal update on error
      context.scheduleUpdate();
    }
  }
}
```

### 2. Provide Configuration Options

```dart
class ConfigurableStateChangeHandler extends VDomStateChangeHandler {
  final bool enableThrottling;
  final bool enableBatching;
  final int throttleMs;
  final int batchMs;
  
  ConfigurableStateChangeHandler({
    this.enableThrottling = true,
    this.enableBatching = false,
    this.throttleMs = 100,
    this.batchMs = 50,
  });
  
  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    if (enableThrottling) {
      _handleThrottled(component, oldState, newState, context);
    } else if (enableBatching) {
      _handleBatched(component, oldState, newState, context);
    } else {
      context.scheduleUpdate();
    }
  }
}
```

### 3. Document Performance Impact

```dart
/// High-performance state change handler for data-heavy components.
/// 
/// This handler implements several optimizations:
/// - Shallow comparison for objects with many properties
/// - Throttling for rapidly changing state
/// - Partial updates for UI-only changes
/// 
/// Performance characteristics:
/// - Reduces re-renders by ~60% for typical data components
/// - Adds ~2ms overhead per state change
/// - Uses ~50KB additional memory for caching
/// 
/// Best used with components that:
/// - Have large state objects (>10 properties)
/// - Update frequently (>10 times per second)
/// - Have expensive render methods
class HighPerformanceStateChangeHandler extends VDomStateChangeHandler {
  // Implementation here...
}
```

## Integration with External Libraries

### 1. MobX Integration

```dart
class MobXStateChangeHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is MobXComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final mobxComponent = component as MobXComponent;
    
    // Check if observable dependencies changed
    final dependencies = mobxComponent.getObservableDependencies();
    final changedDependencies = dependencies.where((dep) => dep.hasChanged).toList();
    
    if (changedDependencies.isEmpty) {
      context.skipUpdate();
      return;
    }
    
    // Update only if relevant observables changed
    context.scheduleUpdate();
  }
}
```

### 2. Custom State Management Integration

```dart
class CustomStoreHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    return component is StoreConnectedComponent;
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final storeComponent = component as StoreConnectedComponent;
    
    // Use store's built-in comparison logic
    if (storeComponent.store.shouldComponentUpdate(oldState, newState)) {
      context.scheduleUpdate();
    } else {
      context.skipUpdate();
    }
  }
}
```

## Debugging and Monitoring

### 1. Add Debug Information

```dart
class DebuggableStateChangeHandler extends VDomStateChangeHandler {
  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    if (kDebugMode) {
      final componentType = component.runtimeType.toString();
      print('🔄 State change in $componentType');
      print('  Decision: ${_getDecision(oldState, newState)}');
    }
    
    // Your logic here
    _makeUpdateDecision(oldState, newState, context);
  }
  
  String _getDecision(dynamic oldState, dynamic newState) {
    if (_shouldSkip(oldState, newState)) return 'SKIP';
    if (_shouldPartialUpdate(oldState, newState)) return 'PARTIAL';
    return 'FULL_UPDATE';
  }
}
```

### 2. Performance Metrics

```dart
class MetricsStateChangeHandler extends VDomStateChangeHandler {
  static final Map<String, StateChangeMetrics> _metrics = {};
  
  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    final stopwatch = Stopwatch()..start();
    final componentType = component.runtimeType.toString();
    
    // Your state change logic
    _performStateChangeLogic(component, oldState, newState, context);
    
    stopwatch.stop();
    
    // Record metrics
    final metrics = _metrics.putIfAbsent(componentType, () => StateChangeMetrics());
    metrics.recordHandling(stopwatch.elapsedMicroseconds);
  }
  
  static Map<String, StateChangeMetrics> getMetrics() => Map.from(_metrics);
}

class StateChangeMetrics {
  int totalHandlings = 0;
  int totalMicroseconds = 0;
  int maxMicroseconds = 0;
  
  void recordHandling(int microseconds) {
    totalHandlings++;
    totalMicroseconds += microseconds;
    maxMicroseconds = math.max(maxMicroseconds, microseconds);
  }
  
  double get averageMicroseconds => totalHandlings > 0 ? totalMicroseconds / totalHandlings : 0;
}
```

Custom state change handlers provide precise control over when and how components update in response to state changes. They're essential for building high-performance applications with complex state management requirements.
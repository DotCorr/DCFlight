# Lifecycle Interceptors

Lifecycle interceptors allow you to hook into component lifecycle events throughout the VDOM system. They provide non-intrusive ways to add behavior around component mounting, updating, and unmounting without modifying the components themselves.

## When to Use Lifecycle Interceptors

Lifecycle interceptors are perfect for:

- **Animation coordination** with VDOM updates
- **Performance monitoring** and profiling
- **Development tools** and debugging
- **Memory leak detection** and cleanup
- **Custom logging** and analytics
- **Resource management** (connections, timers, etc.)
- **Cross-cutting concerns** that affect multiple component types

## Basic Implementation

### 1. Create Your Interceptor

```dart
import 'package:dcflight/framework/renderer/vdom/mutator/vdom_mutator_extension_reg.dart';

class MyLifecycleInterceptor extends VDomLifecycleInterceptor {
  @override
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
    // Called before a component is mounted to the VDOM
    print('About to mount: ${node.runtimeType}');
  }

  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    // Called after a component is successfully mounted
    print('Mounted: ${node.runtimeType}');
  }

  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    // Called before a component update/reconciliation
    print('About to update: ${node.runtimeType}');
  }

  @override
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    // Called after a component update completes
    print('Updated: ${node.runtimeType}');
  }

  @override
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    // Called before a component is unmounted
    print('About to unmount: ${node.runtimeType}');
  }

  @override
  void afterUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    // Called after a component is unmounted
    print('Unmounted: ${node.runtimeType}');
  }
}
```

### 2. Register Your Interceptor

```dart
void initializeMyModule() {
  // Register for specific component types
  VDomExtensionRegistry.instance.registerLifecycleInterceptor<MyComponent>(
    MyLifecycleInterceptor()
  );
  
  // Or register for all components by using base class
  VDomExtensionRegistry.instance.registerLifecycleInterceptor<DCFComponentNode>(
    GlobalLifecycleInterceptor()
  );
}
```

## VDomLifecycleContext API

The context object provides access to VDOM operations:

```dart
class VDomLifecycleContext {
  /// Schedule a component update
  final Function() scheduleUpdate;
  
  /// Force an update on a specific node
  final Function(DCFComponentNode) forceUpdate;
  
  /// Access to VDOM state information
  final Map<String, dynamic> vdomState;
}
```

## Real-World Examples

### 1. Animation Coordinator

```dart
class AnimationLifecycleInterceptor extends VDomLifecycleInterceptor {
  static final Set<String> _animatingComponents = {};
  
  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is AnimatedComponent) {
      final nodeId = node.instanceId;
      
      // Pause animations during VDOM updates to prevent conflicts
      if (_animatingComponents.contains(nodeId)) {
        node.pauseAnimations();
      }
    }
  }

  @override
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is AnimatedComponent) {
      final nodeId = node.instanceId;
      
      // Resume animations after VDOM updates complete
      if (_animatingComponents.contains(nodeId)) {
        // Delay slightly to ensure DOM is stable
        Future.delayed(Duration(milliseconds: 16), () {
          node.resumeAnimations();
        });
      }
    }
  }

  @override
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is AnimatedComponent) {
      // Prepare entrance animations
      node.prepareEntranceAnimation();
    }
  }

  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is AnimatedComponent) {
      final nodeId = node.instanceId;
      _animatingComponents.add(nodeId);
      
      // Start entrance animation after mount
      Future.delayed(Duration(milliseconds: 50), () {
        node.startEntranceAnimation();
      });
    }
  }

  @override
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is AnimatedComponent) {
      final nodeId = node.instanceId;
      
      // Start exit animation before unmount
      if (_animatingComponents.contains(nodeId)) {
        node.startExitAnimation();
        
        // Delay unmount until animation completes
        Future.delayed(node.exitAnimationDuration, () {
          _animatingComponents.remove(nodeId);
        });
      }
    }
  }
}
```

### 2. Performance Monitor

```dart
class PerformanceLifecycleInterceptor extends VDomLifecycleInterceptor {
  static final Map<String, Stopwatch> _updateTimers = {};
  static final Map<String, int> _updateCounts = {};
  
  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    final nodeId = node.instanceId;
    final timer = Stopwatch()..start();
    _updateTimers[nodeId] = timer;
    
    // Track update frequency
    _updateCounts[nodeId] = (_updateCounts[nodeId] ?? 0) + 1;
    
    // Warn about excessive updates
    if (_updateCounts[nodeId]! > 100) {
      print('⚠️ Component ${node.runtimeType} has updated ${_updateCounts[nodeId]} times');
    }
  }

  @override
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    final nodeId = node.instanceId;
    final timer = _updateTimers[nodeId];
    
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMicroseconds;
      
      // Log slow updates
      if (duration > 16000) { // 16ms threshold
        print('🐌 Slow update: ${node.runtimeType} took ${duration / 1000}ms');
      }
      
      // Clean up
      _updateTimers.remove(nodeId);
    }
  }

  @override
  void afterUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    // Clean up tracking data
    final nodeId = node.instanceId;
    _updateTimers.remove(nodeId);
    _updateCounts.remove(nodeId);
  }
}
```

### 3. Memory Leak Detector

```dart
class MemoryLeakDetectorInterceptor extends VDomLifecycleInterceptor {
  static final Map<String, DateTime> _mountTimes = {};
  static final Set<String> _longLivedComponents = {};
  
  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    final nodeId = node.instanceId;
    _mountTimes[nodeId] = DateTime.now();
    
    // Schedule check for long-lived components
    Timer(Duration(minutes: 5), () {
      _checkForLongLivedComponent(node);
    });
  }

  @override
  void afterUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    final nodeId = node.instanceId;
    
    // Calculate component lifetime
    final mountTime = _mountTimes[nodeId];
    if (mountTime != null) {
      final lifetime = DateTime.now().difference(mountTime);
      
      if (lifetime.inMinutes > 10) {
        print('📊 Long-lived component unmounted: ${node.runtimeType} (${lifetime.inMinutes}m)');
      }
    }
    
    // Clean up tracking
    _mountTimes.remove(nodeId);
    _longLivedComponents.remove(nodeId);
  }
  
  void _checkForLongLivedComponent(DCFComponentNode node) {
    final nodeId = node.instanceId;
    
    if (_mountTimes.containsKey(nodeId) && !_longLivedComponents.contains(nodeId)) {
      _longLivedComponents.add(nodeId);
      print('🔍 Long-lived component detected: ${node.runtimeType}');
      
      // Additional memory analysis for StatefulComponents
      if (node is StatefulComponent) {
        _analyzeComponentMemory(node);
      }
    }
  }
  
  void _analyzeComponentMemory(StatefulComponent component) {
    // Analyze hooks for potential memory leaks
    final hookCount = component._hooks?.length ?? 0;
    if (hookCount > 20) {
      print('⚠️ Component has many hooks (${hookCount}): potential memory issue');
    }
    
    // Check for timer leaks, subscription leaks, etc.
    // This is where you'd integrate with your specific leak detection logic
  }
}
```

### 4. Development Tools Integration

```dart
class DevToolsLifecycleInterceptor extends VDomLifecycleInterceptor {
  static final List<ComponentEvent> _eventHistory = [];
  static final Map<String, ComponentSnapshot> _componentSnapshots = {};
  
  @override
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
    _recordEvent(ComponentEvent(
      type: 'beforeMount',
      component: node.runtimeType.toString(),
      nodeId: node.instanceId,
      timestamp: DateTime.now(),
    ));
    
    _captureSnapshot(node, 'beforeMount');
  }

  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    _recordEvent(ComponentEvent(
      type: 'afterMount',
      component: node.runtimeType.toString(),
      nodeId: node.instanceId,
      timestamp: DateTime.now(),
    ));
    
    _captureSnapshot(node, 'afterMount');
  }

  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    _recordEvent(ComponentEvent(
      type: 'beforeUpdate',
      component: node.runtimeType.toString(),
      nodeId: node.instanceId,
      timestamp: DateTime.now(),
    ));
    
    _captureSnapshot(node, 'beforeUpdate');
  }

  @override
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    _recordEvent(ComponentEvent(
      type: 'afterUpdate',
      component: node.runtimeType.toString(),
      nodeId: node.instanceId,
      timestamp: DateTime.now(),
    ));
    
    _captureSnapshot(node, 'afterUpdate');
  }

  void _recordEvent(ComponentEvent event) {
    _eventHistory.add(event);
    
    // Keep only recent events to prevent memory issues
    if (_eventHistory.length > 1000) {
      _eventHistory.removeAt(0);
    }
    
    // Send to dev tools
    DevToolsBridge.sendEvent(event);
  }
  
  void _captureSnapshot(DCFComponentNode node, String phase) {
    final snapshot = ComponentSnapshot(
      nodeId: node.instanceId,
      componentType: node.runtimeType.toString(),
      phase: phase,
      timestamp: DateTime.now(),
      props: _extractProps(node),
      state: _extractState(node),
    );
    
    _componentSnapshots['${node.instanceId}_$phase'] = snapshot;
    
    // Send to dev tools
    DevToolsBridge.sendSnapshot(snapshot);
  }
  
  Map<String, dynamic> _extractProps(DCFComponentNode node) {
    if (node is DCFElement) {
      return Map.from(node.props);
    }
    return {};
  }
  
  Map<String, dynamic> _extractState(DCFComponentNode node) {
    if (node is StatefulComponent) {
      // Extract state from hooks
      return _extractHookState(node);
    }
    return {};
  }
  
  Map<String, dynamic> _extractHookState(StatefulComponent component) {
    final state = <String, dynamic>{};
    
    // This would require access to component internals
    // Implementation depends on your specific needs
    
    return state;
  }
}

class ComponentEvent {
  final String type;
  final String component;
  final String nodeId;
  final DateTime timestamp;
  
  ComponentEvent({
    required this.type,
    required this.component,
    required this.nodeId,
    required this.timestamp,
  });
}

class ComponentSnapshot {
  final String nodeId;
  final String componentType;
  final String phase;
  final DateTime timestamp;
  final Map<String, dynamic> props;
  final Map<String, dynamic> state;
  
  ComponentSnapshot({
    required this.nodeId,
    required this.componentType,
    required this.phase,
    required this.timestamp,
    required this.props,
    required this.state,
  });
}
```

### 5. Resource Manager

```dart
class ResourceManagerInterceptor extends VDomLifecycleInterceptor {
  static final Map<String, List<Resource>> _componentResources = {};
  
  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is ResourceAwareComponent) {
      // Track resources allocated by this component
      final resources = node.getAllocatedResources();
      _componentResources[node.instanceId] = resources;
      
      // Set up automatic cleanup if component stays mounted too long
      Timer(Duration(minutes: 30), () {
        _warnAboutLongRunningResources(node);
      });
    }
  }

  @override
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is ResourceAwareComponent) {
      final nodeId = node.instanceId;
      final resources = _componentResources[nodeId];
      
      if (resources != null) {
        // Clean up resources before component unmounts
        for (final resource in resources) {
          resource.dispose();
        }
        
        print('🧹 Cleaned up ${resources.length} resources for ${node.runtimeType}');
        _componentResources.remove(nodeId);
      }
    }
  }
  
  void _warnAboutLongRunningResources(DCFComponentNode node) {
    final nodeId = node.instanceId;
    final resources = _componentResources[nodeId];
    
    if (resources != null && resources.isNotEmpty) {
      print('⚠️ Component ${node.runtimeType} has held ${resources.length} resources for 30+ minutes');
      
      // Optionally force cleanup of specific resource types
      final expensiveResources = resources.where((r) => r.isExpensive).toList();
      if (expensiveResources.isNotEmpty) {
        print('🔥 Force cleaning ${expensiveResources.length} expensive resources');
        for (final resource in expensiveResources) {
          resource.dispose();
        }
      }
    }
  }
}
```

## Advanced Patterns

### 1. Conditional Interception

```dart
class ConditionalLifecycleInterceptor extends VDomLifecycleInterceptor {
  final bool Function(DCFComponentNode) shouldIntercept;
  
  ConditionalLifecycleInterceptor(this.shouldIntercept);
  
  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    if (shouldIntercept(node)) {
      // Only intercept specific instances
      performConditionalLogic(node, context);
    }
  }
  
  void performConditionalLogic(DCFComponentNode node, VDomLifecycleContext context) {
    // Your conditional logic here
  }
}

// Usage
VDomExtensionRegistry.instance.registerLifecycleInterceptor<MyComponent>(
  ConditionalLifecycleInterceptor((node) {
    return node is MyComponent && node.needsSpecialHandling;
  })
);
```

### 2. Interceptor Chaining

```dart
class ChainedLifecycleInterceptor extends VDomLifecycleInterceptor {
  final List<VDomLifecycleInterceptor> interceptors;
  
  ChainedLifecycleInterceptor(this.interceptors);
  
  @override
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
    for (final interceptor in interceptors) {
      interceptor.beforeMount(node, context);
    }
  }
  
  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    // Execute in reverse order for after hooks
    for (final interceptor in interceptors.reversed) {
      interceptor.afterMount(node, context);
    }
  }
  
  // Implement other methods similarly...
}
```

### 3. Context-Aware Interception

```dart
class ContextAwareLifecycleInterceptor extends VDomLifecycleInterceptor {
  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    // Use context information to make decisions
    final isUpdating = context.vdomState['isUpdating'] as bool? ?? false;
    final isMounting = context.vdomState['isMounting'] as bool? ?? false;
    
    if (isUpdating && !isMounting) {
      // This is a true update, not an initial mount
      handleTrueUpdate(node, context);
    }
  }
  
  void handleTrueUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    // Logic specific to true updates
  }
}
```

## Testing Lifecycle Interceptors

### 1. Unit Testing

```dart
void testLifecycleInterceptor() {
  group('MyLifecycleInterceptor', () {
    late MyLifecycleInterceptor interceptor;
    late MockVDomLifecycleContext context;
    
    setUp(() {
      interceptor = MyLifecycleInterceptor();
      context = MockVDomLifecycleContext();
    });
    
    test('should handle beforeMount correctly', () {
      final node = TestComponent();
      
      interceptor.beforeMount(node, context);
      
      // Verify expected behavior
      expect(interceptor.mountedComponents, contains(node.instanceId));
    });
    
    test('should clean up on unmount', () {
      final node = TestComponent();
      
      interceptor.afterMount(node, context);
      interceptor.beforeUnmount(node, context);
      
      expect(interceptor.mountedComponents, isEmpty);
    });
  });
}
```

### 2. Integration Testing

```dart
void testInterceptorIntegration() {
  group('Interceptor Integration', () {
    test('should work with VDOM lifecycle', () async {
      // Register interceptor
      final interceptor = TestLifecycleInterceptor();
      VDomExtensionRegistry.instance.registerLifecycleInterceptor<TestComponent>(
        interceptor
      );
      
      // Create VDOM and component
      final vdom = VDom(MockPlatformInterface());
      final component = TestComponent();
      
      // Mount component
      await vdom.createRoot(component);
      
      // Verify interceptor was called
      expect(interceptor.beforeMountCalled, isTrue);
      expect(interceptor.afterMountCalled, isTrue);
      
      // Update component
      component.scheduleUpdate();
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify update interception
      expect(interceptor.beforeUpdateCalled, isTrue);
      expect(interceptor.afterUpdateCalled, isTrue);
    });
  });
}
```

## Performance Considerations

### 1. Minimize Work in Interceptors

```dart
class EfficientLifecycleInterceptor extends VDomLifecycleInterceptor {
  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    // Do minimal work in lifecycle methods
    // Defer expensive operations
    
    if (shouldPerformExpensiveOperation(node)) {
      // Schedule expensive work for later
      Future.microtask(() => performExpensiveOperation(node));
    }
  }
  
  bool shouldPerformExpensiveOperation(DCFComponentNode node) {
    // Quick check
    return node is ExpensiveComponent && node.needsProcessing;
  }
}
```

### 2. Use Weak References for Long-term Storage

```dart
class WeakReferenceInterceptor extends VDomLifecycleInterceptor {
  final _weakReferences = <String, WeakReference<DCFComponentNode>>{};
  
  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    // Store weak reference to avoid memory leaks
    _weakReferences[node.instanceId] = WeakReference(node);
  }
  
  @override
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    _weakReferences.remove(node.instanceId);
  }
  
  void cleanupStaleReferences() {
    _weakReferences.removeWhere((key, weakRef) => weakRef.target == null);
  }
}
```

## Best Practices

### 1. Error Handling

```dart
class SafeLifecycleInterceptor extends VDomLifecycleInterceptor {
  @override
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
    try {
      performInterception(node, context);
    } catch (e, stackTrace) {
      // Log error but don't break VDOM operations
      print('Lifecycle interceptor error: $e');
      print('Stack trace: $stackTrace');
      
      // Optionally report to error tracking service
      ErrorReporter.report(e, stackTrace);
    }
  }
}
```

### 2. Cleanup Resources

```dart
class ResourceCleanupInterceptor extends VDomLifecycleInterceptor {
  final Map<String, Timer> _timers = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  
  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    // Set up resources
    final timer = Timer.periodic(Duration(seconds: 1), (_) {
      // Periodic work
    });
    _timers[node.instanceId] = timer;
  }
  
  @override
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    // Always clean up resources
    final timer = _timers.remove(node.instanceId);
    timer?.cancel();
    
    final subscription = _subscriptions.remove(node.instanceId);
    subscription?.cancel();
  }
}
```

### 3. Component Type Specificity

```dart
// Register for specific types only
VDomExtensionRegistry.instance.registerLifecycleInterceptor<AnimatedComponent>(
  AnimationLifecycleInterceptor()
);

VDomExtensionRegistry.instance.registerLifecycleInterceptor<DataComponent>(
  DataLifecycleInterceptor()
);

// Avoid registering for base types unless you really need global interception
// VDomExtensionRegistry.instance.registerLifecycleInterceptor<DCFComponentNode>(
//   GlobalInterceptor() // Use sparingly
// );
```

## Integration with Other Extensions

Lifecycle interceptors work seamlessly with other extension types:

```dart
class CoordinatedLifecycleInterceptor extends VDomLifecycleInterceptor {
  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    // Check if custom reconciliation is handling this update
    final customHandler = VDomExtensionRegistry.instance
        .getReconciliationHandler(node.runtimeType);
    
    if (customHandler != null) {
      // Coordinate with custom reconciliation
      prepareForCustomReconciliation(node);
    }
  }
}
```

Lifecycle interceptors provide powerful hooks into the VDOM lifecycle while maintaining clean separation of concerns. They're perfect for cross-cutting functionality that needs to coordinate with component lifecycle events.
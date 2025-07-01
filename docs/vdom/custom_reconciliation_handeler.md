# Custom Reconciliation Handlers

Custom reconciliation handlers allow you to completely override how specific component types are reconciled during VDOM updates. This is the most powerful extension point, enabling component-specific optimizations and specialized update behaviors.

## When to Use Custom Reconciliation

Custom reconciliation is ideal for:

- **Performance-critical components** that need specialized diffing algorithms
- **Complex components** like virtualized lists, data grids, or canvas-based components
- **Portal components** that render content outside normal tree hierarchy
- **Atomic components** that should always replace rather than update
- **Components with expensive children** where you want to skip unnecessary reconciliation

## Basic Implementation

### 1. Create Your Handler

```dart
import 'package:dcflight/framework/renderer/vdom/mutator/vdom_mutator_extension_reg.dart';

class MyReconciliationHandler extends VDomReconciliationHandler {
  @override
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
    // Only handle your specific component type
    return newNode is MySpecialComponent;
  }

  @override
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  ) async {
    // Your custom reconciliation logic here
    
    // Example: Always replace for atomic components
    if (shouldReplaceCompletely(oldNode, newNode)) {
      await context.replaceNode(oldNode, newNode);
      return;
    }
    
    // Example: Custom property-based reconciliation
    if (onlyPropsChanged(oldNode, newNode)) {
      await reconcilePropsOnly(oldNode, newNode, context);
      return;
    }
    
    // Fall back to default reconciliation when needed
    await context.defaultReconcile(oldNode, newNode);
  }
}
```

### 2. Register Your Handler

```dart
void initializeMyModule() {
  VDomExtensionRegistry.instance.registerReconciliationHandler<MySpecialComponent>(
    MyReconciliationHandler()
  );
}
```

## VDomReconciliationContext API

The context object provides controlled access to VDOM operations:

```dart
class VDomReconciliationContext {
  /// Fall back to default VDOM reconciliation
  final Function(DCFComponentNode, DCFComponentNode) defaultReconcile;
  
  /// Force complete node replacement
  final Function(DCFComponentNode, DCFComponentNode) replaceNode;
  
  /// Mount a new node
  final Function(DCFComponentNode) mountNode;
  
  /// Unmount an existing node
  final Function(DCFComponentNode) unmountNode;
}
```

## Real-World Examples

### 1. Virtualized List Reconciliation

```dart
class VirtualizedListReconciliationHandler extends VDomReconciliationHandler {
  @override
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
    return newNode is VirtualizedListView;
  }

  @override
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  ) async {
    final oldList = oldNode as VirtualizedListView;
    final newList = newNode as VirtualizedListView;
    
    // Only reconcile visible items
    final visibleRange = newList.getVisibleRange();
    final oldVisibleRange = oldList.getVisibleRange();
    
    // Skip reconciliation if scroll position hasn't changed
    if (visibleRange == oldVisibleRange && 
        newList.itemCount == oldList.itemCount) {
      // Only update props, skip children
      await updatePropsOnly(oldNode, newNode);
      return;
    }
    
    // Custom reconciliation for visible items only
    await reconcileVisibleItems(
      oldList, 
      newList, 
      visibleRange, 
      context
    );
  }
  
  Future<void> reconcileVisibleItems(
    VirtualizedListView oldList,
    VirtualizedListView newList,
    VisibleRange range,
    VDomReconciliationContext context,
  ) async {
    // Only reconcile items that are actually visible
    for (int i = range.start; i <= range.end; i++) {
      final oldItem = oldList.getItemAt(i);
      final newItem = newList.getItemAt(i);
      
      if (oldItem != null && newItem != null) {
        await context.defaultReconcile(oldItem, newItem);
      } else if (newItem != null) {
        context.mountNode(newItem);
      } else if (oldItem != null) {
        context.unmountNode(oldItem);
      }
    }
  }
}
```

### 2. Portal Component Reconciliation

```dart
class PortalReconciliationHandler extends VDomReconciliationHandler {
  @override
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
    return newNode is DCFPortal;
  }

  @override
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  ) async {
    final oldPortal = oldNode as DCFPortal;
    final newPortal = newNode as DCFPortal;
    
    // If target changed, replace the entire portal
    if (oldPortal.targetId != newPortal.targetId) {
      await context.replaceNode(oldNode, newNode);
      return;
    }
    
    // Only reconcile portal content, not the portal container
    // Portal content lives in a different part of the tree
    await reconcilePortalContent(oldPortal, newPortal, context);
    
    // Update portal metadata without touching children
    await updatePortalMetadata(oldPortal, newPortal);
  }
  
  Future<void> reconcilePortalContent(
    DCFPortal oldPortal,
    DCFPortal newPortal,
    VDomReconciliationContext context,
  ) async {
    // Portal content reconciliation happens in the target location,
    // not in the normal component tree
    final portalManager = EnhancedPortalManager.instance;
    
    await portalManager.updatePortal(
      portalId: oldPortal.portalId,
      children: newPortal.children,
      metadata: newPortal.metadata,
    );
  }
}
```

### 3. Canvas Component Reconciliation

```dart
class CanvasReconciliationHandler extends VDomReconciliationHandler {
  @override
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
    return newNode is CanvasComponent;
  }

  @override
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  ) async {
    final oldCanvas = oldNode as CanvasComponent;
    final newCanvas = newNode as CanvasComponent;
    
    // Canvas components are expensive to recreate
    // Only update if drawing commands actually changed
    if (!drawingCommandsChanged(oldCanvas, newCanvas)) {
      // Skip all reconciliation - nothing to update
      return;
    }
    
    // For canvas, we never reconcile children (they're rendered to canvas)
    // Just update the canvas rendering
    await updateCanvasRendering(oldCanvas, newCanvas);
  }
  
  bool drawingCommandsChanged(CanvasComponent old, CanvasComponent new_) {
    return old.drawingCommands.hashCode != new_.drawingCommands.hashCode;
  }
  
  Future<void> updateCanvasRendering(CanvasComponent old, CanvasComponent new_) async {
    // Update the native canvas with new drawing commands
    await old.updateNativeCanvas(new_.drawingCommands);
  }
}
```

### 4. Atomic Component Reconciliation

```dart
class AtomicComponentReconciliationHandler extends VDomReconciliationHandler {
  @override
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
    return newNode is AtomicComponent;
  }

  @override
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  ) async {
    final oldAtomic = oldNode as AtomicComponent;
    final newAtomic = newNode as AtomicComponent;
    
    // Atomic components always replace completely if any prop changed
    if (oldAtomic.props != newAtomic.props) {
      await context.replaceNode(oldNode, newNode);
      return;
    }
    
    // If props are identical, no update needed
    // This prevents unnecessary re-renders for expensive atomic components
  }
}
```

## Performance Optimization Patterns

### 1. Skip Expensive Reconciliation

```dart
@override
Future<void> reconcile(oldNode, newNode, context) async {
  // Quick equality check
  if (areEqual(oldNode, newNode)) {
    return; // Skip all reconciliation
  }
  
  // Shallow comparison
  if (onlyShallowPropsChanged(oldNode, newNode)) {
    await updateShallowProps(oldNode, newNode);
    return;
  }
  
  // Deep reconciliation only when necessary
  await context.defaultReconcile(oldNode, newNode);
}
```

### 2. Batch Child Updates

```dart
@override
Future<void> reconcile(oldNode, newNode, context) async {
  final component = newNode as MyBatchedComponent;
  
  if (component.shouldBatchChildUpdates) {
    // Custom batching for child updates
    await batchUpdateChildren(oldNode, newNode, context);
  } else {
    await context.defaultReconcile(oldNode, newNode);
  }
}

Future<void> batchUpdateChildren(
  DCFComponentNode oldNode,
  DCFComponentNode newNode, 
  VDomReconciliationContext context
) async {
  // Collect all child updates first
  final updates = collectChildUpdates(oldNode, newNode);
  
  // Apply updates in optimized order
  for (final update in optimizeUpdateOrder(updates)) {
    await applyUpdate(update, context);
  }
}
```

## Best Practices

### 1. Type Safety
```dart
@override
bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
  // Be specific about types
  return newNode is MyExactComponentType && 
         oldNode is MyExactComponentType;
}
```

### 2. Error Handling
```dart
@override
Future<void> reconcile(oldNode, newNode, context) async {
  try {
    await myCustomReconciliation(oldNode, newNode, context);
  } catch (e) {
    // Fall back to default reconciliation on error
    print('Custom reconciliation failed: $e');
    await context.defaultReconcile(oldNode, newNode);
  }
}
```

### 3. Debugging Support
```dart
@override
Future<void> reconcile(oldNode, newNode, context) async {
  if (kDebugMode) {
    print('Custom reconciling ${newNode.runtimeType}');
  }
  
  // Your reconciliation logic
  
  if (kDebugMode) {
    print('Custom reconciliation complete');
  }
}
```

### 4. Testing
```dart
// Test your reconciliation handler
void testMyReconciliationHandler() {
  final handler = MyReconciliationHandler();
  final oldNode = MyComponent(key: 'test');
  final newNode = MyComponent(key: 'test', data: 'updated');
  
  // Mock context
  final context = MockVDomReconciliationContext();
  
  // Test reconciliation
  await handler.reconcile(oldNode, newNode, context);
  
  // Verify expected behavior
  expect(context.updatesCalled, 1);
}
```

## Common Pitfalls

1. **Forgetting to transfer node relationships**: Always ensure parent/child relationships are maintained
2. **Not handling all code paths**: Make sure all reconciliation paths are covered
3. **Infinite recursion**: Be careful when calling `context.defaultReconcile` to avoid loops
4. **Memory leaks**: Always clean up resources in unmounted nodes
5. **Type assumptions**: Always validate node types in `shouldHandle`

## Integration with Other Extensions

Custom reconciliation handlers work well with other extensions:

```dart
// Coordinate with lifecycle interceptors
class MyReconciliationHandler extends VDomReconciliationHandler {
  @override
  Future<void> reconcile(oldNode, newNode, context) async {
    // Lifecycle interceptors will be called automatically
    // before and after your reconciliation logic
    
    await myCustomLogic(oldNode, newNode, context);
  }
}
```

Custom reconciliation handlers provide the ultimate flexibility for optimizing component updates. Use them when you need fine-grained control over how your components reconcile with the VDOM system.
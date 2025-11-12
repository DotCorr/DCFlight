# Rendering Flow

## Overview

This document describes the complete rendering flow from component creation to native view rendering, similar to how Flutter documents its rendering pipeline.

## High-Level Flow

```
User Code (Component)
    ↓
Component.render() → DCFComponentNode
    ↓
VDOM Tree Construction
    ↓
Reconciliation (if update)
    ↓
Native Bridge Operations
    ↓
Native View Creation/Update
    ↓
Layout Calculation (Yoga)
    ↓
Native View Display
```

## Detailed Flow

### Phase 1: Component Rendering

**Entry Point:** `DCFEngine.render()`

1. **Component Invocation**
   ```dart
   final rootComponent = MyApp();
   await engine.render(rootComponent);
   ```

2. **Component.render()**
   - Component's `render()` method is called
   - Returns a `DCFComponentNode` (usually `DCFElement`)
   - This becomes the `renderedNode`

3. **Node Registration**
   - Component is registered in `_statefulComponents` (if stateful)
   - Component instance is tracked by position/props

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1024-1116)

### Phase 2: VDOM Tree Construction

**Method:** `DCFEngine.renderToNative()`

1. **Node Type Detection**
   - Check if node is `DCFStatefulComponent` or `DCFStatelessComponent`
   - Check if node is `DCFElement`
   - Check if node is `DCFragment` or `EmptyVDomNode`

2. **Component Rendering**
   - Call component's `render()` method
   - Get `renderedNode`
   - Recursively render `renderedNode`

3. **Element Rendering**
   - Generate unique `viewId`
   - Map `viewId` to node in `_nodesByViewId`
   - Create native view via bridge

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1000-1150)

### Phase 3: Native View Creation

**Method:** `DCFEngine._renderElementToNative()`

1. **View ID Generation**
   ```dart
   final viewId = _generateViewId(); // Incremental counter
   _nodesByViewId[viewId] = element;
   element.nativeViewId = viewId;
   ```

2. **Native Bridge Call**
   ```dart
   await _nativeBridge.createView(viewId, element.type, elementProps);
   ```
   - Creates native view (UIView on iOS, View on Android)
   - Stores props in native layer

3. **View Attachment**
   ```dart
   if (parentViewId != null) {
     await _nativeBridge.attachView(viewId, parentViewId, index);
   }
   ```

4. **Event Listeners**
   ```dart
   if (eventTypes.isNotEmpty) {
     await _nativeBridge.addEventListeners(viewId, eventTypes);
   }
   ```

5. **Children Rendering**
   ```dart
   for (var child in element.children) {
     final childId = await renderToNative(child, parentViewId: viewId);
     childIds.add(childId);
   }
   await _nativeBridge.setChildren(viewId, childIds);
   ```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1204-1288)

### Phase 4: Reconciliation (Updates)

**Method:** `DCFEngine._reconcile()`

When state changes, the engine reconciles the old and new VDOM trees:

1. **Node Matching**
   - Match by explicit `key` if both nodes have keys
   - Match by position + type (automatic key inference)
   - Match by position + type + props hash

2. **Update Decision**
   - **Same Node:** Reconcile props and children
   - **Different Node:** Replace (unmount old, mount new)

3. **Props Diffing**
   ```dart
   final changedProps = _computeChangedProps(oldProps, newProps);
   ```
   - Compares old and new props
   - Returns only changed props
   - Handles function props (onPress, etc.)

4. **Native Update**
   ```dart
   if (changedProps.isNotEmpty) {
     await _nativeBridge.updateView(viewId, changedProps);
   }
   ```

5. **Children Reconciliation**
   - Recursively reconcile each child
   - Handle additions, removals, reordering

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1291-1600)

### Phase 5: Layout Calculation

**Native Layer:** After views are created/updated

1. **Yoga Layout Engine**
   - Calculates layout based on style props
   - Handles flexbox layout
   - Computes positions and sizes
   - **For Android Compose:** Measures `ComposeView` with constraints using `View.MeasureSpec.AT_MOST` for proper text wrapping

2. **Layout Application**
   - Applies calculated layout to native views
   - Triggers native view updates
   - **For Android Compose:** Compose content wraps correctly when Yoga provides width constraints

**Location:** 
- iOS: `packages/dcflight/ios/Classes/Layout/YogaShadowTree.swift`
- Android: `packages/dcflight/android/src/main/kotlin/com/dotcorr/dcflight/layout/YogaShadowTree.kt`

**Note:** Android Compose components (like `DCFTextComponent`) use `ComposeView`, which extends `View`. Yoga measures it generically with constraints, allowing Compose Text to wrap correctly. See [Android Compose Integration](../../ANDROID_COMPOSE_INTEGRATION.md) for details.

## Update Flow (State Change)

### Trigger
```dart
// Component state changes
setState(() {
  counter++;
});
```

### Flow
1. **State Update**
   - Component's state is updated
   - Component is marked for update

2. **Update Scheduling**
   ```dart
   _scheduleComponentUpdate(component);
   ```
   - Component added to `_pendingUpdates`
   - Update scheduled with priority

3. **Re-render**
   - Component's `render()` is called again
   - New VDOM tree is created

4. **Reconciliation**
   - Old and new trees are compared
   - Only changed nodes are updated

5. **Native Update**
   - Changed props sent to native layer
   - Native views updated

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1600-1800)

## Batch Updates

The engine batches updates for performance:

1. **Update Collection**
   - Multiple state changes collected
   - Updates grouped by priority

2. **Batch Execution**
   - All updates processed together
   - Single reconciliation pass

3. **Native Commit**
   - All native updates committed atomically
   - Prevents flickering

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1800-2000)

## Priority System

Updates are prioritized:

1. **High Priority**
   - User interactions (button presses)
   - Animations

2. **Normal Priority**
   - Regular state updates
   - Data fetching

3. **Low Priority**
   - Background updates
   - Non-critical renders

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/concurrency/priority.dart`

## Performance Optimizations

### 1. Props Diffing
- Only changed props sent to native
- Reduces bridge communication

### 2. Component Instance Reuse
- Components at same position reused
- State preserved across renders

### 3. Memoization
- Similarity calculations cached
- Reduces reconciliation overhead

### 4. Batch Updates
- Multiple updates batched together
- Single reconciliation pass

## Error Handling

### Error Boundaries
- Components can implement error boundaries
- Errors caught and handled gracefully

### Fallback Rendering
- Failed renders fall back to error UI
- App continues running

**Location:** `packages/dcflight/lib/framework/components/error_boundary.dart`

## Debugging

### Debug Logging
- Comprehensive logging at each phase
- View ID tracking
- Props diffing logs

### Performance Metrics
- Render time tracking
- Update frequency monitoring
- Memory usage tracking

**Location:** `packages/dcflight/lib/framework/renderer/engine/debug/engine_logger.dart`


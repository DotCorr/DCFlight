# Reconciliation

## Overview

Reconciliation is the process of comparing the old and new VDOM trees and efficiently updating only what changed. This is similar to React's reconciliation algorithm, but optimized for native mobile rendering.

## Reconciliation Flow

```
State Change
    ↓
New VDOM Tree Created
    ↓
Compare with Old Tree
    ↓
Match Nodes (by key/position)
    ↓
Update/Replace Nodes
    ↓
Update Native Views
```

## Node Matching

### 1. Key-Based Matching

If both old and new nodes have explicit keys:

```dart
if (oldNode.key != null && newNode.key != null) {
  if (oldNode.key == newNode.key) {
    // Same node - reconcile
  } else {
    // Different nodes - replace
  }
}
```

**Priority:** Highest (most reliable)

### 2. Position-Based Matching (Smart Algorithm)

If no keys, uses a two-pointer greedy matching algorithm with look-ahead:

```dart
// Two independent indices traverse both lists
int oldIndex = 0;
int newIndex = 0;

// Look ahead to detect insertions/removals
// Matches children when types are compatible
// Replaces when types don't match
```

**Algorithm Features:**
- Detects insertions by looking ahead in `newChildren` to find matching `oldChild`
- Detects removals by looking ahead in `oldChildren` to find matching `newChild`
- Handles multiple consecutive insertions/removals correctly
- Maintains correct order of children

**Priority:** Medium (works for most cases, but keys are recommended for dynamic lists)

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 3091-3400)

### 3. Props-Based Matching

Match by position, type, and props hash:

```dart
final propsHash = _computePropsHash(node);
final propsKey = "$positionKey:$propsHash";
final existing = _componentInstancesByProps[propsKey];
```

**Priority:** Low (fallback for edge cases)

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1319-1343)

## Reconciliation Strategies

### Strategy 1: Same Node (Reconcile)

When nodes match (same key/position/type):

1. **Props Diffing**
   ```dart
   final changedProps = _computeChangedProps(oldProps, newProps);
   ```

2. **Update Native View**
   ```dart
   if (changedProps.isNotEmpty) {
     await _nativeBridge.updateView(viewId, changedProps);
   }
   ```

3. **Reconcile Children**
   ```dart
   await _reconcileChildren(oldNode.children, newNode.children);
   ```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1400-1500)

### Strategy 2: Different Node (Replace)

When nodes don't match:

1. **Unmount Old Node**
   ```dart
   oldNode.unmount();
   await _nativeBridge.deleteView(oldNode.nativeViewId);
   ```

2. **Mount New Node**
   ```dart
   newNode.mount(parent);
   await renderToNative(newNode, parentViewId: parentViewId);
   ```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1500-1600)

## Props Diffing

### Algorithm

1. **Added Props**
   ```dart
   for (final key in newProps.keys) {
     if (!oldProps.containsKey(key)) {
       changedProps[key] = newProps[key];
     }
   }
   ```

2. **Changed Props**
   ```dart
   for (final key in newProps.keys) {
     if (oldProps.containsKey(key)) {
       final oldValue = oldProps[key];
       final newValue = newProps[key];
       if (oldValue != newValue) {
         changedProps[key] = newValue;
       }
     }
   }
   ```

3. **Removed Props**
   ```dart
   for (final key in oldProps.keys) {
     if (!newProps.containsKey(key)) {
       // Handle removal (if needed)
     }
   }
   ```

4. **Function Props**
   ```dart
   // Always include function props (onPress, etc.)
   for (final key in oldProps.keys) {
     if (key.startsWith('on') && oldProps[key] is Function) {
       if (!newProps.containsKey(key)) {
         changedProps[key] = oldProps[key];
       }
     }
   }
   ```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 2718-2800)

## Children Reconciliation

### Algorithm

1. **Match Children**
   - Match by key (if present)
   - Match by position and type (if no keys)

2. **Process Matches**
   ```dart
   for (var i = 0; i < max(oldChildren.length, newChildren.length); i++) {
     final oldChild = i < oldChildren.length ? oldChildren[i] : null;
     final newChild = i < newChildren.length ? newChildren[i] : null;
     
     if (oldChild != null && newChild != null) {
       // Reconcile
       await _reconcile(oldChild, newChild);
     } else if (oldChild != null) {
       // Remove
       await _removeNode(oldChild);
     } else if (newChild != null) {
       // Add
       await _addNode(newChild, parentViewId, i);
     }
   }
   ```

3. **Handle Reordering**
   - Detect moved children
   - Reorder in native view tree

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1500-1600)

## Element Reconciliation

### Same Element Type

When element type matches:

1. **Props Update**
   - Diff props
   - Update native view

2. **Children Reconciliation**
   - Reconcile children recursively

3. **Force Replace on Major Changes**
   ```dart
   // If children count differs significantly, force replacement
   final countDiff = (oldChildCount - newChildCount).abs();
   if (countDiff > 3 || countDiff >= (oldChildCount * 0.5).ceil()) {
     await _replaceNode(oldNode, newNode);
   }
   ```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1358-1400)

### Different Element Type

When element type changes:

1. **Full Replacement**
   - Unmount old element
   - Mount new element
   - No reconciliation attempt

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1358-1366)

## Component Reconciliation

### Stateful Components

1. **Instance Matching**
   - Match by position + type
   - Reuse same instance if matched

2. **State Preservation**
   - Component state preserved
   - Only props updated

3. **Re-render**
   - Component's `render()` called
   - New renderedNode created
   - Reconcile renderedNode

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1327-1339)

### Stateless Components

1. **No State to Preserve**
   - Always re-render
   - Reconcile renderedNode

## Performance Optimizations

### 1. Memoization

Similarity calculations cached:

```dart
final cacheKey = "${oldNodeHash}:${newNodeHash}";
if (_similarityCache.containsKey(cacheKey)) {
  return _similarityCache[cacheKey];
}
```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 52-55)

### 2. Early Exit

Skip reconciliation if nodes are identical:

```dart
if (oldNode == newNode) {
  return; // No changes
}
```

### 3. Batch Updates

Multiple reconciliations batched:

```dart
await _batchReconcile(updates);
```

### 4. Props Diffing

Only changed props sent to native:

```dart
if (changedProps.isNotEmpty) {
  await _nativeBridge.updateView(viewId, changedProps);
}
```

## Edge Cases

### 1. Conditional Rendering

When component conditionally returns different structures:

```dart
// Old tree
DCFView(children: [DCFText('A'), DCFText('B')])

// New tree
DCFView(children: [DCFButton('Click')])
```

**Handling:** Force replacement if children structure differs significantly.

### 2. Key Changes

When key changes but component is same:

```dart
// Old
DCFElement(key: '1', type: 'Text', ...)

// New
DCFElement(key: '2', type: 'Text', ...)
```

**Handling:** Treated as different nodes, old unmounted, new mounted.

### 3. Fragment Reconciliation

Fragments don't create views, so reconciliation is simpler:

```dart
// Just reconcile children
await _reconcileChildren(oldFragment.children, newFragment.children);
```

### 4. Empty Node Handling

Empty nodes don't create views:

```dart
if (newNode is EmptyVDomNode) {
  // Unmount old node if exists
  if (oldNode != null) {
    await _removeNode(oldNode);
  }
  return;
}
```

## Debugging

### Reconciliation Logs

Comprehensive logging at each step:

```dart
EngineDebugLogger.logReconcile('START', oldNode, newNode);
EngineDebugLogger.logReconcile('MATCH', oldNode, newNode, reason: 'Same key');
EngineDebugLogger.logReconcile('REPLACE', oldNode, newNode, reason: 'Different type');
```

### Props Diffing Logs

```dart
EngineDebugLogger.log('PROP_DIFF_COMPLETE', 'Props diffing completed',
    extra: {
      'Added': addedCount,
      'Changed': changedCount,
      'Removed': removedCount,
    });
```

**Location:** `packages/dcflight/lib/framework/renderer/engine/debug/engine_logger.dart`

## Best Practices

### 1. Use Keys for Lists

```dart
// ✅ Good
items.map((item) => DCFElement(
  key: item.id,
  type: 'Text',
  elementProps: {'content': item.name},
))

// ❌ Bad (no keys)
items.map((item) => DCFElement(
  type: 'Text',
  elementProps: {'content': item.name},
))
```

### 2. Stable Keys

```dart
// ✅ Good - stable ID
DCFElement(key: user.id, ...)

// ❌ Bad - unstable (changes every render)
DCFElement(key: DateTime.now().toString(), ...)
```

### 3. Avoid Unnecessary Re-renders

```dart
// ✅ Good - memoize expensive computations
final expensiveValue = useMemo(() => computeExpensive(), [deps]);

// ❌ Bad - recompute every render
final expensiveValue = computeExpensive();
```

### 4. Keep Component Trees Shallow

```dart
// ✅ Good - shallow tree
DCFView(children: [child1, child2, child3])

// ❌ Bad - deep nesting
DCFView(children: [
  DCFView(children: [
    DCFView(children: [child])
  ])
])
```


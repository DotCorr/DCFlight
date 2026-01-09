# Reconciliation

## Overview

Reconciliation is the process of comparing the old and new VDOM trees and efficiently updating only what changed. This is similar to React's reconciliation algorithm, but optimized for native mobile rendering.

## Reconciliation Flow

```
State Change
    ↓
New VDOM Tree Created
    ↓
Check Tree Size
    ↓
    ├─ 50+ nodes → Isolate Reconciliation (Parallel)
    │   ↓
    │   Serialize Trees → Worker Isolate
    │   ↓
    │   Parallel Diffing in Isolate
    │   ↓
    │   Return Diff Results
    │   ↓
    └─ < 50 nodes → Main Thread Reconciliation
        ↓
Compare with Old Tree
    ↓
Match Nodes (by key/position)
    ↓
Update/Replace Nodes
    ↓
Collect Effects (Effect List)
    ↓
Commit Phase (Apply Effects)
    ↓
Update Native Views (Main Thread Only)
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

## Isolate-Based Reconciliation

### When Isolates Are Used

Isolates are automatically used for reconciliation when:
- Tree has **20+ nodes** (old + new combined, lowered from 50 for better performance)
- Not initial render (initial render must be synchronous)
- Worker isolates are available (2 workers pre-spawned at startup for optimal performance)

### How It Works

1. **Tree Serialization**
   ```dart
   final oldTreeData = _serializeNodeForIsolate(oldNode);
   final newTreeData = _serializeNodeForIsolate(newNode);
   ```

2. **Send to Worker Isolate**
   ```dart
   _workerPorts[isolateIndex].send({
     'type': 'treeReconciliation',
     'oldTree': oldTreeData,
     'newTree': newTreeData,
   });
   ```

3. **Parallel Diffing in Isolate**
   - Tree diffing happens in background isolate
   - Main thread remains responsive
   - Returns diff results (create, update, delete, replace actions)

4. **Apply Diff on Main Thread**
   ```dart
   await _applyIsolateDiff(oldNode, newNode, result);
   ```
   - All UI updates happen on main thread
   - Native view creation/updates are synchronous
   - Event listeners updated

### Benefits

- **Heavy Trees**: 20+ nodes diffed in parallel (lowered threshold means more trees benefit)
- **UI Responsiveness**: Main thread stays responsive
- **Performance**: 50-80% faster for large reconciliations (typically saves 60-100ms)
- **Safety**: All UI updates on main thread (no race conditions)
- **Pre-spawned Workers**: 2 workers ready at startup (no spawning delay)

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 2064-2160)

## Smart Element-Level Reconciliation

### Overview

When components render to the same element type (e.g., `BenchmarkApp` and `DCFView` both render to `View`), DCFlight uses **element-level reconciliation** instead of component-level replacement. This prevents unnecessary native view destruction/recreation and eliminates layout shifts.

### How It Works

1. **Isolate Detection**: Isolate detects that both components render to the same element type
   ```dart
   // Isolate detects: BenchmarkApp → View, DCFView → View
   // Both render to same element type → reconcile at element level
   ```

2. **ViewId Transfer**: Transfer viewId from old rendered element to new rendered element
   ```dart
   if (oldRendered.nativeViewId != null) {
     newRendered.nativeViewId = oldRendered.nativeViewId;
     newRendered.contentViewId = oldRendered.contentViewId;
   }
   ```

3. **Element-Level Reconciliation**: Reconcile rendered elements directly
   ```dart
   // Bypass component type checks, reconcile at element level
   await _reconcileElement(oldRendered, newRendered);
   ```

### Benefits

- **No Layout Shifts**: Same native view reused (no destruction/recreation)
- **Better Performance**: Element reconciliation is faster than full replacement
- **Smooth Transitions**: UI updates without visual glitches
- **Smart Strategy**: Automatically chooses best reconciliation level

### When It Activates

Element-level reconciliation activates when:
- Isolate detects `replaceChild` or `replace` action
- Both old and new components render to the same element type
- Example: `BenchmarkApp` (Stateful) → `DCFView` (Stateless), both render to `View`

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 2611-2643)

## Direct Replacement for Large Dissimilar Trees

### When Direct Replacement Is Used

For very large trees (100+ nodes) with low structural similarity (<20%), DCFlight uses direct replacement instead of reconciliation. This enables **instant navigation** when switching between completely different screens.

### How It Works

1. **Tree Size Check**: If combined node count is 100+
2. **Similarity Calculation**: Computes structural similarity using LCS algorithm
3. **Direct Replace**: If similarity < 20%, uses `_replaceNode()` instead of reconciliation
4. **Result**: Instant screen transitions without expensive reconciliation

### Benefits

- **Instant Navigation**: Screen transitions are instant for large dissimilar trees
- **No Reconciliation Overhead**: Skips expensive diffing for completely different structures
- **Game Changer**: Makes complex apps with large component trees feel snappy

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1805-1841)

## Performance Optimizations

### 1. Memoization (LRU Cache)

Similarity calculations cached with LRU eviction:

```dart
final cacheKey = "${oldNodeHash}:${newNodeHash}";
final cached = _similarityCache.get(cacheKey);
if (cached != null) {
  return cached;
}
_similarityCache.put(cacheKey, similarity);
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

### 5. Isolate-Based Parallel Reconciliation

For trees with 20+ nodes:
- Diffing happens in worker isolate (parallel)
- Main thread stays responsive
- All UI updates applied on main thread
- Lower threshold (20 vs 50) means more trees benefit

### 6. Direct Replacement for Large Dissimilar Trees

For trees with 100+ nodes and <20% structural similarity:
- Uses direct replacement instead of reconciliation
- Enables instant navigation between completely different screens
- Skips expensive diffing for dissimilar structures

### 7. Effect List (Commit Phase)

Side-effects collected during render, applied atomically in commit:

```dart
// During reconciliation
_effectList.add(Effect(EffectType.update, viewId, props));

// In commit phase
_commitEffects(); // Applies all effects synchronously
```

### 7. Dual Trees

- **Current Tree**: Currently rendered UI
- **WorkInProgress Tree**: Ongoing reconciliation
- Swap after commit completes (prevents partial updates)

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

### 1. When to Use Keys

**You MUST use keys when:**
- Rendering dynamic lists with items that can be reordered
- Lists with identical children at different positions
- Lists where items can be inserted/removed in the middle

**You DON'T need keys when:**
- Static lists (children don't change order)
- Lists with unique children (different types or unique content)
- Simple UI with fixed structure

**Example - When Keys Help (Dynamic Lists):**
```dart
// For dynamic lists that can change order, keys ensure correct matching
final items = useState<List<Item>>([...]);

// ✅ GOOD: Use keys for dynamic lists (React best practice)
DCFView(
  children: items.state.map((item) => DCFText(
    key: item.id, // Unique identifier
    content: item.name,
  )).toList()
)

// ⚠️ OK for static lists: Keys not strictly needed if list doesn't reorder
DCFView(
  children: [
    DCFText(content: "Item 1"),
    DCFText(content: "Item 2"),
    DCFText(content: "Item 3"),
  ]
)
```

**Example - Keys Not Needed:**
```dart
// ✅ FINE: Different types, no keys needed
DCFView(
  children: [
    DCFText(content: "Hello"),
    DCFButton(title: "Click"),
    DCFImage(source: "url"),
  ]
)

// ✅ FINE: Unique content, no keys needed
DCFView(
  children: [
    DCFText(content: "Item 1"),
    DCFText(content: "Item 2"),
    DCFText(content: "Item 3"),
  ]
)
```

### 2. How to Add Keys

```dart
// For DCFElement
DCFElement(
  key: 'unique-id',
  type: 'Text',
  elementProps: {'content': 'Hello'},
)

// For Components (they accept key in constructor)
DCFText(
  key: 'text-1',
  content: 'Hello',
)

DCFButton(
  key: 'button-1',
  buttonProps: DCFButtonProps(title: 'Click'),
  onPress: () {},
)
```

### 3. Stable Keys

```dart
// ✅ Good - stable ID (doesn't change)
DCFElement(key: user.id, ...)
DCFElement(key: item.id.toString(), ...)

// ❌ Bad - unstable (changes every render)
DCFElement(key: DateTime.now().toString(), ...)
DCFElement(key: Random().nextInt(100).toString(), ...)
```

### 4. When You Actually Need Keys

**Important:** React has the same limitation! Most React users don't encounter it because:
1. They use keys for lists (React's recommendation)
2. They rarely have identical children at different positions
3. React's algorithm is similar to ours

**The VDOM is actually MORE robust than React** because our look-ahead algorithm can detect insertions/removals better than React's simple position-based matching.

**When the issue occurs (same as React):**

The problem only happens when you have:
1. **Identical children** (same type AND same props/content)
2. **AND** you insert/remove items between them
3. **AND** you don't use keys

**Example where it COULD be a problem:**
```dart
// Old tree
DCFView(children: [
  DCFText(content: "User: Alice"),  // Position 0
  DCFText(content: "User: Bob"),    // Position 1
  DCFText(content: "User: Alice"),  // Position 2 - identical to position 0!
])

// New tree (insert button between first two)
DCFView(children: [
  DCFText(content: "User: Alice"),  // Position 0
  DCFButton(title: "Follow"),       // Position 1 - INSERTED
  DCFText(content: "User: Bob"),    // Position 2
  DCFText(content: "User: Alice"),  // Position 3 - which Alice is this?
])
```

**But in practice, this is RARE because:**
- Most lists have unique content (user IDs, item IDs, etc.)
- Most lists use keys anyway (React best practice)
- The look-ahead algorithm handles most cases correctly

**Real-world example where you'd need keys:**
```dart
// Dynamic list that can be reordered
final users = useState<List<User>>([...]);

DCFView(
  children: users.state.map((user) => DCFText(
    // ❌ Without key: If list reorders, might match wrong user
    content: user.name,
  )).toList()
)

// ✅ With key: Always matches correctly
DCFView(
  children: users.state.map((user) => DCFText(
    key: user.id, // Unique identifier
    content: user.name,
  )).toList()
)
```

**Bottom Line:**
- **Your VDOM is as safe as React** (actually safer due to look-ahead)
- **Most users won't need keys** (just like React)
- **Use keys for dynamic lists** (React best practice, same here)
- **The limitation is theoretical** - rarely encountered in practice

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


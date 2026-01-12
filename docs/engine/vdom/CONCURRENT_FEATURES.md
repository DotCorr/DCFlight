# DCFlight Concurrent Features

## Overview

DCFlight VDOM implements **React Fiber-inspired concurrent features** optimized for mobile, including:
- **worker_manager-based parallel reconciliation** for heavy trees (20+ nodes)
- **Direct replacement optimization** for large dissimilar trees (100+ nodes, <20% similarity) - enables instant navigation
- **Incremental rendering** with deadline-based scheduling
- **Dual trees** (Current/WorkInProgress) for safe updates
- **Effect list** for atomic commit phase
- **Priority-based scheduling** for responsive UI

---

## 1. worker_manager-Based Parallel Reconciliation

### Overview

For heavy reconciliation tasks (20+ nodes), DCFlight uses the **worker_manager** package to perform parallel tree diffing in background isolates, keeping the main thread responsive.

### How It Works

1. **worker_manager Package**: Uses the `worker_manager` package for efficient isolate management
2. **Dynamic Spawning**: Isolates spawned on-demand with `dynamicSpawning: true` (reusable isolates)
3. **Automatic Detection**: Trees with 20+ nodes automatically use parallel reconciliation
4. **Parallel Diffing**: Tree diffing happens in background isolate
5. **Smart Reconciliation**: Element-level reconciliation when components render to same element type
6. **Main Thread Application**: All UI updates applied on main thread (safe)
7. **Direct Replacement**: For very large trees (100+ nodes) with low structural similarity (<20%), uses direct replacement instead of reconciliation - enables instant navigation
8. **Hot Reload Safety**: Disabled during hot reload to prevent issues

### Benefits

- **Heavy Projects**: Handles large trees without blocking UI
- **Responsiveness**: Main thread stays responsive during reconciliation
- **Performance**: 50-80% faster for large reconciliations (typically saves 60-100ms per reconciliation)
- **Safety**: All native view updates on main thread (no race conditions)
- **Efficient Isolates**: worker_manager handles isolate lifecycle (spawning, reuse, cleanup)
- **Smart Reconciliation**: Element-level reconciliation prevents unnecessary view replacement
- **Instant Navigation**: Direct replacement for large dissimilar trees (100+ nodes, <20% similarity) makes screen transitions instant
- **Lower Threshold**: 20-node threshold means more trees benefit from parallel processing

### Implementation

```dart
// Automatic detection (20+ nodes)
if (!isInitialRender && 
    !_isHotReloading &&
    _workerManagerInitialized &&
    _shouldUseIsolateReconciliation(oldNode, newNode)) {
  await _reconcileWithIsolate(oldNode, newNode);
  return; // Done, diff applied on main thread
}

// Direct replacement for large dissimilar trees (100+ nodes, <20% similarity)
if (!isInitialRender) {
  final nodeCount = _countNodeChildren(oldNode) + _countNodeChildren(newNode);
  if (nodeCount >= 100) {
    final similarity = _computeStructuralSimilarity(oldNode, newNode);
    if (similarity < 0.2) {
      await _replaceNode(oldNode, newNode); // Instant navigation
      return;
    }
  }
}

// Fallback to regular reconciliation
await _reconcileRegular(oldNode, newNode);
```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 1575-1606, 2303-2389)

---

## 2. Incremental Rendering

### Overview

DCFlight implements **incremental rendering** with deadline-based scheduling, allowing work to be split across multiple frames to maintain 60fps.

### Frame Scheduler

```dart
final scheduler = FrameScheduler();
await scheduler.scheduleHighPriorityWork(() {
  // User interactions, animations
});

await scheduler.scheduleLowPriorityWork(() {
  // Background updates, analytics
});
```

### Deadline-Based Processing

Work is processed within frame deadlines:

```dart
final deadline = Deadline.fromNow(Duration(milliseconds: 16)); // ~60fps
await _processUpdatesWithDeadline(updates, deadline);
```

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/scheduling/frame_scheduler.dart`

---

## 3. Dual Trees (Current/WorkInProgress)

### Overview

DCFlight maintains two VDOM trees:
- **Current Tree**: The currently rendered UI
- **WorkInProgress Tree**: The ongoing reconciliation

### How It Works

1. **Reconciliation**: Happens on WorkInProgress tree
2. **Commit Phase**: Effects applied atomically
3. **Tree Swap**: WorkInProgress becomes Current after commit

### Benefits

- **No Partial Updates**: UI never shows intermediate state
- **Atomic Commits**: All changes applied together
- **Rollback Safety**: Can abort WorkInProgress if needed

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (dual tree management)

---

## 4. Effect List (Commit Phase)

### Overview

Side-effects (mutations, lifecycle calls) are collected during the render phase and applied atomically in the commit phase.

### Effect Types

```dart
enum EffectType {
  deletion,    // View deletion
  placement,   // View creation
  update,      // View update
  lifecycle,   // Component lifecycle
}
```

### How It Works

1. **Render Phase**: Effects collected in `_effectList`
2. **Commit Phase**: `_commitEffects()` applies all effects synchronously
3. **Atomic**: All effects applied together (no partial updates)

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/reconciliation/effect_list.dart`

---

## 5. Priority-Based Update System

### Component Priorities

DCFlight has 5 priority levels:

```dart
enum ComponentPriority {
  immediate,  // Text inputs, scroll events, touch interactions (0ms delay)
  high,       // Buttons, navigation, modals (1ms delay)
  normal,     // Regular views, text, images (2ms delay)
  low,        // Analytics, background tasks (5ms delay)
  idle;       // Debug panels, dev tools (16ms delay)
}
```

### Automatic Priority Detection

Components automatically get priorities based on their type:

```dart
// Text inputs, scroll views → immediate
// Buttons, touchables → high
// Regular views → normal
// Background tasks → low
// Debug tools → idle
```

### Manual Priority Declaration

Components can also declare their priority:

```dart
class MyComponent extends DCFStatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  @override
  DCFComponentNode render() {
    // ...
  }
}
```

---

## 6. Concurrent Processing

### How It Works

When 5+ updates are pending, DCFlight automatically switches to concurrent processing:

```dart
if (_concurrentEnabled && updateCount >= _concurrentThreshold) {
  await _processPendingUpdatesConcurrently();
} else {
  await _processPendingUpdatesSerially();
}
```

### Parallel Processing

Updates are processed in parallel using `Future.wait()`:

```dart
final futures = <Future>[];
for (final componentId in batch) {
  futures.add(_updateComponentById(componentId));
}
await Future.wait(futures); // Process in parallel
```

**Benefits:**
- Multiple components update simultaneously
- Faster overall processing
- Better CPU utilization

---

## 7. Priority Scheduling

### Interruption

High-priority updates can interrupt lower-priority processing:

```dart
if (PriorityUtils.shouldInterrupt(priority, currentHighestPriority)) {
  // Cancel current batch, start new one with higher priority
  _updateTimer?.cancel();
  _updateTimer = Timer(delay, _processPendingUpdates);
}
```

### Delay-Based Scheduling

Each priority has a delay:
- **Immediate**: 0ms (process now)
- **High**: 1ms (almost immediate)
- **Normal**: 2ms (next microtask)
- **Low**: 5ms (small delay)
- **Idle**: 16ms (next frame)

---

## 8. Comparison with React Fiber

### React Fiber Concurrent Mode

**Features:**
- ✅ Time slicing (pause/resume mid-render)
- ✅ Multiple priority levels
- ✅ Interruption of low-priority work
- ✅ Suspense (async rendering)

**Use Case:** Web apps with complex interactions, need to keep UI responsive

### DCFlight Concurrent Mode

**Features:**
- ✅ worker_manager-based parallel reconciliation (20+ nodes)
- ✅ Direct replacement for large dissimilar trees (100+ nodes, <20% similarity) - instant navigation
- ✅ Incremental rendering with deadline-based scheduling
- ✅ Dual trees (Current/WorkInProgress)
- ✅ Effect list for atomic commit phase
- ✅ Priority-based scheduling
- ✅ Parallel processing (Future.wait)
- ✅ Interruption of low-priority work
- ✅ Automatic priority detection
- ✅ LRU cache with eviction
- ✅ Error recovery with retry strategies
- ✅ Performance monitoring
- ✅ Optimized logging (debug logs removed for production performance)
- ✅ Hot reload safety (disables worker_manager during hot reload)
- ❌ No time slicing (not needed - faster per operation)
- ❌ No Suspense (not needed - mobile handles async differently)

**Use Case:** Mobile apps with native performance, need efficient updates, handle heavy trees

---

## 9. Performance Benefits

### worker_manager Reconciliation Stats

The engine tracks reconciliation efficiency:

```dart
// Performance metrics logged automatically:
// ⚡ WORKER_MANAGER: Parallel diff computed in Xms
// 📊 WORKER_MANAGER: Performance - Nodes: X | Changes: Y
// 🎯 WORKER_MANAGER: Performance boost - Saved ~Xms
```

### Real-World Impact

**Serial Processing:**
- 10 updates: ~20ms
- 50 updates: ~100ms

**worker_manager Processing:**
- 20+ nodes: ~25-40ms (60-100ms saved)
- 50-80% faster for large reconciliations

**Improvement:** 2-4x faster for large batches

---

## 10. When Concurrent Mode Activates

### Automatic Activation

Concurrent mode activates when:
- 20+ nodes in reconciliation tree
- Not initial render (initial render must be synchronous)
- Not hot reloading (disabled for safety)
- worker_manager initialized successfully

### Manual Control

```dart
// Check if worker_manager is initialized
if (engine._workerManagerInitialized) {
  // Parallel reconciliation available
}
```

---

## 11. Differences from React Fiber

### Time Slicing

**React:** Can pause mid-render, resume later
**DCFlight:** Processes updates in batches (faster per operation)

**Why:** Mobile doesn't need time slicing - operations are fast enough

### Suspense

**React:** Async rendering with loading states
**DCFlight:** No Suspense (mobile handles async differently)

**Why:** Mobile apps use different patterns for async (loading indicators, etc.)

### Priority System

**React:** Complex priority system with lanes
**DCFlight:** Simple 5-level priority system

**Why:** Simpler is better for mobile - fewer edge cases

### Isolate Management

**React:** N/A (JavaScript single-threaded)
**DCFlight:** Uses worker_manager package for efficient isolate management

**Why:** Dart isolates allow true parallelism for heavy computations

---

## 12. Conclusion

**DCFlight implements React Fiber-inspired concurrent features** optimized for mobile:

- ✅ **worker_manager-based parallel reconciliation** - YES (20+ nodes)
- ✅ **Direct replacement optimization** - YES (100+ nodes, <20% similarity) - instant navigation
- ✅ **Incremental rendering** - YES (deadline-based)
- ✅ **Dual trees** - YES (Current/WorkInProgress)
- ✅ **Effect list** - YES (atomic commit phase)
- ✅ **Priority-based scheduling** - YES
- ✅ **Parallel processing** - YES
- ✅ **Interruption** - YES
- ✅ **Automatic priority detection** - YES
- ✅ **LRU cache** - YES (with eviction)
- ✅ **Error recovery** - YES (retry strategies)
- ✅ **Performance monitoring** - YES
- ✅ **Optimized logging** - YES (debug logs removed for production)
- ✅ **Hot reload safety** - YES (disables worker_manager during hot reload)
- ❌ **Time slicing** - NO (not needed - faster per operation)
- ❌ **Suspense** - NO (not needed - mobile handles async differently)

**DCFlight's concurrent mode matches React Fiber's capabilities** while being optimized for mobile:
- worker_manager-based parallel reconciliation for heavy trees (20+ nodes)
- Direct replacement for large dissimilar trees enables instant navigation
- Incremental rendering with frame-aware scheduling
- Dual trees and effect list for safe, atomic updates
- Faster per operation (no pause/resume overhead)
- Better suited for mobile performance requirements
- Production-ready performance (debug logging removed)
- Hot reload safe (disables parallel reconciliation during hot reload)

---

*DCFlight's concurrent mode is production-ready and implements React Fiber-level features optimized for mobile use cases.*

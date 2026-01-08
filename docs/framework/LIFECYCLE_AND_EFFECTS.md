# Component Lifecycle and Effects

## Overview

DCFlight components follow a React-like lifecycle with hooks for state management and side effects. This document explains how lifecycle methods and effects work in the VDOM.

## Component Lifecycle

### Mounting Phase

1. **Component Creation**
   - Component instance is created
   - `render()` is called to get initial VDOM tree
   - Hooks are initialized (useState, useEffect, etc.)

2. **Native View Creation**
   - Native views are created and attached to the view hierarchy
   - Component is registered with the VDOM engine

3. **First Mount (Critical Step)**
   ```dart
   if (!node.isMounted) {
     // 1. Reset effects for first mount (ensures they run even after hot restart)
     node.resetEffectsForFirstMount();
     
     // 2. Mark component as mounted
     node.componentDidMount();
     
     // 3. Run effects after render
     node.runEffectsAfterRender();
   }
   ```

4. **Layout Effects**
   - Layout effects run after component and children are laid out
   - Useful for measurements and DOM operations

5. **Insertion Effects**
   - Insertion effects run after entire tree is ready
   - Useful for navigation, global state, third-party libraries

### Update Phase

1. **State Change**
   - `setState()` is called on a hook
   - Component update is scheduled

2. **Reconciliation**
   - Component's `render()` is called again
   - New VDOM tree is compared with old tree
   - Only changed nodes are updated

3. **Effect Re-evaluation**
   - Effects are checked for dependency changes
   - Only effects with changed dependencies run cleanup and re-execute

### Unmounting Phase

1. **Component Unmount**
   - `componentWillUnmount()` is called
   - All hooks are disposed (cleanup functions run)
   - Native views are removed from hierarchy

## Effect Hook Lifecycle

### Effect Execution Flow

```
Component Mount
    ↓
resetEffectsForFirstMount()  ← Sets _prevDeps = null
    ↓
componentDidMount()
    ↓
runEffectsAfterRender()
    ↓
EffectHook.runEffect()
    ↓
Check: _prevDeps == null?  ← First mount
    ↓ YES
Run effect function
    ↓
Store cleanup function
    ↓
Set _prevDeps = current deps
```

### Effect Update Flow

```
State Change → Reconciliation
    ↓
updateDependencies()  ← Updates _dependencies (no cleanup yet!)
    ↓
runEffectsAfterRender()
    ↓
EffectHook.runEffect()
    ↓
Check: Dependencies changed?
    ↓ YES
Run cleanup function  ← Cleanup old effect
    ↓
Run effect function  ← Run new effect
    ↓
Set _prevDeps = current deps
    ↓ NO (deps unchanged)
Do nothing  ← Keep existing effect and cleanup
```

## Key Framework Guarantees

### 1. Effects Always Run on First Mount

**Problem**: After hot restart, hooks might be reused with stale `_prevDeps`, preventing effects from running.

**Solution**: `resetEffectsForFirstMount()` is called BEFORE `componentDidMount()`, ensuring `_prevDeps = null` so effects always run on first mount.

```dart
// In engine.dart
if (!node.isMounted) {
  node.resetEffectsForFirstMount();  // ← Resets _prevDeps = null
  node.componentDidMount();
  node.runEffectsAfterRender();      // ← Effects run because _prevDeps == null
}
```

### 2. Effects Only Re-run When Dependencies Change

**Problem**: During reconciliation loops, effects might run cleanup unnecessarily, cancelling timers/subscriptions.

**Solution**: `runEffect()` compares dependencies BEFORE running cleanup, preventing unnecessary cleanup.

```dart
void runEffect() {
  final depsChanged = _prevDeps == null || !_areEqualDeps(_dependencies, _prevDeps!);
  
  if (depsChanged) {
    // Only cleanup if deps actually changed
    _cleanup?.call();
    _cleanup = _effect?.call();
    _prevDeps = List.from(_dependencies);
  }
  // If deps unchanged, keep existing effect
}
```

### 3. Cleanup Runs Before New Effect

When dependencies change:
1. Old cleanup function runs
2. New effect function runs
3. New cleanup function is stored

This ensures resources are properly released before new ones are created.

## Best Practices

### Using Effects

```dart
useEffect(() {
  // Setup
  final timer = Timer.periodic(Duration(seconds: 1), (_) {
    // Do something
  });
  
  // Cleanup (runs when deps change or component unmounts)
  return () => timer.cancel();
}, dependencies: [someState]);
```

### Preventing Unnecessary Cleanup

If you need to persist resources across reconciliation (like timers), use instance variables:

```dart
class MyComponent extends DCFStatefulComponent {
  Timer? _timer;  // Persists across effect re-runs
  
  @override
  void componentWillUnmount() {
    _timer?.cancel();  // Cleanup on unmount
    super.componentWillUnmount();
  }
  
  @override
  DCFComponentNode render() {
    useEffect(() {
      // Only recreate if needed
      if (_timer == null) {
        _timer = Timer.periodic(...);
      }
      return () {};  // Don't cancel - handled in componentWillUnmount
    }, dependencies: []);
  }
}
```

## Troubleshooting

### Effect Not Running on Mount

- Check that `resetEffectsForFirstMount()` is being called (framework handles this)
- Verify effect dependencies are correct
- Check for errors in effect function (logged to console)

### Effect Running Too Often

- Verify dependencies array - effects run when ANY dependency changes
- Use instance variables for resources that should persist
- Check for reconciliation loops (excessive re-renders)

### Cleanup Not Running

- Ensure effect returns a cleanup function
- Check that dependencies are changing (cleanup runs before new effect)
- Verify component is unmounting (cleanup runs in `componentWillUnmount`)

## Lifecycle Method Order

```
1. Component created
2. render() called
3. Native views created
4. resetEffectsForFirstMount()  ← Framework ensures effects run
5. componentDidMount()
6. runEffectsAfterRender()      ← Effects run
7. Layout effects scheduled
8. Insertion effects scheduled
...
[State changes trigger reconciliation]
...
9. componentWillUnmount()
10. All hooks disposed (cleanup runs)
11. Native views removed
```


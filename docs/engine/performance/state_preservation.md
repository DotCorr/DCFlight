# State Preservation and Component Identity

When working with `StatefulComponent`s in DCFlight, preserving component instances across parent re-renders is crucial for maintaining internal state. This guide explains the problem and provides two solutions with their performance characteristics.

## The Problem: Instance Recreation Destroys State

Creating a new component instance inside a parent's `render()` method causes state loss:

```dart
// ❌ BAD: Creates new HomePage instance on every App re-render
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final appState = useState("some data");
    
    return HomePage(); // New instance = lost HomePage state
  }
}
```

**What happens:** The VDOM detects a new component instance, unmounts the old `HomePage` (destroying all its `useState`, `useStore`, and `useEffect` state), then mounts the fresh instance.

## Solution 1: Instance Fields (Optimal Performance)

Create the component instance once as a class field:

```dart
// ✅ BEST PERFORMANCE: Instance created once, reused forever
class App extends StatefulComponent {
  final _homePage = HomePage();

  @override
  DCFComponentNode render() {
    final appState = useState("some data");
    
    return _homePage; // Same instance every render
  }
}
```

**Performance:** Zero runtime overhead. No dependency checking, no cache management.

**Limitations:** Cannot access parent state during component creation.

## Solution 2: useMemo Hook (Flexible)

Memoize component creation inside `render()`:

```dart
// ✅ FLEXIBLE: Instance preserved with access to parent state
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final appState = useState("some data");
    
    final homePage = useMemo(() => HomePage(
      initialData: appState.state,
    ), []); // Empty deps = create once, cache forever
    
    return homePage;
  }
}
```

**Performance:** Small runtime overhead for dependency array comparison on each render.

**Benefits:** Component can use parent state/props, definition stays near usage.

## When Components Should Be Recreated

Use non-empty dependency arrays when component instances should change:

```dart
final userProfile = useMemo(() => UserProfile(
  userId: currentUser.state.id,
  permissions: userPermissions.state,
), [currentUser.state.id, userPermissions.state]);

// New UserProfile instance created only when userId or permissions change
```

## Performance Comparison

| Pattern | Creation Cost | Runtime Cost | Use Case |
|---------|---------------|--------------|-----------|
| Instance field | Once (class instantiation) | Zero | Static components |
| `useMemo([])` | Once (first render) | ~1µs per render | Components needing parent state |
| Direct creation | Every render | High + GC pressure | Never recommended for StatefulComponents |

## Best Practices

1. **Use instance fields** for static components that don't need parent state
2. **Use `useMemo([], [])`** for components that need parent state/props
3. **Use non-empty deps** only when you actually want to recreate the component instance
4. **Never create StatefulComponents directly in render()** without memoization

The framework's automatic optimizations (EquatableMixin on primitives, component-level equality) work regardless of which pattern you choose, but preserving instances is essential for maintaining component state.
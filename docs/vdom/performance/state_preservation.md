# State Preservation and Component Identity

In DCFlight, a core principle for managing state is the preservation of a component's instance. When a `StatefulComponent`'s internal state (from `useState` or `useStore`) needs to persist across re-renders of its parent, its instance must not be recreated.

This document explains why this is crucial and details the two recommended patterns for achieving it.

## The Problem: Why `Home()` in `render()` Loses State

Consider a `StatefulComponent` to be like a physical whiteboard. The state you create with `useState` are the drawings on that specific whiteboard.

If you create a new instance of a stateful component directly inside the `render` method of its parent, you are telling the framework: "Throw away the old whiteboard and bring me a brand new, perfectly clean one."

```dart
// ❌ INCORRECT: This will lose the state of `HomePage` on every re-render of `App`.
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // ...
    return HomePage(); // A new instance of HomePage is created every time.
  }
}
```

The VDOM sees a new component instance, unmounts the old one (destroying its state), and mounts the new one. Any user interactions or state changes within `HomePage` are lost.

## Solution 1: The Instance Field Pattern

The most direct way to solve this is to create the component instance once as a `final` field on the parent component's class.

```dart
// ✅ CORRECT: The instance is created once and reused.
class App extends StatefulComponent {
  // The instance is created only when App is instantiated.
  final _homePage = HomePage();

  @override
  DCFComponentNode render() {
    // ...
    return _homePage; // The SAME instance is returned on every render.
  }
}
```

*   **Pros:** Simple and requires no hooks.
*   **Cons:** Can feel clunky, as the component's definition is separated from its usage within the `render` method.

## Solution 2: The `useMemo` Hook (Recommended)

A cleaner, more idiomatic, and more flexible solution is the `useMemo` hook. This hook allows you to define the component inside the `render` method, but it ensures the creation function is only run once, caching the resulting instance.

```dart
// ✅ CORRECT & RECOMMENDED: The instance is created and memoized inside render.
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // useMemo ensures HomePage() is only called once, and the same
    // instance is returned on every subsequent render.
    final homePage = useMemo(() => HomePage(), []);

    return homePage;
  }
}
```

*   **Pros:** Keeps component definition and usage co-located. It's the standard pattern in modern hook-based frameworks. It's more flexible because it can re-create the instance if its dependencies change.
*   **Cons:** Can only be used inside a `StatefulComponent`.

---

### Understanding the `useMemo` Dependency Array `[]`

The second argument to `useMemo` is the **dependency array**. This array is the key to controlling when the memoized value is recalculated.

> `useMemo(createFunction, dependencies)`

The rule is simple: **If any value in the `dependencies` array changes between renders, `useMemo` will discard the old cached value and execute `createFunction` again to create a new one.**

#### The Empty Array `[]`

When you provide an empty array `[]`, you are telling `useMemo`: "The dependencies for this value will *never* change."

Because the list of dependencies is empty, the condition for recalculation is never met. As a result, `useMemo` will:
1.  Execute the creation function (e.g., `() => HomePage()`) on the very first render.
2.  Cache the returned instance (`HomePage`).
3.  On **every subsequent render**, it will return the exact same cached instance without ever calling the creation function again.

This is the perfect mechanism for preserving a stateful component's instance for the entire lifetime of its parent.

#### Non-Empty Dependencies

If you needed to create a new component instance whenever a specific prop or state changed, you would include that value in the dependency array.

```dart
// Re-creates a new UserProfile component ONLY when `userId` changes.
final userProfile = useMemo(() => UserProfile(id: userId), [userId]);
```

For preserving singleton-like screen components within a parent, the empty dependency array `[]` is almost always what you will use.
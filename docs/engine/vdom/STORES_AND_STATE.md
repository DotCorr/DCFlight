# Stores and State Management

## Overview

DCFlight uses a reactive store-based state management system, similar to Redux or MobX, but simpler and more integrated with the VDOM.

## Store Architecture

```
Store<T>
    ↓
StoreRegistry (Global)
    ↓
Components (via hooks)
    ↓
VDOM Updates
```

## Core Concepts

### 1. Store<T>

A reactive container for state that notifies listeners when state changes.

**Location:** `packages/dcflight/lib/framework/components/hooks/store.dart`

**Properties:**
- `state`: Current state value
- `_listeners`: List of functions to notify on state change
- `_componentAccess`: Tracks which components access the store

**Methods:**
- `get state`: Get current state (with access tracking)
- `setState(T newState)`: Update state and notify listeners
- `updateState(T Function(T) updater)`: Update using a function
- `subscribe(void Function(T) listener)`: Register a listener
- `unsubscribe(void Function(T) listener)`: Remove a listener

**Example:**
```dart
final counterStore = Store<int>(0);

// Update state
counterStore.setState(1);

// Update with function
counterStore.updateState((current) => current + 1);

// Subscribe to changes
counterStore.subscribe((newValue) {
  print('Counter changed to $newValue');
});
```

### 2. StoreRegistry

Global registry for managing stores across the app.

**Location:** `packages/dcflight/lib/framework/components/hooks/store.dart`

**Methods:**
- `registerStore<T>(String id, Store<T> store)`: Register a store
- `getStore<T>(String id)`: Get a store by ID
- `removeStore(String id)`: Remove a store
- `createStore<T>(String id, T initialState)`: Create and register

**Example:**
```dart
// Create and register a global store
final userStore = StoreRegistry.instance.createStore(
  'user',
  User(name: 'John', age: 30),
);

// Get the store later
final user = StoreRegistry.instance.getStore<User>('user');
```

### 3. StoreHook<T>

Hook for components to access stores reactively.

**Location:** `packages/dcflight/lib/framework/components/hooks/state_hook.dart`

**Usage:**
```dart
class MyComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useStore(counterStore);
    
    return DCFText(content: 'Count: ${counter.state}');
  }
}
```

**Behavior:**
- Automatically subscribes to store changes
- Triggers component re-render when store updates
- Unsubscribes when component unmounts

## State Management Patterns

### Pattern 1: Local Component State

For component-specific state that doesn't need to be shared.

```dart
class CounterComponent extends DCFStatefulComponent {
  int _count = 0;
  
  @override
  DCFComponentNode render() {
    return DCFButton(
      title: 'Count: $_count',
      onPress: () {
        setState(() {
          _count++;
        });
      },
    );
  }
}
```

### Pattern 2: Global Store

For state that needs to be shared across components.

```dart
// Create global store
final themeStore = Store<bool>(false); // false = light, true = dark

// Component A
class ThemeToggle extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useStore(themeStore);
    
    return DCFButton(
      title: theme.state ? 'Light' : 'Dark',
      onPress: () {
        themeStore.setState(!theme.state);
      },
    );
  }
}

// Component B (different part of app)
class ThemedText extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useStore(themeStore);
    
    return DCFText(
      content: 'Current theme: ${theme.state ? "Dark" : "Light"}',
      textColor: theme.state ? '#FFFFFF' : '#000000',
    );
  }
}
```

### Pattern 3: Store Registry

For managing multiple stores centrally.

```dart
// Register stores
StoreRegistry.instance.registerStore('user', userStore);
StoreRegistry.instance.registerStore('theme', themeStore);
StoreRegistry.instance.registerStore('cart', cartStore);

// Access in components
class MyComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final user = useGlobalStore<User>('user');
    final theme = useGlobalStore<bool>('theme');
    
    return DCFView(
      children: [
        DCFText(content: 'Hello, ${user.state.name}'),
        DCFText(
          content: 'Theme: ${theme.state ? "Dark" : "Light"}',
          textColor: theme.state ? '#FFFFFF' : '#000000',
        ),
      ],
    );
  }
}
```

## Store Lifecycle

### 1. Creation
```dart
final store = Store<T>(initialState);
```

### 2. Registration (Optional)
```dart
StoreRegistry.instance.registerStore('storeId', store);
```

### 3. Subscription
- Components subscribe via `useStore()` hook
- Manual subscription via `store.subscribe()`

### 4. Updates
- State updated via `setState()` or `updateState()`
- All listeners notified
- Subscribed components re-render

### 5. Cleanup
- Components automatically unsubscribe on unmount
- Stores can be removed from registry

## Integration with VDOM

### How Stores Trigger Updates

1. **Store Update**
   ```dart
   store.setState(newValue);
   ```

2. **Listener Notification**
   - All subscribed listeners called
   - `StoreHook` listener triggers component update

3. **Component Re-render**
   ```dart
   _scheduleComponentUpdate(component);
   ```

4. **VDOM Reconciliation**
   - Component's `render()` called
   - New VDOM tree created
   - Reconciled with old tree

5. **Native Update**
   - Changed props sent to native
   - Native views updated

### Store Access Tracking

The store system tracks how components access stores:

- **Hook-based access:** Via `useStore()` hook (recommended)
- **Direct access:** Via `store.state` (not recommended in components)

**Purpose:** Detect inconsistent usage patterns and warn developers.

## Best Practices

### 1. Use Hooks for Store Access
```dart
// ✅ Good
final counter = useStore(counterStore);

// ❌ Bad (in components)
final counter = counterStore.state;
```

### 2. Keep Stores Focused
```dart
// ✅ Good - focused store
final userStore = Store<User>(User());
final themeStore = Store<bool>(false);

// ❌ Bad - monolithic store
final appStore = Store<AppState>(AppState(
  user: User(),
  theme: false,
  cart: Cart(),
  // ... everything
));
```

### 3. Register Global Stores
```dart
// ✅ Good - registered for easy access
StoreRegistry.instance.registerStore('user', userStore);

// ❌ Bad - passed around manually
class MyComponent extends DCFStatefulComponent {
  final Store<User> userStore;
  // ...
}
```

### 4. Use updateState for Complex Updates
```dart
// ✅ Good - atomic update
store.updateState((current) => current.copyWith(
  count: current.count + 1,
  lastUpdated: DateTime.now(),
));

// ❌ Bad - multiple updates
store.setState(store.state.copyWith(count: store.state.count + 1));
store.setState(store.state.copyWith(lastUpdated: DateTime.now()));
```

## Navigation Stores

The navigation system uses stores for routing:

**Location:** `packages/dcf_screens/docs/NavigationStores.md`

**Stores:**
- `globalNavigationCommand`: Current navigation command
- `activeScreenTracker`: Currently active screen
- `navigationStackTracker`: Navigation stack state

**Usage:**
```dart
final navCommand = useGlobalStore<RouteNavigationCommand?>('globalNavigationCommand');
```

## Performance Considerations

### 1. Selective Subscriptions
- Only subscribe to stores you need
- Unsubscribe when component unmounts

### 2. Memoization
- Use `updateState` for complex updates
- Avoid unnecessary state changes

### 3. Batch Updates
- Multiple store updates batched automatically
- Single reconciliation pass

### 4. Store Size
- Keep stores small and focused
- Avoid storing large objects

## Debugging

### Store Access Logging
- Track which components access stores
- Warn about inconsistent usage

### State Change Logging
- Log all state changes
- Track update frequency

### Memory Leaks
- Detect stores with no subscribers
- Warn about potential leaks


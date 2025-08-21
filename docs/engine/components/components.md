# DCFlight Component Optimization Guide

## Overview

DCFlight provides **automatic component re-render optimization** that reduces unnecessary UI updates by 60-90% in typical applications. This guide explains how to write components that take full advantage of this optimization.

## The Problem: Unnecessary Re-renders

Without optimization, every state change in a parent component causes ALL child components to re-render, even if their props haven't changed:

```dart
// ❌ Without optimization:
class Parent extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useState(0);
    
    return DCFView(children: [
      DCFButton(
        onPress: (_) => counter.setState(counter.state + 1),
        buttonProps: DCFButtonProps(title: "Count: ${counter.state}"),
      ),
      
      StaticChild(),      // ❌ Re-renders even though nothing changed
      AnotherChild(),     // ❌ Re-renders even though nothing changed  
      DynamicChild(count: counter.state),  // ✅ Should re-render (props changed)
    ]);
  }
}
```

**Result**: Poor performance, animation stuttering, unnecessary CPU usage.

## The Solution: Smart Re-render Optimization

DCFlight's VDOM automatically detects when components don't need to re-render and skips them entirely.

## Component Optimization Patterns

### ✅ StatelessComponent Pattern

**For components without internal state, use this pattern:**

```dart
class MyComponent extends StatelessComponent with EquatableMixin {
  final String title;
  final int count;
  final Color color;

  MyComponent({
    required this.title,
    required this.count,
    this.color = Colors.blue,
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFView(
      children: [
        DCFText(content: title),
        DCFText(content: "Count: $count"),
      ],
      styleSheet: StyleSheet(backgroundColor: color),
    );
  }

  // ✅ REQUIRED: List ALL props that affect what gets rendered
  @override
  List<Object?> get props => [title, count, color, key];
}
```

**Key Requirements:**
1. ✅ Extend `StatelessComponent` with `EquatableMixin`
2. ✅ Override `props` getter with ALL properties that affect rendering
3. ✅ Always include `key` in the props list

### ✅ StatefulComponent Pattern

**For components with internal state, use this pattern:**

```dart
class MyComponent extends StatefulComponent {
  final String title;  // External prop from parent

  MyComponent({required this.title, super.key});

  @override
  DCFComponentNode render() {
    final count = useState(0);        // Internal state
    final isVisible = useState(true); // Internal state
    
    return DCFView(
      children: [
        DCFText(content: title),  // Uses external prop
        DCFText(content: "Internal count: ${count.state}"),  // Uses internal state
        DCFButton(
          onPress: (_) => count.setState(count.state + 1),  // Changes internal state
          buttonProps: DCFButtonProps(title: "Increment"),
        ),
      ],
    );
  }

  // ✅ NO additional optimization code needed
  // ✅ Framework handles everything automatically
}
```

**Key Requirements:**
1. ✅ Just extend `StatefulComponent` 
2. ✅ No mixin needed
3. ✅ No props override needed
4. ✅ Framework optimizes automatically

## What to Include in Props

### ✅ Include These in Props:
- All constructor parameters that affect rendering
- Props that change styling or layout
- Data that determines what content is shown
- Event handlers (if they can change between renders)
- The `key` property (always include this)

### ❌ Don't Include These:
- Internal state managed by hooks (`useState`, `useRef`, etc.)
- Computed values derived from included props
- The `instanceId` field (framework handles this)
- Private fields or methods

### Examples:

```dart
class UserCard extends StatelessComponent with EquatableMixin {
  final User user;           // ✅ Include - affects content
  final bool isSelected;     // ✅ Include - affects styling  
  final VoidCallback onTap;  // ✅ Include - behavior can change
  final Color? customColor;  // ✅ Include - affects appearance

  // ✅ Correct props list
  @override
  List<Object?> get props => [user, isSelected, onTap, customColor, key];
}

class CounterWidget extends StatelessComponent with EquatableMixin {
  final int count;
  final String label;
  
  // ❌ Incorrect - missing props
  @override
  List<Object?> get props => [count];  // Missing label and key!
  
  // ✅ Correct props list  
  @override
  List<Object?> get props => [count, label, key];
}
```

## Compiler Enforcement

The DCFlight framework **requires** you to implement the `props` getter for all StatelessComponents. If you forget, you'll get a compile-time error:

```dart
// ❌ This will cause a compile error:
class BrokenComponent extends StatelessComponent with EquatableMixin {
  final String title;
  
  @override
  DCFComponentNode render() => DCFText(content: title);
  
  // ❌ ERROR: Missing required override of 'props' getter
}
```

**Error Message:**
```
Missing concrete implementation of 'StatelessComponent.props'.
Try implementing the missing method, or make the class abstract.
```

## Performance Benefits

With proper optimization, you'll see:

### ✅ Before vs After Performance:
```dart
// ❌ Without optimization (all components re-render):
Parent state change → 15 components re-render → Slow, janky UI

// ✅ With optimization (only necessary components re-render):  
Parent state change → 2 components re-render → Fast, smooth UI
```

### ✅ Real-World Performance Gains:
- **60-90% reduction** in unnecessary re-renders
- **Smoother animations** and transitions
- **Better battery life** on mobile devices
- **Improved user experience** across the board

## Common Mistakes

### ❌ Mistake 1: Forgetting EquatableMixin
```dart
// ❌ Wrong - no optimization
class MyComponent extends StatelessComponent {
  @override
  List<Object?> get props => [title, key];
}

// ✅ Correct - optimized
class MyComponent extends StatelessComponent with EquatableMixin {
  @override
  List<Object?> get props => [title, key];
}
```

### ❌ Mistake 2: Missing Props
```dart
class UserProfile extends StatelessComponent with EquatableMixin {
  final User user;
  final bool isEditing;
  final VoidCallback onEdit;

  // ❌ Wrong - missing props, will re-render unnecessarily
  @override
  List<Object?> get props => [user];

  // ✅ Correct - includes all rendering-affecting props
  @override
  List<Object?> get props => [user, isEditing, onEdit, key];
}
```

### ❌ Mistake 3: Using EquatableMixin with StatefulComponent
```dart
// ❌ Wrong - StatefulComponents don't need EquatableMixin
class MyComponent extends StatefulComponent with EquatableMixin {
  // This is unnecessary and can cause issues
}

// ✅ Correct - just extend StatefulComponent
class MyComponent extends StatefulComponent {
  // Framework handles optimization automatically
}
```

## Testing Component Optimization

You can verify your components are optimized by enabling debug logging:

```dart
// Enable VDOM debug logging
DCFEngine.setDebugLogging(true);

// Look for these messages in your logs:
// ✅ "🟢 SKIPPING reconciliation - components are equal"  (optimized)
// ❌ "🔴 CONTINUING reconciliation - components are different"  (re-rendering)
```

## Quick Checklist

When creating components, use this checklist:

### StatelessComponent Checklist:
- [ ] Extends `StatelessComponent with EquatableMixin`
- [ ] Implements `props` getter
- [ ] Includes ALL rendering-affecting properties in props
- [ ] Includes `key` in props list
- [ ] No internal state (uses props only)

### StatefulComponent Checklist:
- [ ] Extends `StatefulComponent` (no mixin)
- [ ] No `props` override needed
- [ ] Uses hooks for internal state (`useState`, `useRef`, etc.)
- [ ] Framework handles optimization automatically

## Summary

DCFlight provides **automatic performance optimization** that makes your apps fast by default. Just follow the component patterns above, and your app will automatically skip 60-90% of unnecessary re-renders.

**Remember:**
- **StatelessComponent**: Use `EquatableMixin` + `props` list
- **StatefulComponent**: Just extend and go - framework handles everything

Your users will notice the difference! 🚀


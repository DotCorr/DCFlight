# DCFlight Reconciliation Model: Signal-Inspired Architecture

## Overview

DCFlight implements a **signal-inspired reconciliation model** that combines the efficiency of fine-grained reactivity with the flexibility of virtual DOM diffing. This document explains how DCFlight's reconciliation works, how it differs from React, and why it's more efficient.

## Table of Contents

1. [Signal-Inspired vs True Signals](#signal-inspired-vs-true-signals)
2. [DCFlight's Reconciliation Flow](#dcflights-reconciliation-flow)
3. [Comparison with React](#comparison-with-react)
4. [Prop Diffing Algorithm](#prop-diffing-algorithm)
5. [Update Decision Logic](#update-decision-logic)
6. [Performance Characteristics](#performance-characteristics)

---

## Signal-Inspired vs True Signals

### What DCFlight Is

DCFlight is **signal-inspired**, not a pure signal-based framework. Here's the distinction:

**Signal-Inspired (DCFlight):**
- Uses Virtual DOM for structure
- Performs prop-level diffing (signal-like granularity)
- Only updates native views when props actually change
- Combines VDOM flexibility with signal efficiency

**True Signals (SolidJS, Preact Signals):**
- No Virtual DOM
- Direct DOM updates
- Reactive primitives track dependencies
- Updates happen at the exact point of change

### Why Signal-Inspired?

DCFlight chose signal-inspired because:
1. **Cross-platform**: VDOM allows consistent rendering across iOS/Android
2. **Flexibility**: Can handle complex component trees and conditional rendering
3. **Efficiency**: Prop-level diffing gives signal-like performance without losing VDOM benefits
4. **Familiarity**: Developers coming from React understand the model

---

## DCFlight's Reconciliation Flow

### High-Level Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    State Change Trigger                      │
│  (useState, Store update, scheduleUpdate, etc.)             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Component Re-render                            │
│  - render() called                                         │
│  - New VDOM tree created                                   │
│  - Old tree preserved in _previousRenderedNodes            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Tree Size Check                                  │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ < 20 nodes   │  │ 20-99 nodes  │  │ ≥ 100 nodes  │    │
│  │              │  │              │  │              │    │
│  │ Main Thread  │  │ Isolate      │  │ Check        │    │
│  │ Reconciliation│ │ Reconciliation│ │ Similarity   │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                  │                  │             │
│         │                  │                  │             │
│         │                  │                  ▼             │
│         │                  │         ┌──────────────────┐  │
│         │                  │         │ < 20% similar?   │  │
│         │                  │         │ → Direct Replace │  │
│         │                  │         │ (Instant Nav)    │  │
│         │                  │         └──────┬───────────┘  │
│         │                  │                │              │
│         └──────────┬────────┴────────────────┘              │
│                    │                                        │
│                    ▼                                        │
│         _reconcile(oldNode, newNode)                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Node Matching                                    │
│                                                             │
│  1. Key-based (if both have keys)                         │
│  2. Position + Type matching                               │
│  3. Props similarity check                                 │
│                                                             │
│  ┌──────────────────────────────────────┐                 │
│  │ Same type?                           │                 │
│  │   YES → Reconcile                    │                 │
│  │   NO  → Replace (unmount + mount)    │                 │
│  └──────────────────────────────────────┘                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Prop Diffing (_diffProps)                       │
│                                                             │
│  ┌──────────────────────────────────────┐                 │
│  │ For each prop in newProps:           │                 │
│  │   - Compare with oldProps            │                 │
│  │   - Deep equality for Maps/Lists     │                 │
│  │   - Skip function handlers           │                 │
│  │   - Track: added, changed, removed   │                 │
│  └──────────────────────────────────────┘                 │
│                                                             │
│  Result: Map<String, dynamic> changedProps                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Update Decision                                  │
│                                                             │
│  ┌──────────────────────────────────────┐                 │
│  │ if (changedProps.isEmpty) {          │                 │
│  │   // NO NATIVE UPDATE                 │                 │
│  │   // Skip updateView()                 │                 │
│  │   // Log: "No prop changes detected" │                 │
│  │ } else {                              │                 │
│  │   // SEND ONLY CHANGED PROPS          │                 │
│  │   await updateView(viewId,            │                 │
│  │                     changedProps)     │                 │
│  │ }                                     │                 │
│  └──────────────────────────────────────┘                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Children Reconciliation                         │
│                                                             │
│  - Match children by position/type/key                     │
│  - Reconcile each matched pair                             │
│  - Handle insertions/removals                              │
│  - Recursive: _reconcile(oldChild, newChild)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Commit Phase                                    │
│                                                             │
│  - Batch all native operations                             │
│  - Apply updates atomically                                │
│  - Result: "X operations (Y creates, Z updates)"          │
└─────────────────────────────────────────────────────────────┘
```

### Detailed Prop Diffing Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    _diffProps(oldProps, newProps)          │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│  Iterate newProps│          │  Iterate oldProps│
│                  │          │                  │
│  For each prop:  │          │  For each prop:  │
│  ┌─────────────┐ │          │  ┌─────────────┐ │
│  │ Not in old? │ │          │  │ Not in new? │ │
│  │ → ADDED     │ │          │  │ → REMOVED   │ │
│  └─────────────┘ │          │  └─────────────┘ │
│                  │          │                  │
│  ┌─────────────┐ │          │                  │
│  │ In old?     │ │          │                  │
│  │ → Compare:  │ │          │                  │
│  │   - Map?    │ │          │                  │
│  │     → Deep  │ │          │                  │
│  │   - List?   │ │          │                  │
│  │     → Deep  │ │          │                  │
│  │   - Other?  │ │          │                  │
│  │     → ==    │ │          │                  │
│  │   - Func?   │ │          │                  │
│  │     → Skip  │ │          │                  │
│  └─────────────┘ │          │                  │
│                  │          │                  │
│  If different:   │          │                  │
│  → CHANGED       │          │                  │
└────────┬─────────┘          └────────┬─────────┘
         │                               │
         └───────────────┬───────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  changedProps Map     │
              │  {                    │
              │    "fontSize": 18,    │  ← Only changed props
              │    "color": "#FF0000" │  ← No unchanged props
              │  }                    │
              └──────────────────────┘
```

---

## Comparison with React

### React's Reconciliation Model

```
┌─────────────────────────────────────────────────────────────┐
│                    State Change                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Component Re-render                             │
│  - Parent re-renders → ALL children re-render              │
│  - Even if props haven't changed                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            React Reconciliation                            │
│                                                             │
│  - Compares entire component trees                         │
│  - Uses keys for matching                                  │
│  - May update even if props are same                       │
│  - Relies on React.memo to prevent updates                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Native Update                                   │
│                                                             │
│  - May update views even if props unchanged                │
│  - Needs manual optimization (memo, useMemo)               │
└─────────────────────────────────────────────────────────────┘
```

### DCFlight's Reconciliation Model

```
┌─────────────────────────────────────────────────────────────┐
│                    State Change                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Component Re-render                             │
│  - Only affected components re-render                      │
│  - VDOM tree created for comparison                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            DCFlight Reconciliation                         │
│                                                             │
│  - Prop-level diffing (signal-like)                        │
│  - Only changed props tracked                              │
│  - Automatic optimization (no memo needed)                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Native Update                                   │
│                                                             │
│  - ONLY updates if props changed                           │
│  - 0 operations if nothing changed                         │
│  - Built-in efficiency                                     │
└─────────────────────────────────────────────────────────────┘
```

### Side-by-Side Comparison

| Aspect | React | DCFlight |
|--------|-------|----------|
| **Update Trigger** | Parent re-render triggers child re-render | Only when props actually change |
| **Prop Diffing** | Component-level (entire props object) | Prop-level (individual prop comparison) |
| **Native Updates** | May update even if props same | Only updates if props changed |
| **Optimization** | Manual (React.memo, useMemo) | Automatic (built-in) |
| **Granularity** | Component-level | Prop-level (signal-inspired) |
| **VDOM** | Yes | Yes |
| **Signals** | No | Signal-inspired (prop-level reactivity) |
| **Performance** | Good (with optimization) | Excellent (automatic) |

### Example: Font Size Change

**React Behavior:**
```
State Change → Re-render → Reconciliation → Native Update
(Even if fontSize prop didn't change, component may update)
```

**DCFlight Behavior:**
```
State Change → Re-render → Prop Diffing → 
  fontSize unchanged? → NO NATIVE UPDATE (0 operations)
  fontSize changed? → UPDATE ONLY fontSize prop
```

---

## Prop Diffing Algorithm

### Implementation Details

The `_diffProps` function (line 4602-4671) performs O(n) prop comparison:

```dart
Map<String, dynamic> _diffProps(
  String elementType,
  Map<String, dynamic> oldProps,
  Map<String, dynamic> newProps
) {
  var changedProps = <String, dynamic>{};
  
  // 1. Check new props (added/changed)
  for (final entry in newProps.entries) {
    final key = entry.key;
    final value = entry.value;
    
    if (value is Function) continue; // Skip handlers
    
    if (!oldProps.containsKey(key)) {
      changedProps[key] = value; // ADDED
    } else {
      final oldValue = oldProps[key];
      
      // Deep equality for complex types
      if (oldValue is Map && value is Map) {
        if (!_mapsEqual(oldValue, value)) {
          changedProps[key] = value; // CHANGED
        }
      } else if (oldValue is List && value is List) {
        if (!_listsEqual(oldValue, value)) {
          changedProps[key] = value; // CHANGED
        }
      } else if (oldValue != value) {
        changedProps[key] = value; // CHANGED
      }
    }
  }
  
  // 2. Check removed props
  for (final key in oldProps.keys) {
    if (!newProps.containsKey(key) && oldProps[key] is! Function) {
      changedProps[key] = null; // REMOVED
    }
  }
  
  return changedProps; // Only changed props
}
```

### Key Features

1. **Deep Equality**: Maps and Lists are compared deeply, not by reference
2. **Function Handling**: Event handlers are skipped in comparison (they're managed separately)
3. **Removal Detection**: Tracks props that were removed (set to null)
4. **Efficiency**: O(n) where n = number of props

---

## Update Decision Logic

### The Critical Check

```dart
// Line 4309-4377 in engine.dart
final changedProps = _diffProps(
  oldElement.type,
  oldElement.elementProps,
  newElement.elementProps
);

// Signal-inspired: Only send changed props
final propsToSend = _isStructuralShock
  ? Map<String, dynamic>.from(newElement.elementProps) // All props
  : changedProps; // Only changed props

if (propsToSend.isNotEmpty) {
  // UPDATE NATIVE VIEW
  await _nativeBridge.updateView(
    oldElement.nativeViewId!,
    propsToSend
  );
} else {
  // NO UPDATE - Signal-inspired efficiency
  print('🔍 RECONCILE_ELEMENT: No prop changes detected');
  // Result: 0 operations sent to native
}
```

### Why This Matters

**React Approach:**
- May call `updateView` even if props are identical
- Relies on native layer to detect no-op
- More bridge calls = more overhead

**DCFlight Approach:**
- Only calls `updateView` if props actually changed
- Skips bridge call entirely if nothing changed
- Fewer bridge calls = better performance

---

## Performance Characteristics

### Metrics

**DCFlight's Signal-Inspired Model:**
- **Prop Diffing**: O(n) where n = props count
- **Update Operations**: Only changed props sent
- **Bridge Calls**: Minimized (0 if no changes)
- **Memory**: Efficient (only stores changed props)

**React's Model:**
- **Component Diffing**: O(n) where n = component count
- **Update Operations**: May send all props
- **Bridge Calls**: More frequent (even for no-ops)
- **Memory**: May store full prop objects

### Real-World Example

**Scenario**: Font scale changes, but `fontSize` prop stays `17`

**React:**
```
Reconciliation: ✅ Runs
Prop Diffing: ✅ Runs (component-level)
Native Update: ⚠️ May still update (depends on memo)
Bridge Calls: 1+ (even if no-op)
```

**DCFlight:**
```
Reconciliation: ✅ Runs (280 nodes)
Prop Diffing: ✅ Runs (prop-level)
Changed Props: {} (empty - fontSize unchanged)
Native Update: ❌ SKIPPED (0 operations)
Bridge Calls: 0 (nothing to update)
```

**Result**: DCFlight is more efficient because it detects no prop changes and skips native updates entirely.

---

## Key Takeaways

1. **Signal-Inspired, Not Pure Signals**: DCFlight combines VDOM flexibility with signal-like efficiency
2. **Prop-Level Granularity**: Updates only when individual props change, not entire components
3. **Automatic Optimization**: No need for manual memoization - efficiency is built-in
4. **Zero-Operation Updates**: If nothing changed, no native operations are sent
5. **Better Than React**: More efficient by default, without requiring developer optimization

---

## Conclusion

DCFlight's reconciliation model is **signal-inspired** - it takes the best of both worlds:
- **VDOM flexibility** from React
- **Signal efficiency** from frameworks like SolidJS

This gives developers a familiar API (React-like) with superior performance (signal-like) out of the box.


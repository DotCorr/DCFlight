# VDOM Documentation

This directory contains comprehensive documentation about DCFlight's Virtual DOM (VDOM) system, similar to how Flutter documents its Widget Tree, Element Tree, and RenderObject Tree.

## Documentation Structure

### Core Concepts

1. **[VDOM Tree Structure](./VDOM_TREE_STRUCTURE.md)**
   - Node types and hierarchy
   - Component tree → VDOM tree → Native view tree
   - Node relationships and mapping
   - Key system and instance tracking

2. **[Rendering Flow](./RENDERING_FLOW.md)**
   - Complete rendering pipeline
   - Component rendering → VDOM construction → Native rendering
   - Update flow and batch updates
   - Performance optimizations

3. **[Stores and State Management](./STORES_AND_STATE.md)**
   - Store architecture
   - State management patterns
   - Integration with VDOM
   - Best practices

4. **[Reconciliation](./RECONCILIATION.md)**
   - Reconciliation algorithm
   - Node matching strategies
   - Props diffing
   - Performance optimizations

5. **[Concurrent Features](./CONCURRENT_FEATURES.md)**
   - Isolate-based parallel reconciliation (50+ nodes)
   - Incremental rendering with deadline-based scheduling
   - Dual trees (Current/WorkInProgress)
   - Effect list for commit phase
   - Priority-based update scheduling
   - Performance benefits

6. **[Concurrent Mode Evidence](./CONCURRENT_MODE_EVIDENCE.md)**
   - Direct code evidence
   - Implementation details
   - API reference

## Quick Reference

### Component Tree → VDOM Tree → Native Views

```
Dart Component
    ↓ render()
DCFComponentNode (VDOM)
    ↓ renderToNative()
Native View (iOS/Android)
```

### Node Types

- **DCFComponentNode**: Base class for all nodes
- **DCFElement**: Primitive UI element (View, Text, Button)
- **DCFStatefulComponent**: Component with state
- **DCFStatelessComponent**: Pure component
- **DCFragment**: Groups multiple nodes
- **EmptyVDomNode**: Conditional absence

### Key Concepts

- **VDOM Tree**: Lightweight representation of UI
- **Reconciliation**: Efficient diffing and updating (with isolate support for 50+ nodes)
- **Isolate Workers**: 4 worker isolates for parallel reconciliation of heavy trees
- **Integer View IDs**: Integer-based view identifiers (0 = root, like React Native)
- **Dual Trees**: Current and WorkInProgress trees for safe updates
- **Effect List**: Side-effects collected during render, applied in commit phase
- **Incremental Rendering**: Frame-aware scheduling with deadline-based work
- **Stores**: Reactive state management
- **Native Bridge**: Communication with native layer
- **Yoga Layout**: Flexbox layout engine

## Comparison with Flutter

| Flutter | DCFlight |
|---------|----------|
| Widget Tree | Component Tree |
| Element Tree | VDOM Tree |
| RenderObject Tree | Native View Tree |
| Widget.build() | Component.render() |
| Element.update() | Reconciliation |
| RenderObject.layout() | Yoga Layout |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    User Code (Dart)                      │
│  Components (DCFStatefulComponent, DCFStatelessComponent)│
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────┐
│                    VDOM Engine                            │
│  • Component Rendering                                    │
│  • VDOM Tree Construction                                 │
│  • Reconciliation (Main Thread + Isolates)               │
│  • Props Diffing                                          │
│  • Incremental Rendering                                  │
│  • Effect List (Commit Phase)                             │
│  • Dual Trees (Current/WorkInProgress)                    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────┐
│              Worker Isolates (4 workers)                  │
│  • Parallel Tree Diffing (50+ nodes)                      │
│  • Props Computation                                      │
│  • Large List Processing                                  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────┐
│                  Native Bridge                            │
│  • createView, updateView, deleteView                    │
│  • attachView, detachView, setChildren                   │
│  • Event Handling                                         │
│  • Integer View IDs (0 = root)                            │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────┐
│              Native Layer (iOS/Android)                   │
│  • UIView / View Creation                                 │
│  • Yoga Layout Engine                                     │
│  • Native View Updates                                    │
└──────────────────────────────────────────────────────────┘
```

## State Management Flow

```
Store<T>
    ↓ setState()
Listener Notification
    ↓
Component Update (via StoreHook)
    ↓
Component Re-render
    ↓
New VDOM Tree
    ↓
Reconciliation
    ↓
Native View Update
```

## Key Files

### Core Engine
- `packages/dcflight/lib/framework/renderer/engine/core/engine.dart`
  - Main VDOM engine
  - Rendering and reconciliation logic
  - Isolate-based parallel reconciliation
  - Incremental rendering with frame scheduler
  - Dual trees and effect list management

### Components
- `packages/dcflight/lib/framework/components/component_node.dart`
  - Base node class
- `packages/dcflight/lib/framework/components/dcf_element.dart`
  - Element node
- `packages/dcflight/lib/framework/components/component.dart`
  - Stateful and stateless components

### State Management
- `packages/dcflight/lib/framework/components/hooks/store.dart`
  - Store implementation
  - StoreRegistry

### Native Bridge
- iOS: `packages/dcflight/ios/Classes/Bridge/DCMauiBridge.swift`
- Android: `packages/dcflight/android/src/main/kotlin/com/dotcorr/dcflight/bridge/DCMauiBridgeImpl.kt`

## Getting Started

1. **Read VDOM Tree Structure** to understand the node hierarchy
2. **Read Rendering Flow** to understand how components become native views
3. **Read Stores and State** to understand state management
4. **Read Reconciliation** to understand how updates work efficiently

## Android Compose Integration

DCFlight supports Jetpack Compose for Android components. See [Android Compose Integration](../../ANDROID_COMPOSE_INTEGRATION.md) for:
- How `ComposeView` works with Yoga layout (it's just a View!)
- Compose component implementation patterns
- `getIntrinsicSize` pattern for Compose components
- Best practices and troubleshooting

**Key Insight:** `ComposeView` extends `View`, so Yoga measures it natively with constraints, allowing Compose Text to wrap correctly.

## Contributing

When adding new features or making changes:

1. Update relevant documentation files
2. Add examples and code snippets
3. Update comparison tables if applicable
4. Keep documentation in sync with code changes


# VDOM Tree Structure

## Overview

DCFlight uses a Virtual DOM (VDOM) architecture similar to React, but optimized for native mobile rendering. The VDOM tree is a lightweight representation of your UI that gets reconciled and rendered to native views.

## Tree Hierarchy

Similar to Flutter's Widget Tree → Element Tree → RenderObject Tree, DCFlight has:

```
Component Tree (Dart)
    ↓
VDOM Tree (DCFComponentNode)
    ↓
Native View Tree (iOS/Android)
```

## Node Types

### 1. DCFComponentNode (Base)

The base class for all VDOM nodes. Every node in the tree extends this.

**Properties:**
- `key`: Optional unique identifier for reconciliation
- `parent`: Reference to parent node
- `nativeViewId`: ID of the native view once rendered
- `contentViewId`: ID of the rendered content (for components)
- `renderedNode`: The rendered node from a component

**Location:** `packages/dcflight/lib/framework/components/component_node.dart`

### 2. DCFElement

Represents a primitive UI element (View, Text, Button, etc.)

**Properties:**
- `type`: Element type string (e.g., 'View', 'Text', 'Button')
- `elementProps`: Map of properties for the element
- `children`: List of child nodes

**Example:**
```dart
DCFElement(
  type: 'Text',
  elementProps: {'content': 'Hello World', 'textColor': '#000000'},
  children: [],
)
```

**Location:** `packages/dcflight/lib/framework/components/dcf_element.dart`

### 3. DCFStatefulComponent

A component with internal state that can trigger re-renders.

**Properties:**
- `state`: Internal component state
- `renderedNode`: The result of calling `render()`

**Lifecycle:**
- `initState()`: Called when component is created
- `render()`: Returns the rendered node tree
- `dispose()`: Called when component is removed

**Location:** `packages/dcflight/lib/framework/components/component.dart`

### 4. DCFStatelessComponent

A component without internal state (pure function component).

**Properties:**
- `renderedNode`: The result of calling `render()`

**Location:** `packages/dcflight/lib/framework/components/component.dart`

### 5. DCFragment

Groups multiple nodes without creating a parent view.

**Use Case:** When you need to return multiple siblings without a wrapper.

**Location:** `packages/dcflight/lib/framework/components/fragment.dart`

### 6. EmptyVDomNode

Represents absence of a node (useful for conditional rendering).

**Use Case:** When a component conditionally returns nothing.

## Tree Example

```dart
// Component Tree (Dart)
MyApp()
  └─ DCFView()
      ├─ DCFText(content: 'Hello')
      └─ DCFButton(title: 'Click')

// VDOM Tree (DCFComponentNode)
DCFStatefulComponent (MyApp)
  └─ renderedNode: DCFElement (type: 'View')
      ├─ DCFElement (type: 'Text', elementProps: {content: 'Hello'})
      └─ DCFElement (type: 'Button', elementProps: {title: 'Click'})

// Native View Tree (iOS/Android)
UIView / ViewGroup (viewId: 1)
  ├─ UILabel / TextView (viewId: 2)
  └─ UIButton / Button (viewId: 3)
```

## Node Relationships

### Parent-Child Links

Every node maintains a `parent` reference:
- Set automatically when adding children
- Used for traversal and reconciliation
- Updated during reconciliation

### View ID Mapping

The engine maintains a bidirectional mapping:
- `_nodesByViewId`: Map from viewId → DCFComponentNode
- `nativeViewId`: Property on node pointing to native view

**Purpose:** Fast lookup during reconciliation and event handling.

## Component Instance Tracking

The engine tracks component instances for automatic key inference:

### 1. Position-Based Tracking
- **Key Format:** `"parentViewId:index:type"`
- **Purpose:** Persist component instances across renders at same position
- **Storage:** `_componentInstancesByPosition`

### 2. Props-Based Tracking
- **Key Format:** `"parentViewId:index:type:propsHash"`
- **Purpose:** Match components with same props even if position changes
- **Storage:** `_componentInstancesByProps`

**Location:** `packages/dcflight/lib/framework/renderer/engine/core/engine.dart` (lines 42-50)

## Key System

### Explicit Keys
```dart
DCFElement(key: 'unique-id', type: 'Text', ...)
```

### Automatic Key Inference
When no key is provided, the engine uses:
- Position in parent
- Component type
- Props hash (for matching)

**Format:** `"parentViewId:index:type"` or `"parentViewId:index:type:propsHash"`

## Tree Traversal

### Depth-First Rendering
The engine renders nodes depth-first:
1. Render component → get renderedNode
2. Render renderedNode's children recursively
3. Attach to parent view

### Reconciliation Traversal
During reconciliation:
1. Compare old and new trees
2. Match nodes by key or position
3. Update only changed nodes
4. Remove unmounted nodes
5. Add new nodes

## Memory Management

### Node Lifecycle
1. **Creation:** Node created in Dart
2. **Mounting:** Node added to tree, native view created
3. **Updating:** Node reconciled, native view updated
4. **Unmounting:** Node removed from tree, native view deleted

### Cleanup
- Unmounted nodes are removed from `_nodesByViewId`
- Component instances are removed from tracking maps
- Native views are deleted via bridge

## Comparison with Flutter

| Flutter | DCFlight |
|---------|----------|
| Widget Tree | Component Tree (Dart) |
| Element Tree | VDOM Tree (DCFComponentNode) |
| RenderObject Tree | Native View Tree |
| Widget.build() | Component.render() |
| Element.update() | Reconciliation |
| RenderObject.layout() | Native Layout (Yoga) |


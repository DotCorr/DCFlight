# Components Documentation

This section covers DCFlight's component system, including how to create custom components, handle events, and use the Canvas API.

## Core Concepts

- **[Component Protocol](./COMPONENT_PROTOCOL.md)** - Interface for creating custom components
- **[Component Conventions](./COMPONENT_CONVENTIONS.md)** - Naming, structure, and best practices
- **[Event System](./EVENT_SYSTEM.md)** - Handling user interactions and gestures
- **[Registry System](./REGISTRY_SYSTEM.md)** - Component registration and lifecycle
- **[Tunnel System](./TUNNEL_SYSTEM.md)** - Cross-component communication

## Advanced Features

- **[Canvas API](./CANVAS_API.md)** - GPU-accelerated 2D rendering with Skia

## Quick Start

### Creating a Custom Component

```dart
class MyCustomComponent extends DCFStatelessComponent {
  final String title;
  
  MyCustomComponent({required this.title});
  
  @override
  DCFElement build(BuildContext context) {
    return DCFView(
      style: {'padding': 20},
      children: [
        DCFText(title, style: {'fontSize': 24}),
      ],
    );
  }
}
```

### Handling Events

```dart
DCFButton(
  onPress: () {
    print('Button pressed!');
  },
  child: DCFText('Click Me'),
)
```

### Using Canvas

```dart
DCFCanvas(
  width: 300,
  height: 300,
  shapes: [
    SkiaCircle(
      cx: 150,
      cy: 150,
      r: 50,
      color: 0xFFFF0000,
    ),
  ],
)
```

## Component Lifecycle

1. **Creation** - Component is instantiated
2. **Registration** - Registered with shadow tree
3. **Layout** - Yoga layout calculated
4. **Rendering** - Native view created/updated
5. **Events** - User interactions handled
6. **Disposal** - Cleanup when removed

## See Also

- [Framework Overview](../FRAMEWORK_OVERVIEW.md)
- [Architecture Comparison](../ARCHITECTURE_COMPARISON.md)
- [VDOM Documentation](../engine/vdom/README.md)

# WidgetToDCFAdaptor Guide

## Overview

`WidgetToDCFAdaptor` is a powerful DCFlight component that allows you to embed **any Flutter widget** directly into the DCFlight native component tree. This enables you to leverage Flutter's rich widget ecosystem (including third-party packages) within your DCFlight application, seamlessly mixing native DCF components with Flutter widgets.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Basic Usage](#basic-usage)
3. [Advanced Usage](#advanced-usage)
4. [How It Works](#how-it-works)
5. [Important Considerations](#important-considerations)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Basic Example

```dart
import 'package:dcflight/dcflight.dart';
import 'package:flutter/widgets.dart';

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(flex: 1),
      children: [
        // Embed a Flutter widget
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            return Container(
              color: Colors.blue,
              child: Center(
                child: Text(
                  'Hello from Flutter!',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            );
          },
          layout: DCFLayout(
            flex: 1,
            width: "100%",
            height: "100%",
          ),
        ),
      ],
    );
  }
}
```

---

## Basic Usage

### Using `WidgetToDCFAdaptor.builder()` (Recommended)

The `.builder()` constructor is **recommended** for reactive widgets that need to update when DCF state changes:

```dart
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    // This function is called on every render
    // Access DCF state here to make the widget reactive
    final counter = useState<int>(0);
    
    return GestureDetector(
      onTap: () {
        counter.setState(counter.state + 1);
      },
      child: Container(
        color: Colors.blue,
        child: Center(
          child: Text('Count: ${counter.state}'),
        ),
      ),
    );
  },
  layout: DCFLayout(
    flex: 1,
    width: "100%",
    height: "100%",
  ),
  styleSheet: DCFStyleSheet(
    // Optional styling
  ),
)
```

**Key Points:**
- `widgetBuilder` is called on **every render** of the DCF component
- This ensures Flutter widgets stay in sync with DCF state
- Use this for widgets that need to react to state changes

### Using `WidgetToDCFAdaptor()` (Static Widget)

For static widgets that don't need to update:

```dart
WidgetToDCFAdaptor(
  widget: Container(
    color: Colors.red,
    child: Text('Static Widget'),
  ),
  layout: DCFLayout(
    width: 200,
    height: 100,
  ),
)
```

**Note:** Static widgets won't update when DCF state changes. Use `.builder()` for reactive widgets.

---

## Advanced Usage

### Mixing Native DCF and Flutter Components

You can freely mix native DCF components with Flutter widgets:

```dart
DCFView(
  layout: DCFLayout(flex: 1),
  children: [
    // Native DCF component
    DCFText(
      content: "Native DCF Text",
      layout: DCFLayout(marginBottom: 20),
    ),
    
    // Flutter widget
    WidgetToDCFAdaptor.builder(
      widgetBuilder: () {
        return FlutterPackageWidget(); // Any Flutter widget
      },
      layout: DCFLayout(flex: 1),
    ),
    
    // Another native DCF component
    DCFButton(
      onPress: (data) {
        // Handle press
      },
      children: [DCFText(content: "Native Button")],
    ),
  ],
)
```

### Using Third-Party Flutter Packages

You can use **any Flutter package** that provides widgets:

```dart
import 'package:some_flutter_package/some_flutter_package.dart';

WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    return ThirdPartyFlutterWidget(
      // Package widget properties
    );
  },
  layout: DCFLayout(flex: 1),
)
```

### Interactive Flutter Widgets

Flutter widgets can receive touch events and be fully interactive:

```dart
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    return GestureDetector(
      onTap: () {
        print('Tapped!');
      },
      onLongPress: () {
        print('Long pressed!');
      },
      child: Container(
        color: Colors.blue,
        child: Center(
          child: Text('Tap me!'),
        ),
      ),
    );
  },
  layout: DCFLayout(flex: 1),
)
```

### Custom Paint and Canvas

You can use Flutter's `CustomPaint` for custom drawing:

```dart
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    return CustomPaint(
      painter: MyCustomPainter(),
      child: Container(),
    );
  },
  layout: DCFLayout(flex: 1),
)
```

### State Management Integration

Flutter widgets can access and modify DCF state:

```dart
class MyComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useState<int>(0);
    final colorIndex = useState<int>(0);
    
    return DCFView(
      layout: DCFLayout(flex: 1),
      children: [
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            // Access DCF state inside widget builder
            return Container(
              color: colors[colorIndex.state % colors.length],
              child: Center(
                child: Text('${counter.state}'),
              ),
            );
          },
          layout: DCFLayout(flex: 1),
        ),
        
        // Native DCF controls that update the state
        DCFButton(
          onPress: (data) {
            counter.setState(counter.state + 1);
          },
          children: [DCFText(content: "Increment")],
        ),
      ],
    );
  }
}
```

---

## How It Works

### Architecture Overview

```
┌─────────────────────────────────────────┐
│  DCF Component Tree                    │
│  ┌───────────────────────────────────┐ │
│  │ WidgetToDCFAdaptor                │ │
│  │  ↓                                 │ │
│  │ DCFElement (type: "FlutterWidget") │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Native Component (iOS/Android)         │
│  ┌───────────────────────────────────┐ │
│  │ DCFFlutterWidgetComponent         │ │
│  │  - Creates FlutterView container  │ │
│  │  - Manages widget lifecycle       │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Flutter Rendering Layer                 │
│  ┌───────────────────────────────────┐ │
│  │ FlutterWidgetRenderer             │ │
│  │  - Global Overlay                 │ │
│  │  - Widget registry                │ │
│  │  - Frame management               │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Flutter Engine                         │
│  ┌───────────────────────────────────┐ │
│  │ FlutterView (native)               │ │
│  │  - Renders Flutter widgets         │ │
│  │  - Handles touch events            │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Component Lifecycle

1. **Render Phase (Dart)**
   - `WidgetToDCFAdaptor.render()` is called
   - `widgetBuilder()` is invoked to get the current Flutter widget
   - Widget is registered in `_WidgetRegistry` with a unique `widgetId`
   - Returns `DCFElement` with type `"FlutterWidget"`

2. **Native Component Creation (iOS/Android)**
   - Native `DCFFlutterWidgetComponent` creates a container view
   - Container view is positioned using Yoga layout
   - Frame information is sent to Flutter via method channel

3. **Flutter Rendering**
   - `FlutterWidgetRenderer` receives frame information
   - Widget is retrieved from registry using `widgetId`
   - Widget is rendered into a global `Overlay` using `OverlayEntry`
   - Widget is positioned at the correct location using `Positioned`

4. **State Updates**
   - When DCF state changes, `render()` is called again
   - New widget is built from `widgetBuilder()`
   - Widget is updated in registry
   - `FlutterWidgetRenderer.markWidgetForRebuild()` triggers rebuild

### Key Components

#### `WidgetToDCFAdaptor` (Dart)
- DCF component that wraps Flutter widgets
- Manages widget registration and lifecycle
- Provides layout and styling properties

#### `DCFFlutterWidgetComponent` (Native)
- iOS: `DCFFlutterWidgetComponent.swift`
- Android: `DCFFlutterWidgetComponent.kt`
- Creates native container view
- Manages FlutterView frame and positioning
- Communicates with Flutter via method channel

#### `FlutterWidgetRenderer` (Dart)
- Manages global `Overlay` for rendering widgets
- Handles widget registry and frame management
- Coordinates widget rendering and updates
- Platform-specific pixel conversion (Android physical → logical pixels)

#### `_WidgetRegistry` (Dart)
- Stores Flutter widgets by `widgetId`
- Allows native side to retrieve widgets
- Ensures widgets are always fresh with latest state

---

## Important Considerations

### Layout and Sizing

- **Layout Properties**: Use `DCFLayout` to control size and position
  ```dart
  layout: DCFLayout(
    flex: 1,              // Fill available space
    width: "100%",       // Percentage width
    height: 200,          // Fixed height
    margin: 10,           // Margins
    padding: 20,          // Padding
  )
  ```

- **Platform Differences**: 
  - iOS: Native sends logical pixels (already correct)
  - Android: Native sends physical pixels (automatically converted to logical)

### Touch Events

- **Flutter widgets can receive touches**: The adaptor doesn't block touch events
- **Hit Testing**: Flutter's hit testing system handles touch events for interactive widgets
- **GestureDetector**: Use `GestureDetector`, `InkWell`, or other Flutter gesture widgets for interaction

### Performance

- **Widget Rebuilding**: `widgetBuilder()` is called on every DCF render
- **Optimization**: Keep widget building lightweight; avoid heavy computations in `widgetBuilder()`
- **State Management**: Use DCF state hooks (`useState`, `useRef`) for efficient updates

### Multiple Instances

- **Multiple Adaptors**: You can use multiple `WidgetToDCFAdaptor` instances in the same component tree
- **Isolation**: Each instance has its own `widgetId` and is rendered independently
- **No Conflicts**: Widgets are isolated and don't interfere with each other

### Flutter Context

- **MaterialApp/Scaffold**: Some Flutter widgets require `MaterialApp` or `Scaffold` context
- **Solution**: Wrap your widget in `MaterialApp` or `Scaffold` if needed:
  ```dart
  WidgetToDCFAdaptor.builder(
    widgetBuilder: () {
      return MaterialApp(
        home: Scaffold(
          body: YourWidget(),
        ),
      );
    },
  )
  ```

---

## Best Practices

### 1. Always Use `.builder()` for Reactive Widgets

```dart
// ✅ Good: Widget updates when state changes
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    final count = useState<int>(0);
    return Text('Count: ${count.state}');
  },
)

// ❌ Bad: Widget won't update
WidgetToDCFAdaptor(
  widget: Text('Count: ${count.state}'), // Static, won't update
)
```

### 2. Keep Widget Building Lightweight

```dart
// ✅ Good: Lightweight builder
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    final data = useRef<HeavyData>(...); // Computed once
    return MyWidget(data: data.value);
  },
)

// ❌ Bad: Heavy computation in builder
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    final heavyData = computeHeavyData(); // Computed every render!
    return MyWidget(data: heavyData);
  },
)
```

### 3. Use Proper Layout Constraints

```dart
// ✅ Good: Explicit sizing
layout: DCFLayout(
  flex: 1,
  width: "100%",
  height: "100%",
)

// ❌ Bad: Unbounded constraints
layout: DCFLayout(), // May cause layout issues
```

### 4. Handle State Updates Properly

```dart
// ✅ Good: State updates trigger rebuilds
final counter = useState<int>(0);

WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    return Text('${counter.state}'); // Updates automatically
  },
)

DCFButton(
  onPress: (data) {
    counter.setState(counter.state + 1); // Triggers rebuild
  },
)
```

### 5. Use GestureDetector for Interaction

```dart
// ✅ Good: Proper gesture handling
WidgetToDCFAdaptor.builder(
  widgetBuilder: () {
    return GestureDetector(
      onTap: () => handleTap(),
      child: Container(...),
    );
  },
)
```

---

## Troubleshooting

### Widget Not Rendering

**Problem**: Flutter widget doesn't appear on screen

**Solutions**:
1. Check that `layout` properties are set correctly
2. Ensure `widgetBuilder()` returns a valid widget
3. Verify the widget doesn't have zero size constraints
4. Check native logs for frame information

### Widget Not Updating

**Problem**: Widget doesn't update when DCF state changes

**Solutions**:
1. Use `.builder()` instead of static constructor
2. Ensure state is accessed inside `widgetBuilder()`
3. Check that `setState()` is being called correctly

### Touch Events Not Working

**Problem**: Taps/clicks don't work on Flutter widget

**Solutions**:
1. Wrap widget in `GestureDetector` or `InkWell`
2. Ensure widget has a non-transparent background
3. Check that widget isn't covered by other views

### Layout Issues on Android

**Problem**: Widget appears oversized or positioned incorrectly on Android

**Solutions**:
1. This is handled automatically by the framework (pixel conversion)
2. Ensure layout properties are set correctly
3. Check that constraints are not unbounded

### Performance Issues

**Problem**: App feels slow with Flutter widgets

**Solutions**:
1. Avoid heavy computations in `widgetBuilder()`
2. Use `useRef` for expensive data that doesn't need to rebuild
3. Limit the number of `WidgetToDCFAdaptor` instances
4. Profile with Flutter DevTools

---

## Examples

### Complete Example: Counter App

```dart
import 'package:dcflight/dcflight.dart';
import 'package:flutter/widgets.dart';

class CounterApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useState<int>(0);
    final colorIndex = useState<int>(0);
    
    final colors = [
      DCFColors.blue,
      DCFColors.green,
      DCFColors.orange,
      DCFColors.pink,
      DCFColors.purple,
    ];
    
    return DCFView(
      layout: DCFLayout(flex: 1),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.black,
      ),
      children: [
        // Flutter widget with interaction
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            return GestureDetector(
              onTap: () {
                counter.setState(counter.state + 1);
              },
              child: Container(
                color: DCFColors.black,
                child: CustomPaint(
                  painter: CounterPainter(
                    count: counter.state,
                    color: colors[colorIndex.state % colors.length],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${counter.state}',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: colors[colorIndex.state % colors.length],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Tap to increment',
                          style: TextStyle(
                            fontSize: 18,
                            color: DCFColors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          layout: DCFLayout(
            flex: 1,
            width: "100%",
            height: "100%",
          ),
        ),
        
        // Native DCF controls
        DCFView(
          layout: DCFLayout(
            width: "100%",
            padding: 20,
          ),
          children: [
            DCFButton(
              onPress: (data) {
                colorIndex.setState(colorIndex.state + 1);
              },
              children: [
                DCFText(content: "Change Color"),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Related Documentation

- [Component Protocol](COMPONENT_PROTOCOL.md) - Native component development
- [Framework Overview](FRAMEWORK_OVERVIEW.md) - DCFlight architecture
- [Event System](EVENT_SYSTEM.md) - Event handling in DCFlight

---

## Summary

`WidgetToDCFAdaptor` is a powerful bridge between DCFlight's native component system and Flutter's widget ecosystem. It allows you to:

- ✅ Embed any Flutter widget into DCFlight apps
- ✅ Use third-party Flutter packages seamlessly
- ✅ Mix native DCF and Flutter components freely
- ✅ Maintain full interactivity and state management
- ✅ Leverage Flutter's rich widget ecosystem

The adaptor handles all the complexity of rendering Flutter widgets within the native component tree, making it easy to use Flutter widgets alongside native DCF components.


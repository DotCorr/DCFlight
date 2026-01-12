# Worklet Usage Guide

## Quick Start

### 1. Define a Worklet

```dart
import 'package:dcflight/dcflight.dart';

@Worklet
double elasticBounce(double time, double damping, double frequency) {
  return Math.sin(time * frequency) * Math.exp(-time * damping);
}
```

### 2. Use in Component

```dart
ReanimatedView(
  worklet: elasticBounce,
  workletConfig: {
    'damping': 0.8,
    'frequency': 10.0,
    'targetProperty': 'scale',  // Optional: which property to animate
  },
)
```

**That's it!** No build steps, no code generation - just write and use!

## How It Works

### Runtime IR Interpretation

1. **Compilation (Automatic)**
   - When you use `@Worklet`, the system automatically compiles it to IR (Intermediate Representation)
   - IR is a JSON structure that describes your worklet's logic
   - IR is sent to native via `WorkletConfig`

2. **Runtime Execution (Native)**
   - Native `WorkletInterpreter` executes the IR directly on the UI thread
   - Just like React Native Reanimated's JavaScript interpreter
   - **Zero rebuilds needed** - hot reload works perfectly!

3. **Property Updates**
   - Worklet results are applied via `WorkletRuntime` API
   - Universal API works on any view (not component-specific)
   - Automatically handles shadow views and layout updates

### Flow

```
Dart: @Worklet double myWorklet(double time) => time * 2;
  ↓
Compile to IR: { type: 'binaryOp', operator: 'multiply', left: 'time', right: 2 }
  ↓
Send IR to Native (via WorkletConfig)
  ↓
Native: WorkletInterpreter.execute(ir, elapsed, config)
  ↓
Result: 4.0 (if elapsed = 2.0)
  ↓
WorkletRuntime.getView(viewId).setProperty("scale", 4.0)
  ↓
UI updates on UI thread (60fps)
```

## Supported Operations

See [WORKLET_SUPPORTED_OPERATIONS.md](./WORKLET_SUPPORTED_OPERATIONS.md) for full list.

**Supported:**
- ✅ Math operations (`+`, `-`, `*`, `/`, `%`)
- ✅ Math functions (`Math.sin`, `Math.cos`, etc.)
- ✅ List operations (`list[index]`, `list.length`)
- ✅ String operations (`string.substring`, `string.length`)
- ✅ Conditionals (`? :`)
- ✅ `WorkletRuntime` API calls (universal view manipulation)

**Not Supported:**
- ❌ Loops (`for`, `while`)
- ❌ Async operations
- ❌ I/O operations
- ❌ Complex object creation

## Examples

### Text Animation (Typewriter)

```dart
@Worklet
String typewriter(double elapsed, List<String> words, double speed) {
  final wordIndex = (elapsed / 2.0).floor() % words.length;
  final charIndex = ((elapsed % 2.0) * speed).floor();
  final word = words[wordIndex];
  return word.substring(0, charIndex.clamp(0, word.length));
}

AnimatedText(
  worklet: typewriter,
  workletConfig: {
    'words': ['Hello', 'World'],
    'speed': 10.0,
    'updateTextChild': true,  // Required for text worklets
  },
)
```

### Numeric Animation

```dart
@Worklet
double pulse(double time) {
  return Math.sin(time * Math.PI * 2) * 0.5 + 0.5;
}

ReanimatedView(
  worklet: pulse,
  workletConfig: {
    'targetProperty': 'opacity',  // Animate opacity
  },
)
```

### Complex Calculation with WorkletRuntime

```dart
@Worklet
double elasticBounce(double time, double damping, double frequency) {
  final scale = Math.sin(time * frequency) * Math.exp(-time * damping);
  // Use WorkletRuntime to update multiple views
  WorkletRuntime.getView(10).setProperty("scale", scale);
  WorkletRuntime.getView(11).setProperty("opacity", scale);
  return scale;
}

ReanimatedView(
  worklet: elasticBounce,
  workletConfig: {
    'damping': 0.8,
    'frequency': 10.0,
  },
)
```

## WorkletRuntime API

The `WorkletRuntime` API is **universal** - works on any view, not just specific components:

```dart
@Worklet
double animateView(double time) {
  // Works on ANY view (Button, Container, Image, etc.)
  WorkletRuntime.getView(viewId).setProperty("opacity", 0.5);
  WorkletRuntime.getView(viewId).setProperty("scale", 1.5);
  WorkletRuntime.getView(viewId).setProperty("translateX", 100.0);
  WorkletRuntime.getView(viewId).setProperty("rotation", 45.0);
  return time;
}
```

**Universal Properties:**
- `opacity` / `alpha` - Works on any view
- `scale`, `scaleX`, `scaleY` - Works on any view
- `translateX`, `translateY` - Works on any view
- `rotation`, `rotationX`, `rotationY` - Works on any view

**Component-Specific:**
- `text` - Only works on text views

## Performance

- ✅ **Zero bridge calls** during execution
- ✅ **Runs on UI thread** (60fps guaranteed)
- ✅ **Cannot be blocked** by Dart thread
- ✅ **Runtime interpretation** (like React Native Reanimated)
- ✅ **No rebuilds needed** (hot reload works!)
- ✅ **Low CPU usage** - efficient IR interpretation

## Troubleshooting

### "Worklet not executing"

**Solution:**
1. Check that worklet only uses supported operations
2. Verify `workletConfig` is provided
3. Check native logs for IR interpretation errors

### "Property not updating"

**Solution:**
1. Verify `targetProperty` is set in `workletConfig`
2. Check that viewId is correct (for `WorkletRuntime` calls)
3. Ensure property is supported (see WorkletRuntime API)

### "Text not updating"

**Solution:**
1. Set `updateTextChild: true` in `workletConfig`
2. Ensure worklet returns `String` type
3. Check that text view exists in hierarchy

## Next Steps

- See [WORKLET_RUNTIME_EXECUTION.md](./WORKLET_RUNTIME_EXECUTION.md) for technical details
- See [WORKLET_SUPPORTED_OPERATIONS.md](./WORKLET_SUPPORTED_OPERATIONS.md) for full operation list
- See [WORKLET_BUILD_INTEGRATION.md](./WORKLET_BUILD_INTEGRATION.md) for build-time integration (future)

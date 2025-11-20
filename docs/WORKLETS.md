# Worklets - UI Thread Execution System

## Overview

Worklets are **framework-level infrastructure** that enable custom functions to execute entirely on the native UI thread with zero bridge calls. This provides smooth 60fps animations and high-performance rendering even when the Dart thread is busy.

## Architecture

### Framework-Level Design

Worklets are implemented in the **framework layer** (`dcflight`), making them available to all components and packages:

```
┌─────────────────────────────────────────────────────────┐
│              Framework Layer (dcflight)                 │
│  - @Worklet annotation                                  │
│  - WorkletConfig class                                  │
│  - WorkletExecutor utility                              │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────▼──────┐ ┌────▼─────┐ ┌──────▼──────┐
│ dcf_reanimated│ │ dcf_     │ │ Custom      │
│               │ │ primitives│ │ Packages    │
│ Uses worklets │ │ Uses     │ │ Can use     │
│ for animations│ │ worklets │ │ worklets    │
└───────────────┘ └──────────┘ └──────────────┘
```

### Execution Flow

```
Dart Thread                    Native UI Thread
     │                               │
     │  Define worklet function      │
     │  @Worklet                     │
     │  double update(double t)      │
     │                               │
     │  Serialize worklet            │
     ├──────────────────────────────>│
     │  (One-time config)            │
     │                               │
     │  (No more calls)              │ (Runs 60 times/second)
     │                               │ (Zero bridge calls)
     │                               │ (Pure UI thread)
     │                               │
     │  "Animation complete"         │
     │<──────────────────────────────┤
```

## Key Benefits

### 1. Zero Bridge Calls During Execution

**Without Worklets:**
- 60+ bridge calls per second (one per frame)
- Serialization overhead on every call
- Dart thread can block animations
- Result: 20-30fps, stuttering

**With Worklets:**
- 1 bridge call (configuration only)
- Native execution on UI thread
- Cannot be blocked by Dart thread
- Result: Smooth 60fps guaranteed

### 2. Type Safety

Full Dart type checking provides compile-time guarantees:

```dart
@Worklet
double updateParticle(double time, double initialX) {
  // Type-safe - compiler ensures correctness
  return initialX + (time * 50);
}
```

### 3. Reusable Across All Components

Since worklets are in the framework, **any component** can use them:

- ✅ DCF Reanimated (animations)
- ✅ GPU Component (particle systems)
- ✅ Custom components (your packages)
- ✅ Any future component

## Use Cases

### 1. Custom Animation Logic

When simple `from`/`to` values aren't enough:

```dart
@Worklet
double elasticBounce(double time) {
  // Complex physics calculation
  final damping = 0.8;
  final frequency = 8.0;
  final omega = frequency * 2 * 3.14159;
  final exponential = pow(2, -damping * time);
  final sine = sin((omega * time) + acos(damping));
  return 1 - exponential * sine;
}

ReanimatedView(
  worklet: elasticBounce,
  workletConfig: {'duration': 2000},
)
```

### 2. Particle Systems

Perfect for confetti, explosions, or any particle effect:

```dart
@Worklet
double updateConfettiParticle(double time, double initialX, double initialY) {
  final gravity = 9.8;
  final x = initialX + (time * 50); // velocity
  final y = initialY + (0.5 * gravity * time * time); // physics
  return y;
}

DCFConfetti(
  particleCount: 50,
  duration: 2000,
  // Uses worklet internally for 60fps particles
)
```

### 3. Gesture-Driven Animations

Real-time response to gestures:

```dart
@Worklet
double followGesture(double gestureX, double gestureY) {
  // Smoothly follow gesture with physics
  // No bridge calls = instant response
  return calculateSmoothPosition(gestureX, gestureY);
}
```

### 4. Complex Easing Functions

Custom easing that isn't in presets:

```dart
@Worklet
double customEase(double progress) {
  // Your custom easing calculation
  return 1 - pow(2, -10 * progress) * sin((progress * 10 - 0.75) * (2 * PI / 3));
}
```

## API Reference

### @Worklet Annotation

Marks a function as a worklet that runs on the UI thread:

```dart
@Worklet
double myWorklet(double time) {
  return time * 2;
}
```

### WorkletConfig

Configuration for worklet execution:

```dart
final config = WorkletExecutor.serialize(myWorklet);
// config.id - Unique identifier
// config.serializedFunction - Serialized function
// config.parameterNames - Parameter names
// config.returnType - Return type
```

### WorkletExecutor

Utility for serializing worklets:

```dart
@Worklet
double update(double time) => time * 2;

final config = WorkletExecutor.serialize(update);
```

### Type Definitions

```dart
// Worklet with no parameters
WorkletFunction<T>

// Worklet with one parameter
WorkletFunction1<T, P1>

// Worklet with two parameters
WorkletFunction2<T, P1, P2>

// Worklet with three parameters
WorkletFunction3<T, P1, P2, P3>

// Worklet with four parameters
WorkletFunction4<T, P1, P2, P3, P4>
```

## Native Implementation

### iOS (CADisplayLink)

```swift
// Framework provides worklet config via props
if let workletData = props["worklet"] as? [String: Any] {
    // Execute worklet on UI thread via CADisplayLink
    displayLink = CADisplayLink(target: self, selector: #selector(update))
    displayLink?.add(to: .main, forMode: .common)
}
```

### Android (Choreographer)

```kotlin
// Framework provides worklet config via props
if (props["worklet"] is Map<*, *>) {
    // Execute worklet on UI thread via Choreographer
    choreographer.postFrameCallback { frameTimeNanos ->
        // Execute worklet
        choreographer.postFrameCallback(this)
    }
}
```

## Adding Worklet Support to Components

### Step 1: Dart Side

Accept worklet parameter in your component:

```dart
class MyComponent extends DCFStatelessComponent {
  final Function? worklet;
  final Map<String, dynamic>? workletConfig;
  
  MyComponent({
    this.worklet,
    this.workletConfig,
    // ... other props
  });
  
  @override
  DCFComponentNode render() {
    final props = {
      // ... other props
    };
    
    if (worklet != null) {
      final serialized = WorkletExecutor.serialize(worklet!);
      props['worklet'] = serialized.toMap();
      if (workletConfig != null) {
        props['workletConfig'] = workletConfig;
      }
    }
    
    return DCFElement(type: 'MyComponent', elementProps: props);
  }
}
```

### Step 2: Native Side

Implement worklet execution:

**iOS:**
```swift
if let workletData = props["worklet"] as? [String: Any] {
    // Configure worklet execution
    configureWorklet(workletData, config: props["workletConfig"])
    
    // Start CADisplayLink for 60fps execution
    startDisplayLink()
}
```

**Android:**
```kotlin
if (props["worklet"] is Map<*, *>) {
    val workletData = props["worklet"] as Map<String, Any?>
    val config = props["workletConfig"] as? Map<String, Any?>
    
    // Configure worklet execution
    configureWorklet(workletData, config)
    
    // Start Choreographer for 60fps execution
    startFrameCallback()
}
```

## Performance Characteristics

| Metric | Without Worklets | With Worklets |
|--------|------------------|---------------|
| Bridge Calls | 60+ per second | 1 (config only) |
| Thread | Dart/JS thread | UI thread |
| Can Be Blocked | Yes (GC, computation) | No (native) |
| FPS | 20-30fps typical | 60fps guaranteed |
| Memory | High (bridge overhead) | Low (native only) |
| Battery | High (constant communication) | Low (native execution) |

## Best Practices

### ✅ Do

- Use worklets for custom animation logic
- Use worklets for particle systems
- Use worklets for gesture-driven animations
- Use worklets when you need 60fps performance
- Keep worklet functions simple and focused

### ❌ Don't

- Use worklets for simple animations (use `AnimatedStyle` instead)
- Use worklets for one-time calculations (use regular Dart functions)
- Make worklets too complex (keep them focused)
- Use worklets for static transforms (use `DCFLayout` transforms)

## Examples

### Confetti Animation

```dart
final showConfetti = useState(false);

DCFButton(
  onPress: (_) => showConfetti.setState(true),
  children: [DCFText(content: "Celebrate!")],
),

if (showConfetti.state)
  DCFConfetti(
    particleCount: 50,
    duration: 2000,
    onComplete: () => showConfetti.setState(false),
  ),
```

### Custom Bounce Animation

```dart
@Worklet
double customBounce(double time) {
  final gravity = 9.8;
  final bounce = 0.6;
  // Complex bounce physics
  return calculateBounce(time, gravity, bounce);
}

ReanimatedView(
  worklet: customBounce,
  workletConfig: {'duration': 2000},
  children: [DCFText(content: "Bouncing!")],
)
```

## Comparison with React Native

| Feature | React Native Reanimated | DCFlight Worklets |
|---------|------------------------|-------------------|
| Type Safety | TypeScript | Dart (Stronger) |
| UI Thread | Worklets | Worklets ✅ |
| Bridge Calls | 0 during exec | 0 during exec ✅ |
| Performance | 60fps | 60fps ✅ |
| Framework Level | Package-level | Framework-level ✅ |
| Reusability | Package-specific | All components ✅ |

## Migration from Package-Level

Worklets were moved from `dcf_reanimated` to framework:

- ✅ **Before**: Only dcf_reanimated could use worklets
- ✅ **After**: All components can use worklets
- ✅ **Backward Compatible**: Existing code still works
- ✅ **Better Architecture**: Infrastructure in framework

## Troubleshooting

### Worklet Not Executing

- Ensure worklet is properly serialized
- Check native component implements worklet execution
- Verify worklet config is passed correctly

### Performance Issues

- Ensure worklet runs on UI thread (not Dart thread)
- Check for unnecessary complexity in worklet function
- Verify no bridge calls during execution

### Type Errors

- Use proper type annotations
- Ensure worklet signature matches expected types
- Check parameter types match native expectations

## Summary

Worklets provide:

- ✅ **Framework-level infrastructure** - Available to all components
- ✅ **Zero bridge calls** - During execution
- ✅ **60fps guaranteed** - UI thread execution
- ✅ **Type safety** - Full Dart type checking
- ✅ **Reusable** - Any component can use worklets
- ✅ **High performance** - Native execution

Worklets are the foundation for high-performance animations and rendering in DCFlight, enabling smooth 60fps experiences across all components and packages.


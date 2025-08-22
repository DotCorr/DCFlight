# DCF Reanimated Documentation

**Version:** 1.0.0  
**A powerful animation library for DCFlight that runs entirely on the UI thread**

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Core Concepts](#core-concepts)
4. [API Reference](#api-reference)
5. [Components](#components)
6. [Animation Values](#animation-values)
7. [Animated Styles](#animated-styles)
8. [Hooks](#hooks)
9. [Presets](#presets)
10. [Examples](#examples)
11. [Performance](#performance)
12. [Migration Guide](#migration-guide)

## Overview

DCF Reanimated is a high-performance animation library built specifically for DCFlight applications. Unlike traditional animation libraries that rely on bridge communication, DCF Reanimated runs **entirely on the UI thread** using native iOS `CADisplayLink` and Android equivalent systems.

### Key Features

- 🚀 **Pure UI Thread Execution** - Zero bridge calls during animations
- ⚡ **60fps Performance** - Native CADisplayLink-driven animations
- 🎯 **Declarative API** - Configure once, animate smoothly
- 🔧 **Zero Setup** - No babel plugins or worklets required
- 📱 **Cross Platform** - iOS and Android support
- 🎨 **Rich Animation Types** - Transform, opacity, layout, and color animations

### How It Works

DCF Reanimated uses a **"configure once, animate purely"** architecture:

1. **Configuration Phase**: Animation parameters are sent via props (single bridge call)
2. **Animation Phase**: Native animation engine runs on UI thread with zero bridge interference
3. **Completion Phase**: Events are fired back to Dart when animations complete

```
Dart (Configuration) → Bridge → Native (Pure UI Thread Animation)
```

## Installation

Add DCF Reanimated to your `pubspec.yaml`:

```yaml
dependencies:
  dcf_reanimated: ^1.0.0
```

### Initialization

DCF Reanimated automatically initializes when you first use `ReanimatedView`. No manual setup required!

```dart
import 'package:dcf_reanimated/dcf_reanimated.dart';

// Ready to use! 🎉
```

## Core Concepts

### Animation Philosophy

DCF Reanimated follows these core principles:

1. **Declarative Configuration**: Describe what you want, not how to do it
2. **UI Thread Isolation**: Animations run independently of Dart/JavaScript
3. **Minimal Bridge Usage**: Configure once, animate smoothly
4. **Native Performance**: Leverage platform-specific animation systems

### Animation Lifecycle

```
Create → Configure → Start → Update (60fps) → Complete
   ↓         ↓        ↓           ↓            ↓
  Props → Native → UI Thread → CADisplayLink → Events
```

## API Reference

### ReanimatedView

The main component for creating animated views.

```dart
ReanimatedView({
  required List<DCFComponentNode> children,
  AnimatedStyle? animatedStyle,
  LayoutProps layout = const LayoutProps(),
  StyleSheet styleSheet = const StyleSheet(),
  String? animationId,
  bool autoStart = true,
  int startDelay = 0,
  void Function()? onAnimationStart,
  void Function()? onAnimationComplete,
  void Function()? onAnimationRepeat,
  Map<String, dynamic>? events,
  Key? key,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `children` | `List<DCFComponentNode>` | required | Child components to render |
| `animatedStyle` | `AnimatedStyle?` | `null` | Animation configuration |
| `layout` | `LayoutProps` | `LayoutProps()` | Layout properties |
| `styleSheet` | `StyleSheet` | `StyleSheet()` | Static styling |
| `animationId` | `String?` | `null` | Unique identifier for animation |
| `autoStart` | `bool` | `true` | Whether to start animation automatically |
| `startDelay` | `int` | `0` | Delay before starting (milliseconds) |
| `onAnimationStart` | `Function()?` | `null` | Called when animation starts |
| `onAnimationComplete` | `Function()?` | `null` | Called when animation completes |
| `onAnimationRepeat` | `Function()?` | `null` | Called when animation repeats |
| `events` | `Map<String, dynamic>?` | `null` | Additional event handlers |

## Animation Values

### ReanimatedValue

Defines a single property animation configuration.

```dart
ReanimatedValue({
  required double from,
  required double to,
  int duration = 300,
  String curve = 'easeInOut',
  int delay = 0,
  bool repeat = false,
  int? repeatCount,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `from` | `double` | required | Starting value |
| `to` | `double` | required | Ending value |
| `duration` | `int` | `300` | Duration in milliseconds |
| `curve` | `String` | `'easeInOut'` | Animation easing curve |
| `delay` | `int` | `0` | Delay before starting |
| `repeat` | `bool` | `false` | Whether to repeat |
| `repeatCount` | `int?` | `null` | Number of repetitions (null = infinite) |

#### Supported Curves

- `'linear'` - Constant speed
- `'easeIn'` - Slow start, fast end
- `'easeOut'` - Fast start, slow end
- `'easeInOut'` - Slow start and end
- `'spring'` - Natural spring motion

### SharedValue

A reactive value that can be animated over time.

```dart
final scale = useSharedValue(1.0);

// Animate to new value
final animationConfig = scale.withTiming(
  toValue: 1.5,
  duration: 300,
  curve: 'easeOut',
);
```

#### Methods

- **`withTiming()`** - Create timing animation
- **`withSpring()`** - Create spring animation  
- **`withRepeat()`** - Create repeating animation

## Animated Styles

### AnimatedStyle

Container for multiple property animations.

```dart
AnimatedStyle()
  .transform(
    scale: ReanimatedValue(from: 0, to: 1, duration: 300),
    rotation: ReanimatedValue(from: 0, to: 6.28, duration: 1000),
  )
  .opacity(ReanimatedValue(from: 0, to: 1, duration: 500))
  .backgroundColor(ReanimatedValue(from: 0, to: 1, duration: 300));
```

### Transform Properties

```dart
AnimatedStyle().transform({
  ReanimatedValue? scale,        // Uniform scale
  ReanimatedValue? scaleX,       // X-axis scale
  ReanimatedValue? scaleY,       // Y-axis scale
  ReanimatedValue? translateX,   // X translation
  ReanimatedValue? translateY,   // Y translation
  ReanimatedValue? rotation,     // Z-axis rotation (radians)
  ReanimatedValue? rotationX,    // X-axis rotation (radians)
  ReanimatedValue? rotationY,    // Y-axis rotation (radians)
})
```

### Opacity

```dart
AnimatedStyle().opacity(ReanimatedValue(from: 0, to: 1))
```

### Background Color

```dart
// Value represents hue (0-1)
AnimatedStyle().backgroundColor(ReanimatedValue(from: 0, to: 0.5))
```

### Layout Properties

```dart
AnimatedStyle().layout({
  ReanimatedValue? width,
  ReanimatedValue? height,
  ReanimatedValue? top,
  ReanimatedValue? left,
  ReanimatedValue? right,
  ReanimatedValue? bottom,
})
```

## Hooks

### useSharedValue

Create a shared value for animations.

```dart
class MyComponent extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final opacity = useSharedValue(0.0);
    
    final animatedStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .opacity(opacity.withTiming(toValue: 1.0, duration: 500));
    });
    
    return ReanimatedView(
      animatedStyle: animatedStyle,
      children: [/* ... */],
    );
  }
}
```

### useAnimatedStyle

Create animated styles with dependencies.

```dart
final animatedStyle = useAnimatedStyle(
  () => AnimatedStyle().transform(
    scale: scale.withTiming(toValue: isPressed ? 0.95 : 1.0),
  ),
  dependencies: [isPressed], // Recreate when isPressed changes
);
```

### useAnimatedCallback

Register callbacks for animation events.

```dart
useAnimatedCallback(
  () => print('Animation completed!'),
  animationId: 'my-animation',
  dependencies: [someValue],
);
```

## Presets

DCF Reanimated includes common animation presets via the `Reanimated` class.

### Entrance Animations

#### fadeIn()
```dart
ReanimatedView(
  animatedStyle: Reanimated.fadeIn(
    duration: 300,
    delay: 0,
    curve: 'easeInOut',
  ),
  children: [/* ... */],
)
```

#### scaleIn()
```dart
ReanimatedView(
  animatedStyle: Reanimated.scaleIn(
    fromScale: 0.0,
    toScale: 1.0,
    duration: 300,
    curve: 'easeOut',
  ),
  children: [/* ... */],
)
```

#### slideInRight() / slideInLeft()
```dart
ReanimatedView(
  animatedStyle: Reanimated.slideInRight(
    distance: 100.0,
    duration: 300,
    curve: 'easeOut',
  ),
  children: [/* ... */],
)
```

### Exit Animations

#### fadeOut()
```dart
ReanimatedView(
  animatedStyle: Reanimated.fadeOut(
    duration: 300,
    curve: 'easeInOut',
  ),
  children: [/* ... */],
)
```

### Continuous Animations

#### bounce()
```dart
ReanimatedView(
  animatedStyle: Reanimated.bounce(
    bounceScale: 1.2,
    duration: 600,
    repeat: true,
    repeatCount: 3,
  ),
  children: [/* ... */],
)
```

#### pulse()
```dart
ReanimatedView(
  animatedStyle: Reanimated.pulse(
    minOpacity: 0.5,
    maxOpacity: 1.0,
    duration: 1000,
    repeat: true,
  ),
  children: [/* ... */],
)
```

#### rotate()
```dart
ReanimatedView(
  animatedStyle: Reanimated.rotate(
    fromRotation: 0.0,
    toRotation: 6.28, // 2π (full rotation)
    duration: 1000,
    repeat: true,
  ),
  children: [/* ... */],
)
```

### Complex Animations

#### slideScaleFadeIn()
```dart
ReanimatedView(
  animatedStyle: Reanimated.slideScaleFadeIn(
    slideDistance: 50.0,
    fromScale: 0.8,
    toScale: 1.0,
    fromOpacity: 0.0,
    toOpacity: 1.0,
    duration: 400,
    curve: 'easeOut',
  ),
  children: [/* ... */],
)
```

## Examples

### Basic Fade In

```dart
ReanimatedView(
  animatedStyle: Reanimated.fadeIn(duration: 500),
  children: [
    DCFText(content: "Hello World!"),
  ],
)
```

### Interactive Scale Animation

```dart
class ScaleButton extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final isPressed = useState(false);
    final scale = useSharedValue(1.0);
    
    final animatedStyle = useAnimatedStyle(() {
      return AnimatedStyle().transform(
        scale: scale.withTiming(
          toValue: isPressed.state ? 0.95 : 1.0,
          duration: 150,
          curve: 'easeOut',
        ),
      );
    }, dependencies: [isPressed.state]);
    
    return ReanimatedView(
      animatedStyle: animatedStyle,
      children: [
        DCFButton(
          buttonProps: DCFButtonProps(title: "Press Me"),
          onPress: (_) => isPressed.setState(!isPressed.state),
        ),
      ],
    );
  }
}
```

### Complex Entrance Sequence

```dart
class AnimatedCard extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      children: [
        // Background fade in
        ReanimatedView(
          animationId: "background",
          animatedStyle: Reanimated.fadeIn(duration: 300),
          children: [DCFView(/* background */)],
        ),
        
        // Card slide in with scale
        ReanimatedView(
          animationId: "card",
          animatedStyle: Reanimated.slideScaleFadeIn(
            slideDistance: 100,
            duration: 600,
            delay: 200,
          ),
          onAnimationComplete: () => print("Card animation done!"),
          children: [
            DCFText(content: "Animated Card"),
          ],
        ),
        
        // Button bounce in
        ReanimatedView(
          animationId: "button",
          animatedStyle: Reanimated.bounce(
            bounceScale: 1.1,
            duration: 400,
            delay: 800,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Action"),
              onPress: (_) => print("Button pressed!"),
            ),
          ],
        ),
      ],
    );
  }
}
```

### Loading Spinner

```dart
ReanimatedView(
  animatedStyle: Reanimated.rotate(
    duration: 1000,
    repeat: true,
  ),
  children: [
    DCFIcon(icon: "loading"),
  ],
)
```

### Staggered List Animation

```dart
class AnimatedList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final items = ['Item 1', 'Item 2', 'Item 3', 'Item 4'];
    
    return DCFView(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        
        return ReanimatedView(
          animationId: "item_$index",
          animatedStyle: Reanimated.slideInLeft(
            distance: 100,
            duration: 300,
            delay: index * 100, // Stagger by 100ms
            curve: 'easeOut',
          ),
          children: [
            DCFText(content: item),
          ],
        );
      }).toList(),
    );
  }
}
```

## Performance

### Why DCF Reanimated is Fast

1. **Pure UI Thread Execution**: Animations run on native UI thread using `CADisplayLink`
2. **Zero Bridge Calls**: No communication overhead during animation
3. **Native Property Updates**: Direct manipulation of UIView properties
4. **Optimized Configuration**: All parameters sent in single bridge call

### Performance Characteristics

- **Animation FPS**: 60fps (tied to display refresh rate)
- **Bridge Calls**: 1 per animation (configuration only)
- **Memory**: Minimal overhead (native animation state only)
- **CPU**: Efficient native code execution

### Best Practices

#### ✅ Do
- Use `animationId` for debugging and callbacks
- Combine multiple properties in single `AnimatedStyle`
- Leverage presets for common patterns
- Use `autoStart: false` for controlled timing

#### ❌ Don't
- Create new `ReanimatedValue` instances on every render
- Use excessive `repeatCount` values
- Animate layout properties frequently (prefer transform)
- Chain multiple `ReanimatedView` components unnecessarily

### Performance Comparison

| Feature | DCF Reanimated | Traditional Animated |
|---------|----------------|---------------------|
| Bridge Calls | 1 (config) | 60+ per second |
| Thread | UI Thread | Bridge Thread |
| FPS | 60fps | 30-45fps typical |
| Memory | Low | High (bridge overhead) |

## Migration Guide

### From Traditional Animations

**Before (Traditional)**:
```dart
// Multiple bridge calls, lower performance
AnimationController controller;
Tween<double> tween;
// Manual animation management
```

**After (DCF Reanimated)**:
```dart
// Single configuration, pure UI thread
ReanimatedView(
  animatedStyle: Reanimated.fadeIn(duration: 300),
  children: [/* content */],
)
```

### From React Native Reanimated

DCF Reanimated uses a similar API philosophy but with key differences:

| React Native Reanimated | DCF Reanimated |
|-------------------------|----------------|
| `useSharedValue()` | `useSharedValue()` ✅ |
| `useAnimatedStyle()` | `useAnimatedStyle()` ✅ |
| `withTiming()` | `ReanimatedValue()` |
| `Animated.View` | `ReanimatedView` |
| Worklets | Native UI Thread |

**Migration Example**:

```javascript
// React Native Reanimated
const opacity = useSharedValue(0);
const animatedStyle = useAnimatedStyle(() => ({
  opacity: withTiming(opacity.value, { duration: 300 })
}));
```

```dart
// DCF Reanimated
final opacity = useSharedValue(0.0);
final animatedStyle = useAnimatedStyle(() =>
  AnimatedStyle().opacity(
    opacity.withTiming(toValue: 1.0, duration: 300)
  )
);
```

## Troubleshooting

### Common Issues

**Animation not starting**
- Ensure `autoStart: true` (default)
- Check `animatedStyle` is properly configured
- Verify `animationId` is unique

**Poor performance**
- Avoid animating layout properties frequently
- Use transform properties instead
- Check for excessive `repeatCount`

**Events not firing**
- Ensure `animationId` is set
- Check callback function is properly bound
- Verify animation actually completes

### Debug Tips

```dart
ReanimatedView(
  animationId: "debug_animation", // Always set for debugging
  animatedStyle: /* ... */,
  onAnimationStart: () => print("Animation started"),
  onAnimationComplete: () => print("Animation completed"),
  children: [/* ... */],
)
```

## Native Implementation Details

### iOS Architecture

DCF Reanimated uses the following iOS components:

- **CADisplayLink**: 60fps animation driver
- **CGAffineTransform**: Transform animations
- **UIView properties**: Direct property manipulation
- **Grand Central Dispatch**: Thread management

### Animation Flow

1. **Configuration**: Dart → Bridge → Native configuration
2. **Execution**: CADisplayLink → Animation Engine → UIView updates
3. **Completion**: Native events → Bridge → Dart callbacks

This architecture ensures maximum performance while maintaining a clean, declarative API.

---

**DCF Reanimated** - Built with ❤️ for smooth, performant animations in DCFlight applications.
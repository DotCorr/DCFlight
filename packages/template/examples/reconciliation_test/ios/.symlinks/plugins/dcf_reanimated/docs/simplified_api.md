# DCF Reanimated Simplified API

## Overview

DCF Reanimated now provides simplified methods for common animation patterns, removing the complexity of manual `ReanimatedValue` construction for real-time shared value animations.

## Problem Solved

**Before (Complex)**:
```dart
final animatedStyle = useAnimatedStyle(() {
  final currentWidth = sharedValue.state * 300;
  return AnimatedStyle()
    .layout(width: ReanimatedValue(
      from: currentWidth,
      to: currentWidth, 
      duration: 1,
      curve: 'linear',
    ));
}, dependencies: [sharedValue.state]);
```

**After (Simple)**:
```dart
final animatedStyle = useAnimatedStyle(() {
  return AnimatedStyle()
    .widthValue(sharedValue.state * 300);
}, dependencies: [sharedValue.state]);
```

## New Simplified Methods

### Layout Properties

#### `.widthValue(double value, {bool asPercentage = false})`
Animates width from a shared value.
- `value`: The current width value
- `asPercentage`: If true, converts 0.0→1.0 to 0%→100%

```dart
// Pixel-based width animation
.widthValue(slider.state * 300) // 0px → 300px

// Percentage-based width animation  
.widthValue(slider.state, asPercentage: true) // 0% → 100%
```

#### `.heightValue(double value, {bool asPercentage = false})`
Animates height from a shared value.

```dart
.heightValue(slider.state * 200) // 0px → 200px
```

### Visual Properties

#### `.opacityValue(double value)`
Animates opacity from a shared value (0.0 → 1.0).

```dart
.opacityValue(slider.state) // Fade in/out
```

### Transform Properties

#### `.scaleValue(double value)`
Animates scale from a shared value.

```dart
.scaleValue(0.5 + slider.state * 0.5) // 0.5x → 1.0x scale
```

#### `.translateXValue(double value)`
Animates horizontal translation from a shared value.

```dart
.translateXValue(slider.state * 100) // Slide 100px horizontally
```

#### `.translateYValue(double value)`
Animates vertical translation from a shared value.

```dart
.translateYValue(slider.state * 50) // Slide 50px vertically
```

## Complete Example

```dart
class AnimatedComponent extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final animationValue = useState<double>(0.0);
    
    final animatedStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .widthValue(animationValue.state * 300)     // Width: 0px → 300px
        .opacityValue(animationValue.state)         // Opacity: 0.0 → 1.0  
        .scaleValue(0.8 + animationValue.state * 0.2); // Scale: 0.8x → 1.0x
    }, dependencies: [animationValue.state]);
    
    return DCFView(
      children: [
        DCFSlider(
          value: animationValue.state,
          onValueChange: (v) => animationValue.setState(v['value']),
        ),
        ReanimatedView(
          animatedStyle: animatedStyle,
          children: [DCFText(content: "Animated!")],
        ),
      ],
    );
  }
}
```

## Benefits

1. **Reduced Boilerplate**: No manual `ReanimatedValue` construction
2. **Automatic Real-time Tracking**: Built-in instant duration and linear curve
3. **Type Safety**: Compile-time validation of animation properties
4. **Consistent API**: All methods follow the same pattern
5. **Performance**: Still runs purely on UI thread with zero bridge calls

## Migration Guide

### Old Layout Animation
```dart
// Old way
.layout(width: ReanimatedValue(
  from: value, to: value, duration: 1, curve: 'linear'
))

// New way
.widthValue(value)
```

### Old Transform Animation
```dart
// Old way
.transform(scale: ReanimatedValue(
  from: value, to: value, duration: 1, curve: 'linear'
))

// New way
.scaleValue(value)
```

### Old Opacity Animation
```dart
// Old way  
.opacity(ReanimatedValue(
  from: value, to: value, duration: 1, curve: 'linear'
))

// New way
.opacityValue(value)
```

## Advanced Usage

The simplified methods are perfect for real-time animations driven by sliders, gestures, or shared values. For complex timed animations, you can still use the original `ReanimatedValue` API with timing functions like `withTiming()`, `withSpring()`, etc.

```dart
// Real-time animation (use simplified API)
.widthValue(gestureValue.state * 200)

// Timed animation (use original API)
.layout(width: ReanimatedValue.withTiming(
  from: 0, to: 200, duration: 500, curve: 'easeInOut'
))
```

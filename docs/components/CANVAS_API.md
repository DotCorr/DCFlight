# Canvas API Documentation

GPU-accelerated 2D rendering with Skia for high-performance graphics.

## Overview

The DCFlight Canvas API provides a powerful, GPU-accelerated 2D rendering system using Skia. It's designed for:
- Custom graphics and visualizations
- Particle systems and animations
- Charts and data visualization
- Game rendering
- Complex UI effects

## Table of Contents

- [Basic Usage](#basic-usage)
- [Shapes](#shapes)
- [Paint Properties](#paint-properties)
- [Transformations](#transformations)
- [Gradients & Shaders](#gradients--shaders)
- [Filters & Effects](#filters--effects)
- [Performance Optimization](#performance-optimization)
- [Platform Details](#platform-details)

---

## Basic Usage

### Simple Canvas

```dart
import 'package:dcf_reanimated/dcf_reanimated.dart';

class MyComponent extends DCFStatelessComponent {
  @override
  DCFElement build(BuildContext context) {
    return DCFCanvas(
      width: 300,
      height: 300,
      shapes: [
        SkiaCircle(
          cx: 150,
          cy: 150,
          r: 50,
          color: 0xFFFF0000, // Red
        ),
      ],
    );
  }
}
```

### Animated Canvas

```dart
class AnimatedCanvas extends DCFStatefulComponent {
  @override
  DCFElement build(BuildContext context) {
    final rotation = useState(0.0);
    
    useEffect(() {
      final timer = Timer.periodic(Duration(milliseconds: 16), (_) {
        rotation.setState(rotation.state + 0.05);
      });
      return () => timer.cancel();
    }, []);
    
    return DCFCanvas(
      width: 300,
      height: 300,
      repaintOnFrame: true, // Enable continuous rendering
      shapes: [
        SkiaGroup(
          transform: [
            {'rotate': rotation.state},
            {'translate': [150.0, 150.0]},
          ],
          children: [
            SkiaRect(
              x: -25,
              y: -25,
              width: 50,
              height: 50,
              color: 0xFF00FF00,
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Shapes

### SkiaCircle

Draw circles and dots.

```dart
SkiaCircle(
  cx: 100,        // Center X
  cy: 100,        // Center Y
  r: 50,          // Radius
  color: 0xFFFF0000,
  style: 'fill',  // 'fill' or 'stroke'
  strokeWidth: 2.0,
)
```

### SkiaRect

Draw rectangles.

```dart
SkiaRect(
  x: 50,
  y: 50,
  width: 100,
  height: 100,
  color: 0xFF00FF00,
  style: 'fill',
)
```

### SkiaRRect

Draw rounded rectangles.

```dart
SkiaRRect(
  x: 50,
  y: 50,
  width: 100,
  height: 100,
  rx: 10,  // X-axis corner radius
  ry: 10,  // Y-axis corner radius
  color: 0xFF0000FF,
)
```

### SkiaOval

Draw ellipses.

```dart
SkiaOval(
  x: 50,
  y: 50,
  width: 100,
  height: 60,
  color: 0xFFFFFF00,
)
```

### SkiaLine

Draw lines.

```dart
SkiaLine(
  x1: 0,
  y1: 0,
  x2: 100,
  y2: 100,
  color: 0xFF000000,
  strokeWidth: 2.0,
)
```

### SkiaPath

Draw complex paths using SVG path syntax.

```dart
SkiaPath(
  pathString: 'M 10 10 L 100 10 L 100 100 Z',
  color: 0xFFFF00FF,
  style: 'stroke',
  strokeWidth: 2.0,
)
```

### SkiaText

Render text.

```dart
SkiaText(
  text: 'Hello, World!',
  x: 50,
  y: 50,
  fontSize: 24.0,
  fontFamily: 'Arial',
  fontWeight: 700, // 100-900
  fontStyle: 0,    // 0=normal, 1=italic
  color: 0xFF000000,
)
```

---

## Paint Properties

### Color

Colors are specified as 32-bit ARGB integers:

```dart
0xFFFF0000  // Red (opaque)
0x80FF0000  // Red (50% transparent)
0xFF00FF00  // Green
0xFF0000FF  // Blue
```

### Opacity

Control transparency separately from color:

```dart
SkiaCircle(
  cx: 100,
  cy: 100,
  r: 50,
  color: 0xFFFF0000,
  opacity: 0.5, // 0.0 (transparent) to 1.0 (opaque)
)
```

### Style

- `'fill'` - Fill the shape (default)
- `'stroke'` - Draw outline only

```dart
SkiaRect(
  x: 50,
  y: 50,
  width: 100,
  height: 100,
  color: 0xFF000000,
  style: 'stroke',
  strokeWidth: 3.0,
)
```

### Blend Modes

Control how shapes blend with the background:

```dart
SkiaCircle(
  cx: 100,
  cy: 100,
  r: 50,
  color: 0xFFFF0000,
  blendMode: 'multiply', // See blend modes list below
)
```

**Available Blend Modes:**
- `clear`, `src`, `dst`, `srcOver`, `dstOver`
- `srcIn`, `dstIn`, `srcOut`, `dstOut`
- `srcATop`, `dstATop`, `xor`, `plus`
- `modulate`, `screen`, `overlay`, `darken`, `lighten`
- `colorDodge`, `colorBurn`, `hardLight`, `softLight`
- `difference`, `exclusion`, `multiply`, `hue`, `saturation`, `color`, `luminosity`

---

## Transformations

Use `SkiaGroup` to apply transformations to multiple shapes:

### Translation

```dart
SkiaGroup(
  transform: [
    {'translateX': 50.0},
    {'translateY': 100.0},
    // or combined:
    {'translate': [50.0, 100.0]},
  ],
  children: [/* shapes */],
)
```

### Rotation

```dart
SkiaGroup(
  transform: [
    {'rotate': 0.785}, // Radians (45 degrees)
  ],
  children: [/* shapes */],
)
```

### Scaling

```dart
SkiaGroup(
  transform: [
    {'scaleX': 2.0},
    {'scaleY': 1.5},
    // or combined:
    {'scale': [2.0, 1.5]},
  ],
  children: [/* shapes */],
)
```

### Skewing

```dart
SkiaGroup(
  transform: [
    {'skewX': 0.5},
    {'skewY': 0.3},
  ],
  children: [/* shapes */],
)
```

### Combined Transformations

Transformations are applied in order:

```dart
SkiaGroup(
  transform: [
    {'translate': [150.0, 150.0]}, // Move to center
    {'rotate': rotation},           // Rotate around center
    {'scale': [2.0, 2.0]},         // Scale up
  ],
  children: [/* shapes */],
)
```

---

## Gradients & Shaders

### Linear Gradient

```dart
SkiaRect(
  x: 0,
  y: 0,
  width: 200,
  height: 200,
  shader: SkiaLinearGradient(
    x0: 0,
    y0: 0,
    x1: 200,
    y1: 200,
    colors: [0xFFFF0000, 0xFF0000FF],
    stops: [0.0, 1.0], // Optional
  ),
)
```

### Radial Gradient

```dart
SkiaCircle(
  cx: 100,
  cy: 100,
  r: 50,
  shader: SkiaRadialGradient(
    cx: 100,
    cy: 100,
    radius: 50,
    colors: [0xFFFFFFFF, 0xFF000000],
    stops: [0.0, 1.0],
  ),
)
```

### Conic Gradient (Sweep)

```dart
SkiaCircle(
  cx: 100,
  cy: 100,
  r: 50,
  shader: SkiaConicGradient(
    cx: 100,
    cy: 100,
    startAngle: 0.0,
    colors: [0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFF0000],
    stops: [0.0, 0.33, 0.66, 1.0],
  ),
)
```

---

## Filters & Effects

### Blur

```dart
SkiaCircle(
  cx: 100,
  cy: 100,
  r: 50,
  color: 0xFFFF0000,
  filters: [
    SkiaBlur(blur: 10.0),
  ],
)
```

### Drop Shadow

```dart
SkiaRect(
  x: 50,
  y: 50,
  width: 100,
  height: 100,
  color: 0xFF00FF00,
  filters: [
    SkiaDropShadow(
      dx: 5.0,
      dy: 5.0,
      blur: 10.0,
      color: 0x80000000, // Semi-transparent black
    ),
  ],
)
```

### Color Matrix

Apply color transformations:

```dart
SkiaCircle(
  cx: 100,
  cy: 100,
  r: 50,
  color: 0xFFFF0000,
  colorFilter: SkiaColorMatrix(
    matrix: [
      // 5x4 color matrix (20 values)
      1, 0, 0, 0, 0,  // Red
      0, 1, 0, 0, 0,  // Green
      0, 0, 1, 0, 0,  // Blue
      0, 0, 0, 1, 0,  // Alpha
    ],
  ),
)
```

### Path Effects

#### Dash Effect

```dart
SkiaLine(
  x1: 0,
  y1: 100,
  x2: 200,
  y2: 100,
  color: 0xFF000000,
  style: 'stroke',
  strokeWidth: 2.0,
  pathEffect: SkiaDashPathEffect(
    intervals: [10.0, 5.0], // 10px dash, 5px gap
    phase: 0.0,
  ),
)
```

#### Discrete Effect

```dart
SkiaPath(
  pathString: 'M 10 10 L 200 10',
  color: 0xFF000000,
  style: 'stroke',
  pathEffect: SkiaDiscretePathEffect(
    length: 10.0,
    deviation: 5.0,
  ),
)
```

#### Corner Effect

```dart
SkiaRect(
  x: 50,
  y: 50,
  width: 100,
  height: 100,
  color: 0xFF000000,
  style: 'stroke',
  pathEffect: SkiaCornerPathEffect(r: 10.0),
)
```

---

## Performance Optimization

### 1. Use `repaintOnFrame` Wisely

Only enable continuous rendering when needed:

```dart
DCFCanvas(
  repaintOnFrame: true, // Only for animations
  shapes: [/* ... */],
)
```

### 2. Minimize Shape Count

Combine shapes when possible. Instead of 100 circles, use a single path or custom drawing.

### 3. Avoid Recreating Shapes

Cache shape data in state:

```dart
final shapes = useState<List<Map<String, dynamic>>>([]);

useEffect(() {
  // Create shapes once
  shapes.setState(generateShapes());
}, []);

return DCFCanvas(shapes: shapes.state);
```

### 4. Use Groups for Batch Transformations

Apply transformations to groups instead of individual shapes:

```dart
SkiaGroup(
  transform: [{'rotate': angle}],
  children: [
    // All children inherit transformation
    SkiaCircle(...),
    SkiaRect(...),
  ],
)
```

### 5. Leverage GPU Acceleration

The Canvas API is GPU-accelerated by default. Complex effects (gradients, blur) are handled efficiently by Skia.

---

## Platform Details

### iOS

- Uses **Metal** backend for GPU acceleration
- Shared `GrDirectContext` across all canvases (~50MB total)
- Lazy surface creation for memory efficiency

### Android

- Uses built-in **Skia** library (android.graphics.Canvas)
- Hardware-accelerated by default
- Efficient view recycling

### Memory Usage

**Optimized (Current):**
- Single canvas: ~20-30MB
- Multiple canvases: ~50-80MB total (shared context)

**Previous (Per-Canvas Context):**
- Single canvas: ~150MB
- Multiple canvases: ~300MB+ (separate contexts)

---

## Examples

### Particle System

```dart
class ParticleSystem extends DCFStatefulComponent {
  @override
  DCFElement build(BuildContext context) {
    final particles = useState<List<Particle>>([]);
    
    useEffect(() {
      // Initialize particles
      particles.setState(List.generate(100, (i) => Particle()));
      
      // Update loop
      final timer = Timer.periodic(Duration(milliseconds: 16), (_) {
        particles.setState(
          particles.state.map((p) => p.update()).toList(),
        );
      });
      
      return () => timer.cancel();
    }, []);
    
    return DCFCanvas(
      width: 400,
      height: 400,
      repaintOnFrame: true,
      shapes: particles.state.map((p) => SkiaCircle(
        cx: p.x,
        cy: p.y,
        r: p.size,
        color: p.color,
        opacity: p.opacity,
      )).toList(),
    );
  }
}
```

### Custom Chart

```dart
class BarChart extends DCFStatelessComponent {
  final List<double> data;
  
  BarChart({required this.data});
  
  @override
  DCFElement build(BuildContext context) {
    final barWidth = 300.0 / data.length;
    final maxValue = data.reduce(max);
    
    return DCFCanvas(
      width: 300,
      height: 200,
      shapes: data.asMap().entries.map((entry) {
        final index = entry.key;
        final value = entry.value;
        final height = (value / maxValue) * 180;
        
        return SkiaRect(
          x: index * barWidth + 5,
          y: 200 - height - 10,
          width: barWidth - 10,
          height: height,
          shader: SkiaLinearGradient(
            x0: 0,
            y0: 200 - height,
            x1: 0,
            y1: 200,
            colors: [0xFF4CAF50, 0xFF8BC34A],
          ),
        );
      }).toList(),
    );
  }
}
```

---

## API Reference

### DCFCanvas Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `width` | `double` | required | Canvas width |
| `height` | `double` | required | Canvas height |
| `shapes` | `List<Map>` | `[]` | Shapes to render |
| `repaintOnFrame` | `bool` | `false` | Enable continuous rendering |
| `backgroundColor` | `int?` | `null` | Background color (ARGB) |

### Common Shape Props

| Prop | Type | Description |
|------|------|-------------|
| `color` | `int` | ARGB color value |
| `opacity` | `double?` | 0.0 to 1.0 |
| `style` | `String?` | 'fill' or 'stroke' |
| `strokeWidth` | `double?` | Stroke width (when style='stroke') |
| `blendMode` | `String?` | Blend mode |
| `shader` | `Map?` | Gradient or shader |
| `colorFilter` | `Map?` | Color filter |
| `filters` | `List<Map>?` | Image filters |
| `pathEffect` | `Map?` | Path effect |

---

## Best Practices

1. **Cache static shapes** - Don't recreate shape data on every render
2. **Use groups** - Batch transformations for better performance
3. **Minimize repaints** - Only use `repaintOnFrame` for animations
4. **Optimize particle count** - Keep under 500 particles for 60fps
5. **Leverage GPU** - Use gradients and effects - they're GPU-accelerated
6. **Profile performance** - Use Flutter DevTools to identify bottlenecks

---

## Troubleshooting

### Canvas not rendering

- Ensure `width` and `height` are set
- Check that shapes array is not empty
- Verify color values are valid ARGB integers

### Poor performance

- Reduce shape count
- Disable `repaintOnFrame` if not animating
- Use simpler shapes (circles instead of complex paths)
- Batch transformations with groups

### Memory issues

- Ensure you're on the latest version (with shared context pool)
- Limit canvas instances
- Dispose timers in `useEffect` cleanup

---

## See Also

- [Component Protocol](./COMPONENT_PROTOCOL.md)
- [Worklets](../guides/WORKLETS.md) - For high-performance animations
- [Performance Optimizations](../performance/OPTIMIZATIONS.md)

# DCFCanvas API Documentation

**Version:** 1.0.0  
**Canvas rendering using Flutter texture registry and native GPU acceleration**

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [API Reference](#api-reference)
4. [Usage Examples](#usage-examples)
5. [Performance Considerations](#performance-considerations)
6. [Troubleshooting](#troubleshooting)
7. [Implementation Details](#implementation-details)

## Overview

`DCFCanvas` provides GPU-accelerated 2D canvas rendering using Flutter's texture registry system. Unlike traditional canvas implementations that render only in the Dart runtime, `DCFCanvas` leverages Flutter framework internals to render directly to native views using platform-specific GPU acceleration.

### Key Features

- 🎨 **GPU-Accelerated Rendering** - Uses Flutter texture registry for native GPU rendering
- ⚡ **60fps Performance** - Smooth animations with native display link
- 🔄 **Real-time Updates** - Continuous rendering support for animations
- 📱 **Cross-Platform** - iOS and Android support with platform-optimized rendering
- 🎯 **Flutter Canvas API** - Familiar `dart:ui` Canvas API
- 🖼️ **Texture-Based** - Direct pixel transfer to native views

### How It Works

```
Dart Canvas API → PictureRecorder → ui.Image → Pixel Data → Tunnel → Native Texture
                                                                         ↓
                                                              Flutter Texture Registry
                                                                         ↓
                                                              Platform GPU Rendering
                                                                         ↓
                                                              Native View Display
```

1. **Dart Side**: Uses `dart:ui` Canvas API to draw
2. **Rendering**: Converts drawing to pixel data (RGBA format)
3. **Transfer**: Sends pixels via FrameworkTunnel to native side
4. **Native Side**: Converts RGBA to platform format (BGRA on iOS, ARGB on Android)
5. **Display**: Uses Flutter texture registry to display in native view

---

## Architecture

### Flutter Texture Registry Integration

`DCFCanvas` uses Flutter's texture registry system, which allows Dart code to create textures that are rendered by native code. This provides:

- **Direct GPU Access**: Native views can render textures directly using platform GPU
- **Efficient Memory**: Shared memory between Dart and native
- **Smooth Performance**: 60fps rendering with native display link

### Platform-Specific Implementation

#### iOS
- Uses `CVPixelBuffer` for pixel data storage
- Converts RGBA → BGRA (iOS native format)
- Uses `CALayer` with texture contents for display
- Registers with Flutter texture registry via `FlutterTexture`

#### Android
- Uses `Bitmap` with `ARGB_8888` format
- Converts RGBA → ARGB (Android native format)
- Uses `TextureView` with `SurfaceTexture` for display
- Registers with Flutter texture registry via `TextureRegistry`

### Component Registration

The canvas component must be registered in the native component registry:

**iOS:** `packages/dcf_reanimated/ios/Classes/Components/DCFCanvasComponent.swift`
**Android:** `packages/dcf_reanimated/android/src/main/kotlin/com/dotcorr/dcf_reanimated/components/DCFCanvasComponent.kt`

Both platforms register the component as `"Canvas"` in the registry.

---

## API Reference

### DCFCanvas

The main component for canvas rendering.

```dart
DCFCanvas({
  required void Function(ui.Canvas canvas, Size size) onPaint,
  bool repaintOnFrame = false,
  Color? backgroundColor,
  Size size = const Size(300, 300),
  DCFLayout? layout,
  DCFStyleSheet? styleSheet,
  Key? key,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `onPaint` | `void Function(ui.Canvas, Size)` | required | Callback that receives canvas and size for drawing |
| `repaintOnFrame` | `bool` | `false` | If `true`, continuously renders at ~60fps for animations |
| `backgroundColor` | `Color?` | `null` | Background color for the canvas |
| `size` | `Size` | `Size(300, 300)` | Canvas dimensions in logical pixels |
| `layout` | `DCFLayout?` | `null` | Layout properties for positioning |
| `styleSheet` | `DCFStyleSheet?` | `null` | Style properties |

#### Canvas API

The `onPaint` callback receives a `ui.Canvas` instance from `dart:ui`, which supports:

- **Drawing Shapes**: `drawCircle`, `drawRect`, `drawPath`, `drawLine`, etc.
- **Text Rendering**: `drawParagraph`, `drawText`
- **Transformations**: `translate`, `rotate`, `scale`, `skew`
- **Clipping**: `clipRect`, `clipPath`, `clipRRect`
- **Paint Styles**: `Paint` with `PaintingStyle.fill` or `PaintingStyle.stroke`

**Example:**
```dart
onPaint: (canvas, size) {
  final paint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  
  canvas.drawCircle(
    Offset(size.width / 2, size.height / 2),
    50,
    paint,
  );
}
```

---

## Usage Examples

### Static Canvas

Render a canvas that updates only when props change:

```dart
DCFCanvas(
  size: const Size(300, 300),
  backgroundColor: const Color(0xFF1a1a2e),
  layout: layouts['canvasBox'],
  onPaint: (canvas, size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      50,
      paint,
    );
  },
)
```

### Animated Canvas (60fps)

Render a canvas that updates every frame for smooth animations:

```dart
class AnimatedCanvas extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final animationValue = useState<double>(0.0);
    
    // Update animation value continuously
    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        animationValue.setState((animationValue.state + 0.01) % 1.0);
      });
      return () => timer.cancel();
    }, dependencies: []);
    
    return DCFCanvas(
      size: const Size(300, 300),
      repaintOnFrame: true,  // Enable continuous rendering
      onPaint: (canvas, size) {
        final paint = Paint()
          ..color = Color.lerp(
            Colors.red,
            Colors.blue,
            animationValue.state,
          )!
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(
            size.width / 2 + (animationValue.state - 0.5) * 100,
            size.height / 2,
          ),
          50,
          paint,
        );
      },
    );
  }
}
```

### Confetti Animation

Full-screen confetti animation using canvas:

```dart
DCFConfetti(
  particleCount: 100,
  duration: 3000,
  config: const ConfettiConfig(
    gravity: 9.8,
    initialVelocity: 80.0,
    spread: 360.0,
    colors: [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
    ],
  ),
  onComplete: () {
    print('Confetti complete!');
  },
)
```

---

## Performance Considerations

### Canvas Size

**Important:** Canvas size directly affects memory usage and performance.

- **Small Canvas** (300x300): ~360KB per frame, smooth 60fps
- **Medium Canvas** (800x600): ~1.9MB per frame, good performance
- **Large Canvas** (1080x2400): ~10MB per frame, may cause OOM on low-end devices

**Best Practice:** Use screen dimensions for full-screen canvases, but be aware of memory constraints.

```dart
// ✅ Good: Use actual screen size
final screenWidth = ScreenUtilities.instance.screenWidth;
final screenHeight = ScreenUtilities.instance.screenHeight;
DCFCanvas(
  size: Size(screenWidth, screenHeight),
  // ...
)

// ❌ Bad: Fixed large size may cause OOM
DCFCanvas(
  size: const Size(1080, 2400),  // 10MB per frame!
  // ...
)
```

### Continuous Rendering

When `repaintOnFrame: true`, the canvas renders at ~60fps (every 16ms). This is suitable for:

- ✅ Smooth animations
- ✅ Particle effects
- ✅ Real-time visualizations
- ✅ Interactive drawings

**Avoid** continuous rendering for:
- ❌ Static content (use `repaintOnFrame: false`)
- ❌ Infrequent updates (trigger renders manually)
- ❌ Large canvases (consider reducing size or frame rate)

### Memory Management

Canvas rendering creates pixel buffers that are transferred to native. These are automatically managed, but:

- **Large canvases** consume significant memory
- **Continuous rendering** keeps memory active
- **Multiple canvases** multiply memory usage

**Tip:** Dispose of canvases when not needed, especially in lists or dynamic content.

---

## Troubleshooting

### Issue: Canvas Not Rendering

**Symptoms:**
- Canvas appears blank
- No drawing visible
- Tunnel calls return `null` or `false`

**Solutions:**

1. **Check view registration delay:**
```dart
// ✅ Good: Wait for view registration
Future.delayed(const Duration(milliseconds: 200), () {
  // Canvas will render after view is registered
});

// ❌ Bad: Immediate render (view might not be ready)
// Canvas renders immediately
```

2. **Verify canvasId is unique:**
```dart
// ✅ Good: Unique ID per canvas instance
final canvasId = useMemo(() => UniqueKey().toString(), dependencies: []);

// ❌ Bad: Same ID for multiple canvases
final canvasId = "canvas1";  // Conflicts if multiple instances
```

3. **Check tunnel return values:**
```dart
final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {...});
if (result == true) {
  // ✅ Success
} else if (result == false) {
  // ⚠️ View not ready - retry later
} else {
  // ❌ Error - check logs
}
```

### Issue: Colors Are Wrong

**Symptoms:**
- Colors appear swapped (red/blue)
- Background color is wrong
- Colors look inverted

**Cause:** Byte order mismatch between Dart (RGBA) and native formats.

**Solution:** The framework automatically converts:
- **iOS**: RGBA → BGRA (handled in native code)
- **Android**: RGBA → ARGB (handled in native code)

If colors are still wrong, check:
1. Native conversion code is correct
2. Pixel buffer format matches platform expectations
3. Background color is applied correctly

### Issue: Canvas Not Centered

**Symptoms:**
- Canvas appears at wrong position
- Not aligned with layout

**Solutions:**

1. **Use layout properties:**
```dart
DCFCanvas(
  layout: DCFLayout(
    width: '100%',
    height: 300,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  // ...
)
```

2. **Match canvas size to layout:**
```dart
// ✅ Good: Canvas size matches layout height
DCFCanvas(
  size: const Size(300, 300),
  layout: DCFLayout(height: 300),
  // ...
)

// ❌ Bad: Size mismatch
DCFCanvas(
  size: const Size(300, 300),
  layout: DCFLayout(height: 150),  // Mismatch!
  // ...
)
```

### Issue: Infinite Rendering Loop

**Symptoms:**
- Continuous tunnel calls
- High CPU usage
- Logs show repeated "Tunnel call result: null"

**Cause:** Canvas keeps trying to render when view isn't ready.

**Solution:**
```dart
// ✅ Good: Track view readiness
bool isViewReady = false;

void renderFrame() {
  if (!isViewReady) {
    _renderToNative(canvasId).then((result) {
      if (result == true) {
        isViewReady = true;
      }
    });
  } else {
    _renderToNative(canvasId);
  }
}

// Start rendering after delay
Future.delayed(const Duration(milliseconds: 200), () {
  renderFrame();
  if (repaintOnFrame) {
    Timer.periodic(const Duration(milliseconds: 16), (_) {
      renderFrame();
    });
  }
});
```

### Issue: Out of Memory (OOM)

**Symptoms:**
- App crashes on iOS/Android
- "Out of memory" errors
- Canvas rendering stops

**Cause:** Canvas size too large or too many canvases.

**Solutions:**

1. **Reduce canvas size:**
```dart
// ❌ Bad: Too large
DCFCanvas(size: const Size(1080, 2400))

// ✅ Good: Reasonable size
DCFCanvas(size: const Size(400, 600))
```

2. **Use screen dimensions:**
```dart
// ✅ Good: Use actual screen size
final width = ScreenUtilities.instance.screenWidth;
final height = ScreenUtilities.instance.screenHeight;
DCFCanvas(size: Size(width, height))
```

3. **Limit continuous rendering:**
```dart
// ✅ Good: Only render when needed
DCFCanvas(
  repaintOnFrame: false,  // Static content
  // ...
)
```

---

## Implementation Details

### Pixel Format Conversion

The framework handles byte order conversion automatically:

**Dart → Native:**
- Dart sends: **RGBA** (Red, Green, Blue, Alpha)
- iOS expects: **BGRA** (Blue, Green, Red, Alpha)
- Android expects: **ARGB** (Alpha, Red, Green, Blue)

**Conversion Code:**

**iOS:**
```swift
// Convert RGBA to BGRA
for x in 0..<width {
    let srcPixel = srcRow.advanced(by: x * 4)
    let dstPixel = dstRow.advanced(by: x * 4)
    
    dstPixel[0] = srcPixel[2] // B
    dstPixel[1] = srcPixel[1] // G
    dstPixel[2] = srcPixel[0] // R
    dstPixel[3] = srcPixel[3] // A
}
```

**Android:**
```kotlin
// Convert RGBA to ARGB
for (i in pixels.indices step 4) {
    argbPixels[i] = pixels[i + 3]     // A
    argbPixels[i + 1] = pixels[i]     // R
    argbPixels[i + 2] = pixels[i + 1] // G
    argbPixels[i + 3] = pixels[i + 2] // B
}
```

### Texture Registration

The canvas view registers with Flutter's texture registry:

**iOS:**
```swift
if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
   let registrar = appDelegate.pluginRegistrant as? FlutterPluginRegistrar {
    textureId = registrar.textures().register(self)
}
```

**Android:**
```kotlin
val textureRegistry = FlutterEngineCache.getInstance()
    .get(flutterEngine.dartExecutor.binaryMessenger)
    ?.textureRegistry()
textureId = textureRegistry?.createSurfaceTexture()
```

### View Registration

Canvas views register themselves with a unique `canvasId`:

**iOS:**
```swift
static var canvasViews: [String: DCFCanvasView] = [:]

func update(props: [String: Any]) {
    if let id = props["canvasId"] as? String {
        DCFCanvasView.canvasViews[id] = self
    }
}
```

**Android:**
```kotlin
companion object {
    val canvasViews = ConcurrentHashMap<String, DCFCanvasView>()
}

fun update(props: Map<String, Any?>) {
    val id = props["canvasId"] as? String
    if (id != null) {
        canvasViews[id] = this
    }
}
```

### Tunnel Method

The canvas uses FrameworkTunnel to send pixel data:

```dart
final result = await FrameworkTunnel.call('Canvas', 'updateTexture', {
  'canvasId': canvasId,
  'pixels': byteData.buffer.asUint8List(),
  'width': size.width.toInt(),
  'height': size.height.toInt(),
});
```

**Return Values:**
- `true`: Success, texture updated
- `false`: View not registered yet (retry later)
- `null`: Error or method not found

---

## Best Practices

### 1. Use Appropriate Canvas Size

```dart
// ✅ Good: Reasonable size for content
DCFCanvas(size: const Size(300, 300))

// ✅ Good: Use screen dimensions for full-screen
final size = Size(
  ScreenUtilities.instance.screenWidth,
  ScreenUtilities.instance.screenHeight,
);
DCFCanvas(size: size)

// ❌ Bad: Unnecessarily large
DCFCanvas(size: const Size(1080, 2400))
```

### 2. Enable Continuous Rendering Only When Needed

```dart
// ✅ Good: Static content
DCFCanvas(
  repaintOnFrame: false,
  onPaint: (canvas, size) {
    // Draw static content
  },
)

// ✅ Good: Animated content
DCFCanvas(
  repaintOnFrame: true,  // Enable for animations
  onPaint: (canvas, size) {
    // Draw animated content
  },
)
```

### 3. Handle View Readiness

```dart
// ✅ Good: Wait for view registration
useEffect(() {
  Future.delayed(const Duration(milliseconds: 200), () {
    // Canvas view should be registered now
    _renderToNative(canvasId);
  });
}, dependencies: [canvasId]);
```

### 4. Use Unique Canvas IDs

```dart
// ✅ Good: Unique ID per instance
final canvasId = useMemo(() => UniqueKey().toString(), dependencies: []);

// ❌ Bad: Same ID for all instances
final canvasId = "canvas";
```

### 5. Clean Up Resources

```dart
// ✅ Good: Cancel timers on dispose
useEffect(() {
  Timer? frameTimer;
  
  if (repaintOnFrame) {
    frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _renderToNative(canvasId);
    });
  }
  
  return () {
    frameTimer?.cancel();
  };
}, dependencies: [canvasId, repaintOnFrame]);
```

---

## Related Documentation

- [Tunnel System](../components/TUNNEL_SYSTEM.md) - How FrameworkTunnel works
- [DCF Reanimated](./dcf_reanimated.md) - Animation library
- [Component Protocol](../components/COMPONENT_PROTOCOL.md) - Native component implementation

---

**DCFCanvas** - GPU-accelerated canvas rendering with Flutter texture registry integration.


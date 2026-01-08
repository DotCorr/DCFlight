# Performance Optimizations

## 1. Disable FlutterView to Save Memory & CPU

By default, DCFlight creates a FlutterViewController/FlutterView that consumes ~300MB of memory and 30% CPU even when not rendering any Flutter widgets.

If you're **only using native DCFlight components** (not Flutter widgets), you can disable the FlutterView to dramatically improve performance.

### How to Disable

#### iOS

Add this to your `AppDelegate.swift` **before** calling `divergeToFlight()`:

```swift
UserDefaults.standard.set(false, forKey: "ENABLE_FLUTTER_VIEW")
```

#### Android

Add this to your `MainActivity.kt` **before** calling `divergeToFlight()`:

```kotlin
getSharedPreferences("dcflight_prefs", Context.MODE_PRIVATE)
    .edit()
    .putBoolean("ENABLE_FLUTTER_VIEW", false)
    .apply()
```

### When to Enable

Only set `ENABLE_FLUTTER_VIEW` to `true` if you're using:
- `FlutterWidget` component
- Any Flutter-based UI components
- WebView or other Flutter plugins that require the Flutter view

---

## 2. Skia Context Pooling (Automatic)

**iOS Only** - Automatically reduces Skia GPU memory from ~300MB to ~50-80MB.

### What Changed

Previously, each `DCFCanvas` created its own `GrDirectContext` (~150MB each). Now all canvases share a single context.

This optimization is **automatic** and follows React Native Skia's approach:
- ✅ Single shared `GrDirectContext` for all canvases
- ✅ Lazy surface creation (only when drawing)
- ✅ Efficient GPU resource management

### Android

Android already uses the built-in `android.graphics.Canvas` which is efficiently backed by Skia. No additional optimization needed.

---

## Performance Impact Summary

**With Both Optimizations:**
- Memory: ~60-80MB (vs ~600MB)
- CPU: ~5% idle (vs ~30%)
- Faster app startup
- Smooth 60fps animations

**Recommended for:**
- Apps using only native DCFlight components
- Production apps where performance is critical
- Apps with multiple canvas instances

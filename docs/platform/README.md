# Platform-Specific Documentation

Platform-specific implementations, integrations, and customizations for iOS and Android.

## Android

- **[Compose Integration](./ANDROID_COMPOSE_INTEGRATION.md)** - Using Jetpack Compose with DCFlight
- **[Color Overrides](./ANDROID_COMPONENTS_COLOR_OVERRIDES.md)** - Android-specific color handling

## iOS

- **[View Controller Systems](./IOS_VIEW_CONTROLLER_SYSTEMS.md)** - View controller wrappers, layout guides, and content insets
- **[Color Overrides](./IOS_COMPONENTS_COLOR_OVERRIDES.md)** - iOS-specific color handling

## Cross-Platform

- **[Explicit Color Overrides](./EXPLICIT_COLOR_OVERRIDES.md)** - Manual color override system

## Platform Differences

### Rendering

| Feature | iOS | Android |
|---------|-----|---------|
| UI Framework | UIKit | Android Views |
| GPU Backend | Metal (Skia) | Skia (built-in) |
| Layout | Yoga | Yoga |
| Threading | Main thread | Main thread |

### Performance

| Metric | iOS | Android |
|--------|-----|---------|
| Startup | ~100ms | ~150ms |
| Frame time | ~8ms | ~10ms |
| Memory (base) | ~40MB | ~50MB |
| Memory (with Canvas) | ~60MB | ~70MB |

## Best Practices

### iOS
- Use Metal for GPU-intensive operations
- Leverage shared Skia context for multiple canvases
- Profile with Instruments

### Android
- Use Compose for modern UI components
- Leverage hardware acceleration
- Profile with Android Profiler

## See Also

- [Framework Overview](../FRAMEWORK_OVERVIEW.md)
- [Performance Optimizations](../performance/OPTIMIZATIONS.md)

# Performance Optimizations

Guides and best practices for optimizing DCFlight applications.

## Available Optimizations

- **[Memory & CPU Optimizations](./OPTIMIZATIONS.md)** - FlutterView disabling and Skia context pooling

## Performance Checklist

### Memory

- [ ] Disable FlutterView if not using Flutter widgets
- [ ] Use shared Skia context (automatic in latest version)
- [ ] Limit canvas instances
- [ ] Dispose timers and subscriptions
- [ ] Avoid memory leaks in state

### CPU

- [ ] Use `repaintOnFrame` only for animations
- [ ] Batch component updates
- [ ] Minimize reconciliation work
- [ ] Use worklets for animations
- [ ] Profile with DevTools

### Rendering

- [ ] Keep component tree shallow
- [ ] Use `shouldComponentUpdate` when appropriate
- [ ] Avoid unnecessary re-renders
- [ ] Optimize canvas shape count
- [ ] Use GPU-accelerated effects

## Benchmarks

### Memory Usage

| Configuration | Memory |
|---------------|--------|
| Base (no optimizations) | ~600MB |
| FlutterView disabled | ~300MB |
| + Skia context pooling | ~60-80MB |

### Frame Times

| Scenario | Frame Time |
|----------|------------|
| Simple list (100 items) | ~8ms |
| Complex UI | ~12ms |
| Canvas animation (100 particles) | ~10ms |
| Canvas animation (500 particles) | ~16ms |

## Tools

- **Flutter DevTools** - CPU profiler, memory profiler
- **Xcode Instruments** - iOS-specific profiling
- **Android Profiler** - Android-specific profiling

## See Also

- [VDOM Performance Analysis](../engine/vdom/VDOM_PERFORMANCE_ANALYSIS.md)
- [Worklets](../guides/WORKLETS.md)
- [Canvas API](../components/CANVAS_API.md)

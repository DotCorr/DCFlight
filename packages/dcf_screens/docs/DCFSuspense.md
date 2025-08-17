# DCFSuspense Component

## Overview

`DCFSuspense` is a conditional rendering component that allows you to suspend rendering of expensive content until a condition is met. This prevents unnecessary component creation, lifecycle execution, and resource usage.

## Key Benefits

- 🎬 **Prevents Premature Animations**: Stops animations from starting before screens are visible
- 🚀 **Performance Optimization**: Only creates components when actually needed
- 🧹 **Memory Efficiency**: Reduces memory usage by not rendering inactive screens
- 🔄 **Smooth Transitions**: Maintains navigation stack for seamless back navigation

## Basic Usage

```dart
DCFSuspense(
  shouldRender: shouldShowContent,
  debugName: "MyComponent",
  children: () => ExpensiveComponent(), // Only called when shouldRender is true
  fallback: () => LoadingPlaceholder(),  // Optional fallback content
)
```

## API Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `shouldRender` | `bool` | Whether to render the children or show fallback |
| `children` | `DCFComponentNode Function()` | Builder for the actual content |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fallback` | `DCFComponentNode Function()?` | `null` | Fallback content when suspended |
| `debugName` | `String?` | `'Unknown'` | Name for debug logging |
| `layout` | `LayoutProps?` | `LayoutProps()` | Layout properties for container |
| `styleSheet` | `StyleSheet?` | `StyleSheet()` | Style sheet for container |
| `enableDebugLogs` | `bool` | `true` | Whether to show debug logs |

## Examples

### Basic Suspense

```dart
DCFSuspense(
  shouldRender: isDataLoaded,
  debugName: "DataView",
  children: () => DataVisualizationComponent(),
  fallback: () => DCFText(content: "Loading data..."),
)
```

### Navigation-Based Suspense

```dart
DCFSuspense(
  shouldRender: currentRoute == "settings",
  debugName: "Settings",
  children: () => SettingsScreen(),
  fallback: () => DCFView(children: []), // Empty fallback
)
```

### Performance-Critical Component

```dart
DCFSuspense(
  shouldRender: shouldRenderAnimations,
  debugName: "Animations",
  children: () => ComplexAnimationScreen(),
  // No fallback = renders empty DCFView when suspended
)
```

## Debug Output

When `enableDebugLogs` is true, DCFSuspense provides helpful debug information:

```
🏗️ DCFSuspense[Settings]: Rendering children (active)
⏸️ DCFSuspense[AnimatedModal]: Rendering fallback (suspended)
```

## Best Practices

### ✅ DO

- Use descriptive `debugName` for easier debugging
- Provide lightweight fallback components
- Use suspense for expensive components (animations, heavy computations)
- Combine with navigation state for screen-level suspense

### ❌ DON'T

- Wrap every component in suspense (only use when needed)
- Create expensive fallback components
- Use suspense for critical UI elements that should always be visible
- Forget to handle the suspended state in your app logic

## Common Patterns

### Screen Suspense Pattern

```dart
DCFSuspense(
  shouldRender: activeScreen == screenName,
  debugName: screenName,
  children: () => MyScreen(),
  fallback: () => ScreenPlaceholder(screenName),
)
```

### Conditional Feature Loading

```dart
DCFSuspense(
  shouldRender: featureFlag.isEnabled && userHasPermission,
  debugName: "PremiumFeature",
  children: () => PremiumFeatureComponent(),
  fallback: () => FeatureUnavailableMessage(),
)
```

### Data-Dependent Rendering

```dart
DCFSuspense(
  shouldRender: data != null && !isLoading,
  debugName: "DataContent",
  children: () => DataDisplayComponent(data: data!),
  fallback: () => LoadingSpinner(),
)
```

## Integration with Navigation

DCFSuspense works perfectly with DCF's navigation system to create efficient screen management:

```dart
// Automatic screen suspense based on navigation state
bool shouldRenderScreen(String route) {
  final activeScreen = activeScreenTracker.state;
  final navStack = navigationStackTracker.state;
  
  return activeScreen == route || 
         navStack.contains(route) || 
         route == "home";
}

DCFSuspense(
  shouldRender: shouldRenderScreen("profile/settings"),
  children: () => SettingsScreen(),
)
```

## Performance Impact

### Before DCFSuspense
```
🎬 AnimationController created (unnecessary)
🎬 Animation STARTED (premature)
💾 Heavy component in memory (wasteful)
```

### After DCFSuspense  
```
⏸️ Component suspended (efficient)
🎬 Animation STARTED (only when needed)
💾 Memory usage optimized
```

## Related Components

- [`DCFEasyScreen`](./DCFEasyScreen.md) - Automatic suspense for navigation screens
- [`DCFScreen`](./DCFScreen.md) - Base screen component
- [`AppNavigation`](./AppNavigation.md) - Navigation system that works with suspense
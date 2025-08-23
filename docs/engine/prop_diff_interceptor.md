# PropDiffInterceptor System

## Overview

The PropDiffInterceptor system allows component packages to customize how the DCFlight VDOM handles property diffing for their specific components. This enables advanced optimizations without polluting the core framework with component-specific logic.

## Architecture

The system consists of three main parts:

1. **PropDiffInterceptor Interface** - Defines the contract for custom prop diffing
2. **VDomExtensionRegistry** - Manages registration of interceptors
3. **Core VDOM Integration** - Calls interceptors during reconciliation

## The Problem It Solves

### Without PropDiffInterceptor

```dart
// VDOM core would need component-specific logic:
Map<String, dynamic> _diffProps(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
  var changedProps = /* standard diffing logic */;
  
  // ❌ BAD: Core framework tied to specific components
  if (elementType == 'ReanimatedView') {
    // Animation-specific logic here
  }
  if (elementType == 'VideoPlayer') {
    // Video-specific logic here  
  }
  // More component-specific hacks...
  
  return changedProps;
}
```

### With PropDiffInterceptor

```dart
// ✅ GOOD: Core framework stays generic
Map<String, dynamic> _diffProps(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
  var changedProps = /* standard diffing logic */;
  
  // Let registered interceptors handle component-specific logic
  final interceptors = VDomExtensionRegistry.instance.getPropDiffInterceptors();
  for (final interceptor in interceptors) {
    if (interceptor.shouldHandle(elementType, oldProps, newProps)) {
      changedProps = interceptor.interceptPropDiff(elementType, oldProps, newProps, changedProps);
    }
  }
  
  return changedProps;
}
```

## Interface Definition

```dart
abstract class PropDiffInterceptor {
  /// Should this interceptor handle prop diffing for this element type?
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps);
  
  /// Modify the changed props before sending to native
  Map<String, dynamic> interceptPropDiff(
    String elementType,
    Map<String, dynamic> oldProps,
    Map<String, dynamic> newProps,
    Map<String, dynamic> changedProps,
  );
}
```

## Usage Guide

### Step 1: Implement the Interceptor

```dart
class ReanimatedPropDiffInterceptor extends PropDiffInterceptor {
  @override
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    return elementType == 'ReanimatedView';
  }
  
  @override
  Map<String, dynamic> interceptPropDiff(
    String elementType,
    Map<String, dynamic> oldProps, 
    Map<String, dynamic> newProps,
    Map<String, dynamic> changedProps,
  ) {
    // Don't re-send animation props if animationId is the same
    if (oldProps['animationId'] == newProps['animationId'] && 
        oldProps['animationId'] != null) {
      changedProps.remove('animatedStyle');
      changedProps.remove('autoStart');
      changedProps.remove('animationId');
    }
    return changedProps;
  }
}
```

### Step 2: Auto-Register the Interceptor

```dart
class ReanimatedInit {
  static bool _initialized = false;
  
  static void ensureInitialized() {
    if (_initialized) return;
    
    VDomExtensionRegistry.instance.registerPropDiffInterceptor(
      ReanimatedPropDiffInterceptor()
    );
    
    _initialized = true;
  }
}

// In your component constructor:
class ReanimatedView extends StatelessComponent {
  ReanimatedView({
    required this.children,
    // ... other params
  }) {
    ReanimatedInit.ensureInitialized(); // ✅ Auto-register on first use
  }
}
```

### Step 3: Use Your Component

```dart
// Developers just use your component - optimization happens automatically!
ReanimatedView(
  animationId: "my-animation",
  animatedStyle: Reanimated.fadeIn(),
  children: [
    DCFButton(
      buttonProps: DCFButtonProps(title: "Counter: ${state.state}"),
      onPress: (v) => state.setState(state.state + 1),
    ),
  ],
)
```

## Common Use Cases

### 1. Animation Components

**Problem**: Animation props shouldn't be re-sent when only content changes.

```dart
class AnimationInterceptor extends PropDiffInterceptor {
  @override
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    return elementType == 'AnimatedView' || elementType == 'ReanimatedView';
  }
  
  @override
  Map<String, dynamic> interceptPropDiff(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps, Map<String, dynamic> changedProps) {
    // Keep animation stable if animation ID unchanged
    if (oldProps['animationId'] == newProps['animationId'] && oldProps['animationId'] != null) {
      changedProps.remove('animatedStyle');
      changedProps.remove('duration');
      changedProps.remove('delay');
    }
    return changedProps;
  }
}
```

### 2. Media Components

**Problem**: Media should only restart when source changes, not when UI props change.

```dart
class MediaInterceptor extends PropDiffInterceptor {
  @override
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    return elementType == 'VideoPlayer' || elementType == 'AudioPlayer';
  }
  
  @override
  Map<String, dynamic> interceptPropDiff(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps, Map<String, dynamic> changedProps) {
    // Don't restart media if source is the same
    if (oldProps['source'] == newProps['source'] && oldProps['source'] != null) {
      changedProps.remove('autoPlay');
      changedProps.remove('startTime');
    }
    return changedProps;
  }
}
```

### 3. Expensive Computation Components

**Problem**: Expensive computations shouldn't re-run when only styling changes.

```dart
class ChartInterceptor extends PropDiffInterceptor {
  @override
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    return elementType == 'Chart' || elementType == 'Graph';
  }
  
  @override
  Map<String, dynamic> interceptPropDiff(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps, Map<String, dynamic> changedProps) {
    // Don't recalculate chart if data is the same
    if (_isDataUnchanged(oldProps['data'], newProps['data'])) {
      changedProps.remove('data');
      changedProps.remove('computeExpensiveLayout');
    }
    return changedProps;
  }
  
  bool _isDataUnchanged(dynamic oldData, dynamic newData) {
    // Custom deep comparison logic for chart data
    return oldData.toString() == newData.toString();
  }
}
```

### 4. Map Components

**Problem**: Map shouldn't re-initialize when only markers change.

```dart
class MapInterceptor extends PropDiffInterceptor {
  @override
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    return elementType == 'MapView';
  }
  
  @override
  Map<String, dynamic> interceptPropDiff(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps, Map<String, dynamic> changedProps) {
    // Don't re-initialize map if region is the same
    if (oldProps['region'] == newProps['region']) {
      changedProps.remove('initialRegion');
      changedProps.remove('mapType');
    }
    return changedProps;
  }
}
```

## Best Practices

### 1. Use Element Type Filtering

Always check the element type in `shouldHandle()`:

```dart
@override
bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
  return elementType == 'YourComponentType'; // ✅ Specific filtering
}
```

### 2. Auto-Registration Pattern

Use the auto-registration pattern for seamless developer experience:

```dart
class YourComponentInit {
  static bool _initialized = false;
  
  static void ensureInitialized() {
    if (_initialized) return;
    VDomExtensionRegistry.instance.registerPropDiffInterceptor(YourInterceptor());
    _initialized = true;
  }
}
```

### 3. Defensive Prop Checking

Always check if props exist before comparing:

```dart
@override
Map<String, dynamic> interceptPropDiff(/* params */) {
  // ✅ Safe prop checking
  if (oldProps['stableId'] != null && 
      oldProps['stableId'] == newProps['stableId']) {
    // Apply optimization
  }
  return changedProps;
}
```

### 4. Document Your Optimization

Clearly document what your interceptor optimizes:

```dart
/// Prevents animation restart when ReanimatedView content changes
/// but animationId remains the same. This allows UI updates without
/// interrupting ongoing animations.
class ReanimatedPropDiffInterceptor extends PropDiffInterceptor {
  // ...
}
```

### 5. Test Edge Cases

Test your interceptor with various scenarios:

```dart
void testInterceptor() {
  final interceptor = YourInterceptor();
  
  // Test same stable ID
  assert(interceptor.shouldHandle('YourType', {'id': 'same'}, {'id': 'same'}));
  
  // Test different stable ID
  assert(!interceptor.shouldHandle('YourType', {'id': 'old'}, {'id': 'new'}));
  
  // Test missing props
  assert(interceptor.shouldHandle('YourType', {}, {'id': 'new'}));
}
```

## Registration Methods

### Method 1: Auto-Registration (Recommended)

```dart
// In component constructor/first use
YourInit.ensureInitialized();
```

### Method 2: Manual Registration

```dart
// In app initialization
void main() {
  VDomExtensionRegistry.instance.registerPropDiffInterceptor(YourInterceptor());
  runApp(MyApp());
}
```

### Method 3: Conditional Registration

```dart
// Register only in certain conditions
if (Platform.isIOS) {
  VDomExtensionRegistry.instance.registerPropDiffInterceptor(IOSSpecificInterceptor());
}
```

## Performance Considerations

### 1. Efficient shouldHandle()

Make `shouldHandle()` fast since it's called for every prop diff:

```dart
@override
bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
  // ✅ Fast string comparison
  return elementType == 'YourType';
  
  // ❌ Avoid expensive operations here
  // return expensiveCheck(oldProps, newProps);
}
```

### 2. Minimal Property Removal

Only remove props that actually need optimization:

```dart
@override
Map<String, dynamic> interceptPropDiff(/* params */) {
  if (shouldOptimize(oldProps, newProps)) {
    changedProps.remove('expensiveProp'); // ✅ Specific removal
    // ❌ Don't remove everything: changedProps.clear();
  }
  return changedProps;
}
```

### 3. Cache Comparison Results

For expensive comparisons, consider caching:

```dart
class YourInterceptor extends PropDiffInterceptor {
  final Map<String, bool> _comparisonCache = {};
  
  bool _shouldOptimize(Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    final key = '${oldProps['id']}-${newProps['id']}';
    return _comparisonCache.putIfAbsent(key, () => 
      expensiveComparison(oldProps, newProps)
    );
  }
}
```

## Debugging

### Enable Prop Diff Logging

```dart
class DebugInterceptor extends PropDiffInterceptor {
  @override
  Map<String, dynamic> interceptPropDiff(/* params */) {
    print('🔍 PropDiff for $elementType:');
    print('  Old props: ${oldProps.keys}');
    print('  New props: ${newProps.keys}');
    print('  Changed props before: ${changedProps.keys}');
    
    // Your optimization logic
    
    print('  Changed props after: ${changedProps.keys}');
    return changedProps;
  }
}
```

### Verify Interceptor Registration

```dart
void debugInterceptors() {
  final interceptors = VDomExtensionRegistry.instance.getPropDiffInterceptors();
  print('📋 Registered interceptors: ${interceptors.length}');
  for (final interceptor in interceptors) {
    print('  - ${interceptor.runtimeType}');
  }
}
```


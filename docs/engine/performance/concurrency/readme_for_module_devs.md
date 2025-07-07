# Module Developer Concurrency Guide

## Introduction

As a DCFlight module developer, understanding and leveraging the concurrent VDOM is crucial for building high-performance components. This guide shows you how to optimize your modules for DCFlight's hybrid concurrent scheduling system.

## Why Concurrency Matters

### 🎯 **User Experience Impact**

**Without Concurrency**:
```dart
// All updates block each other
onButtonPress() {
  updateUserProfile();      // Blocks for 50ms
  refreshNotifications();   // Blocks for 30ms  
  updateAnalytics();        // Blocks for 20ms
  // Total: 100ms delay = janky UI
}
```

**With DCFlight Concurrency**:
```dart
// Updates are prioritized and time-sliced
onButtonPress() {
  updateUserProfile();      // High priority: 2ms
  refreshNotifications();   // Normal priority: runs later
  updateAnalytics();        // Low priority: background
  // Button responds in 2ms = smooth UI
}
```

### 📊 **Performance Benefits**

- **60fps Maintained**: Frame budget prevents UI blocking
- **Instant Feedback**: High-priority updates finish in 1-5ms
- **Smart Scheduling**: Critical work interrupts less important tasks
- **Battery Efficiency**: Idle components use minimal resources

## Component Priority System

### 🏆 **Priority Levels Explained**

```dart
enum ComponentPriority {
  immediate, // 1ms  - User is actively interacting RIGHT NOW
  high,      // 5ms  - User expects immediate visual feedback  
  normal,    // 16ms - Standard UI updates, visible content
  low,       // 50ms - Background data, non-critical updates
  idle;      // 100ms- Analytics, debugging, cleanup tasks
}
```

### ⚡ **When to Use Each Priority**

#### **Immediate Priority** (1ms time slice)
```dart
class TextInput extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
  
  // Use for:
  // - Text input cursor movement
  // - Scroll position updates  
  // - Touch interaction feedback
  // - Real-time drawing/gestures
}
```

#### **High Priority** (5ms time slice)
```dart
class NavigationButton extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  // Use for:
  // - Button press responses
  // - Navigation transitions
  // - Modal show/hide
  // - Form validation feedback
  // - Portal content updates
}
```

#### **Normal Priority** (16ms time slice)
```dart
class ContentView extends StatefulComponent {
  // Default priority - no interface needed
  
  // Use for:
  // - Content text updates
  // - Image loading states
  // - List item rendering
  // - Regular UI updates
}
```

#### **Low Priority** (50ms time slice)
```dart
class DataSyncComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
  
  // Use for:
  // - Background data fetching
  // - Cache updates
  // - Preloading content
  // - Non-urgent state changes
}
```

#### **Idle Priority** (100ms time slice)
```dart
class DebugPanel extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.idle;
  
  // Use for:
  // - Debug information
  // - Analytics tracking
  // - Cleanup operations
  // - Development tools
}
```

### 🎯 **Dynamic Priority Assignment**

Priority can change based on component state:

```dart
class AdaptiveMediaPlayer extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority {
    if (isUserScrubbing) return ComponentPriority.immediate;  // Real-time feedback
    if (isPlaying) return ComponentPriority.high;            // Smooth playback
    if (isVisible) return ComponentPriority.normal;          // Standard updates
    return ComponentPriority.low;                            // Background loading
  }
}
```

## Building Concurrency-Aware Components

### 🔧 **Basic Priority Implementation**

```dart
class MyModule extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  @override
  DCFComponentNode render() {
    final data = useState<String>('Loading...', 'data');
    
    useEffect(() {
      // This update will use HIGH priority
      loadData().then((result) => data.setState(result));
    }, dependencies: []);
    
    return DCFText(data.state);
  }
}
```

### 🎨 **Advanced Priority Strategies**

#### **Context-Aware Priority**
```dart
class SmartComponent extends StatefulComponent implements ComponentPriorityInterface {
  final bool isInteractive;
  final bool isVisible;
  final bool isUserFocused;
  
  @override
  ComponentPriority get priority {
    // User is actively interacting
    if (isUserFocused && isInteractive) {
      return ComponentPriority.immediate;
    }
    
    // Important but not immediate
    if (isVisible && isInteractive) {
      return ComponentPriority.high;
    }
    
    // Visible content
    if (isVisible) {
      return ComponentPriority.normal;
    }
    
    // Off-screen or background
    return ComponentPriority.low;
  }
}
```

#### **Performance-Based Priority**
```dart
class AdaptiveComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority {
    // Check frame budget usage
    final stats = VDom.instance.getConcurrencyStats();
    final frameBudgetUsed = stats['scheduler']['frameBudgetPercent'] as int;
    
    // Reduce priority if system is under load
    if (frameBudgetUsed > 80) {
      return ComponentPriority.low;  // Be nice to other components
    }
    
    return ComponentPriority.normal;
  }
}
```

## Optimizing State Updates

### ⚡ **Efficient State Management**

```dart
class OptimizedComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  @override
  DCFComponentNode render() {
    // Separate concerns by priority
    final criticalData = useState<String>('', 'critical');
    final backgroundData = useState<Map>({}, 'background');
    
    // High-priority user action
    void onUserAction() {
      criticalData.setState('Updated!'); // Uses HIGH priority
    }
    
    // Low-priority background update
    useEffect(() {
      // This runs at LOW priority (doesn't block UI)
      Timer(Duration(seconds: 1), () {
        fetchBackgroundData().then((data) {
          backgroundData.setState(data);
        });
      });
    }, dependencies: []);
    
    return DCFButton(
      onPress: onUserAction,
      child: DCFText(criticalData.state),
    );
  }
}
```

### 🧠 **Batching Strategy**

```dart
class BatchingComponent extends StatefulComponent {
  void performBulkUpdate() {
    // Multiple state changes are automatically batched
    // by the concurrent scheduler
    
    updateUserProfile();    // Scheduled together
    updatePreferences();    // Scheduled together  
    updateAnalytics();      // Scheduled together
    
    // All execute in one reconciliation cycle
  }
}
```

## Portal Components and High Priority

### 🚪 **Why Portals Use High Priority**

Portals render content outside normal component hierarchy, requiring immediate updates to prevent visual glitches:

```dart
class MyPortal extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high; // Like DCFPortal
  
  @override
  DCFComponentNode render() {
    return DCFPortal(
      targetId: 'modal-root',
      children: [
        DCFView(
          props: {'backgroundColor': 'rgba(0,0,0,0.5)'},
          children: [modalContent],
        ),
      ],
    );
  }
}
```

### 🎯 **Modal and Overlay Best Practices**

```dart
class ResponsiveModal extends StatefulComponent implements ComponentPriorityInterface {
  final bool isVisible;
  
  @override
  ComponentPriority get priority {
    // High priority when visible for smooth animations
    return isVisible ? ComponentPriority.high : ComponentPriority.low;
  }
  
  @override
  DCFComponentNode render() {
    if (!isVisible) return EmptyVDomNode();
    
    return DCFPortal(
      targetId: 'modal-root',
      children: [animatedModalContent],
    );
  }
}
```

## Performance Monitoring

### 📊 **Built-in Metrics**

```dart
class MonitoredComponent extends StatefulComponent {
  @override
  DCFComponentNode render() {
    useEffect(() {
      // Monitor concurrency performance in debug builds
      if (kDebugMode) {
        final stats = VDom.instance.getConcurrencyStats();
        
        print('Frame Budget Used: ${stats['scheduler']['frameBudgetPercent']}%');
        print('Queue Length: ${stats['normal']['queueLength']}');
        
        // Warn if frame budget is consistently high
        if (stats['scheduler']['frameBudgetPercent'] > 80) {
          print('⚠️ High frame budget usage - consider optimizing');
        }
      }
    }, dependencies: []);
    
    return myContent;
  }
}
```

### 🔍 **Custom Performance Tracking**

```dart
class ProfiledComponent extends StatefulComponent {
  void performExpensiveOperation() {
    final stopwatch = Stopwatch()..start();
    
    // Your expensive work here
    processLargeDataSet();
    
    stopwatch.stop();
    
    // Adjust priority based on performance
    if (stopwatch.elapsedMilliseconds > 10) {
      // This operation is expensive, use lower priority next time
      _setDynamicPriority(ComponentPriority.low);
    }
  }
}
```

## Common Patterns and Anti-Patterns

### ✅ **Good Practices**

#### **Priority Inheritance**
```dart
class ParentComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  @override
  DCFComponentNode render() {
    return DCFView(
      children: [
        // Child inherits parent's priority context
        ChildComponent(), // Benefits from HIGH priority
      ],
    );
  }
}
```

#### **Conditional Priority**
```dart
class ConditionalComponent extends StatefulComponent implements ComponentPriorityInterface {
  final bool isLoading;
  
  @override
  ComponentPriority get priority {
    // High priority during loading for responsive feedback
    return isLoading ? ComponentPriority.high : ComponentPriority.normal;
  }
}
```

### ❌ **Anti-Patterns**

#### **Immediate Priority Abuse**
```dart
// DON'T: Everything as immediate priority
class BadComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate; // ❌ TOO AGGRESSIVE
  
  // This starves other components and doesn't actually improve UX
}
```

#### **Ignoring Frame Budget**
```dart
// DON'T: Expensive work without time slicing
class HeavyComponent extends StatefulComponent {
  void expensiveWork() {
    // ❌ Blocks for 100ms
    for (int i = 0; i < 1000000; i++) {
      processItem(i);
    }
  }
}

// DO: Break work into chunks
class OptimizedHeavyComponent extends StatefulComponent {
  void expensiveWorkOptimized() {
    _processChunked(0, 1000000);
  }
  
  void _processChunked(int start, int total) {
    final chunkSize = 1000;
    final end = math.min(start + chunkSize, total);
    
    // Process chunk
    for (int i = start; i < end; i++) {
      processItem(i);
    }
    
    // Continue in next frame if more work
    if (end < total) {
      Timer(Duration.zero, () => _processChunked(end, total));
    }
  }
}
```

## Testing Concurrency

### 🧪 **Performance Testing**

```dart
void testComponentPerformance() {
  final vdom = VDom(mockBridge);
  
  // Enable performance monitoring
  vdom.setDebugLogging(true);
  
  // Create high-load scenario
  for (int i = 0; i < 100; i++) {
    vdom.createComponent(MyComponent(key: 'test_$i'));
  }
  
  // Check frame budget usage
  final stats = vdom.getConcurrencyStats();
  assert(stats['scheduler']['frameBudgetPercent'] < 80);
}
```

### 📏 **Priority Testing**

```dart
void testPriorityBehavior() {
  final component = MyComponent();
  
  // Test priority assignment
  assert(component.priority == ComponentPriority.high);
  
  // Test dynamic priority
  component.isInteractive = true;
  assert(component.priority == ComponentPriority.immediate);
}
```

## Module Distribution Guidelines

### 📦 **Documentation Requirements**

When publishing DCFlight modules, document:

1. **Component priorities** and rationale
2. **Performance characteristics** (time complexity, memory usage)
3. **Concurrency behavior** (blocking vs non-blocking operations)
4. **Frame budget impact** for heavy components

### 🏷️ **Priority Declarations**

```dart
/// High-priority interactive button component
/// 
/// **Concurrency**: Uses HIGH priority for instant user feedback
/// **Performance**: ~2ms update time, minimal frame budget impact
/// **Best for**: Navigation, forms, critical user interactions
class InteractiveButton extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
}
```

## Conclusion

DCFlight's concurrent VDOM gives you unprecedented control over UI performance. By understanding and leveraging the priority system, you can build modules that:

- **Respond instantly** to user interactions
- **Maintain 60fps** during complex updates  
- **Scale efficiently** under heavy load
- **Provide smooth UX** in all scenarios

Remember: concurrency is not just about speed—it's about creating **responsive, delightful user experiences** that feel instant and smooth.

---

**Next**: Read the [Component Priority Determination Guide](link) for detailed priority selection strategies.
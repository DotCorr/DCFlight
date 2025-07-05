# Component Priority Determination Guide

## Introduction

Choosing the right priority for your DCFlight components is crucial for optimal performance. This guide provides concrete decision trees, real-world examples, and best practices for determining component priorities.

## Priority Decision Framework

### 🎯 **The Priority Decision Tree**

```
Is the user actively interacting with this component RIGHT NOW?
├─ YES → IMMEDIATE (1ms)
│   ├─ Text cursor movement
│   ├─ Real-time drawing
│   ├─ Drag & drop operations
│   └─ Live scroll updates
│
└─ NO → Does the user expect immediate visual feedback?
    ├─ YES → HIGH (5ms)
    │   ├─ Button presses
    │   ├─ Navigation transitions
    │   ├─ Modal dialogs
    │   ├─ Form validation
    │   └─ Portal content
    │
    └─ NO → Is this component visible to the user?
        ├─ YES → NORMAL (16ms)
        │   ├─ Content updates
        │   ├─ Image loading
        │   ├─ List rendering
        │   └─ Text changes
        │
        └─ NO → Is this a background/system task?
            ├─ YES (Background) → LOW (50ms)
            │   ├─ Data synchronization
            │   ├─ Cache updates
            │   ├─ Preloading
            │   └─ Analytics
            │
            └─ YES (Development) → IDLE (100ms)
                ├─ Debug panels
                ├─ Performance monitoring
                ├─ Cleanup tasks
                └─ Development tools
```

## Priority Categories in Detail

### ⚡ **IMMEDIATE Priority (1ms)**

**When to Use**: User is actively manipulating the component with real-time feedback expected.

#### **Text Input Components**
```dart
class RealTimeTextEditor extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
  
  // Examples:
  // - Cursor position updates
  // - Character insertion/deletion
  // - Text selection changes
  // - Auto-complete suggestions
}
```

#### **Touch/Gesture Components**
```dart
class DrawingCanvas extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
  
  // Examples:
  // - Drawing/painting apps
  // - Signature capture
  // - Real-time gesture recognition
  // - Interactive diagrams
}
```

#### **Scroll Components**
```dart
class HighPerformanceScrollView extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
  
  // Examples:
  // - Smooth scrolling lists
  // - Parallax effects
  // - Infinite scroll
  // - Virtual scrolling
}
```

#### **Real-Time Media**
```dart
class LiveVideoPlayer extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
  
  // Examples:
  // - Video scrubbing
  // - Audio waveform updates
  // - Live streaming controls
  // - Real-time filters
}
```

### 🔥 **HIGH Priority (5ms)**

**When to Use**: User expects instant visual feedback for their action.

#### **Interactive Controls**
```dart
class ResponsiveButton extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  // Examples:
  // - Buttons (press feedback)
  // - Switches/toggles
  // - Sliders
  // - Tab selection
}
```

#### **Navigation Components**
```dart
class NavigationController extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  // Examples:
  // - Route transitions
  // - Back button
  // - Menu navigation
  // - Breadcrumbs
}
```

#### **Modal/Overlay Systems**
```dart
class ModalDialog extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  // Examples:
  // - Alert dialogs
  // - Bottom sheets
  // - Popover menus
  // - Toast notifications
}
```

#### **Portal Components** (like DCFPortal)
```dart
class CustomPortal extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  // Why HIGH priority:
  // - Rendered outside normal hierarchy
  // - Visual glitches if delayed
  // - User expects instant appearance
  // - Often used for critical UI (modals, tooltips)
}
```

#### **Form Validation**
```dart
class FormField extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
  
  // Examples:
  // - Inline validation messages
  // - Error highlighting
  // - Success indicators
  // - Field completion status
}
```

### 📄 **NORMAL Priority (16ms)** - DEFAULT

**When to Use**: Standard UI updates for visible content.

#### **Content Components**
```dart
class ContentView extends StatefulComponent {
  // No interface needed - uses default NORMAL priority
  
  // Examples:
  // - Article text
  // - Blog posts
  // - Product descriptions
  // - News feeds
}
```

#### **Media Components**
```dart
class ImageGallery extends StatefulComponent {
  // Examples:
  // - Image loading states
  // - Photo galleries
  // - Video thumbnails
  // - Media carousels
}
```

#### **List Components**
```dart
class DataList extends StatefulComponent {
  // Examples:
  // - Static lists
  // - Search results
  // - Product listings
  // - Contact lists
}
```

### 🐌 **LOW Priority (50ms)**

**When to Use**: Background operations that don't affect immediate user experience.

#### **Data Management**
```dart
class BackgroundDataSync extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
  
  // Examples:
  // - API data fetching
  // - Cache updates
  // - Database synchronization
  // - File downloads
}
```

#### **Analytics & Tracking**
```dart
class AnalyticsTracker extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
  
  // Examples:
  // - User behavior tracking
  // - Performance metrics
  // - Crash reporting
  // - Usage statistics
}
```

#### **Preloading & Optimization**
```dart
class ContentPreloader extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
  
  // Examples:
  // - Image preloading
  // - Route preloading
  // - Data prefetching
  // - Cache warming
}
```

### 😴 **IDLE Priority (100ms)**

**When to Use**: Development tools and non-production features.

#### **Debug Components**
```dart
class DebugPanel extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.idle;
  
  // Examples:
  // - Performance monitors
  // - Debug overlays
  // - Development tools
  // - Logging interfaces
}
```

#### **Testing Utilities**
```dart
class TestingHelpers extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.idle;
  
  // Examples:
  // - UI testing tools
  // - Mock data generators
  // - Testing controls
  // - Debug buttons
}
```

## Dynamic Priority Strategies

### 🎯 **Context-Aware Priority**

```dart
class AdaptiveComponent extends StatefulComponent implements ComponentPriorityInterface {
  final bool isUserInteracting;
  final bool isVisible;
  final bool isCriticalPath;
  
  @override
  ComponentPriority get priority {
    // User is actively using this component
    if (isUserInteracting) {
      return ComponentPriority.immediate;
    }
    
    // Critical user flow (checkout, login, etc.)
    if (isCriticalPath) {
      return ComponentPriority.high;
    }
    
    // Visible but not actively used
    if (isVisible) {
      return ComponentPriority.normal;
    }
    
    // Background/off-screen
    return ComponentPriority.low;
  }
}
```

### 📱 **Device Performance Adaptation**

```dart
class PerformanceAwareComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority {
    // Check system performance
    final stats = VDom.instance.getConcurrencyStats();
    final frameBudgetUsed = stats['scheduler']['frameBudgetPercent'] as int;
    
    // Reduce priority on slower devices or high load
    if (frameBudgetUsed > 80) {
      return ComponentPriority.low;  // Be conservative
    } else if (frameBudgetUsed > 60) {
      return ComponentPriority.normal;
    } else {
      return ComponentPriority.high; // System has headroom
    }
  }
}
```

### 🔄 **State-Based Priority**

```dart
class StatefulPriorityComponent extends StatefulComponent implements ComponentPriorityInterface {
  final String state; // 'loading', 'interactive', 'complete', 'error'
  
  @override
  ComponentPriority get priority {
    switch (state) {
      case 'interactive':
        return ComponentPriority.immediate; // User is interacting
      case 'loading':
        return ComponentPriority.high;      // Show loading feedback
      case 'error':
        return ComponentPriority.high;      // Show errors immediately
      case 'complete':
        return ComponentPriority.normal;    // Standard content
      default:
        return ComponentPriority.low;       // Background states
    }
  }
}
```

### ⏰ **Time-Based Priority**

```dart
class TimeAwarePriorityComponent extends StatefulComponent implements ComponentPriorityInterface {
  final DateTime createdAt = DateTime.now();
  
  @override
  ComponentPriority get priority {
    final age = DateTime.now().difference(createdAt);
    
    // Newer components get higher priority
    if (age.inSeconds < 5) {
      return ComponentPriority.high;    // Fresh content
    } else if (age.inMinutes < 1) {
      return ComponentPriority.normal;  // Recent content
    } else {
      return ComponentPriority.low;     // Older content
    }
  }
}
```

## Real-World Component Examples

### 🛒 **E-Commerce App**

```dart
// Shopping Cart Button - Immediate feedback expected
class CartButton extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
}

// Product Search - Real-time filtering
class SearchInput extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
}

// Product List - Visible content
class ProductList extends StatefulComponent {
  // Uses default NORMAL priority
}

// Recommendation Engine - Background processing
class RecommendationEngine extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
}

// Analytics Tracking - Non-critical
class PurchaseAnalytics extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
}
```

### 📱 **Social Media App**

```dart
// Like Button - Instant feedback
class LikeButton extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
}

// Live Comments - Real-time updates
class LiveComments extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
}

// Photo Feed - Visible content
class PhotoFeed extends StatefulComponent {
  // Uses default NORMAL priority
}

// Story Preloader - Background optimization
class StoryPreloader extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
}
```

### 🎮 **Gaming App**

```dart
// Game Controls - Real-time input
class GameController extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;
}

// Score Display - Immediate feedback
class ScoreBoard extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
}

// Background Music - Standard playback
class BackgroundMusic extends StatefulComponent {
  // Uses default NORMAL priority
}

// Achievement System - Background processing
class AchievementTracker extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;
}
```

## Priority Anti-Patterns

### ❌ **Common Mistakes**

#### **Everything is Immediate**
```dart
// DON'T: Overusing immediate priority
class BadComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate; // ❌
  
  // This creates priority inversion and starves other components
}
```

#### **Ignoring User Context**
```dart
// DON'T: Static priority without considering usage
class StaticPriorityComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high; // ❌ Always high
  
  // Should consider: Is user interacting? Is it visible? Is it critical?
}
```

#### **Background Work as High Priority**
```dart
// DON'T: Background tasks with high priority
class BackgroundTask extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high; // ❌
  
  void syncDataInBackground() {
    // This should be LOW priority, not HIGH
  }
}
```

### ✅ **Correct Approaches**

#### **Contextual Priority**
```dart
// DO: Consider user context
class SmartComponent extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority {
    if (isUserInteracting) return ComponentPriority.immediate;
    if (isVisible && isImportant) return ComponentPriority.high;
    if (isVisible) return ComponentPriority.normal;
    return ComponentPriority.low;
  }
}
```

#### **Progressive Enhancement**
```dart
// DO: Start conservative, escalate when needed
class ProgressiveComponent extends StatefulComponent implements ComponentPriorityInterface {
  ComponentPriority _currentPriority = ComponentPriority.normal;
  
  @override
  ComponentPriority get priority => _currentPriority;
  
  void onUserInteraction() {
    _currentPriority = ComponentPriority.high; // Escalate
    scheduleUpdate();
  }
  
  void onInteractionEnd() {
    _currentPriority = ComponentPriority.normal; // Return to normal
    scheduleUpdate();
  }
}
```

## Testing Priority Decisions

### 🧪 **Priority Validation Tests**

```dart
void testComponentPriorities() {
  group('Component Priority Tests', () {
    test('Interactive components use high priority', () {
      final button = InteractiveButton();
      expect(button.priority, ComponentPriority.high);
    });
    
    test('Background tasks use low priority', () {
      final analytics = AnalyticsTracker();
      expect(analytics.priority, ComponentPriority.low);
    });
    
    test('Real-time components use immediate priority', () {
      final textInput = RealTimeTextEditor();
      expect(textInput.priority, ComponentPriority.immediate);
    });
  });
}
```

### 📊 **Performance Impact Testing**

```dart
void testFrameBudgetImpact() {
  final vdom = VDom(mockBridge);
  
  // Test high-load scenario
  for (int i = 0; i < 100; i++) {
    vdom.createComponent(TestComponent(priority: ComponentPriority.high));
  }
  
  // Verify frame budget isn't exceeded
  final stats = vdom.getConcurrencyStats();
  final frameBudgetUsed = stats['scheduler']['frameBudgetPercent'] as int;
  
  expect(frameBudgetUsed, lessThan(80)); // Should stay under 80%
}
```

### 🔍 **Priority Behavior Testing**

```dart
void testDynamicPriorityBehavior() {
  final component = AdaptiveComponent(isUserInteracting: false);
  
  // Initial state
  expect(component.priority, ComponentPriority.normal);
  
  // User starts interacting
  component.isUserInteracting = true;
  expect(component.priority, ComponentPriority.immediate);
  
  // User stops interacting
  component.isUserInteracting = false;
  expect(component.priority, ComponentPriority.normal);
}
```

## Priority Documentation Template

### 📝 **Component Documentation**

When documenting your components, include priority information:

```dart
/// Interactive navigation button with high-priority updates
/// 
/// **Priority**: HIGH (5ms time slice)
/// **Rationale**: Users expect immediate visual feedback for navigation actions
/// **Performance**: ~2ms average update time, minimal frame budget impact
/// **Use cases**: Primary navigation, form submission, critical user actions
/// 
/// ```dart
/// NavigationButton(
///   text: 'Go to Profile',
///   onPress: () => navigator.push('/profile'),
/// )
/// ```
class NavigationButton extends StatefulComponent implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;
}
```

### 📊 **Module Performance Profile**

```dart
/// Performance Profile for MyModule
/// 
/// **Component Priorities**:
/// - InteractiveButton: HIGH (user feedback)
/// - ContentView: NORMAL (visible content)
/// - DataSync: LOW (background processing)
/// 
/// **Frame Budget Impact**: 
/// - Light load: <10% of frame budget
/// - Heavy load: <25% of frame budget
/// - Peak load: <40% of frame budget
/// 
/// **Recommended Usage**:
/// - Max 10 interactive components per screen
/// - Batch background operations
/// - Monitor frame budget in development
```

## Best Practices Summary

### ✅ **Do's**

1. **Start with NORMAL** priority and optimize based on user needs
2. **Use IMMEDIATE** only for real-time user interactions
3. **Apply HIGH** priority to user-facing feedback and navigation
4. **Assign LOW** priority to background tasks and analytics
5. **Reserve IDLE** for development and debugging tools
6. **Consider dynamic priority** based on component state
7. **Test performance impact** of priority decisions
8. **Document priority rationale** for other developers

### ❌ **Don'ts**

1. **Don't default to IMMEDIATE** unless genuinely real-time
2. **Don't ignore frame budget** warnings in development
3. **Don't mix priority levels** randomly without strategy
4. **Don't forget about background tasks** - they need LOW priority
5. **Don't assume all user interactions** need IMMEDIATE priority
6. **Don't skip performance testing** with realistic component counts
7. **Don't change priorities** without measuring impact

## Conclusion

Proper priority assignment is the key to unlocking DCFlight's full performance potential. By following this guide's decision framework and real-world examples, you can create components that provide excellent user experiences while maintaining optimal system performance.

Remember: **Priority is not just about speed—it's about creating the right user experience at the right time with the right amount of system resources.**

The goal is responsive, smooth, delightful interfaces that feel instant when they need to be and efficient always.

---

**Key Takeaway**: Use the decision tree, consider user context, test performance impact, and document your choices. DCFlight's concurrent VDOM will handle the rest!
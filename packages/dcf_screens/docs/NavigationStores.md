# Navigation Store Architecture

## Overview

The DCF Navigation System uses a reactive store-based architecture to manage navigation state efficiently. This document explains how the stores work, their relationships, and how they enable automatic suspense and state management.

## Store Architecture

```
┌─────────────────────┐    ┌─────────────────────┐
│ Navigation Commands │    │   Navigation State  │
├─────────────────────┤    ├─────────────────────┤
│ globalNavigationCmd │───▶│ activeScreenTracker │
│ globalNavigationTgt │    │ navigationStackTrkr │
└─────────────────────┘    └─────────────────────┘
           │                          │
           ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐
│   Command Routing   │    │  Suspense Decision  │
│                     │    │                     │
│ DCFEasyScreen       │    │    DCFSuspense      │
│ determines if it    │    │  shouldRender =     │
│ should handle cmd   │    │  activeScreen ||    │
│                     │    │  inNavStack ||      │
│                     │    │  isHome             │
└─────────────────────┘    └─────────────────────┘
```

## Core Stores

### 1. globalNavigationCommand

**Type**: `Store<RouteNavigationCommand?>`
**Purpose**: Holds the current navigation command to be executed
**Lifecycle**: Set by AppNavigation → Consumed by DCFEasyScreen → Cleared after execution

```dart
final globalNavigationCommand = Store<RouteNavigationCommand?>(null);

// Usage examples:
globalNavigationCommand.setState(RouteNavigationCommand(
  navigateToRoute: NavigateToRouteCommand(route: "profile")
));

// Cleared after processing:
globalNavigationCommand.setState(null);
```

**Command Types**:
- `NavigateToRouteCommand` - Push navigation
- `PopRouteCommand` - Back navigation  
- `PopToRouteCommand` - Pop to specific route
- `ReplaceWithRouteCommand` - Replace current route
- `PresentModalRouteCommand` - Modal presentation
- `DismissModalRouteCommand` - Modal dismissal

### 2. globalNavigationTarget

**Type**: `Store<String?>`
**Purpose**: Specifies which screen should handle the navigation command
**Lifecycle**: Set by AppNavigation → Used by DCFEasyScreen for command routing → Cleared after execution

```dart
final globalNavigationTarget = Store<String?>(null);

// Targeted navigation:
globalNavigationTarget.setState("profile"); // Only profile screen handles command

// Broadcast navigation:
globalNavigationTarget.setState(null); // Any screen can handle command
```

**Command Routing Logic**:
```dart
// In DCFEasyScreen
routeNavigationCommand: _shouldHandleCommand(route, globalTarget.state) 
    ? globalCommand.state 
    : null,

bool _shouldHandleCommand(String screenRoute, String? targetRoute) {
  if (targetRoute == null) return true;  // Broadcast command
  return screenRoute == targetRoute;     // Targeted command
}
```

### 3. activeScreenTracker

**Type**: `Store<String?>`
**Purpose**: Tracks which screen is currently active/visible
**Lifecycle**: Updated by AppNavigation (predictive) → Confirmed by DCFEasyScreen (onAppear)

```dart
final activeScreenTracker = Store<String?>("home");

// Predictive update (immediate UI response):
activeScreenTracker.setState("profile");

// Confirmed update (when navigation completes):
// DCFEasyScreen automatically calls this in onAppear
activeScreenTracker.setState("profile");
```

**Usage in Suspense**:
```dart
// DCFSuspense uses this for render decisions
bool shouldRender = activeScreenTracker.state == route;
```

### 4. navigationStackTracker

**Type**: `Store<List<String>>`
**Purpose**: Maintains the current navigation stack for back navigation and suspense
**Lifecycle**: Updated by AppNavigation → Used by DCFSuspense for render decisions

```dart
final navigationStackTracker = Store<List<String>>(["home"]);

// Stack evolution:
navigationStackTracker.setState(["home"]);                    // Initial
navigationStackTracker.setState(["home", "profile"]);         // Navigate to profile
navigationStackTracker.setState(["home", "profile", "settings"]); // Navigate to settings
navigationStackTracker.setState(["home", "profile"]);         // Back from settings
```

**Stack Management Logic**:
```dart
// Forward navigation
static void _updateNavigationStack(String route) {
  final currentStack = List<String>.from(navigationStackTracker.state);
  
  // Handle nested routes
  if (route.contains("/")) {
    final parentRoute = route.split("/")[0];
    if (!currentStack.contains(parentRoute)) {
      currentStack.add(parentRoute);
    }
  }
  
  if (!currentStack.contains(route)) {
    currentStack.add(route);
  }
  
  navigationStackTracker.setState(currentStack);
}

// Back navigation
static void goBack() {
  final currentStack = List<String>.from(navigationStackTracker.state);
  if (currentStack.length > 1) {
    currentStack.removeLast();
    final revealedScreen = currentStack.last;
    activeScreenTracker.setState(revealedScreen);
    navigationStackTracker.setState(currentStack);
  }
}
```

## Store Relationships

### Command Flow
```
AppNavigation.navigateTo("profile", fromScreen: "home")
    │
    ├── globalNavigationTarget.setState("home")
    ├── globalNavigationCommand.setState(command)
    ├── activeScreenTracker.setState("profile")      // Predictive
    └── navigationStackTracker.setState([...])       // Predictive
    
DCFEasyScreen (route: "home")
    │
    ├── useStore(globalNavigationCommand)           // Receives command
    ├── useStore(globalNavigationTarget)            // Checks if targeted
    └── Processes command if targeted to "home"
    
iOS Navigation System
    │
    └── Fires onAppear event for "profile" screen
    
DCFEasyScreen (route: "profile")  
    │
    ├── onAppear: activeScreenTracker.setState("profile")  // Confirmation
    └── AppNavigation.clearCommand()                       // Cleanup
```

### Suspense Flow
```
DCFSuspense Component
    │
    ├── activeScreen = useStore(activeScreenTracker)
    ├── navStack = useStore(navigationStackTracker)
    │
    └── shouldRender = activeScreen == route ||
                       navStack.contains(route) ||
                       route == "home"
    
Render Decision
    │
    ├── if shouldRender: builder()              // Create actual component
    └── else: fallback() || empty DCFView       // Placeholder or nothing
```

## State Synchronization

### Immediate Updates (Predictive)
```dart
// AppNavigation provides immediate UI feedback
AppNavigation.navigateTo("profile");
// ↓ Immediate (same frame)
activeScreenTracker.setState("profile");        // UI updates immediately
navigationStackTracker.setState(["home", "profile"]); // Suspense re-evaluates
```

### Confirmed Updates (Event-Driven)
```dart
// DCFEasyScreen confirms state when navigation actually completes
onAppear: (data) {
  activeScreenTracker.setState(route);          // Confirms prediction was correct
}

onNavigationEvent: (data) {
  _autoHandleNavigationEvent(data);             // Handles complex navigation
  AppNavigation.clearCommand();                 // Cleans up commands
}
```

### Error Correction
If predictive updates are wrong (rare), the event-driven updates correct them:

```dart
// Prediction: user navigates to "profile"
activeScreenTracker.setState("profile");

// Reality: navigation was cancelled
onNavigationEvent: (data) {
  if (data['action'] == 'cancelled') {
    activeScreenTracker.setState(previousScreen); // Corrects state
  }
}
```

## Performance Characteristics

### Memory Usage
```
Traditional Navigation (All Screens Always Rendered):
├── HomeScreen: 2MB (always in memory)
├── ProfileScreen: 3MB (always in memory)  
├── SettingsScreen: 1.5MB (always in memory)
├── AnimationScreen: 8MB (always in memory) ⚠️ WASTEFUL
└── Total: 14.5MB

DCF Navigation (Suspense-Based):
├── HomeScreen: 2MB (active)
├── ProfileScreen: 0.1MB (suspended - placeholder only)
├── SettingsScreen: 0.1MB (suspended - placeholder only)  
├── AnimationScreen: 0.1MB (suspended - placeholder only) ✅ EFFICIENT
└── Total: 2.3MB (84% memory reduction)
```

### CPU Usage
```
Store Updates per Navigation:
├── activeScreenTracker: 1 update (immediate)
├── navigationStackTracker: 1 update (immediate)
├── globalNavigationCommand: 2 updates (set → clear)
├── globalNavigationTarget: 2 updates (set → clear)
└── Total: 6 lightweight store updates (minimal CPU impact)

Component Re-renders:
├── DCFSuspense components: Re-evaluate shouldRender (fast)
├── Only newly active screen: Full render
├── Previously active screen: Continues rendering (in stack)
└── All other screens: No re-render (suspended)
```

### Network Usage
```
Lazy Loading Benefits:
├── Images: Only loaded when screen becomes active
├── API calls: Only triggered when component actually renders  
├── Heavy computations: Deferred until screen is visible
└── Network requests: Reduced by 70-90% for typical apps
```

## Advanced Patterns

### Nested Route Handling
```dart
// Route: "profile/settings/advanced"
// Stack: ["home", "profile", "profile/settings", "profile/settings/advanced"]

static void _updateNavigationStack(String route) {
  final currentStack = List<String>.from(navigationStackTracker.state);
  
  if (route.contains("/")) {
    final parts = route.split("/");
    
    // Add intermediate routes
    for (int i = 1; i <= parts.length; i++) {
      final intermediateRoute = parts.take(i).join("/");
      if (!currentStack.contains(intermediateRoute)) {
        currentStack.add(intermediateRoute);
      }
    }
  }
  
  navigationStackTracker.setState(currentStack);
}
```

### Modal Stack Management
```dart
// Modal presentation doesn't replace stack, adds to it
AppNavigation.presentModal("photo_picker");
// Stack before: ["home", "profile"]
// Stack after: ["home", "profile", "photo_picker"]

// Modal dismissal returns to previous screen
AppNavigation.dismissModal();
// Stack: ["home", "profile"] (photo_picker removed)
// Active: "profile" (restored)
```

### Tab Navigation Integration
```dart
// Each tab maintains its own stack
final tabStacks = {
  "home_tab": ["home", "notifications"],
  "profile_tab": ["profile", "settings"],
  "search_tab": ["search"]
};

// Switching tabs restores the tab's stack
void switchToTab(String tabId) {
  final tabStack = tabStacks[tabId] ?? [tabId];
  navigationStackTracker.setState(tabStack);
  activeScreenTracker.setState(tabStack.last);
}
```

## Debugging Store State

### Debug Utilities
```dart
// Log current state
void debugNavigationState() {
  print("🔍 Navigation Debug State:");
  print("  Active Screen: ${activeScreenTracker.state}");
  print("  Navigation Stack: ${navigationStackTracker.state}");
  print("  Pending Command: ${globalNavigationCommand.state?.toMap()}");
  print("  Command Target: ${globalNavigationTarget.state}");
}

// Reset state for testing
void resetNavigationState() {
  activeScreenTracker.setState("home");
  navigationStackTracker.setState(["home"]);
  globalNavigationCommand.setState(null);
  globalNavigationTarget.setState(null);
}
```

### Store Watchers
```dart
// Monitor store changes
class NavigationDebugger {
  static void startWatching() {
    activeScreenTracker.addListener((screen) {
      print("🎯 Active screen changed to: $screen");
    });
    
    navigationStackTracker.addListener((stack) {
      print("📚 Navigation stack updated: $stack");
    });
    
    globalNavigationCommand.addListener((command) {
      if (command != null) {
        print("🧭 New navigation command: ${command.toMap()}");
      } else {
        print("🧹 Navigation command cleared");
      }
    });
  }
}
```

### Performance Monitoring
```dart
class NavigationPerformanceMonitor {
  static final Map<String, DateTime> _navigationTimes = {};
  
  static void startNavigation(String route) {
    _navigationTimes[route] = DateTime.now();
    print("⏱️ Navigation started to: $route");
  }
  
  static void endNavigation(String route) {
    final startTime = _navigationTimes[route];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      print("✅ Navigation completed to $route in ${duration.inMilliseconds}ms");
      _navigationTimes.remove(route);
    }
  }
}
```

## Best Practices

### ✅ DO

- **Use targeted navigation** with `fromScreen` parameter
- **Let stores manage state automatically** - don't manually update
- **Monitor store state** during development for debugging
- **Use the stack for back navigation logic** - it's maintained automatically
- **Leverage predictive updates** for immediate UI responsiveness

### ❌ DON'T

- **Manually update stores** outside of AppNavigation and DCFEasyScreen
- **Assume store state is synchronous** with native navigation
- **Clear commands manually** - DCFEasyScreen handles this
- **Bypass the store system** for navigation state
- **Store sensitive data** in navigation stores (they're for routing only)

## Store Migration Guide

### From Manual State Management
```dart
// ❌ Before: Manual state tracking
class NavigationManager {
  static String currentScreen = "home";
  static List<String> navigationStack = ["home"];
  
  static void navigateTo(String route) {
    currentScreen = route;
    navigationStack.add(route);
    // Manual UI updates...
  }
}

// ✅ After: Store-based architecture
// Just use AppNavigation - stores are handled automatically
AppNavigation.navigateTo("profile");
```

### Integration with Existing State
```dart
// Combine with your existing state management
class AppState {
  // Your existing state
  static final userState = Store<User?>(null);
  static final settingsState = Store<Settings>(defaultSettings);
  
  // DCF Navigation stores (add these)
  static final navigationStores = {
    'command': globalNavigationCommand,
    'target': globalNavigationTarget, 
    'activeScreen': activeScreenTracker,
    'stack': navigationStackTracker,
  };
}
```

## Related Documentation

- [DCFEasyScreen Integration](./DCFEasyScreen.md#store-integration)
- [AppNavigation Store Usage](./AppNavigation.md#store-synchronization)
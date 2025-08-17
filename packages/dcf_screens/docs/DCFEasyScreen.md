# DCFEasyScreen Component

## Overview

`DCFEasyScreen` is a high-level wrapper around `DCFScreen` that eliminates 75% of navigation boilerplate code while providing automatic suspense, state management, and event handling.

## Key Benefits

- 🧹 **75% Less Boilerplate**: Reduces screen definitions from 20+ lines to 4 lines
- 🎬 **Automatic Suspense**: Prevents premature component creation and animation
- 🧭 **Smart Navigation**: Handles command routing and state updates automatically  
- 🔄 **Event Management**: Processes navigation events with zero configuration
- ⚙️ **Optional Overrides**: Full customization available when needed

## Quick Start

### Before (Manual DCFScreen)
```dart
DCFScreen(
  route: "home/animated_modal",
  presentationStyle: DCFPresentationStyle.push,
  routeNavigationCommand: _shouldHandleCommand("home/animated_modal", globalNavTarget.state) 
      ? globalNavCommand.state : null,
  onNavigationEvent: (data) {
    print("🚀 Navigation event: $data");
    _handleNavigationEvents("home/animated_modal", data);
    AppNavigation.clearCommand();
  },
  onAppear: (data) {
    print("✅ Route appeared: $data");
    activeScreenTracker.setState("home/animated_modal");
  },
  builder: () => DCFSuspense(
    shouldRender: _shouldRenderScreen("home/animated_modal"),
    debugName: "AnimatedModal",
    children: () => AnimatedModalScreen(),
  ),
),
```

### After (DCFEasyScreen)
```dart
DCFEasyScreen(
  route: "home/animated_modal",
  presentationStyle: DCFPresentationStyle.push,
  builder: () => AnimatedModalScreen(),
),
```

## API Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `route` | `String` | Unique screen identifier |
| `presentationStyle` | `DCFPresentationStyle` | How screen is presented |
| `builder` | `DCFComponentNode Function()` | Screen content builder |

### Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pushConfig` | `DCFPushConfig?` | `null` | Push navigation configuration |
| `tabConfig` | `DCFTabConfig?` | `null` | Tab navigation configuration |
| `modalConfig` | `DCFModalConfig?` | `null` | Modal presentation configuration |
| `alwaysRender` | `bool` | `false` | Skip suspense (always render) |
| `placeholder` | `DCFComponentNode Function()?` | `null` | Custom suspended state |

### Event Override Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `onAppear` | `Function(Map)?` | Called after automatic state update |
| `onDisappear` | `Function(Map)?` | Called when screen disappears |
| `onNavigationEvent` | `Function(Map)?` | Called after automatic event handling |
| `onHeaderActionPress` | `Function(Map)?` | Called when header action pressed |
| `onReceiveParams` | `Function(Map)?` | Called when receiving navigation params |

## Usage Examples

### Minimal Screen
```dart
DCFEasyScreen(
  route: "about",
  presentationStyle: DCFPresentationStyle.push,
  builder: () => AboutScreen(),
)
```

### Screen with Title
```dart
DCFEasyScreen(
  route: "settings",
  presentationStyle: DCFPresentationStyle.push,
  pushConfig: DCFPushConfig(title: "Settings"),
  builder: () => SettingsScreen(),
)
```

### Screen with Header Actions
```dart
DCFEasyScreen(
  route: "profile",
  presentationStyle: DCFPresentationStyle.push,
  pushConfig: DCFPushConfig(
    title: "Profile",
    suffixActions: [
      DCFPushHeaderActionConfig.withSVGPackage(
        title: "Edit",
        package: "icons",
        iconName: "edit",
        actionId: "edit_profile",
      ),
    ],
  ),
  onHeaderActionPress: (data) {
    if (data['actionId'] == "edit_profile") {
      AppNavigation.navigateTo("profile/edit");
    }
  },
  builder: () => ProfileScreen(),
)
```

### Always Rendered Screen
```dart
DCFEasyScreen(
  route: "home",
  presentationStyle: DCFPresentationStyle.push,
  alwaysRender: true, // Never suspend this screen
  pushConfig: DCFPushConfig(title: "Home"),
  builder: () => HomeScreen(),
)
```

### Screen with Custom Placeholder
```dart
DCFEasyScreen(
  route: "heavy_animations",
  presentationStyle: DCFPresentationStyle.push,
  placeholder: () => DCFView(
    children: [
      DCFText(content: "Loading animations..."),
      DCFActivityIndicator(),
    ],
  ),
  builder: () => HeavyAnimationScreen(),
)
```

### Screen with Custom Event Handling
```dart
DCFEasyScreen(
  route: "analytics",
  presentationStyle: DCFPresentationStyle.push,
  onAppear: (data) {
    // Custom logic runs AFTER automatic state update
    AnalyticsService.trackScreenView("analytics");
  },
  onNavigationEvent: (data) {
    // Custom logic runs AFTER automatic event handling
    print("Custom analytics navigation: $data");
  },
  builder: () => AnalyticsScreen(),
)
```

## Automatic Features

### 🧭 Navigation Command Routing
DCFEasyScreen automatically handles navigation commands targeted to its route:

```dart
// This command will only be handled by the "settings" screen
AppNavigation.navigateTo("settings", fromScreen: "home");
```

### 🎯 Active Screen Tracking
Automatically updates `activeScreenTracker` when screen appears:

```dart
// Happens automatically in DCFEasyScreen
activeScreenTracker.setState(route);
```

### 🔄 Navigation Event Processing
Automatically processes navigation events and updates state:

```dart
// Automatic handling for pop, popTo, popToRoot, etc.
switch (action) {
  case 'pop':
    if (targetRoute == route) {
      activeScreenTracker.setState(route);
    }
    break;
}
```

### 🎬 Intelligent Suspense
Automatically wraps builder with DCFSuspense using smart logic:

```dart
bool shouldRender = 
    activeScreen == route ||           // Current screen
    navStack.contains(route) ||        // In navigation stack  
    route == "home";                   // Always render home
```

### 🧹 Command Cleanup
Automatically clears navigation commands after processing:

```dart
AppNavigation.clearCommand(); // Called automatically
```

## Debug Output

DCFEasyScreen provides comprehensive debug logging:

```
✅ profile route appeared: {route: profile}
🚀 profile navigation event: {action: pop, targetRoute: home}
🔍 Navigation event for profile: action=pop, target=home
🏗️ DCFSuspense[profile]: Rendering children (active)
⏸️ DCFSuspense[settings]: Rendering fallback (suspended)
```

## Best Practices

### ✅ DO

- Use `DCFEasyScreen` for all new screens
- Set `alwaysRender: true` only for critical screens (like home)
- Provide custom `onHeaderActionPress` for interactive headers
- Use descriptive route names for better debugging

### ❌ DON'T

- Mix `DCFEasyScreen` and manual `DCFScreen` unnecessarily
- Set `alwaysRender: true` on every screen
- Override navigation events unless you need custom logic
- Forget to clear navigation commands if overriding `onNavigationEvent`

## Migration from DCFScreen

### Step 1: Replace Simple Screens
Start with screens that have no custom logic:

```dart
// Before
DCFScreen(route: "about", builder: () => AboutScreen())

// After  
DCFEasyScreen(route: "about", builder: () => AboutScreen())
```

### Step 2: Move Custom Logic to Overrides
For screens with custom navigation handling:

```dart
DCFEasyScreen(
  route: "custom",
  onNavigationEvent: (data) {
    // Your custom logic here
    // Automatic handling already happened
  },
  builder: () => CustomScreen(),
)
```

### Step 3: Remove Boilerplate
Delete helper methods like `_shouldHandleCommand`, `_handleNavigationEvents`, etc. - DCFEasyScreen handles these automatically.

## Performance Impact

### Before DCFEasyScreen
- 20+ lines of boilerplate per screen
- Manual suspense management
- Manual state tracking
- Manual event handling
- Easy to introduce bugs

### After DCFEasyScreen  
- 4 lines per screen
- Automatic suspense
- Automatic state management
- Automatic event handling
- Bug-free navigation

## Related Components

- [`DCFSuspense`](./DCFSuspense.md) - The underlying suspense component
- [`DCFScreen`](./DCFScreen.md) - The base screen component
- [`AppNavigation`](./AppNavigation.md) - Navigation helper that works seamlessly
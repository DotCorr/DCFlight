# AppNavigation Helper

## Overview

`AppNavigation` is a comprehensive navigation helper that provides a clean, type-safe API for navigation while automatically managing suspense state, navigation stacks, and screen tracking.

## Key Features

- 🧭 **Simple API**: Easy-to-use navigation methods
- 🎯 **Targeted Navigation**: Route commands to specific screens
- 🎬 **Suspense Integration**: Automatic state updates for efficient rendering
- 📚 **Stack Management**: Intelligent navigation stack tracking
- 🔄 **State Synchronization**: Keeps UI state in sync with navigation

## Basic Navigation

### Navigate to Route
```dart
// Simple navigation
AppNavigation.navigateTo("profile");

// With parameters
AppNavigation.navigateTo("profile/edit", params: {
  "userId": "123",
  "mode": "edit"
});

// Targeted navigation (recommended)
AppNavigation.navigateTo("settings", fromScreen: "profile");
```

### Navigate Back
```dart
// Simple back navigation
AppNavigation.goBack();

// From specific screen
AppNavigation.goBack(fromScreen: "settings");

// Back with result data
AppNavigation.goBackWithResult({
  "saved": true,
  "changes": ["theme", "notifications"]
}, fromScreen: "settings");
```

## Advanced Navigation

### Pop to Specific Route
```dart
// Pop to a specific screen in the stack
AppNavigation.popToRoute("home");
AppNavigation.popToRoute("profile", fromScreen: "settings");

// Pop to root (home)
AppNavigation.goToRoot();
AppNavigation.goToRootInstant(); // Without animation
```

### Replace Current Route
```dart
// Replace current screen with another
AppNavigation.replace("login");
AppNavigation.replace("dashboard", params: {"role": "admin"});
```

### Modal Presentation
```dart
// Present modal
AppNavigation.presentModal("photo_viewer", params: {
  "imageUrl": "https://example.com/image.jpg"
});

// Full screen modal
AppNavigation.presentFullScreenModal("video_player");

// Page sheet modal
AppNavigation.presentPageSheetModal("settings");

// Dismiss modal
AppNavigation.dismissModal();
AppNavigation.dismissModalWithResult({"rating": 5});
```

## API Reference

### Route Navigation

| Method | Parameters | Description |
|--------|------------|-------------|
| `navigateTo()` | `route`, `params?`, `fromScreen?` | Navigate to a route |
| `navigateToInstant()` | `route`, `params?`, `fromScreen?` | Navigate without animation |

### Pop Navigation

| Method | Parameters | Description |
|--------|------------|-------------|
| `goBack()` | `fromScreen?` | Pop current route |
| `goBackInstant()` | `fromScreen?` | Pop without animation |
| `goBackWithResult()` | `result`, `fromScreen?` | Pop with result data |
| `popToRoute()` | `route`, `fromScreen?` | Pop to specific route |
| `goToRoot()` | `fromScreen?` | Pop to root route |
| `goToRootInstant()` | `fromScreen?` | Pop to root without animation |

### Replace Navigation

| Method | Parameters | Description |
|--------|------------|-------------|
| `replace()` | `route`, `params?`, `fromScreen?` | Replace current route |
| `replaceInstant()` | `route`, `params?`, `fromScreen?` | Replace without animation |

### Modal Navigation

| Method | Parameters | Description |
|--------|------------|-------------|
| `presentModal()` | `route`, `params?`, `fromScreen?` | Present default modal |
| `presentFullScreenModal()` | `route`, `params?`, `fromScreen?` | Present full screen modal |
| `presentPageSheetModal()` | `route`, `params?`, `fromScreen?` | Present page sheet modal |
| `dismissModal()` | `fromScreen?` | Dismiss current modal |
| `dismissModalWithResult()` | `result`, `fromScreen?` | Dismiss with result |

### Utility Methods

| Method | Description |
|--------|-------------|
| `clearCommand()` | Clear pending navigation commands |
| `hasPendingCommand()` | Check if navigation command is pending |
| `getCurrentCommand()` | Get current navigation command |
| `getActiveScreen()` | Get currently active screen |
| `getNavigationStack()` | Get current navigation stack |
| `shouldRenderScreen()` | Check if screen should render (for suspense) |
| `resetSuspenseState()` | Reset navigation state (debugging) |

## Targeted Navigation

### Why Use `fromScreen`?

Targeted navigation prevents command conflicts when multiple screens could handle the same route:

```dart
// ❌ Could be handled by any screen named "settings"
AppNavigation.navigateTo("settings"); 

// ✅ Only handled by the "profile" screen
AppNavigation.navigateTo("settings", fromScreen: "profile");
```

### Smart Command Routing

DCFEasyScreen automatically handles commands targeted to its route:

```dart
DCFEasyScreen(
  route: "profile",
  // This screen will only handle commands with fromScreen: "profile"
  builder: () => ProfileScreen(),
)
```

## Suspense Integration

AppNavigation automatically updates suspense state for optimal performance:

### Immediate UI Updates
```dart
// UI updates immediately for responsive feel
AppNavigation.navigateTo("profile");
// activeScreenTracker.setState("profile") ← Happens automatically
// Navigation stack updated ← Happens automatically
```

### Predictive State Management
```dart
// Going back predicts which screen will be revealed
AppNavigation.goBack(); 
// Calculates previous screen from navigation stack
// Updates activeScreenTracker before navigation completes
```

## Navigation Stack Management

### Automatic Stack Tracking
```dart
// Navigation stack is automatically maintained
AppNavigation.navigateTo("home");        // Stack: ["home"]
AppNavigation.navigateTo("profile");     // Stack: ["home", "profile"] 
AppNavigation.navigateTo("settings");    // Stack: ["home", "profile", "settings"]
AppNavigation.goBack();                  // Stack: ["home", "profile"]
```

### Nested Route Handling
```dart
// Nested routes are handled intelligently
AppNavigation.navigateTo("profile/settings");
// Stack: ["home", "profile", "profile/settings"]
// Both "profile" and "profile/settings" marked for rendering
```

## Working with DCFEasyScreen

AppNavigation is designed to work seamlessly with DCFEasyScreen:

```dart
class StackScreenRegistry extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFFragment(children: [
      DCFEasyScreen(
        route: "home",
        alwaysRender: true,
        onHeaderActionPress: (data) {
          // Use AppNavigation in event handlers
          AppNavigation.navigateTo("settings", fromScreen: "home");
        },
        builder: () => HomeScreen(),
      ),
      
      DCFEasyScreen(
        route: "settings", 
        // Automatic suspense based on AppNavigation state
        builder: () => SettingsScreen(),
      ),
    ]);
  }
}
```

## Navigation Parameters

### Passing Data Between Screens
```dart
// Sending screen
AppNavigation.navigateTo("user_detail", params: {
  "userId": "12345",
  "name": "John Doe",
  "avatar": "https://example.com/avatar.jpg"
});

// Receiving screen
DCFEasyScreen(
  route: "user_detail",
  onReceiveParams: (data) {
    final params = data['params'] as Map<String, dynamic>;
    final userId = params['userId'];
    final name = params['name'];
    // Use the parameters...
  },
  builder: () => UserDetailScreen(),
)
```

### Result Data from Screens
```dart
// Child screen returning data
AppNavigation.goBackWithResult({
  "settingsSaved": true,
  "theme": "dark",
  "notifications": false
}, fromScreen: "settings");

// Parent screen receiving data
DCFEasyScreen(
  route: "profile",
  onReceiveParams: (data) {
    if (data.containsKey('result')) {
      final result = data['result'] as Map<String, dynamic>;
      if (result['settingsSaved'] == true) {
        // Handle settings save...
      }
    }
  },
  builder: () => ProfileScreen(),
)
```

## Debug Information

AppNavigation provides comprehensive debug logging:

```
🧭 GLOBAL NAV: {navigateToRoute: profile, animated: true} from home
📚 Navigation stack updated: [home, profile]
🔄 Suspense state reset to home
```

### Debug Helper Methods
```dart
// Get current navigation state
final state = AppNavigation.getNavigationState();
print("Active: ${state['currentRoute']}");
print("Stack: ${state['navigationStack']}");

// Reset for debugging
AppNavigation.resetSuspenseState();
```

## Best Practices

### ✅ DO

- Always use `fromScreen` parameter for targeted navigation
- Use descriptive route names
- Pass structured data in parameters
- Handle result data in `onReceiveParams`
- Use instant variants sparingly (for immediate responses)

### ❌ DON'T

- Navigate without clearing commands (handled automatically with DCFEasyScreen)
- Manually manage navigation state (let AppNavigation handle it)
- Use navigation without considering suspense impact
- Ignore result data from child screens

## Common Patterns

### Settings Flow
```dart
// Navigate to settings
AppNavigation.navigateTo("settings", fromScreen: "profile");

// User cancels
AppNavigation.goBack(fromScreen: "settings");

// User saves
AppNavigation.goBackWithResult({
  "saved": true,
  "changes": updatedSettings
}, fromScreen: "settings");
```

### Modal Workflow
```dart
// Present modal
AppNavigation.presentModal("photo_picker", fromScreen: "profile");

// User selects photo
AppNavigation.dismissModalWithResult({
  "photoUrl": selectedPhotoUrl
}, fromScreen: "photo_picker");
```

### Deep Navigation
```dart
// Navigate deep into app
AppNavigation.navigateTo("profile");
AppNavigation.navigateTo("settings");
AppNavigation.navigateTo("advanced");

// Quick return to root
AppNavigation.goToRoot();
```

## Performance Considerations

AppNavigation is optimized for performance through:

- **Predictive Updates**: UI updates before navigation completes
- **Efficient Stack Management**: Minimal memory usage
- **Suspense Integration**: Only renders necessary components
- **Batched State Updates**: Reduces re-renders

## Related Documentation

- [`DCFEasyScreen`](./DCFEasyScreen.md) - Works seamlessly with AppNavigation
- [`DCFSuspense`](./DCFSuspense.md) - Underlying suspense system
- [`Navigation Store Architecture`](./NavigationStores.md) - How state is managed
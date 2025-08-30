# DCF Screens - Production-Ready Navigation System

A comprehensive, memory-efficient navigation system for DCFlight applications with automatic suspense, route reuse, and native user interaction detection.

## 🎉 Status: **PRODUCTION READY**

All navigation APIs are fully implemented, tested, and production-ready:
- ✅ **Stack Navigation** (Push/Pop) - Complete with user gesture detection
- ✅ **Modal Navigation** - Complete with swipe-to-dismiss support
- ✅ **Sheet Navigation** - Complete with detent changes and interactions
- ✅ **Popover Navigation** - Complete with background dismissal
- ✅ **Overlay Navigation** - Complete
- 🧪 **Tab Navigation** - Experimental (use with caution)

## 🚀 Key Features

- **🧠 Automatic Memory Management**: Built-in suspense system prevents memory leaks
- **🔄 Route Reuse**: Navigate to the same route multiple times without black screens
- **👆 User Interaction Detection**: All native gestures (swipes, taps, long-press) properly detected
- **⚡ Performance Optimized**: Only renders active screens, suspends inactive ones
- **🛡️ Type Safe**: Full TypeScript support with proper error handling

## 📦 Installation

```dart
dependencies:
  dcf_screens: ^1.0.0
```

## 🏠 Important: Initial Route

**Your app's initial page MUST have the route `"home"`** - this is required for proper navigation stack management.

## 🎯 Basic Usage

### DCFEasyScreen - The Main Component

Use `DCFEasyScreen` for all your screens. It automatically handles suspense, route reuse, and native interactions:

```dart
DCFEasyScreen(
  route: "home",
  alwaysRender: true, // Skip suspense for home screen
  pushConfig: DCFPushConfig(
    title: "Home",
    backButtonTitle: "Back",
  ),
  builder: () => MyHomeScreen(),
),

DCFEasyScreen(
  route: "profile/settings",
  pushConfig: DCFPushConfig(
    title: "Settings",
    prefixActions: [
      DCFPushHeaderActionConfig.withTextOnly(title: "Cancel"),
    ],
    suffixActions: [
      DCFPushHeaderActionConfig.withTextOnly(title: "Done"),
    ],
  ),
  onHeaderActionPress: (data) {
    if (data['title'] == "Cancel") {
      AppNavigation.goBack(fromScreen: "profile/settings");
    }
  },
  builder: () => SettingsScreen(),
),
```

## 📱 Navigation APIs

### Stack Navigation (Push/Pop)

```dart
// Navigate to a new screen
AppNavigation.navigateTo(
  "profile/settings",
  fromScreen: "profile",
  params: {"userId": 123},
);

// Go back
AppNavigation.goBack(fromScreen: "profile/settings");

// Pop to specific route
AppNavigation.popTo("home", fromScreen: "profile/settings");

// Replace current screen
AppNavigation.replaceWith(
  "profile/edit",
  fromScreen: "profile",
  params: {"mode": "edit"},
);
```

### Modal Navigation

```dart
// Present modal
AppNavigation.presentModal(
  "user/profile",
  fromScreen: "home",
  params: {"userId": 456},
);

// Dismiss modal
AppNavigation.dismissModal(fromScreen: "user/profile");

// Modal with custom config
DCFEasyScreen(
  route: "settings/modal",
  modalConfig: DCFModalConfig(
    allowsBackgroundDismiss: true,
    detents: [DCFModalDetent.medium, DCFModalDetent.large],
    showDragIndicator: true,
  ),
  builder: () => ModalSettingsScreen(),
),
```

### Sheet Navigation

```dart
DCFEasyScreen(
  route: "photo/picker",
  modalConfig: DCFModalConfig(
    detents: [
      DCFModalDetent.small,
      DCFModalDetent.medium,
      DCFModalDetent.large,
    ],
    selectedDetentIndex: 1,
    showDragIndicator: true,
    cornerRadius: 16.0,
  ),
  builder: () => PhotoPickerScreen(),
),
```

### Popover Navigation

```dart
DCFEasyScreen(
  route: "menu/popover",
  popoverConfig: DCFPopoverConfig(
    preferredWidth: 200,
    preferredHeight: 300,
    dismissOnOutsideTap: true,
  ),
  builder: () => MenuPopoverScreen(),
),
```

## 🔄 Automatic Suspense System

The navigation system automatically manages memory with intelligent suspense:

```dart
// ✅ This screen renders when active
DCFEasyScreen(
  route: "profile",
  builder: () => ProfileScreen(), // Only builds when needed
),

// ✅ Skip suspense for always-visible screens
DCFEasyScreen(
  route: "home",
  alwaysRender: true, // Always rendered
  builder: () => HomeScreen(),
),

// ✅ Custom placeholder for suspended screens
DCFEasyScreen(
  route: "heavy/screen",
  placeholder: () => LoadingPlaceholder(),
  builder: () => HeavyDataScreen(),
),
```

## 🎮 User Interaction Detection

All native user interactions are automatically detected and handled:

### Stack Navigation
- ✅ Back button taps
- ✅ Swipe-to-go-back gestures
- ✅ iOS 14+ long-press back button context menu
- ✅ Interactive transitions

### Modal/Sheet Navigation
- ✅ Swipe-to-dismiss gestures
- ✅ Background tap dismissal
- ✅ Sheet detent changes
- ✅ Drag indicator interactions

### Popover Navigation
- ✅ Background tap dismissal
- ✅ Arrow direction changes

## 🧪 Tab Navigation (Experimental)

⚠️ **Tab navigation is experimental and should be used with caution in production.**

```dart
// Tab navigation example (experimental)
DCFEasyScreen(
  route: "tab/home",
  tabConfig: DCFTabConfig(
    title: "Home",
    icon: DCFIcons.home,
    index: 0,
  ),
  builder: () => TabHomeScreen(),
),
```

## 🎯 Event Handling

### Navigation Events
```dart
DCFEasyScreen(
  route: "my/screen",
  onNavigationEvent: (data) {
    final action = data['action'];
    final userInitiated = data['userInitiated'] ?? false;

    if (userInitiated) {
      print("User performed: $action");
      // Handle user-initiated navigation
    } else {
      print("Programmatic: $action");
      // Handle programmatic navigation
    }
  },
  onAppear: (data) => print("Screen appeared"),
  onDisappear: (data) => print("Screen disappeared"),
  builder: () => MyScreen(),
),
```

### Header Actions
```dart
DCFEasyScreen(
  route: "profile",
  pushConfig: DCFPushConfig(
    title: "Profile",
    suffixActions: [
      DCFPushHeaderActionConfig.withSVGPackage(
        title: "Settings",
        package: "dcf_primitives",
        iconName: DCFIcons.settings,
        actionId: "settings_btn",
      ),
    ],
  ),
  onHeaderActionPress: (data) {
    if (data['actionId'] == "settings_btn") {
      AppNavigation.navigateTo("profile/settings", fromScreen: "profile");
    }
  },
  builder: () => ProfileScreen(),
),
```

## 🧹 Memory Management

The system automatically handles memory cleanup:

```dart
// ✅ Screens are automatically suspended when not active
// ✅ Memory is freed for unused screens
// ✅ Route reuse works without memory leaks
// ✅ Navigation state is properly managed

// No manual cleanup needed!
```

## 🏗️ Route Structure

Organize routes hierarchically:

```dart
// ✅ Root routes
"home"
"profile"
"settings"

// ✅ Nested routes
"profile/edit"
"profile/settings"
"home/modal"
"settings/advanced"

// ✅ Deep nesting
"profile/settings/privacy"
"home/gallery/photo/edit"
```

## 📋 Configuration Examples

### Complete Screen Setup
```dart
class ScreenRegistry extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFFragment(
      children: [
        // Home screen (always rendered)
        DCFEasyScreen(
          route: "home", // Required: Must be "home"
          alwaysRender: true,
          pushConfig: DCFPushConfig(title: "Home"),
          builder: () => HomeScreen(),
        ),

        // Profile screen with header actions
        DCFEasyScreen(
          route: "profile",
          pushConfig: DCFPushConfig(
            title: "Profile",
            suffixActions: [
              DCFPushHeaderActionConfig.withSVGPackage(
                title: "Settings",
                iconName: DCFIcons.settings,
                actionId: "settings",
              ),
            ],
          ),
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings") {
              AppNavigation.navigateTo("profile/settings", fromScreen: "profile");
            }
          },
          builder: () => ProfileScreen(),
        ),

        // Modal screen
        DCFEasyScreen(
          route: "photo/modal",
          modalConfig: DCFModalConfig(
            allowsBackgroundDismiss: true,
            detents: [DCFModalDetent.large],
          ),
          builder: () => PhotoModalScreen(),
        ),
      ],
    );
  }
}
```

## 🐛 TODO / Known Issues

### High Priority
- [ ] **iOS 14+ Long-Press Context Menu**: Long-press back button context menu navigation not fully handled for nested routes

### Low Priority
- [ ] Tab navigation improvements (currently experimental)
- [ ] Advanced gesture customization
- [ ] Custom transition animations

## 📚 Advanced Usage

### Custom Suspense Behavior
```dart
DCFEasyScreen(
  route: "custom/screen",
  alwaysRender: false, // Use suspense
  placeholder: () => DCFView(
    children: [
      DCFText(content: "Loading custom screen..."),
    ],
  ),
  builder: () => CustomScreen(),
),
```

### Complex Navigation Flows
```dart
// Multi-step flows
AppNavigation.navigateTo("onboarding/step1", fromScreen: "home");
AppNavigation.replaceWith("onboarding/step2", fromScreen: "onboarding/step1");
AppNavigation.replaceWith("onboarding/step3", fromScreen: "onboarding/step2");
AppNavigation.popTo("home", fromScreen: "onboarding/step3");
```

## 🔧 Best Practices

1. **Always start with route "home"** for your initial screen
2. **Use hierarchical route naming** (`"parent/child"`)
3. **Set `alwaysRender: true`** only for frequently accessed screens
4. **Handle both user-initiated and programmatic navigation** in event handlers
5. **Use appropriate presentation styles** (modal vs push vs sheet)
6. **Test user gestures** (swipes, taps, long-press) on real devices

## 📄 License

MIT License - see LICENSE file for details.

## 🙋 Support

For issues, questions, or contributions, please refer to the DCFlight documentation or create an issue in the repository.

---

**🎉 Navigation is production-ready! No memory leaks, full gesture support, and automatic cleanup across all navigation APIs.**

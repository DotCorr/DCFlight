# Getting Started with DCFlight

## 🎯 What is DCFlight?

DCFlight is a revolutionary UI framework that renders **actual native UI components** on iOS and Android while providing a React-like development experience in Dart. Unlike Flutter, which abstracts UI rendering, DCFlight uses the Flutter engine as a runtime and renders true native components for optimal performance and platform consistency.

## 🏗️ Key Concepts

### Native UI Rendering
- **iOS**: Components render as actual UIKit views (`UIButton`, `UILabel`, `UIView`)
- **Android**: Components render as actual Android views (`Button`, `TextView`, `LinearLayout`)
- **No Abstractions**: Direct mapping to platform UI components

### Flutter Engine as Runtime
- Uses Flutter engine for Dart execution, not UI rendering
- Method channels bridge native UI events to Dart code
- Single shared engine architecture for optimal performance

### React-like Development
- Component-based architecture with `render()` methods
- State management with `useState` hooks
- Virtual DOM with automatic optimization
- Props-based component composition

## 🚀 Quick Start

### 1. Project Setup

Create a new DCFlight project using the CLI:

```bash
# Install DCFlight CLI
dart pub global activate dcflight_cli

# Create new project
dcf create app my_app
cd my_app

# Run your DCFlight app
dcf go
```

### 2. Your First Component

```dart
// lib/main.dart
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        padding: 20,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.white,
      ),
      children: [
        DCFText(
          content: "Welcome to DCFlight!",
          textProps: DCFTextProps(
            fontSize: 28,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
            textAlign: DCFTextAlignment.center,
          ),
        ),
        Counter(), // Your custom component
      ],
    );
  }
}

class Counter extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    
    return DCFView(
      layout: LayoutProps(
        alignItems: YogaAlign.center,
        gap: 16,
        marginTop: 32,
      ),
      children: [
        DCFText(
          content: "Count: ${count.state}",
          textProps: DCFTextProps(
            fontSize: 24,
            color: Colors.blue,
          ),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Increment"),
          layout: LayoutProps(height: 50, width: 150),
          styleSheet: StyleSheet(
            backgroundColor: Colors.blue,
            borderRadius: 8,
          ),
          onPress: (data) {
            print("Button pressed!"); // This will show in logs
            count.setState(count.state + 1);
          },
        ),
      ],
    );
  }
}
```

## 🧩 Core Components

### Layout Components

#### DCFView - Container
```dart
DCFView(
  layout: LayoutProps(
    flex: 1,
    flexDirection: YogaFlexDirection.column,
    justifyContent: YogaJustifyContent.spaceBetween,
    alignItems: YogaAlign.center,
    padding: 16,
    gap: 8,
  ),
  styleSheet: StyleSheet(
    backgroundColor: Colors.grey.shade100,
    borderRadius: 12,
    borderColor: Colors.grey.shade300,
    borderWidth: 1,
  ),
  children: [
    // Child components
  ],
)
```

#### DCFScrollView - Scrollable Container
```dart
DCFScrollView(
  layout: LayoutProps(flex: 1),
  scrollDirection: Axis.vertical,
  showsScrollIndicator: true,
  children: [
    // Long list of components that need scrolling
  ],
)
```

### Input Components

#### DCFButton - Native Button
```dart
DCFButton(
  buttonProps: DCFButtonProps(
    title: "Click Me",
    systemStyle: DCFButtonSystemStyle.filled, // iOS system style
  ),
  layout: LayoutProps(height: 44, width: 200),
  styleSheet: StyleSheet(
    backgroundColor: Colors.blue,
    borderRadius: 8,
  ),
  onPress: (eventData) {
    // Handle button press
    print("Button pressed: $eventData");
  },
)
```

#### DCFTextInput - Native Text Field
```dart
class TextInputExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final text = useState<String>("");
    
    return DCFTextInput(
      textInputProps: DCFTextInputProps(
        placeholder: "Enter your name",
        value: text.state,
        keyboardType: DCFKeyboardType.default,
      ),
      onTextChange: (data) {
        text.setState(data['text'] ?? '');
      },
      layout: LayoutProps(height: 44),
      styleSheet: StyleSheet(
        borderColor: Colors.grey,
        borderWidth: 1,
        borderRadius: 8,
        padding: EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
```

### Display Components

#### DCFText - Native Text
```dart
DCFText(
  content: "Hello, DCFlight!",
  textProps: DCFTextProps(
    fontSize: 18,
    fontWeight: DCFFontWeight.medium,
    color: Colors.black,
    textAlign: DCFTextAlignment.left,
  ),
)
```

#### DCFImage - Native Image
```dart
DCFImage(
  imageProps: DCFImageProps(
    source: "https://example.com/image.jpg", // URL or asset path
    contentMode: DCFImageContentMode.aspectFit,
    placeholder: "assets/images/placeholder.png",
  ),
  layout: LayoutProps(width: 200, height: 200),
  styleSheet: StyleSheet(
    borderRadius: 12,
    backgroundColor: Colors.grey.shade200,
  ),
)
```

## 🎨 Styling System

DCFlight uses a CSS-like styling system with native performance:

```dart
StyleSheet(
  // Colors
  backgroundColor: Colors.blue,
  borderColor: Colors.grey,
  
  // Dimensions
  borderRadius: 8,
  borderWidth: 1,
  
  // Shadows
  boxShadow: [
    BoxShadow(
      color: Colors.black26,
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ],
  
  // Spacing (handled by LayoutProps)
  // padding: EdgeInsets.all(16), // Use LayoutProps instead
)
```

## 📐 Layout System

DCFlight uses Facebook's Yoga layout engine for consistent cross-platform layouts:

```dart
LayoutProps(
  // Flexbox
  flex: 1,
  flexDirection: YogaFlexDirection.column,
  justifyContent: YogaJustifyContent.center,
  alignItems: YogaAlign.center,
  flexWrap: YogaWrap.wrap,
  
  // Dimensions
  width: 200,
  height: 100,
  minWidth: 100,
  maxHeight: 300,
  
  // Spacing
  margin: EdgeInsets.all(16),
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  gap: 8, // Space between children
  
  // Positioning
  position: YogaPositionType.absolute,
  top: 10,
  left: 20,
)
```

## 🔄 State Management

### useState Hook
```dart
class StateExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Single values
    final counter = useState<int>(0);
    final name = useState<String>("DCFlight");
    final isLoading = useState<bool>(false);
    
    // Complex objects
    final user = useState<Map<String, dynamic>>({
      'name': 'John Doe',
      'email': 'john@example.com',
    });
    
    return DCFView(
      children: [
        DCFText(content: "Hello, ${user.state['name']}!"),
        
        DCFButton(
          buttonProps: DCFButtonProps(
            title: isLoading.state ? "Loading..." : "Update User"
          ),
          onPress: isLoading.state ? null : (data) async {
            isLoading.setState(true);
            
            // Simulate async operation
            await Future.delayed(Duration(seconds: 1));
            
            // Update user
            final updatedUser = Map<String, dynamic>.from(user.state);
            updatedUser['name'] = 'Jane Doe';
            user.setState(updatedUser);
            
            isLoading.setState(false);
          },
        ),
      ],
    );
  }
}
```

### Component Optimization
```dart
// For components without internal state
class OptimizedComponent extends StatelessComponent with EquatableMixin {
  final String title;
  final int value;
  
  OptimizedComponent({required this.title, required this.value});
  
  @override
  List<Object?> get props => [title, value];
  
  @override
  DCFComponentNode render() {
    // Only re-renders when title or value changes
    return DCFText(content: "$title: $value");
  }
}
```

## 🔗 Navigation

DCFlight provides native navigation on both platforms:

```dart
// Navigation setup
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFNavigationView(
      initialRoute: "/home",
      routes: {
        "/home": () => HomeScreen(),
        "/profile": () => ProfileScreen(),
        "/settings": () => SettingsScreen(),
      },
    );
  }
}

// Navigate between screens
class HomeScreen extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      children: [
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Profile"),
          onPress: (data) {
            DCFNavigation.push("/profile");
          },
        ),
      ],
    );
  }
}
```

## 🌐 Platform Features

### iOS-Specific Features
```dart
// iOS system button styles
DCFButton(
  buttonProps: DCFButtonProps(
    title: "iOS Style",
    systemStyle: DCFButtonSystemStyle.filled,
  ),
)

// iOS navigation
DCFNavigationBar(
  title: "Settings",
  leftBarButtonItems: [
    DCFBarButtonItem(
      title: "Cancel",
      onPress: (data) => DCFNavigation.pop(),
    ),
  ],
)
```

### Android-Specific Features
```dart
// Material Design components
DCFButton(
  buttonProps: DCFButtonProps(
    title: "Material Button",
    materialStyle: DCFMaterialButtonStyle.filled,
  ),
)

// Android app bar
DCFAppBar(
  title: "Settings",
  navigationIcon: DCFAppBarIcon.back,
  onNavigationPress: (data) => DCFNavigation.pop(),
)
```

## 🐛 Debugging

### Enable Debug Logging
```dart
// In main.dart
void main() {
  DCFlight.enableDebugLogging(); // Enable detailed logs
  DCFlight.start(app: MyApp());
}
```

### Debug Component Rendering
```dart
DCFView(
  debugName: "MainContainer", // Shows in logs
  children: [
    // Components
  ],
)
```

### Event Debugging
```dart
DCFButton(
  onPress: (eventData) {
    print("Button pressed:");
    print("Event data: $eventData");
    print("Timestamp: ${DateTime.now()}");
  },
)
```

## 📱 Platform Setup

### iOS Setup
```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter

@main
@objc class AppDelegate: DCFAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Android Setup
```kotlin
// android/app/src/main/kotlin/MainActivity.kt
package com.example.myapp

import com.dotcorr.dcflight.DCFActivity

class MainActivity: DCFActivity() {
    // DCFActivity handles all setup automatically
}
```

## 🚀 Next Steps

1. **Explore Components**: Check out the [Component Guide](./engine/components/components.md)
2. **Learn Architecture**: Read the [Architecture Overview](./ARCHITECTURE.md)
3. **Platform Details**: Dive into [Platform Implementation](./PLATFORM_IMPLEMENTATION.md)
4. **Layout System**: Master the [Layout Guide](./engine/layout/README.md)

## 💡 Tips for Success

1. **Think Native**: DCFlight renders actual native components - leverage platform strengths
2. **Optimize Wisely**: Use `EquatableMixin` for StatelessComponent optimization
3. **Debug Thoroughly**: Enable logging to understand event flow
4. **Platform Consistency**: Test on both iOS and Android
5. **Performance First**: Single engine architecture ensures optimal performance

# DCF Primitives

[![pub package](https://img.shields.io/pub/v/dcf_primitives.svg)](https://pub.dev/packages/dcf_primitives)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The official primitive component library for the DCFlight framework. This package provides a comprehensive set of cross-platform UI components that work seamlessly across iOS, Android, and other platforms supported by DCFlight.

## Features

- **Cross-Platform Components**: Write once, run everywhere with native performance
- **Type-Safe API**: Full TypeScript-style type safety in Dart
- **Adaptive Theming**: Automatic light/dark mode support
- **Native Performance**: Direct native rendering without widget overhead
- **Component-Based Architecture**: React-like development experience

## Installation

Add `dcf_primitives` to your `pubspec.yaml`:

```yaml
dependencies:
  dcf_primitives: ^0.0.1
  dcflight: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

class MyApp extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      children: [
        DCFText(
          content: "Hello DCFlight!",
          textProps: DCFTextProps(fontSize: 24),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Click me"),
          onPress: (data) => print("Button pressed!"),
        ),
      ],
    );
  }
}
```

## Available Components

### Basic Components
- **DCFView** - Container view with layout support
- **DCFText** - Text display with rich formatting
- **DCFImage** - Image display with caching
- **DCFIcon** - Icon display from built-in icon library
- **DCFSVG** - SVG image rendering

### Input Components
- **DCFButton** - Touchable button with press events
- **DCFTextInput** - Text input with keyboard support
- **DCFCheckbox** - Checkbox with custom styling
- **DCFToggle** - Switch/toggle component
- **DCFSlider** - Range slider input
- **DCFDropdown** - Dropdown/picker component

### Layout Components
- **DCFScrollView** - Scrollable container
- **DCFFlatList** - High-performance list component
- **DCFSafeAreaView** - Safe area handling
- **DCFModal** - Modal dialog component
- **DCFModalHeader** - Modal header with close button

### Interactive Components
- **DCFTouchableOpacity** - Touchable wrapper with opacity feedback
- **DCFGestureDetector** - Gesture recognition (tap, swipe, etc.)
- **DCFSwipeableView** - Swipeable container for custom interactions

### Animation Components
- **DCFAnimatedView** - Animated container
- **DCFAnimatedText** - Animated text with transitions
- **DCFSpinner** - Loading spinner/activity indicator

## Component Props and Styling

All components support:
- **Layout Props**: Flexbox-based layout system
- **Style Sheet**: CSS-like styling with type safety
- **Event Handlers**: Type-safe event callbacks

```dart
DCFButton(
  buttonProps: DCFButtonProps(title: "Styled Button"),
  layout: LayoutProps(
    width: 200,
    height: 50,
    margin: EdgeInsets.all(10),
  ),
  styleSheet: StyleSheet(
    backgroundColor: Colors.blue,
    borderRadius: 8,
  ),
  onPress: (data) => handleButtonPress(),
)
```

## Theming and Customization

DCF Primitives supports adaptive theming that automatically responds to system light/dark mode:

```dart
// Components automatically adapt to system theme
DCFView(
  styleSheet: StyleSheet(
    backgroundColor: Colors.systemBackground, // Adapts to light/dark
  ),
  children: [
    DCFText(
      content: "Adaptive text",
      textProps: DCFTextProps(
        color: Colors.label, // Adapts to light/dark
      ),
    ),
  ],
)
```

## Event Handling

All interactive components provide type-safe event callbacks:

```dart
DCFTextInput(
  onValueChange: (Map<dynamic, dynamic> data) {
    final String newValue = data['value'];
    print('Input changed to: $newValue');
  },
  onFocus: (data) => print('Input focused'),
  onBlur: (data) => print('Input blurred'),
)
```

## Performance

DCF Primitives is built for performance:
- **Native Rendering**: Components render directly to native views
- **Efficient Updates**: Only changed properties trigger updates
- **Memory Efficient**: Automatic view recycling in lists
- **Smooth Animations**: Hardware-accelerated animations

## Platform Support

- ✅ **iOS** (UIKit)
- ✅ **Android** (Native Android Views)
- 🚧 **macOS** (Coming soon)
- 🚧 **Windows** (Coming soon)
- 🚧 **Linux** (Coming soon)

## Examples

Check out the [example app](https://github.com/dotcorr/dcflight/tree/main/packages/template/dcf_go) for comprehensive usage examples.

## Documentation

- [Component API Reference](https://docs.dcflight.dev/primitives)
- [DCFlight Framework Docs](https://docs.dcflight.dev)
- [Getting Started Guide](https://docs.dcflight.dev/getting-started)

## Contributing

We welcome contributions! Please see our [Contributing Guide](https://github.com/dotcorr/dcflight/blob/main/CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/dotcorr/dcflight/blob/main/LICENSE) file for details.

## About DCFlight

DCF Primitives is part of the DCFlight framework, a next-generation cross-platform mobile development framework that brings React-like component architecture to native mobile development.

- **Website**: [dcflight.dev](https://dcflight.dev)
- **GitHub**: [github.com/dotcorr/dcflight](https://github.com/dotcorr/dcflight)
- **Documentation**: [docs.dcflight.dev](https://docs.dcflight.dev)
- **Community**: [Discord](https://discord.gg/dcflight)

---

Made with ❤️ by [Dotcorr Studio](https://dotcorr.com)

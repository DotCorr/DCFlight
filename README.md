```
                               ▂▄▓▄▂         

██████╗  ██████╗███████╗██╗     ██╗ ██████╗ ██╗  ██╗████████╗
██╔══██╗██╔════╝██╔════╝██║     ██║██╔════╝ ██║  ██║╚══██╔══╝
██║  ██║██║     █████╗  ██║     ██║██║  ███╗███████║   ██║   
██║  ██║██║     ██╔══╝  ██║     ██║██║   ██║██╔══██║   ██║   
██████╔╝╚██████╗██║     ███████╗██║╚██████╔╝██║  ██║   ██║   
╚═════╝  ╚═════╝╚═╝     ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   
```

# DCFlight

A cross-platform mobile framework that renders **actual native UI** using a declarative component architecture. Built on the Flutter engine for Dart runtime, DCFlight provides direct native rendering without platform views or heavy abstractions.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🚀 What is DCFlight?

DCFlight is a framework that renders **actual native UI** (UIKit on iOS, Android Views on Android) using a declarative component system written in Dart. Unlike Flutter's widget system, DCFlight directly renders native views, providing:

- ✅ **True Native Performance** - Direct native UI rendering, no platform views
- ✅ **Declarative Components** - Component-based architecture with state management
- ✅ **Cross-Platform Consistency** - Same code, native on both platforms
- ✅ **VDOM Reconciliation** - Efficient updates with virtual DOM diffing
- ✅ **Yoga Layout Engine** - Flexbox-based layout system
- ✅ **Hot Reload Support** - Fast development iteration

### Architecture

DCFlight uses the Flutter engine for the Dart runtime (similar to how React Native uses Hermes), but diverges completely from Flutter's UI rendering. Instead, it renders directly to native views:

```
Dart Components → VDOM Engine → Native Bridge → Native Views (UIKit/Android Views)
```

**Key Differences:**
- **Not React**: DCFlight has its own component system and architecture
- **Native-First**: Direct native rendering, not a web view or abstraction layer
- **Dart-Based**: Uses Dart for the component layer, not JavaScript
- **Framework-Managed**: Framework handles component lifecycle and updates

## 📝 Quick Start

### iOS Setup

```swift
import dcflight

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

### Dart Example

```dart
import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';

void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);

  await DCFlight.start(app: DCFView(
    layout: DCFLayout(
      flex: 1, 
      justifyContent: YogaJustifyContent.center, 
      alignItems: YogaAlign.center
    ),
    styleSheet: DCFStyleSheet(backgroundColor: DCFColors.blue),
    children: [
      DCFText(content: "Hello World ✈️"),
    ]
  ));
}
```

## 📦 Packages

- **`dcflight`** - Core framework engine, renderer, and bridge
- **`dcf_primitives`** - Built-in UI primitive components (View, Text, Button, etc.)
- **`dcf_screens`** - Screen management and navigation
- **`dcf_reanimated`** - Animation system
- **`cli`** - Command-line tools for project and module creation

## 🛠️ CLI Tools

Create a new DCFlight app:

```bash
dcf create app
```

Create a new module:

```bash
dcf create module
```

See [CLI Guide](docs/cli/CLI_GUIDE.md) for more information.

## 📚 Documentation

### Getting Started
- [Framework Overview](docs/FRAMEWORK_OVERVIEW.md) - Architecture and concepts
- [Component Protocol](docs/COMPONENT_PROTOCOL.md) - Component development guide
- [Event System](docs/EVENT_SYSTEM.md) - Event handling and propagation

### Development Guides
- [Framework Guidelines](FRAMEWORK_GUIDELINES.md) - Complete development guide
- [Module Development](packages/template/dcf_module/GUIDELINES.md) - Creating modules
- [Component Conventions](docs/COMPONENT_CONVENTIONS.md) - Naming and patterns

### Contributing
- [Contributing Guide](CONTRIBUTING.md) - How to contribute to DCFlight
- [Code of Conduct](CONTRIBUTING.md#code-of-conduct) - Community guidelines

### Technical Documentation
- [Registry System](docs/REGISTRY_SYSTEM.md) - Component registration
- [Tunnel System](docs/TUNNEL_SYSTEM.md) - Native method calls
- [Architecture Comparison](docs/ARCHITECTURE_COMPARISON.md) - Framework comparison

## 🏗️ Architecture

DCFlight follows a layered architecture:

```
┌─────────────────────────────────────┐
│    Dart Layer (Components)          │
│  StatelessComponent / StatefulComponent │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│      VDOM Engine (Reconciliation)    │
│  Component Diffing & Update Batching │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│      Native Bridge Interface         │
│  Method Channel Communication        │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│    Native Layer (iOS/Android)        │
│  DCFComponent Implementation         │
└─────────────────────────────────────┘
```

## 🎯 Key Features

- **Native UI Rendering** - Direct native views, no platform views or abstractions
- **Component-Based** - Declarative component architecture with state management
- **Cross-Platform** - Write once, native on both platforms
- **VDOM System** - Efficient updates with virtual DOM diffing and reconciliation
- **Yoga Layout** - Flexbox-based layout engine for consistent layouts
- **Hot Reload** - Fast development iteration with hot restart support
- **Type-Safe** - Full Dart type safety throughout the framework
- **Extensible** - Plugin system for creating custom modules and components

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

- Read [Framework Guidelines](FRAMEWORK_GUIDELINES.md) for development practices
- Check [Component Protocol](docs/COMPONENT_PROTOCOL.md) for component development
- Follow our [Code of Conduct](CONTRIBUTING.md#code-of-conduct)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## ☕ Support

> **Your support fuels the grind. Every contribution keeps this journey alive.**

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://coff.ee/squirelboy360)

---

**Built with ❤️ by the DCFlight team**

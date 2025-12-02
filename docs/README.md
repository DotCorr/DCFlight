# DCFlight Documentation

**DCFlight** is a high-performance, React-inspired framework for building native mobile applications with Dart. It combines the developer experience of React with the performance of native UI.

## 📚 Documentation Structure

### 🎯 [Getting Started](./FRAMEWORK_OVERVIEW.md)
Framework overview, architecture, and core concepts.

### 🧩 Components

- **[Component Protocol](./components/COMPONENT_PROTOCOL.md)** - How to create custom components
- **[Component Conventions](./components/COMPONENT_CONVENTIONS.md)** - Naming and structure guidelines
- **[Event System](./components/EVENT_SYSTEM.md)** - Handling user interactions
- **[Registry System](./components/REGISTRY_SYSTEM.md)** - Component registration
- **[Tunnel System](./components/TUNNEL_SYSTEM.md)** - Cross-component communication
- **[Canvas API](./components/CANVAS_API.md)** - GPU-accelerated 2D rendering

### 🏗️ Engine & Architecture

- **[Architecture Comparison](./ARCHITECTURE_COMPARISON.md)** - DCFlight vs React Native vs Flutter
- **[VDOM](./engine/vdom/README.md)** - Virtual DOM implementation
  - [Reconciliation](./engine/vdom/RECONCILIATION.md)
  - [Rendering Flow](./engine/vdom/RENDERING_FLOW.md)
  - [Concurrent Features](./engine/vdom/CONCURRENT_FEATURES.md)
  - [State Management](./engine/vdom/STORES_AND_STATE.md)
  - [Performance Analysis](./engine/vdom/VDOM_PERFORMANCE_ANALYSIS.md)

### 📱 Platform-Specific

- **Android**
  - [Compose Integration](./platform/ANDROID_COMPOSE_INTEGRATION.md)
  - [Color Overrides](./platform/ANDROID_COMPONENTS_COLOR_OVERRIDES.md)
- **iOS**
  - [View Controller Systems](./platform/IOS_VIEW_CONTROLLER_SYSTEMS.md) - View controller wrappers, layout guides, and content insets
  - [Color Overrides](./platform/IOS_COMPONENTS_COLOR_OVERRIDES.md)
- **[Explicit Color Overrides](./platform/EXPLICIT_COLOR_OVERRIDES.md)**

### 📖 Guides

- **[Widget to DCF Adaptor](./guides/WIDGET_TO_DCF_ADAPTOR.md)** - Migrating from Flutter widgets
- **[Worklets](./guides/WORKLETS.md)** - High-performance animations

### ⚡ Performance

- **[Optimization Guide](./performance/OPTIMIZATIONS.md)** - Memory and CPU optimizations

### 🛠️ CLI

- **[CLI Guide](./cli/CLI_GUIDE.md)** - Command-line tools
- **[Quick Reference](./cli/CLI_QUICK_REFERENCE.md)** - Common commands

---

## 🚀 Quick Links

### For Component Developers
1. Start with [Component Protocol](./components/COMPONENT_PROTOCOL.md)
2. Follow [Component Conventions](./components/COMPONENT_CONVENTIONS.md)
3. Learn the [Event System](./components/EVENT_SYSTEM.md)

### For App Developers
1. Read [Framework Overview](./FRAMEWORK_OVERVIEW.md)
2. Check [Widget to DCF Adaptor](./guides/WIDGET_TO_DCF_ADAPTOR.md) if migrating from Flutter
3. Explore [Canvas API](./components/CANVAS_API.md) for custom graphics

### For Performance Optimization
1. Review [Performance Optimizations](./performance/OPTIMIZATIONS.md)
2. Study [VDOM Performance Analysis](./engine/vdom/VDOM_PERFORMANCE_ANALYSIS.md)
3. Use [Worklets](./guides/WORKLETS.md) for animations

---

## 🏛️ Architecture

```
DCFlight
├── Dart Layer (Business Logic)
│   ├── Components (DCFView, DCFText, etc.)
│   ├── Hooks (useState, useEffect, etc.)
│   └── Virtual DOM (Reconciliation)
│
├── Bridge Layer
│   ├── Method Channels
│   └── Event Channels
│
└── Native Layer (Rendering)
    ├── iOS (UIKit + Skia)
    └── Android (Views + Skia)
```

---

## 📦 Core Packages

- **`dcflight`** - Core framework
- **`dcf_primitives`** - Basic UI components
- **`dcf_reanimated`** - Advanced animations & Canvas
- **`dcf_cli`** - Development tools

---

## 🤝 Contributing

See individual documentation files for contribution guidelines specific to each area.

---

## 📄 License

MIT License - See LICENSE file for details

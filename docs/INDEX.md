# DCFlight Documentation Index

Welcome to the comprehensive DCFlight documentation! This index will guide you through all available resources for learning and using DCFlight.

## 🚀 Getting Started

### Essential Reading
1. **[Getting Started Guide](./GETTING_STARTED.md)** - Start here! Complete setup and your first DCFlight app
2. **[Architecture Overview](./ARCHITECTURE.md)** - Understand how DCFlight works under the hood
3. **[Platform Implementation](./PLATFORM_IMPLEMENTATION.md)** - iOS and Android implementation details

### Quick References  
- **[Troubleshooting Guide](./TROUBLESHOOTING.md)** - Solutions to common issues
- **[Component System](./engine/components/components.md)** - Building and optimizing components
- **[Layout System](./engine/layout/README.md)** - Mastering the Yoga layout engine

## 📚 Core Concepts

### Framework Architecture
- **[Architecture Overview](./ARCHITECTURE.md)** - Single engine, method channels, VDOM
- **[Platform Implementation](./PLATFORM_IMPLEMENTATION.md)** - Native UI integration patterns
- **Component System** - React-like components with native rendering
- **State Management** - `useState` hooks and optimization

### Platform Integration
- **iOS Implementation** - UIKit component mapping and setup
- **Android Implementation** - Android View mapping and configuration  
- **Method Channels** - Native ↔ Dart communication bridge
- **Event System** - User interaction handling

## 🎨 Component Development

### Component Types
- **[Component System Guide](./engine/components/components.md)** - StatelessComponent vs StatefulComponent
- **State Management** - Using `useState` hooks effectively
- **Performance Optimization** - `EquatableMixin` and re-render prevention
- **Event Handling** - Native UI events to Dart callbacks

### Available Components
- **Layout Components** - `DCFView`, `DCFScrollView`
- **Input Components** - `DCFButton`, `DCFTextInput`
- **Display Components** - `DCFText`, `DCFImage`
- **Navigation Components** - Platform-specific navigation

## 📐 Layout & Styling

### Layout System
- **[Layout Guide](./engine/layout/README.md)** - Yoga flexbox layout engine
- **[Web Defaults](./engine/layout/web_defaults.md)** - CSS-compatible layout behavior
- **LayoutProps** - Flexbox properties, dimensions, spacing
- **StyleSheet** - Colors, borders, shadows, and visual styling

### Best Practices
- **Responsive Design** - Cross-platform layout strategies
- **Performance** - Efficient layout updates and optimizations
- **Platform Consistency** - Leveraging platform-specific design systems

## 🔧 Development Tools

### DCFlight CLI
- **Project Management** - `create`, `run`, `build` commands
- **Module System** - Adding and managing DCFlight modules
- **Development Workflow** - Hot reload and debugging features

### Debugging
- **[Troubleshooting Guide](./TROUBLESHOOTING.md)** - Common issues and solutions
- **Debug Logging** - Comprehensive logging for development
- **Platform Debugging** - Xcode and Android Studio integration
- **Performance Monitoring** - Component rendering and optimization

## 🏗️ Advanced Topics

### Engine & Performance
- **[Custom State Change Handler](./engine/custom_state_change_handler.md)** - Advanced state management
- **[Lifecycle Interpreter](./engine/lifecycle_intepreter.md)** - Component lifecycle management
- **[Performance Optimization](./engine/performance/)** - Advanced performance techniques
- **[Concurrency](./engine/performance/concurrency/)** - Multi-threaded component updates

### Extensibility
- **[Mutator System](./engine/mutator_system\(extensibility\).md)** - Extending DCFlight capabilities  
- **[Prop Diff Interceptor](./engine/prop_diff_interceptor.md)** - Custom prop change handling
- **[Custom Reconciliation Handler](./engine/custom_reconciliation_handeler.md)** - VDOM customization

### Development Tools
- **[Hot Reload Watcher](./devtools/HOT_RELOAD_WATCHER.md)** - Advanced hot reload system
- **[Hot Restart System](./devtools/HOT_RESTART_SYSTEM.md)** - Development restart mechanisms

## 📱 Platform-Specific Features

### iOS Integration
- **UIKit Components** - Direct mapping to native iOS components
- **Navigation Controllers** - UINavigationController integration
- **System Styles** - iOS design system and appearance
- **Platform APIs** - Accessing iOS-specific functionality

### Android Integration  
- **Android Views** - Direct mapping to native Android components
- **Material Design** - Material Design component integration
- **Fragments** - Android Fragment system integration
- **Platform APIs** - Accessing Android-specific functionality

## 🔌 Packages & Extensions

### Core Packages
- **[DCF Primitives](./primitives_docs/)** - Basic UI components and utilities
- **[DCF Reanimated](../packages/dcf_reanimated/docs/)** - High-performance animations
- **[DCF Screens](../packages/dcf_screens/docs/)** - Navigation and screen management

### Package Documentation
- **[Primitives API Reference](./primitives_docs/API_REFERENCE.md)** - Complete API documentation
- **[Hooks System](./hooks/hooks.md)** - React-like hooks for state and lifecycle

## 🐛 Debugging & Troubleshooting

### Common Issues
- **[Troubleshooting Guide](./TROUBLESHOOTING.md)** - Comprehensive issue resolution
- **Method Channel Issues** - Communication between native and Dart
- **Component Rendering** - Layout and display problems
- **Performance Issues** - Optimization and profiling

### Debug Tools
- **Debug Logging** - Enabling comprehensive logging
- **Component Inspection** - Understanding component tree and updates
- **Platform Debugging** - Native debugging with Xcode/Android Studio
- **Performance Profiling** - Identifying bottlenecks and optimizations

## 📖 Examples & Tutorials

### Sample Applications
- **[Template Projects](../packages/template/)** - Starting point for new DCFlight apps
- **[Example Apps](../packages/examples/)** - Real-world DCFlight applications
- **Integration Examples** - Platform-specific integration patterns

### Tutorials
- **First DCFlight App** - Step-by-step app creation
- **Component Development** - Building custom components
- **State Management Patterns** - Effective state handling
- **Platform Integration** - Leveraging native platform features

## 🤝 Contributing

### Development
- **Architecture Understanding** - Framework internals and design
- **Platform Implementation** - iOS and Android integration
- **Testing** - Component testing and platform verification
- **Documentation** - Contributing to docs and examples

### Community
- **GitHub Issues** - Bug reports and feature requests
- **Discussions** - Community support and questions
- **Pull Requests** - Contributing code and improvements

## 📄 Reference

### API Documentation
- **[Primitives API](./primitives_docs/API_REFERENCE.md)** - Complete component API
- **Layout Properties** - All layout configuration options
- **StyleSheet Properties** - Visual styling options
- **Event System** - Event handling and callbacks

### Migration Guides
- **From Flutter** - Migrating Flutter apps to DCFlight
- **From React Native** - Transitioning from React Native
- **Version Updates** - Upgrading between DCFlight versions

---

## 📚 Recommended Learning Path

### Beginners
1. [Getting Started Guide](./GETTING_STARTED.md)
2. [Component System](./engine/components/components.md)
3. [Layout System](./engine/layout/README.md)
4. Build your first DCFlight app

### Intermediate
1. [Architecture Overview](./ARCHITECTURE.md)
2. [Platform Implementation](./PLATFORM_IMPLEMENTATION.md)
3. [Performance Optimization](./engine/components/components.md#performance-optimization)
4. Explore platform-specific features

### Advanced
1. [Engine Internals](./engine/)
2. [Extensibility Systems](./engine/mutator_system\(extensibility\).md)
3. [Performance Tuning](./engine/performance/)
4. Contribute to the framework

---

**Need Help?** Check the [Troubleshooting Guide](./TROUBLESHOOTING.md) or create an issue on [GitHub](https://github.com/DotCorr/DCFlight/issues).

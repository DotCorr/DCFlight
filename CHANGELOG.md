# DCFlight Framework - Root Changelog

This is the main changelog for the DCFlight Framework monorepo. For package-specific changes, see individual package changelogs:

- **DCFlight Core Framework**: [`packages/dcflight/CHANGELOG.md`](packages/dcflight/CHANGELOG.md)
- **DCF Primitives**: [`packages/dcf_primitives/CHANGELOG.md`](packages/dcf_primitives/CHANGELOG.md)
- **DCFlight CLI**: [`cli/CHANGELOG.md`](cli/CHANGELOG.md)

## [0.0.2] - 2025-01-16

### 🚀 Revolutionary Framework Update

This release introduces a groundbreaking **declarative-imperative hybrid pattern** for cross-platform UI component control - the world's first of its kind. This innovative approach combines the best of both paradigms while eliminating their respective drawbacks.

### Package Changes Summary

#### Core Framework ([dcflight](packages/dcflight/CHANGELOG.md))
- Revolutionary prop-based command system replacing legacy imperative methods
- Enhanced VDOM efficiency with smart command diffing  
- 50% reduction in bridge calls through command batching
- Improved bridge performance and memory management

#### Primitives Library ([dcf_primitives](packages/dcf_primitives/CHANGELOG.md))
- Complete migration to prop-based command pattern for all interactive components
- New type-safe command classes for ScrollView, FlatList, AnimatedView, Button, TouchableOpacity, GestureDetector, Text, and Image
- Enhanced component set with DCFWebView, DCFAlert, DCFModal, DCFSegmentedControl, DCFSlider, DCFSpinner, DCFDropdown
- Removed unreliable DCFUrlWrapperViewComponent
- Fixed critical iOS threading issues and memory leaks

#### CLI Tooling ([cli](cli/CHANGELOG.md))
- Updated project templates to use new command pattern
- Enhanced scaffolding with updated component examples
- Improved generated documentation

### Migration Impact
- **Breaking Change**: DCFUrlWrapperView component removed (use DCFGestureDetector + url_launcher)
- **Zero Breaking Change**: All other components maintain backward compatibility
- **Performance Gain**: Significant performance improvements across all platforms
- **Developer Experience**: Enhanced type safety, testability, and debugging capabilities

### Innovation Highlights
- **Type-Safe Commands**: Compile-time validation prevents runtime errors
- **Zero Memory Overhead**: No ref management or cleanup needed
- **Time-Travel Debugging**: Commands are serializable state snapshots
- **Minimal Re-renders**: Only command prop changes trigger updates
- **Unit Testable**: Commands serialize to predictable maps

---

**Full details in individual package changelogs.**

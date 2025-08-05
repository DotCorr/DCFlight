/*
 * 
 * A special component that can "suspend" its children from rendering while
 * keeping them in the component tree for navigation and lifecycle purposes.
 * 
 * Think of it as a virtual container - psychologically there, physically suspended.
 */

import 'package:dcflight/dcflight.dart';

/// Suspension modes for different use cases
enum DCFSuspensionMode {
  /// Completely suspended - children don't render at all
  full,

  /// Placeholder mode - renders a lightweight placeholder instead
  placeholder,

  /// Background mode - renders but hidden/invisible
  background,

  /// Memory mode - pre-rendered but kept in memory only
  memory,
}

/// A component that can suspend its children from rendering while keeping them
/// in the component tree for navigation registration and lifecycle purposes
class DCFSuspensionView extends StatefulComponent {
  /// Whether children are currently suspended
  final bool suspended;

  /// Mode of suspension behavior
  final DCFSuspensionMode mode;

  /// Children to suspend/unsuspend
  final List<DCFComponentNode> children;

  /// Placeholder to show when suspended (for placeholder mode)
  final DCFComponentNode? placeholder;

  /// Layout props for the suspension container
  final LayoutProps? layout;

  /// Style for the suspension container
  final StyleSheet? styleSheet;

  /// Suspension reason (for debugging)
  final String? suspensionReason;

  /// Callback when suspension state changes
  final Function(bool suspended)? onSuspensionChange;

  /// Pre-render children even when suspended (for faster unsuspension)
  final bool preRender;

  DCFSuspensionView({
    super.key,
    this.suspended = false,
    this.mode = DCFSuspensionMode.full,
    required this.children,
    this.placeholder,
    this.layout,
    this.styleSheet,
    this.suspensionReason,
    this.onSuspensionChange,
    this.preRender = true,
  });

  @override
  DCFComponentNode render() {
    // Call suspension change callback if provided
    if (onSuspensionChange != null) {
      useEffect(() {
        onSuspensionChange!(suspended);
        return null;
      }, dependencies: [suspended]);
    }

    // Debug logging
    useEffect(() {
      final reason = suspensionReason ?? 'Unknown';
      print(
          "🎭 SuspensionView: ${suspended ? 'SUSPENDED' : 'ACTIVE'} - $reason");
      return null;
    }, dependencies: [suspended]);

    // Handle different suspension modes
    if (suspended) {
      switch (mode) {
        case DCFSuspensionMode.full:
          return _renderFullSuspension();

        case DCFSuspensionMode.placeholder:
          return _renderPlaceholderSuspension();

        case DCFSuspensionMode.background:
          return _renderBackgroundSuspension();

        case DCFSuspensionMode.memory:
          return _renderMemorySuspension();
      }
    }

    // Not suspended - render normally
    return _renderActive();
  }

  /// Full suspension - render nothing (or minimal container)
  DCFComponentNode _renderFullSuspension() {
    if (preRender) {
      // Pre-render in memory but don't display
      return DCFSuspensionContainer(
        suspended: true,
        mode: mode,
        layout: layout,
        styleSheet: styleSheet,
        children: children, // Still render for registration
        visible: false,
      );
    } else {
      // Truly empty - just a minimal container
      return DCFSuspensionContainer(
        suspended: true,
        mode: mode,
        layout: layout,
        styleSheet: styleSheet,
        children: [], // No children at all
        visible: false,
      );
    }
  }

  /// Placeholder suspension - show a placeholder instead
  DCFComponentNode _renderPlaceholderSuspension() {
    return DCFSuspensionContainer(
      suspended: true,
      mode: mode,
      layout: layout,
      styleSheet: styleSheet,
      children: placeholder != null ? [placeholder!] : [_defaultPlaceholder()],
      visible: true,
    );
  }

  /// Background suspension - render but invisible
  DCFComponentNode _renderBackgroundSuspension() {
    return DCFSuspensionContainer(
      suspended: true,
      mode: mode,
      layout: layout?.copyWith(
        position: YogaPositionType.absolute,
        absoluteLayout: AbsoluteLayout(
          top: -9999, // Move way off screen
          left: -9999,
        ),
      ),
      styleSheet: styleSheet?.copyWith(opacity: 0.0),
      children: children,
      visible: false,
    );
  }

  /// Memory suspension - pre-rendered but kept in memory only
  DCFComponentNode _renderMemorySuspension() {
    return DCFSuspensionContainer(
      suspended: true,
      mode: mode,
      layout: layout?.copyWith(
        display: YogaDisplay.none,
      ),
      children: children, // Pre-rendered in memory
      visible: false,
    );
  }

  /// Active mode - render normally
  DCFComponentNode _renderActive() {
    return DCFSuspensionContainer(
      suspended: false,
      mode: mode,
      layout: layout,
      styleSheet: styleSheet,
      children: children,
      visible: true,
    );
  }

  /// Default placeholder when none is provided
  DCFComponentNode _defaultPlaceholder() {
    return DCFView(
      layout: LayoutProps(
        height: 50,
        width: "100%",
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: Colors.grey.withOpacity(0.1),
        borderRadius: 8,
      ),
      children: [
        DCFText(
          content: "Loading...",
          textProps: DCFTextProps(
            fontSize: 14,
            color: Colors.grey,
            textAlign: "center",
          ),
        ),
      ],
    );
  }
}

/// Internal container that handles the suspension magic
class DCFSuspensionContainer extends StatelessComponent
    implements ComponentPriorityInterface {
  final bool suspended;
  final DCFSuspensionMode mode;
  final LayoutProps? layout;
  final StyleSheet? styleSheet;
  final List<DCFComponentNode> children;
  final bool visible;

  DCFSuspensionContainer({
    super.key,
    required this.suspended,
    required this.mode,
    this.layout,
    this.styleSheet,
    required this.children,
    required this.visible,
  });

  @override
  ComponentPriority get priority {
    // Suspended components have lower priority
    if (suspended) {
      return ComponentPriority.low;
    }
    return ComponentPriority.normal;
  }

  @override
  DCFComponentNode render() {
    // Special metadata to signal to VDOM about suspension
    final suspensionProps = {
      'isSuspended': suspended,
      'suspensionMode': mode.name,
      'visible': visible,
      'suspensionContainer': true,
    };

    return DCFElement(
      type: 'SuspensionView',
      props: {
        ...suspensionProps,
        if (layout != null) ...layout!.toMap(),
        if (styleSheet != null) ...styleSheet!.toMap(),
      },
      children: children,
    );
  }
}

/// Helper function to create suspended screen components
DCFSuspensionView createSuspendedScreen({
  required String screenName,
  required DCFComponentNode Function() builder,
  bool suspended = true,
  DCFSuspensionMode mode = DCFSuspensionMode.memory,
  String? reason,
}) {
  return DCFSuspensionView(
    key: Key(screenName).toString(),
    suspended: suspended,
    mode: mode,
    suspensionReason: reason ?? "Screen '$screenName' lazy loading",
    preRender: true, // Pre-render for faster activation
    children: [builder()],
  );
}

/// Extension for easier suspension control
extension SuspensionControl on Store<bool> {
  /// Create a suspension view controlled by this store
  DCFSuspensionView suspensionView({
    required List<DCFComponentNode> children,
    DCFSuspensionMode mode = DCFSuspensionMode.full,
    DCFComponentNode? placeholder,
    LayoutProps? layout,
    StyleSheet? styleSheet,
    String? reason,
  }) {
    return DCFSuspensionView(
      suspended: state,
      mode: mode,
      children: children,
      placeholder: placeholder,
      layout: layout,
      styleSheet: styleSheet,
      suspensionReason: reason,
      onSuspensionChange: (suspended) {
        print(
            "🎭 Suspension changed: $suspended${reason != null ? ' - $reason' : ''}");
      },
    );
  }
}

/// Smart suspension manager for screens
class DCFSuspensionManager {
  static final Map<String, Store<bool>> _suspensionStores = {};

  /// Get or create suspension store for a screen
  static Store<bool> getStore(String screenName) {
    return _suspensionStores.putIfAbsent(
      screenName,
      () => Store<bool>(true), // Start suspended
    );
  }

  /// Suspend a screen
  static void suspend(String screenName, {String? reason}) {
    final store = getStore(screenName);
    store.setState(true);
    print(
        "🎭 SuspensionManager: Suspended '$screenName'${reason != null ? ' - $reason' : ''}");
  }

  /// Activate a screen
  static void activate(String screenName, {String? reason}) {
    final store = getStore(screenName);
    store.setState(false);
    print(
        "🎭 SuspensionManager: Activated '$screenName'${reason != null ? ' - $reason' : ''}");
  }

  /// Check if screen is suspended
  static bool isSuspended(String screenName) {
    return getStore(screenName).state;
  }

  /// Suspend all screens except the given one
  static void suspendAllExcept(String activeScreen) {
    for (final entry in _suspensionStores.entries) {
      if (entry.key != activeScreen) {
        entry.value.setState(true);
      }
    }
    print("🎭 SuspensionManager: Suspended all except '$activeScreen'");
  }

  /// Get suspension statistics
  static Map<String, dynamic> getStats() {
    final suspended = _suspensionStores.entries
        .where((entry) => entry.value.state)
        .map((entry) => entry.key)
        .toList();

    final active = _suspensionStores.entries
        .where((entry) => !entry.value.state)
        .map((entry) => entry.key)
        .toList();

    return {
      'totalScreens': _suspensionStores.length,
      'suspended': suspended,
      'active': active,
      'suspendedCount': suspended.length,
      'activeCount': active.length,
    };
  }
}

// 🎯 DCFLazySuspense - Suspense with built-in navigation awareness
import 'package:dcflight/dcflight.dart';

///
/// This variant automatically determines when to render based on
/// the current active screen state.
class DCFLazySuspense extends DCFStatefulComponent with EquatableMixin {
  /// The route/screen name this suspense is for
  final String routeName;

  /// Store that tracks the current active screen
  final Store<String?> activeScreenStore;

  /// The content to render when this route is active
  final DCFComponentNode Function() children;

  /// Optional fallback content when route is not active
  final DCFComponentNode Function()? fallback;

  /// Optional additional condition (AND with route check)
  final bool Function()? additionalCondition;

  /// Layout properties for the container
  final DCFLayout? layout;

  /// Style sheet for the container
  final DCFStyleSheet? styleSheet;

  /// Whether to show debug logs
  final bool enableDebugLogs;

  DCFLazySuspense({
    super.key,
    required this.routeName,
    required this.activeScreenStore,
    required this.children,
    this.fallback,
    this.additionalCondition,
    this.layout,
    this.styleSheet,
    this.enableDebugLogs = true,
  });

  @override
  DCFComponentNode render() {
    // Watch the active screen store
    final activeScreen = useStore(activeScreenStore);

    // Determine if we should render
    bool shouldRender = activeScreen.state == routeName;

    // Apply additional condition if provided
    if (additionalCondition != null) {
      shouldRender = shouldRender && additionalCondition!();
    }

    if (shouldRender) {
      if (enableDebugLogs) {
        print(
            "🏗️ DCFLazySuspense[$routeName]: Rendering children (route active)");
      }

      return DCFView(
        layout: layout ?? DCFLayout(),
        styleSheet: styleSheet ?? DCFStyleSheet(),
        children: [children()],
      );
    } else {
      if (enableDebugLogs) {
        print(
            "⏸️ DCFLazySuspense[$routeName]: Rendering fallback (route inactive)");
      }

      if (fallback != null) {
        return DCFView(
          layout: layout ?? DCFLayout(),
          styleSheet: styleSheet ?? DCFStyleSheet(),
          children: [fallback!()],
        );
      } else {
        return DCFView(
          layout: layout ?? DCFLayout(),
          styleSheet: styleSheet ?? DCFStyleSheet(),
          children: [],
        );
      }
    }
  }

  @override
  List<Object?> get props => [
        key,
        routeName,
        activeScreenStore,
        children,
        fallback,
        additionalCondition,
        layout,
        styleSheet,
        enableDebugLogs,
      ];
}

/// 🎯 Helper extension for Store to create Suspense easily
extension StoreToSuspense<T> on Store<T> {
  /// Create a DCFSuspense that renders when store value matches condition
  DCFSuspense suspenseWhen(
    bool Function(T? value) condition,
    DCFComponentNode Function() children, {
    DCFComponentNode Function()? fallback,
    String? debugName,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    bool enableDebugLogs = true,
  }) {
    return DCFSuspense(
      shouldRender: condition(state),
      children: children,
      fallback: fallback,
      debugName: debugName,
      layout: layout,
      styleSheet: styleSheet,
      enableDebugLogs: enableDebugLogs,
    );
  }

  /// Create a DCFSuspense that renders when store value equals target
  DCFSuspense suspenseEquals(
    T target,
    DCFComponentNode Function() children, {
    DCFComponentNode Function()? fallback,
    String? debugName,
    DCFLayout? layout,
    DCFStyleSheet? styleSheet,
    bool enableDebugLogs = true,
  }) {
    return suspenseWhen(
      (value) => value == target,
      children,
      fallback: fallback,
      debugName: debugName,
      layout: layout,
      styleSheet: styleSheet,
      enableDebugLogs: enableDebugLogs,
    );
  }
}

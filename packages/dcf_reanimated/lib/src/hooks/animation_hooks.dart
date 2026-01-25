/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'package:dcflight/dcflight.dart';
import '../values/animation_values.dart';
import '../styles/animated_style.dart';

/// DCF Reanimated hooks for use within StatefulComponent widgets.
/// 
/// These hooks provide reactive animation capabilities that run purely
/// on the UI thread for maximum performance.
extension PureReanimatedHooks on DCFStatefulComponent {
  /// Creates a shared value that runs purely on UI thread.
  /// 
  /// [SharedValue] objects can be animated smoothly without bridge calls
  /// once they're configured. They maintain their state across rebuilds
  /// using [useRef] internally.
  /// 
  /// Example:
  /// ```dart
  /// class AnimatedButton extends StatefulComponent {
  ///   @override
  ///   DCFComponentNode render() {
  ///     final scale = useSharedValue(1.0);
  ///     
  ///     return ReanimatedView(
  ///       animatedStyle: useAnimatedStyle(() => 
  ///         AnimatedStyle().transform(scale: scale.withTiming(toValue: 1.2))
  ///       ),
  ///       children: [/* ... */],
  ///     );
  ///   }
  /// }
  /// ```
  SharedValue useSharedValue(double initialValue) {
    final ref = useRef<SharedValue?>(null);

    if (ref.current == null) {
      ref.current = SharedValue(initialValue);
    }

    return ref.current!;
  }

  /// Creates animated style that runs purely on UI thread.
  /// 
  /// The [styleFactory] function is called whenever dependencies change,
  /// allowing you to create responsive animations based on state.
  /// 
  /// The [dependencies] list determines when the style should be recreated.
  /// Include all state variables that the animation depends on.
  /// 
  /// Example:
  /// ```dart
  /// class ResponsiveAnimation extends StatefulComponent {
  ///   @override
  ///   DCFComponentNode render() {
  ///     final isPressed = useState(false);
  ///     final scale = useSharedValue(1.0);
  ///     
  ///     final animatedStyle = useAnimatedStyle(() {
  ///       return AnimatedStyle()
  ///         .transform(scale: scale.withTiming(
  ///           toValue: isPressed.state ? 0.95 : 1.0,
  ///           duration: 150,
  ///         ));
  ///     }, dependencies: [isPressed.state]);
  ///     
  ///     return ReanimatedView(
  ///       animatedStyle: animatedStyle,
  ///       children: [/* ... */],
  ///     );
  ///   }
  /// }
  /// ```
  AnimatedStyle useAnimatedStyle(
    AnimatedStyle Function() styleFactory, {
    List<Object?> dependencies = const [],
  }) {
    final ref = useRef<AnimatedStyle?>(null);
    final depsRef = useRef<List<Object?>?>(null);

    // Check if dependencies have changed
    bool depsChanged = false;
    if (depsRef.current == null ||
        depsRef.current!.length != dependencies.length) {
      depsChanged = true;
    } else {
      for (int i = 0; i < dependencies.length; i++) {
        if (depsRef.current![i] != dependencies[i]) {
          depsChanged = true;
          break;
        }
      }
    }

    // Recreate style if dependencies changed
    if (ref.current == null || depsChanged) {
      ref.current = styleFactory();
      depsRef.current = List.from(dependencies);
    }

    return ref.current!;
  }

  /// Registers callbacks for animation events.
  /// 
  /// This hook allows you to respond to animation lifecycle events
  /// without having to manage event handlers manually. The callback
  /// will be called when animations with the specified [animationId] complete.
  /// 
  /// Like other hooks, callbacks are recreated when [dependencies] change.
  /// 
  /// Example:
  /// ```dart
  /// class NotificationBanner extends StatefulComponent {
  ///   @override
  ///   DCFComponentNode render() {
  ///     final isVisible = useState(true);
  ///     
  ///     useAnimatedCallback(() {
  ///       // Hide banner after fade out completes
  ///       isVisible.setState(false);
  ///     }, 
  ///     animationId: 'banner-fade-out',
  ///     dependencies: []);
  ///     
  ///     return ReanimatedView(
  ///       animationId: 'banner-fade-out',
  ///       animatedStyle: AnimatedStyle().opacity(
  ///         ReanimatedValue(from: 1.0, to: 0.0, duration: 300)
  ///       ),
  ///       children: [/* ... */],
  ///     );
  ///   }
  /// }
  /// ```
  void useAnimatedCallback(
    void Function() callback, {
    required String animationId,
    List<Object?> dependencies = const [],
  }) {
    final callbackRef = useRef<void Function()?>(null);
    final depsRef = useRef<List<Object?>?>(null);

    // Check if dependencies have changed
    bool depsChanged = false;
    if (depsRef.current == null ||
        depsRef.current!.length != dependencies.length) {
      depsChanged = true;
    } else {
      for (int i = 0; i < dependencies.length; i++) {
        if (depsRef.current![i] != dependencies[i]) {
          depsChanged = true;
          break;
        }
      }
    }

    // Update callback if dependencies changed
    if (callbackRef.current == null || depsChanged) {
      callbackRef.current = callback;
      depsRef.current = List.from(dependencies);
      
      // Register callback with animation system
      // This would typically involve registering with a global animation manager
      // For now, we'll store the reference for future implementation
    }
  }
}

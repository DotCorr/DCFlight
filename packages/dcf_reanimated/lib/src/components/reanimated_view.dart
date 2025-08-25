/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library dcf_reanimated.components;

import 'package:dcflight/dcflight.dart';
import '../styles/animated_style.dart';
import '../helper/init.dart';

/// The main animated view component that runs animations purely on the UI thread.
/// 
/// [ReanimatedView] is a drop-in replacement for [DCFView] that adds animation
/// capabilities without sacrificing performance. All animations are configured
/// via props and run natively without bridge calls.
/// 
/// Key features:
/// - Pure UI thread execution (60fps)
/// - Zero bridge calls during animation
/// - Automatic initialization
/// - Event callbacks for animation lifecycle
/// - Unique animation IDs for debugging
/// 
/// Example:
/// ```dart
/// ReanimatedView(
///   animatedStyle: Reanimated.fadeIn(duration: 500),
///   onAnimationComplete: () => print("Fade complete!"),
///   children: [
///     DCFText(content: "I animate smoothly!"),
///   ],
/// )
/// ```
class ReanimatedView extends StatelessComponent with EquatableMixin {
  /// Child components to render inside the animated view
  final List<DCFComponentNode> children;
  
  /// Animation configuration that runs on UI thread
  final AnimatedStyle? animatedStyle;
  
  /// Layout properties for positioning and sizing
  final LayoutProps layout;
  
  /// Static styling properties (non-animated)
  final StyleSheet styleSheet;
  
  /// Whether to start animation automatically when component mounts
  final bool autoStart;
  
  /// Delay before starting animation in milliseconds
  final int startDelay;
  
  /// Called when animation begins
  final void Function()? onAnimationStart;
  
  /// Called when animation completes
  final void Function()? onAnimationComplete;
  
  /// Called when animation repeats (for repeating animations)
  final void Function()? onAnimationRepeat;
  
  /// Additional event handlers
  final Map<String, dynamic>? events;

  /// Creates a new animated view component.
  /// 
  /// The [children] parameter is required, all others have sensible defaults.
  /// Animation initialization is handled automatically.
  ReanimatedView({
    required this.children,
    this.animatedStyle,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.autoStart = true,
    this.startDelay = 0,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.onAnimationRepeat,
    this.events,
    super.key,
  }) {
    // Ensure DCF Reanimated is initialized before first use
    ReanimatedInit.ensureInitialized();
  }

  @override
  DCFComponentNode render() {
    // Prepare event handlers map
    Map<String, dynamic> eventHandlers = events ?? {};

    // Add lifecycle callbacks to event handlers
    if (onAnimationStart != null) {
      eventHandlers['onAnimationStart'] = onAnimationStart;
    }
    if (onAnimationComplete != null) {
      eventHandlers['onAnimationComplete'] = onAnimationComplete;
    }
    if (onAnimationRepeat != null) {
      eventHandlers['onAnimationRepeat'] = onAnimationRepeat;
    }

    // Build props map for native bridge communication
    Map<String, dynamic> props = {
      // Animation configuration
      'autoStart': autoStart,
      'startDelay': startDelay,
      'isPureReanimated': true, // Flag for native to use pure animation mode
      
      // Layout and styling
      ...layout.toMap(),
      ...styleSheet.toMap(),
      
      // Event handlers
      ...eventHandlers,
    };

    // Include animation style configuration if provided
    if (animatedStyle != null) {
      props['animatedStyle'] = animatedStyle!.toMap();
    }

    // Create DCF element that will be rendered by native component
    return DCFElement(
      type: 'ReanimatedView', // Must match native component registration
      elementProps: props,
      children: children,
    );
  }

  /// Properties for equality comparison (used by EquatableMixin)
  @override
  List<Object?> get props => [
        children,
        animatedStyle,
        layout,
        styleSheet,
        autoStart,
        startDelay,
        onAnimationStart,
        onAnimationComplete,
        onAnimationRepeat,
        events,
        key,
      ];
}

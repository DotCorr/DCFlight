/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// 🚀 DCF Swipeable View Component
/// 
/// A low-level animatable view that responds to gestures (swipe right, left, up, down).
/// Allows users to create custom drawers and swipeable components with real-time movement.
class DCFSwipeableView extends StatelessComponent {
  /// Child components to display inside the swipeable view
  final List<DCFComponentNode> children;
  
  /// Whether the view can be swiped horizontally
  final bool horizontalSwipeEnabled;
  
  /// Whether the view can be swiped vertically
  final bool verticalSwipeEnabled;
  
  /// Minimum distance to trigger a swipe gesture
  final double swipeThreshold;
  
  /// Whether to enable elastic/bouncy behavior at edges
  final bool elasticEnabled;
  
  /// Maximum distance the view can move beyond bounds (elastic effect)
  final double elasticDistance;
  
  /// Resistance factor for elastic movement (0.0 to 1.0)
  final double elasticResistance;
  
  /// Whether to animate back to position when gesture ends
  final bool animateBack;
  
  /// Duration for animations in milliseconds
  final int animationDuration;
  
  /// Called when swipe starts
  final Function(Map<dynamic, dynamic>)? onSwipeStart;
  
  /// Called during swipe movement (real-time updates)
  final Function(Map<dynamic, dynamic>)? onSwipeMove;
  
  /// Called when swipe ends
  final Function(Map<dynamic, dynamic>)? onSwipeEnd;
  
  /// Called when swiped right
  final Function(Map<dynamic, dynamic>)? onSwipeRight;
  
  /// Called when swiped left
  final Function(Map<dynamic, dynamic>)? onSwipeLeft;
  
  /// Called when swiped up
  final Function(Map<dynamic, dynamic>)? onSwipeUp;
  
  /// Called when swiped down
  final Function(Map<dynamic, dynamic>)? onSwipeDown;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties  
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;

  DCFSwipeableView({
    super.key,
    this.children = const [],
    this.horizontalSwipeEnabled = true,
    this.verticalSwipeEnabled = true,
    this.swipeThreshold = 50.0,
    this.elasticEnabled = true,
    this.elasticDistance = 100.0,
    this.elasticResistance = 0.3,
    this.animateBack = true,
    this.animationDuration = 300,
    this.onSwipeStart,
    this.onSwipeMove,
    this.onSwipeEnd,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onSwipeUp,
    this.onSwipeDown,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.events,
  });

  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};
    
    if (onSwipeStart != null) {
      eventMap['onSwipeStart'] = onSwipeStart;
    }
    
    if (onSwipeMove != null) {
      eventMap['onSwipeMove'] = onSwipeMove;
    }
    
    if (onSwipeEnd != null) {
      eventMap['onSwipeEnd'] = onSwipeEnd;
    }
    
    if (onSwipeRight != null) {
      eventMap['onSwipeRight'] = onSwipeRight;
    }
    
    if (onSwipeLeft != null) {
      eventMap['onSwipeLeft'] = onSwipeLeft;
    }
    
    if (onSwipeUp != null) {
      eventMap['onSwipeUp'] = onSwipeUp;
    }
    
    if (onSwipeDown != null) {
      eventMap['onSwipeDown'] = onSwipeDown;
    }
    
    return DCFElement(
      type: 'SwipeableView',
      props: {
        'horizontalSwipeEnabled': horizontalSwipeEnabled,
        'verticalSwipeEnabled': verticalSwipeEnabled,
        'swipeThreshold': swipeThreshold,
        'elasticEnabled': elasticEnabled,
        'elasticDistance': elasticDistance,
        'elasticResistance': elasticResistance,
        'animateBack': animateBack,
        'animationDuration': animationDuration,
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: children,
    );
  }

  /// Helper method to create a horizontal-only swipeable view (like a drawer)
  static DCFSwipeableView horizontalDrawer({
    required List<DCFComponentNode> children,
    double swipeThreshold = 50.0,
    bool elasticEnabled = true,
    Function(Map<dynamic, dynamic>)? onSwipeRight,
    Function(Map<dynamic, dynamic>)? onSwipeLeft,
  }) {
    return DCFSwipeableView(
      children: children,
      horizontalSwipeEnabled: true,
      verticalSwipeEnabled: false,
      swipeThreshold: swipeThreshold,
      elasticEnabled: elasticEnabled,
      onSwipeRight: onSwipeRight,
      onSwipeLeft: onSwipeLeft,
    );
  }

  /// Helper method to create a vertical-only swipeable view (like a pull-to-refresh)
  static DCFSwipeableView verticalScroller({
    required List<DCFComponentNode> children,
    double swipeThreshold = 50.0,
    bool elasticEnabled = true,
    Function(Map<dynamic, dynamic>)? onSwipeUp,
    Function(Map<dynamic, dynamic>)? onSwipeDown,
  }) {
    return DCFSwipeableView(
      children: children,
      horizontalSwipeEnabled: false,
      verticalSwipeEnabled: true,
      swipeThreshold: swipeThreshold,
      elasticEnabled: elasticEnabled,
      onSwipeUp: onSwipeUp,
      onSwipeDown: onSwipeDown,
    );
  }

  /// Helper method to create a custom gesture view with specific thresholds
  static DCFSwipeableView customGesture({
    required List<DCFComponentNode> children,
    bool horizontalSwipeEnabled = true,
    bool verticalSwipeEnabled = true,
    double swipeThreshold = 50.0,
    double elasticDistance = 100.0,
    double elasticResistance = 0.3,
    Function(Map<dynamic, dynamic>)? onSwipeMove,
    Function(Map<dynamic, dynamic>)? onSwipeEnd,
  }) {
    return DCFSwipeableView(
      children: children,
      horizontalSwipeEnabled: horizontalSwipeEnabled,
      verticalSwipeEnabled: verticalSwipeEnabled,
      swipeThreshold: swipeThreshold,
      elasticDistance: elasticDistance,
      elasticResistance: elasticResistance,
      onSwipeMove: onSwipeMove,
      onSwipeEnd: onSwipeEnd,
    );
  }
}

/// Swipeable view constants
class DCFSwipeableViewConstants {
  static const double defaultSwipeThreshold = 50.0;
  static const double defaultElasticDistance = 100.0;
  static const double defaultElasticResistance = 0.3;
  static const int defaultAnimationDuration = 300;
}

/// Swipe direction constants
class DCFSwipeDirection {
  static const String left = 'left';
  static const String right = 'right';
  static const String up = 'up';
  static const String down = 'down';
}
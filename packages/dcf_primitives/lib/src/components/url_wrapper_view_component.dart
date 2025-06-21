/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// URL opening behavior
enum DCFUrlOpenBehavior {
  inApp,        // Open within the app (if webview available)
  external,     // Open in external browser
  safariView,   // Open in Safari View Controller (iOS)
  customTab,    // Open in Chrome Custom Tab (Android)
}

/// URL wrapper view properties
class DCFUrlWrapperProps {
  /// The URL to open when interacted with
  final String url;
  
  /// How to open the URL
  final DCFUrlOpenBehavior openBehavior;
  
  /// Whether to detect tap gestures
  final bool detectPress;
  
  /// Whether to detect long press gestures
  final bool detectLongPress;
  
  /// Whether to detect double tap gestures
  final bool detectDoubleTap;
  
  /// Whether to detect swipe gestures
  final bool detectSwipe;
  
  /// Whether to detect pan gestures
  final bool detectPan;
  
  /// Long press delay in milliseconds
  final int longPressDelay;
  
  /// Whether the gesture detector is disabled
  final bool disabled;
  
  /// Whether to use adaptive theming
  final bool adaptive;
  
  /// Create URL wrapper props
  const DCFUrlWrapperProps({
    required this.url,
    this.openBehavior = DCFUrlOpenBehavior.external,
    this.detectPress = true,
    this.detectLongPress = false,
    this.detectDoubleTap = false,
    this.detectSwipe = false,
    this.detectPan = false,
    this.longPressDelay = 500,
    this.disabled = false,
    this.adaptive = true,
  });
  
  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'openBehavior': openBehavior.name,
      'detectPress': detectPress,
      'detectLongPress': detectLongPress,
      'detectDoubleTap': detectDoubleTap,
      'detectSwipe': detectSwipe,
      'detectPan': detectPan,
      'longPressDelay': longPressDelay,
      'disabled': disabled,
      'adaptive': adaptive,
    };
  }
}

/// URL wrapper view - specialized gesture detector for opening URLs
class DCFUrlWrapperView extends StatelessComponent {
  /// Child nodes to wrap with URL opening functionality
  final List<DCFComponentNode> children;
  
  /// URL wrapper properties
  final DCFUrlWrapperProps urlWrapperProps;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;
  
  /// Called when URL is about to open
  final Function(Map<dynamic, dynamic>)? onUrlOpenStart;
  
  /// Called when URL opening succeeds
  final Function(Map<dynamic, dynamic>)? onUrlOpenSuccess;
  
  /// Called when URL opening fails
  final Function(Map<dynamic, dynamic>)? onUrlOpenError;
  
  /// Called when tap is detected (before URL handling)
  final Function(Map<dynamic, dynamic>)? onTapDetected;
  
  /// Called when long press is detected (before URL handling)
  final Function(Map<dynamic, dynamic>)? onLongPressDetected;
  
  /// Called when double tap is detected (before URL handling)
  final Function(Map<dynamic, dynamic>)? onDoubleTapDetected;
  
  /// Called when swipe is detected
  final Function(Map<dynamic, dynamic>)? onSwipeDetected;
  
  /// Called when pan gesture starts
  final Function(Map<dynamic, dynamic>)? onPanStart;
  
  /// Called when pan gesture updates
  final Function(Map<dynamic, dynamic>)? onPanUpdate;
  
  /// Called when pan gesture ends
  final Function(Map<dynamic, dynamic>)? onPanEnd;
  
  /// Create a URL wrapper view component
  DCFUrlWrapperView({
    required this.children,
    required this.urlWrapperProps,
    this.layout = const LayoutProps(padding: 8),
    this.styleSheet = const StyleSheet(),
    this.onUrlOpenStart,
    this.onUrlOpenSuccess,
    this.onUrlOpenError,
    this.onTapDetected,
    this.onLongPressDetected,
    this.onDoubleTapDetected,
    this.onSwipeDetected,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};
    
    // URL-specific events
    if (onUrlOpenStart != null) {
      eventMap['onUrlOpenStart'] = onUrlOpenStart;
    }
    
    if (onUrlOpenSuccess != null) {
      eventMap['onUrlOpenSuccess'] = onUrlOpenSuccess;
    }
    
    if (onUrlOpenError != null) {
      eventMap['onUrlOpenError'] = onUrlOpenError;
    }
    
    // Gesture detection events (only add if detection is enabled)
    if (urlWrapperProps.detectPress && onTapDetected != null) {
      eventMap['onTapDetected'] = onTapDetected;
    }
    
    if (urlWrapperProps.detectLongPress && onLongPressDetected != null) {
      eventMap['onLongPressDetected'] = onLongPressDetected;
    }
    
    if (urlWrapperProps.detectDoubleTap && onDoubleTapDetected != null) {
      eventMap['onDoubleTapDetected'] = onDoubleTapDetected;
    }
    
    if (urlWrapperProps.detectSwipe && onSwipeDetected != null) {
      eventMap['onSwipeDetected'] = onSwipeDetected;
    }
    
    if (urlWrapperProps.detectPan) {
      if (onPanStart != null) {
        eventMap['onPanStart'] = onPanStart;
      }
      if (onPanUpdate != null) {
        eventMap['onPanUpdate'] = onPanUpdate;
      }
      if (onPanEnd != null) {
        eventMap['onPanEnd'] = onPanEnd;
      }
    }
    
    return DCFElement(
      type: 'UrlWrapperView',
      props: {
        ...urlWrapperProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: children,
    );
  }
}

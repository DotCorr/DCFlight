/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Measurement data returned by measure() callback
class DCFMeasureData {
  /// X coordinate of the origin (top-left corner) of the measured view in the viewport
  final double x;
  
  /// Y coordinate of the origin (top-left corner) of the measured view in the viewport
  final double y;
  
  /// Width of the view
  final double width;
  
  /// Height of the view
  final double height;
  
  /// X coordinate of the view in the viewport (typically the whole screen)
  final double pageX;
  
  /// Y coordinate of the view in the viewport (typically the whole screen)
  final double pageY;

  DCFMeasureData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pageX,
    required this.pageY,
  });

  /// Create from raw map data
  factory DCFMeasureData.fromMap(Map<dynamic, dynamic> data) {
    return DCFMeasureData(
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      width: (data['width'] as num).toDouble(),
      height: (data['height'] as num).toDouble(),
      pageX: (data['pageX'] as num).toDouble(),
      pageY: (data['pageY'] as num).toDouble(),
    );
  }
}

/// Measurement data returned by measureInWindow() callback
class DCFMeasureInWindowData {
  /// X coordinate of the view in the current window
  final double x;
  
  /// Y coordinate of the view in the current window
  final double y;
  
  /// Width of the view
  final double width;
  
  /// Height of the view
  final double height;

  DCFMeasureInWindowData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Create from raw map data
  factory DCFMeasureInWindowData.fromMap(Map<dynamic, dynamic> data) {
    return DCFMeasureInWindowData(
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      width: (data['width'] as num).toDouble(),
      height: (data['height'] as num).toDouble(),
    );
  }
}

/// Viewport configuration for viewport enter/leave detection
class DCFViewportConfig {
  /// Whether to trigger callback only once (default: false = every time)
  final bool once;
  
  /// Amount of element that must be visible (0.0 to 1.0, default: 0.0 = any visibility)
  final double amount;
  
  /// Margin around viewport (in pixels, default: 0)
  final double margin;

  const DCFViewportConfig({
    this.once = false,
    this.amount = 0.0,
    this.margin = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'once': once,
    'amount': amount,
    'margin': margin,
  };
}

/// Viewport component for measuring layout and detecting viewport visibility
/// 
/// This component provides:
/// 1. **Layout Measurement** (works on ANY view, not just scroll views):
///    - `onMeasure`: Returns view position and size in viewport coordinates
///    - `onMeasureInWindow`: Returns view position and size in window coordinates
/// 
/// 2. **Viewport Detection** (works with or without scroll views):
///    - If view is inside a ScrollView: detects when view enters/leaves the scroll view's visible area
///    - If view is NOT in a ScrollView: detects when view enters/leaves the window/screen bounds
///    - `onViewportEnter`: Called when view becomes visible in viewport
///    - `onViewportLeave`: Called when view leaves viewport
/// 
/// Example:
/// ```dart
/// DCFViewport(
///   onMeasure: (data) {
///     print('View measured: ${data.width}x${data.height} at (${data.x}, ${data.y})');
///   },
///   onMeasureInWindow: (data) {
///     print('View in window: ${data.width}x${data.height} at (${data.x}, ${data.y})');
///   },
///   onViewportEnter: () {
///     print('View entered viewport');
///   },
///   onViewportLeave: () {
///     print('View left viewport');
///   },
///   viewport: DCFViewportConfig(once: true, amount: 0.5),
///   children: [
///     DCFText(content: "Measurable content"),
///   ],
/// )
/// ```
class DCFViewport extends DCFStatelessComponent {
  /// Child components to render inside the viewport
  final List<DCFComponentNode> children;

  /// Layout properties for positioning and sizing
  final DCFLayout? layout;

  /// Static styling properties (non-animated)
  final DCFStyleSheet? styleSheet;

  /// Callback when view is measured (called on layout)
  /// Provides: x, y, width, height, pageX, pageY
  final Function(DCFMeasureData)? onMeasure;

  /// Callback when view is measured in window coordinates
  /// Provides: x, y, width, height
  final Function(DCFMeasureInWindowData)? onMeasureInWindow;

  /// Callback when element enters viewport
  final void Function()? onViewportEnter;

  /// Callback when element exits viewport
  final void Function()? onViewportLeave;

  /// Viewport detection configuration
  final DCFViewportConfig? viewport;

  /// Create a viewport component
  DCFViewport({
    required this.children,
    this.layout,
    this.styleSheet,
    this.onMeasure,
    this.onMeasureInWindow,
    this.onViewportEnter,
    this.onViewportLeave,
    this.viewport,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final eventMap = <String, dynamic>{};
    
    // Register measure callback
    if (onMeasure != null) {
      eventMap['onMeasure'] = (Map<dynamic, dynamic> data) {
        onMeasure!(DCFMeasureData.fromMap(data));
      };
    }
    
    // Register measureInWindow callback
    if (onMeasureInWindow != null) {
      eventMap['onMeasureInWindow'] = (Map<dynamic, dynamic> data) {
        onMeasureInWindow!(DCFMeasureInWindowData.fromMap(data));
      };
    }
    
    // Register viewport callbacks
    if (onViewportEnter != null) {
      eventMap['onViewportEnter'] = onViewportEnter;
    }
    
    if (onViewportLeave != null) {
      eventMap['onViewportLeave'] = onViewportLeave;
    }
    
    // Add viewport config if provided
    if (viewport != null) {
      eventMap['viewport'] = viewport!.toMap();
    }

    return DCFElement(
      type: 'Viewport',
      elementProps: {
        ...(layout ?? const DCFLayout()).toMap(),
        ...(styleSheet ?? const DCFStyleSheet(backgroundColor: DCFColors.transparent)).toMap(),
        ...eventMap,
      },
      children: children,
    );
  }
}


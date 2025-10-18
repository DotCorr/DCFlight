/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Gesture detector tap callback data
class DCFGestureTapData {
  /// Whether the tap was from user interaction
  final bool fromUser;
  
  /// X coordinate of the tap
  final double x;
  
  /// Y coordinate of the tap
  final double y;
  
  /// Timestamp of the tap
  final DateTime timestamp;

  DCFGestureTapData({
    this.fromUser = true,
    required this.x,
    required this.y,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGestureTapData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGestureTapData(
      fromUser: data['fromUser'] as bool? ?? true,
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
}

/// Gesture detector long press callback data
class DCFGestureLongPressData {
  /// Whether the long press was from user interaction
  final bool fromUser;
  
  /// X coordinate of the long press
  final double x;
  
  /// Y coordinate of the long press
  final double y;
  
  /// Timestamp of the long press
  final DateTime timestamp;

  DCFGestureLongPressData({
    this.fromUser = true,
    required this.x,
    required this.y,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGestureLongPressData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGestureLongPressData(
      fromUser: data['fromUser'] as bool? ?? true,
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Gesture detector swipe callback data
class DCFGestureSwipeData {
  /// Direction of the swipe
  final String direction;
  
  /// Whether the swipe was from user interaction
  final bool fromUser;
  
  /// Velocity of the swipe
  final double velocity;
  
  /// Timestamp of the swipe
  final DateTime timestamp;

  DCFGestureSwipeData({
    required this.direction,
    this.fromUser = true,
    required this.velocity,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGestureSwipeData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGestureSwipeData(
      direction: data['direction'] as String,
      fromUser: data['fromUser'] as bool? ?? true,
      velocity: (data['velocity'] as num).toDouble(),
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Gesture detector pan callback data
class DCFGesturePanData {
  /// X coordinate of the pan
  final double x;
  
  /// Y coordinate of the pan
  final double y;
  
  /// Whether the pan was from user interaction
  final bool fromUser;
  
  /// Timestamp of the pan
  final DateTime timestamp;

  DCFGesturePanData({
    required this.x,
    required this.y,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGesturePanData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGesturePanData(
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// A gesture detector component implementation using StatelessComponent
class DCFGestureDetector extends DCFStatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// The layout properties
  final DCFLayout layout;

  /// The styleSheet properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Tap event handler - receives type-safe gesture data
  final Function(DCFGestureTapData)? onTap;

  /// Long press event handler - receives type-safe gesture data
  final Function(DCFGestureLongPressData)? onLongPress;

  /// Swipe left event handler - receives type-safe gesture data
  final Function(DCFGestureSwipeData)? onSwipeLeft;

  /// Swipe right event handler - receives type-safe gesture data
  final Function(DCFGestureSwipeData)? onSwipeRight;

  /// Swipe up event handler - receives type-safe gesture data
  final Function(DCFGestureSwipeData)? onSwipeUp;

  /// Swipe down event handler - receives type-safe gesture data
  final Function(DCFGestureSwipeData)? onSwipeDown;

  /// Pan start event handler - receives type-safe gesture data
  final Function(DCFGesturePanData)? onPanStart;

  /// Pan update event handler - receives type-safe gesture data
  final Function(DCFGesturePanData)? onPanUpdate;

  /// Pan end event handler - receives type-safe gesture data
  final Function(DCFGesturePanData)? onPanEnd;

  /// Whether to use adaptive theming
  final bool adaptive;

  /// Create a gesture detector component
  DCFGestureDetector({
    required this.children,
    this.layout = const DCFLayout(padding: 8, height: 50, width: 200),
    this.styleSheet = const DCFStyleSheet(),
    this.onTap,
    this.onLongPress,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.events,
    this.adaptive = true,
    super.key,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    if (onTap != null) {
      eventMap['onTap'] = (Map<dynamic, dynamic> data) {
        onTap!(DCFGestureTapData.fromMap(data));
      };
    }

    if (onLongPress != null) {
      eventMap['onLongPress'] = (Map<dynamic, dynamic> data) {
        onLongPress!(DCFGestureLongPressData.fromMap(data));
      };
    }

    if (onSwipeLeft != null) {
      eventMap['onSwipeLeft'] = (Map<dynamic, dynamic> data) {
        onSwipeLeft!(DCFGestureSwipeData.fromMap(data));
      };
    }

    if (onSwipeRight != null) {
      eventMap['onSwipeRight'] = (Map<dynamic, dynamic> data) {
        onSwipeRight!(DCFGestureSwipeData.fromMap(data));
      };
    }

    if (onSwipeUp != null) {
      eventMap['onSwipeUp'] = (Map<dynamic, dynamic> data) {
        onSwipeUp!(DCFGestureSwipeData.fromMap(data));
      };
    }

    if (onSwipeDown != null) {
      eventMap['onSwipeDown'] = (Map<dynamic, dynamic> data) {
        onSwipeDown!(DCFGestureSwipeData.fromMap(data));
      };
    }

    if (onPanStart != null) {
      eventMap['onPanStart'] = (Map<dynamic, dynamic> data) {
        onPanStart!(DCFGesturePanData.fromMap(data));
      };
    }

    if (onPanUpdate != null) {
      eventMap['onPanUpdate'] = (Map<dynamic, dynamic> data) {
        onPanUpdate!(DCFGesturePanData.fromMap(data));
      };
    }

    if (onPanEnd != null) {
      eventMap['onPanEnd'] = (Map<dynamic, dynamic> data) {
        onPanEnd!(DCFGesturePanData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
      'adaptive': adaptive,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'GestureDetector',
      elementProps: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        children,
        layout,
        styleSheet,
        events,
        onTap,
        onLongPress,
        onSwipeLeft,
        onSwipeRight,
        onSwipeUp,
        onSwipeDown,
        onPanStart,
        onPanUpdate,
        onPanEnd,
        adaptive,
        key,
      ];
}

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
  
  /// X translation (delta from start)
  final double translationX;
  
  /// Y translation (delta from start)
  final double translationY;
  
  /// X velocity
  final double velocityX;
  
  /// Y velocity
  final double velocityY;
  
  /// Whether the pan was from user interaction
  final bool fromUser;
  
  /// Timestamp of the pan
  final DateTime timestamp;

  DCFGesturePanData({
    required this.x,
    required this.y,
    this.translationX = 0.0,
    this.translationY = 0.0,
    this.velocityX = 0.0,
    this.velocityY = 0.0,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGesturePanData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGesturePanData(
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      translationX: (data['translationX'] as num?)?.toDouble() ?? 0.0,
      translationY: (data['translationY'] as num?)?.toDouble() ?? 0.0,
      velocityX: (data['velocityX'] as num?)?.toDouble() ?? 0.0,
      velocityY: (data['velocityY'] as num?)?.toDouble() ?? 0.0,
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Gesture detector double tap callback data (same as tap)
/// Uses DCFGestureTapData

/// Gesture detector pinch callback data
class DCFGesturePinchData {
  /// X coordinate of the pinch center
  final double x;
  
  /// Y coordinate of the pinch center
  final double y;
  
  /// Scale factor (1.0 = no change, >1.0 = zoom in, <1.0 = zoom out)
  final double scale;
  
  /// Velocity of the pinch (scale per second)
  final double velocity;
  
  /// Whether the pinch was from user interaction
  final bool fromUser;
  
  /// Timestamp of the pinch
  final DateTime timestamp;

  DCFGesturePinchData({
    required this.x,
    required this.y,
    required this.scale,
    this.velocity = 0.0,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGesturePinchData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGesturePinchData(
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      scale: (data['scale'] as num).toDouble(),
      velocity: (data['velocity'] as num?)?.toDouble() ?? 0.0,
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Gesture detector rotation callback data
class DCFGestureRotationData {
  /// X coordinate of the rotation center
  final double x;
  
  /// Y coordinate of the rotation center
  final double y;
  
  /// Rotation angle in radians
  final double rotation;
  
  /// Rotation velocity (radians per second)
  final double velocity;
  
  /// Whether the rotation was from user interaction
  final bool fromUser;
  
  /// Timestamp of the rotation
  final DateTime timestamp;

  DCFGestureRotationData({
    required this.x,
    required this.y,
    required this.rotation,
    this.velocity = 0.0,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGestureRotationData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGestureRotationData(
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      rotation: (data['rotation'] as num).toDouble(),
      velocity: (data['velocity'] as num?)?.toDouble() ?? 0.0,
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Gesture detector hover callback data (for mouse/trackpad)
class DCFGestureHoverData {
  /// X coordinate of the hover
  final double x;
  
  /// Y coordinate of the hover
  final double y;
  
  /// Whether the hover was from user interaction
  final bool fromUser;
  
  /// Timestamp of the hover
  final DateTime timestamp;

  DCFGestureHoverData({
    required this.x,
    required this.y,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFGestureHoverData.fromMap(Map<dynamic, dynamic> data) {
    return DCFGestureHoverData(
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
  
  /// Double tap event handler - receives type-safe gesture data
  final Function(DCFGestureTapData)? onDoubleTap;
  
  /// Pinch start event handler - receives type-safe gesture data
  final Function(DCFGesturePinchData)? onPinchStart;
  
  /// Pinch update event handler - receives type-safe gesture data
  final Function(DCFGesturePinchData)? onPinchUpdate;
  
  /// Pinch end event handler - receives type-safe gesture data
  final Function(DCFGesturePinchData)? onPinchEnd;
  
  /// Rotation start event handler - receives type-safe gesture data
  final Function(DCFGestureRotationData)? onRotationStart;
  
  /// Rotation update event handler - receives type-safe gesture data
  final Function(DCFGestureRotationData)? onRotationUpdate;
  
  /// Rotation end event handler - receives type-safe gesture data
  final Function(DCFGestureRotationData)? onRotationEnd;
  
  /// Hover event handler - receives type-safe gesture data (desktop/web)
  final Function(DCFGestureHoverData)? onHover;


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
    this.onDoubleTap,
    this.onPinchStart,
    this.onPinchUpdate,
    this.onPinchEnd,
    this.onRotationStart,
    this.onRotationUpdate,
    this.onRotationEnd,
    this.onHover,
    this.events,
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
    
    if (onDoubleTap != null) {
      eventMap['onDoubleTap'] = (Map<dynamic, dynamic> data) {
        onDoubleTap!(DCFGestureTapData.fromMap(data));
      };
    }
    
    if (onPinchStart != null) {
      eventMap['onPinchStart'] = (Map<dynamic, dynamic> data) {
        onPinchStart!(DCFGesturePinchData.fromMap(data));
      };
    }
    
    if (onPinchUpdate != null) {
      eventMap['onPinchUpdate'] = (Map<dynamic, dynamic> data) {
        onPinchUpdate!(DCFGesturePinchData.fromMap(data));
      };
    }
    
    if (onPinchEnd != null) {
      eventMap['onPinchEnd'] = (Map<dynamic, dynamic> data) {
        onPinchEnd!(DCFGesturePinchData.fromMap(data));
      };
    }
    
    if (onRotationStart != null) {
      eventMap['onRotationStart'] = (Map<dynamic, dynamic> data) {
        onRotationStart!(DCFGestureRotationData.fromMap(data));
      };
    }
    
    if (onRotationUpdate != null) {
      eventMap['onRotationUpdate'] = (Map<dynamic, dynamic> data) {
        onRotationUpdate!(DCFGestureRotationData.fromMap(data));
      };
    }
    
    if (onRotationEnd != null) {
      eventMap['onRotationEnd'] = (Map<dynamic, dynamic> data) {
        onRotationEnd!(DCFGestureRotationData.fromMap(data));
      };
    }
    
    if (onHover != null) {
      eventMap['onHover'] = (Map<dynamic, dynamic> data) {
        onHover!(DCFGestureHoverData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
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
}

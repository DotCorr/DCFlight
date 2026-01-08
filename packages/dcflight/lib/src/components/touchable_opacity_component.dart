/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Touchable opacity press callback data
class DCFTouchableOpacityPressData {
  /// Whether the press was from user interaction
  final bool fromUser;
  
  /// Timestamp of the press
  final DateTime timestamp;

  DCFTouchableOpacityPressData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTouchableOpacityPressData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTouchableOpacityPressData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Touchable opacity press in callback data
class DCFTouchableOpacityPressInData {
  /// Whether the press in was from user interaction
  final bool fromUser;
  
  /// Timestamp of the press in
  final DateTime timestamp;

  DCFTouchableOpacityPressInData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTouchableOpacityPressInData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTouchableOpacityPressInData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Touchable opacity press out callback data
class DCFTouchableOpacityPressOutData {
  /// Whether the press out was from user interaction
  final bool fromUser;
  
  /// Timestamp of the press out
  final DateTime timestamp;

  DCFTouchableOpacityPressOutData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTouchableOpacityPressOutData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTouchableOpacityPressOutData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Touchable opacity long press callback data
class DCFTouchableOpacityLongPressData {
  /// Whether the long press was from user interaction
  final bool fromUser;
  
  /// Timestamp of the long press
  final DateTime timestamp;

  DCFTouchableOpacityLongPressData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFTouchableOpacityLongPressData.fromMap(Map<dynamic, dynamic> data) {
    return DCFTouchableOpacityLongPressData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// A touchable opacity component implementation using StatelessComponent
class DCFTouchableOpacity extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// Opacity when pressed
  final double activeOpacity;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Press event handler - receives type-safe press data
  final Function(DCFTouchableOpacityPressData)? onPress;

  /// Press in event handler - receives type-safe press in data
  final Function(DCFTouchableOpacityPressInData)? onPressIn;

  /// Press out event handler - receives type-safe press out data
  final Function(DCFTouchableOpacityPressOutData)? onPressOut;

  /// Long press event handler - receives type-safe long press data
  final Function(DCFTouchableOpacityLongPressData)? onLongPress;

  /// Long press delay in milliseconds
  final int longPressDelay;

  /// Whether the component is disabled
  final bool disabled;

  /// Event handlers
  final Map<String, dynamic>? events;


  /// Create a touchable opacity component
  DCFTouchableOpacity({
    required this.children,
    this.activeOpacity = 0.2,
    this.layout = const DCFLayout(padding: 8, height: 50, width: 200),
    this.styleSheet = const DCFStyleSheet(),
    this.onPress,
    this.onPressIn,
    this.onPressOut,
    this.onLongPress,
    this.longPressDelay = 500,
    this.disabled = false,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    if (onPress != null) {
      eventMap['onPress'] = (Map<dynamic, dynamic> data) {
        onPress!(DCFTouchableOpacityPressData.fromMap(data));
      };
    }

    if (onPressIn != null) {
      eventMap['onPressIn'] = (Map<dynamic, dynamic> data) {
        onPressIn!(DCFTouchableOpacityPressInData.fromMap(data));
      };
    }

    if (onPressOut != null) {
      eventMap['onPressOut'] = (Map<dynamic, dynamic> data) {
        onPressOut!(DCFTouchableOpacityPressOutData.fromMap(data));
      };
    }

    if (onLongPress != null) {
      eventMap['onLongPress'] = (Map<dynamic, dynamic> data) {
        onLongPress!(DCFTouchableOpacityLongPressData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
      'activeOpacity': activeOpacity,
      'disabled': disabled,
      'longPressDelay': longPressDelay,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'TouchableOpacity',
      elementProps: props,
      children: children,
    );
  }
}


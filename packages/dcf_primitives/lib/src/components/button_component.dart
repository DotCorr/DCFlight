/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Button press callback data
class DCFButtonPressData {
  /// Whether the press was from user interaction
  final bool fromUser;
  
  /// Timestamp of the press
  final DateTime timestamp;

  DCFButtonPressData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFButtonPressData.fromMap(Map<dynamic, dynamic> data) {
    return DCFButtonPressData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
}

/// Button long press callback data
class DCFButtonLongPressData {
  /// Whether the long press was from user interaction
  final bool fromUser;
  
  /// Timestamp of the long press
  final DateTime timestamp;

  DCFButtonLongPressData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFButtonLongPressData.fromMap(Map<dynamic, dynamic> data) {
    return DCFButtonLongPressData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
}

/// Button properties
class DCFButtonProps extends Equatable implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// The title text of the button
  final String title;

  /// Disabled state
  final bool disabled;

  /// Whether to use adaptive theming
  final bool adaptive;

  /// Create button props
  const DCFButtonProps({
    required this.title,
    this.disabled = false,
    this.adaptive = true,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'disabled': disabled,
      'adaptive': adaptive,
    };
  }

  @override
  List<Object?> get props => [title, disabled, adaptive];
}

/// A button component implementation using StatelessComponent
class DCFButton extends DCFStatelessComponent with EquatableMixin {
  /// The button properties
  final DCFButtonProps buttonProps;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Press event handler - receives type-safe press data
  final Function(DCFButtonPressData)? onPress;

  /// Long press event handler - receives type-safe long press data
  final Function(DCFButtonLongPressData)? onLongPress;

  /// Create a button component
  DCFButton({
    required this.buttonProps,
    this.layout = const DCFLayout( width: 200,alignItems: YogaAlign.center,justifyContent: YogaJustifyContent.center),
    this.styleSheet = const DCFStyleSheet(),
    this.onPress,
    this.onLongPress,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Create an events map for the onPress handler
    Map<String, dynamic> eventMap = events ?? {};

    if (onPress != null) {
      eventMap['onPress'] = (Map<dynamic, dynamic> data) {
        onPress!(DCFButtonPressData.fromMap(data));
      };
    }

    if (onLongPress != null) {
      eventMap['onLongPress'] = (Map<dynamic, dynamic> data) {
        onLongPress!(DCFButtonLongPressData.fromMap(data));
      };
    }

    // Serialize command if provided
    Map<String, dynamic> props = {
      ...buttonProps.toMap(),
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'Button',
      elementProps: props,
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        buttonProps,
        layout,
        styleSheet,
        onPress,
        onLongPress,
        events,
        key,
      ];
}

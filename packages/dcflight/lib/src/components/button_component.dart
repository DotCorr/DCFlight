/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/src/components/touchable_opacity_component.dart';

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

/// Button style enum - determines the underlying primitive behavior
enum DCFButtonStyle {
  /// Uses TouchableOpacity with opacity feedback
  touchableOpacity,
  
  /// Uses Pressable with press feedback (if available, falls back to touchableOpacity)
  pressable,
  
  /// No visual feedback, just gesture detection
  none,
}

/// Button properties
class DCFButtonProps implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Disabled state
  final bool disabled;

  /// Button style - determines underlying primitive behavior
  final DCFButtonStyle buttonStyle;

  /// Active opacity for touchableOpacity style (0.0 to 1.0)
  final double activeOpacity;

  /// Long press delay in milliseconds
  final int longPressDelay;

  /// Create button props
  const DCFButtonProps({
    this.disabled = false,
    this.buttonStyle = DCFButtonStyle.touchableOpacity,
    this.activeOpacity = 0.2,
    this.longPressDelay = 500,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'disabled': disabled,
      'buttonStyle': buttonStyle.name,
      'activeOpacity': activeOpacity,
      'longPressDelay': longPressDelay,
    };
  }
}

/// A button component implementation using TouchableOpacity as the underlying primitive
/// Button now accepts children instead of title, giving users full control over button content
class DCFButton extends DCFStatelessComponent {
  /// The button properties
  final DCFButtonProps? buttonProps;

  /// Child nodes - Button now accepts children instead of title
  final List<DCFComponentNode> children;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Explicit color override: textColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for button text
  final Color? textColor;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Press event handler - receives type-safe press data
  final Function(DCFButtonPressData)? onPress;

  /// Long press event handler - receives type-safe long press data
  final Function(DCFButtonLongPressData)? onLongPress;

  /// Create a button component
  DCFButton({
    this.buttonProps,
    this.children = const [],
    this.layout = const DCFLayout(
      width: "100%", 
      padding: 0,
      margin: 0,
      alignItems: DCFAlign.center, 
      justifyContent: DCFJustifyContent.center, 
      height: 45,
    ),
    this.styleSheet = const DCFStyleSheet(backgroundColor: DCFColors.blueAccent, borderRadius: 10),
    this.textColor,
    this.onPress,
    this.onLongPress,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    // Map button events to touchable opacity events
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

    final buttonStyle = buttonProps?.buttonStyle ?? DCFButtonStyle.touchableOpacity;
    final activeOpacity = buttonProps?.activeOpacity ?? 0.2;
    final longPressDelay = buttonProps?.longPressDelay ?? 500;
    final disabled = buttonProps?.disabled ?? false;

    // Merge default Button layout with user-provided layout
    final defaultButtonLayout = const DCFLayout(
      width: "100%", 
      padding: 0,
      margin: 0,
      alignItems: DCFAlign.center, 
      justifyContent: DCFJustifyContent.center, 
      height: 45,
    );
    final mergedLayout = defaultButtonLayout.merge(layout);

    // Based on buttonStyle, choose the underlying primitive
    // For now, we use TouchableOpacity for all styles (pressable and none can be added later)
    // Users can opt out and use raw TouchableOpacity/GestureDetector if they need more control
    switch (buttonStyle) {
      case DCFButtonStyle.touchableOpacity:
      case DCFButtonStyle.pressable:
      case DCFButtonStyle.none:
        // All styles use TouchableOpacity as the underlying primitive
        // The buttonStyle is passed through for potential future use
        return DCFTouchableOpacity(
          children: children,
          activeOpacity: buttonStyle == DCFButtonStyle.none ? 1.0 : activeOpacity,
          disabled: disabled,
          longPressDelay: longPressDelay,
          layout: mergedLayout,
          styleSheet: styleSheet,
          onPress: onPress != null
              ? (DCFTouchableOpacityPressData data) {
                  onPress!(DCFButtonPressData(
                    fromUser: data.fromUser,
                    timestamp: data.timestamp,
                  ));
                }
              : null,
          onLongPress: onLongPress != null
              ? (DCFTouchableOpacityLongPressData data) {
                  onLongPress!(DCFButtonLongPressData(
                    fromUser: data.fromUser,
                    timestamp: data.timestamp,
                  ));
                }
              : null,
          events: eventMap,
        ).render();
    }
  }
}


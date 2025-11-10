/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Toggle value change callback data
class DCFToggleValueData {
  /// Current toggle value
  final bool value;
  
  /// Whether the change was from user interaction
  final bool fromUser;
  
  /// Timestamp of the change
  final DateTime timestamp;

  DCFToggleValueData({
    required this.value,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFToggleValueData.fromMap(Map<dynamic, dynamic> data) {
    return DCFToggleValueData(
      value: data['value'] as bool,
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// 🚀 DCF Toggle Component (Switch)
///
/// A toggle/switch component that provides native platform behavior.
class DCFToggle extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Current value of the toggle
  final bool value;

  /// Called when toggle value changes
  final Function(DCFToggleValueData)? onValueChange;

  /// Whether the toggle is disabled
  final bool disabled;

  /// Explicit color override: activeColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for active track/thumb
  final Color? activeColor;

  /// Explicit color override: inactiveColor (overrides StyleSheet.secondaryColor)
  /// If provided, this will override the semantic secondaryColor for inactive track
  final Color? inactiveColor;

  /// Size of the toggle
  final String size;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  DCFToggle({
    super.key,
    required this.value,
    this.onValueChange,
    this.disabled = false,
    this.activeColor,
    this.inactiveColor,
    this.size = 'medium',
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(backgroundColor: DCFColors.transparent),
    this.events,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    if (onValueChange != null) {
      eventMap['onValueChange'] = (Map<dynamic, dynamic> data) {
        onValueChange!(DCFToggleValueData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
      'value': value,
      'disabled': disabled,
      'size': size,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      if (activeColor != null) 'activeColor': DCFColors.toNativeString(activeColor!),
      if (inactiveColor != null) 'inactiveColor': DCFColors.toNativeString(inactiveColor!),
      ...eventMap,
    };

    return DCFElement(
      type: 'Toggle',
      elementProps: props,
      children: [],
    );
  }
}

/// Toggle size constants
class DCFToggleSize {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Checkbox value change callback data
class DCFCheckboxValueData {
  /// Current checkbox value
  final bool value;
  
  /// Whether the change was from user interaction
  final bool fromUser;
  
  /// Timestamp of the change
  final DateTime timestamp;

  DCFCheckboxValueData({
    required this.value,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFCheckboxValueData.fromMap(Map<dynamic, dynamic> data) {
    return DCFCheckboxValueData(
      value: data['value'] as bool,
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// 🚀 DCF Checkbox Component
///
/// A checkbox component that provides native platform behavior.
class DCFCheckbox extends DCFStatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Current checked state of the checkbox
  final bool checked;

  /// Called when checkbox state changes
  final Function(DCFCheckboxValueData)? onValueChange;

  /// Whether the checkbox is disabled
  final bool disabled;


  /// NOTE: All colors removed - use StyleSheet semantic colors:
  /// - primaryColor: active/checked color and checkmark color
  /// - secondaryColor: inactive/unchecked color

  /// Size of the checkbox
  final String size;

  /// Style preset for the checkbox (renamed from style to avoid conflict with StyleSheet)
  final String checkboxStyle;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  DCFCheckbox({
    super.key,
    required this.checked,
    this.onValueChange,
    this.disabled = false,
    // All color props removed - use StyleSheet semantic colors
    this.size = 'medium',
    this.checkboxStyle = 'default',
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(
        borderWidth: 2, borderColor: Colors.grey, borderRadius: 8),
    this.events,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    if (onValueChange != null) {
      eventMap['onValueChange'] = (Map<dynamic, dynamic> data) {
        onValueChange!(DCFCheckboxValueData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
      'checked': checked,
      'disabled': disabled,
      'size': size,
      'checkboxStyle': checkboxStyle,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    // All color props removed - native components use StyleSheet semantic colors

    return DCFElement(
      type: 'Checkbox',
      elementProps: props,
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        checked,
        onValueChange,
        disabled,
        // All color props removed
        size,
        checkboxStyle,
        layout,
        styleSheet,
        events,
        key,
      ];
}

/// Checkbox size constants
class DCFCheckboxSize {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
}

/// Checkbox style presets
class DCFCheckboxStyle {
  static const String defaultStyle = 'default';
  static const String material = 'material';
  static const String cupertino = 'cupertino';
  static const String custom = 'custom';
}

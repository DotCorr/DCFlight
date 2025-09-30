/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// 🚀 DCF Toggle Component (Switch)
///
/// A toggle/switch component that provides native platform behavior.
/// Supports custom styling, sizes, and colors with adaptive theming.
class DCFToggle extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Current value of the toggle
  final bool value;

  /// Called when toggle value changes
  final Function(Map<dynamic, dynamic>)? onValueChange;

  /// Whether the toggle is disabled
  final bool disabled;

  /// Whether to use adaptive theming (system colors)
  final bool adaptive;

  /// Track color when toggle is on
  final Color? activeTrackColor;

  /// Track color when toggle is off
  final Color? inactiveTrackColor;

  /// Thumb color when toggle is on
  final Color? activeThumbColor;

  /// Thumb color when toggle is off
  final Color? inactiveThumbColor;

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
    this.adaptive = true,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.activeThumbColor,
    this.inactiveThumbColor,
    this.size = 'medium',
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(backgroundColor: Colors.transparent),
    this.events,
  });

  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};

    if (onValueChange != null) {
      eventMap['onValueChange'] = onValueChange;
    }

    Map<String, dynamic> props = {
      'value': value,
      'disabled': disabled,
      'adaptive': adaptive,
      'size': size,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    // Add color properties if provided
    if (activeTrackColor != null) {
      props['activeTrackColor'] =
          '#${activeTrackColor!.value.toRadixString(16).padLeft(8, '0')}';
    }

    if (inactiveTrackColor != null) {
      props['inactiveTrackColor'] =
          '#${inactiveTrackColor!.value.toRadixString(16).padLeft(8, '0')}';
    }

    if (activeThumbColor != null) {
      props['activeThumbColor'] =
          '#${activeThumbColor!.value.toRadixString(16).padLeft(8, '0')}';
    }

    if (inactiveThumbColor != null) {
      props['inactiveThumbColor'] =
          '#${inactiveThumbColor!.value.toRadixString(16).padLeft(8, '0')}';
    }

    return DCFElement(
      type: 'Toggle',
      elementProps: props,
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        value,
        disabled,
        adaptive,
        activeTrackColor,
        inactiveTrackColor,
        activeThumbColor,
        inactiveThumbColor,
        size,
        layout,
        styleSheet,
        events,
      ];
}

/// Toggle size constants
class DCFToggleSize {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/renderer/vdom/core/concurrency/schedule.dart';

/// A touchable opacity component implementation using StatelessComponent
class DCFTouchableOpacity extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// Opacity when pressed
  final double activeOpacity;

  /// The layout properties
  final LayoutProps layout;

  /// The style properties
  final StyleSheet styleSheet;

  /// Press event handler - receives Map<dynamic, dynamic> with press data
  final Function(Map<dynamic, dynamic>)? onPress;

  /// Press in event handler - receives Map<dynamic, dynamic>
  final Function(Map<dynamic, dynamic>)? onPressIn;

  /// Press out event handler - receives Map<dynamic, dynamic>
  final Function(Map<dynamic, dynamic>)? onPressOut;

  /// Long press event handler - receives Map<dynamic, dynamic>
  final Function(Map<dynamic, dynamic>)? onLongPress;

  /// Long press delay in milliseconds
  final int longPressDelay;

  /// Whether the component is disabled
  final bool disabled;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Whether to use adaptive theming
  final bool adaptive;

  /// Create a touchable opacity component
  DCFTouchableOpacity({
    required this.children,
    this.activeOpacity = 0.2,
    this.layout = const LayoutProps(padding: 8, height: 50, width: 200),
    this.styleSheet = const StyleSheet(),
    this.onPress,
    this.onPressIn,
    this.onPressOut,
    this.onLongPress,
    this.longPressDelay = 500,
    this.disabled = false,
    this.events,
    this.adaptive = true,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};

    if (onPress != null) {
      eventMap['onPress'] = onPress;
    }

    if (onPressIn != null) {
      eventMap['onPressIn'] = onPressIn;
    }

    if (onPressOut != null) {
      eventMap['onPressOut'] = onPressOut;
    }

    if (onLongPress != null) {
      eventMap['onLongPress'] = onLongPress;
    }

    // Serialize command if provided
    Map<String, dynamic> props = {
      'activeOpacity': activeOpacity,
      'disabled': disabled,
      'longPressDelay': longPressDelay,
      'adaptive': adaptive,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'TouchableOpacity',
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        children,
        activeOpacity,
        layout,
        styleSheet,
        onPress,
        onPressIn,
        onPressOut,
        onLongPress,
        longPressDelay,
        disabled,
        events,
        adaptive,
        key,
      ];
}

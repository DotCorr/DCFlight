/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// A basic view component implementation using StatelessComponent
class DCFView extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// The layout properties
  final LayoutProps layout;

  /// The style properties
  final StyleSheet styleSheet;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Whether to use adaptive theming
  final bool adaptive;

  /// Layout event handler
  final Function(Map<dynamic, dynamic>)? onLayout;

  /// Create a view component
  DCFView({
    this.layout = const LayoutProps(height: "100%", width: "100%" ),
    this.styleSheet = const StyleSheet(),
    this.children = const [],
    this.events,
    this.adaptive = true,
    this.onLayout,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final eventMap = events ?? <String, dynamic>{};
    if (onLayout != null) {
      eventMap['onLayout'] = onLayout;
    }

    return DCFElement(
      type: 'View',
      elementProps: {
        ...layout.toMap(),
        ...styleSheet.toMap(),
        'adaptive': adaptive,
        ...eventMap,
      },
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        layout,
        styleSheet,
        children,
        events,
        adaptive,
        onLayout,
        key,
      ];
}


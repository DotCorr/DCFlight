/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import 'package:dcflight/dcflight.dart';

/// A basic view component implementation using StatelessComponent
class DCFView extends StatelessComponent {
  /// The layout properties
  final LayoutProps layout;

  /// The style properties
  final StyleSheet style;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Create a view component
  DCFView({
    this.layout = const LayoutProps(),
    this.style = const StyleSheet(),
    this.children = const [],
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'View',
      props: {
        ...layout.toMap(),
        ...style.toMap(),
        ...(events ?? {}),
      },
      children: children,
    );
  }
}

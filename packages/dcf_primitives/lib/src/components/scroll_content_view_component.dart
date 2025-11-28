/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// DCFScrollContentView - Content view wrapper for ScrollView children
/// This component wraps the children of a ScrollView and is laid out by Yoga
/// (Matches React Native's ScrollContentView pattern)
class DCFScrollContentView extends DCFStatelessComponent {
  /// Child nodes
  final List<DCFComponentNode> children;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  DCFScrollContentView({
    required this.children,
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    super.key,
  });

  @override
  DCFComponentNode render() {
    final props = <String, dynamic>{
      ...layout.toMap(),
      ...styleSheet.toMap(),
    };

    return DCFElement(
      type: 'ScrollContentView', // Registered component name
      elementProps: props,
      children: children,
    );
  }
}


/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';
import 'package:meta/meta.dart';

/// DCFScrollContentView - Content view wrapper for ScrollView children
/// 
/// **INTERNAL USE ONLY** - Users should NOT use this component directly.
/// DCFScrollView automatically wraps children in ScrollContentView behind the scenes.
/// 
/// This component wraps the children of a ScrollView and is laid out by Yoga.
/// It matches React Native's ScrollContentView pattern.
@internal
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


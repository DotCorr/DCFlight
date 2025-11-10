/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// View layout callback data
class DCFViewLayoutData {
  /// Width of the view
  final double width;
  
  /// Height of the view
  final double height;
  
  /// X position of the view
  final double x;
  
  /// Y position of the view
  final double y;
  
  /// Timestamp of the layout event
  final DateTime timestamp;

  DCFViewLayoutData({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFViewLayoutData.fromMap(Map<dynamic, dynamic> data) {
    return DCFViewLayoutData(
      width: (data['width'] as num).toDouble(),
      height: (data['height'] as num).toDouble(),
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// A basic view component implementation using StatelessComponent
class DCFView extends DCFStatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Layout event handler
  final Function(DCFViewLayoutData)? onLayout;

  /// Create a view component
  DCFView({
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(backgroundColor: DCFColors.transparent),
    this.children = const [],
    this.events,
    this.onLayout,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final eventMap = events ?? <String, dynamic>{};
    if (onLayout != null) {
      eventMap['onLayout'] = (Map<dynamic, dynamic> data) {
        onLayout!(DCFViewLayoutData.fromMap(data));
      };
    }

    return DCFElement(
      type: 'View',
      elementProps: {
        ...layout.toMap(),
        ...styleSheet.toMap(),
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
        onLayout,
        key,
      ];
}

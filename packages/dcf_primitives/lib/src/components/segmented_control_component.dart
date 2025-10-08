/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Segmented control selection change callback data
class DCFSegmentedControlSelectionData {
  /// Selected segment index
  final int selectedIndex;
  
  /// Selected segment value
  final String selectedValue;
  
  /// Whether the selection was from user interaction
  final bool fromUser;
  
  /// Timestamp of the selection change
  final DateTime timestamp;

  DCFSegmentedControlSelectionData({
    required this.selectedIndex,
    required this.selectedValue,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFSegmentedControlSelectionData.fromMap(Map<dynamic, dynamic> data) {
    return DCFSegmentedControlSelectionData(
      selectedIndex: data['selectedIndex'] as int,
      selectedValue: data['selectedValue'] as String,
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Segmented control item configuration
class DCFSegmentItem extends Equatable {
  /// The title text for the segment
  final String title;

  /// Optional icon asset path
  final String? iconAsset;

  /// Whether this segment is enabled
  final bool enabled;

  const DCFSegmentItem({
    required this.title,
    this.iconAsset,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      if (iconAsset != null) 'iconAsset': iconAsset,
      'enabled': enabled,
    };
  }

  @override
  List<Object?> get props => [title, iconAsset, enabled];
}

/// Segmented control properties
class DCFSegmentedControlProps extends Equatable {
  /// The list of segment items (type-safe)
  final List<DCFSegmentItem> segments;

  /// The currently selected segment index
  final int selectedIndex;

  /// Whether the segmented control is enabled
  final bool enabled;

  /// Whether to use adaptive theming (system colors)
  final bool adaptive;

  /// Background color of the segmented control
  final String? backgroundColor;

  /// Color of the selected segment (iOS 13+)
  final String? selectedTintColor;

  /// Tint color (affects text color of selected segment)
  final String? tintColor;

  /// Create segmented control props
  const DCFSegmentedControlProps({
    this.segments = const [DCFSegmentItem(title: 'Segment 1')],
    this.selectedIndex = 0,
    this.enabled = true,
    this.adaptive = true,
    this.backgroundColor,
    this.selectedTintColor,
    this.tintColor,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'segments': segments.map((item) => item.toMap()).toList(),
      'selectedIndex': selectedIndex,
      'enabled': enabled,
      'adaptive': adaptive,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (selectedTintColor != null) 'selectedTintColor': selectedTintColor,
      if (tintColor != null) 'tintColor': tintColor,
    };
  }

  @override
  List<Object?> get props => [
        segments,
        selectedIndex,
        enabled,
        adaptive,
        backgroundColor,
        selectedTintColor,
        tintColor,
      ];
}

/// A segmented control component implementation using StatelessComponent
class DCFSegmentedControl extends DCFStatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// The segmented control properties
  final DCFSegmentedControlProps segmentedControlProps;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Selection change event handler - receives type-safe selection data
  final Function(DCFSegmentedControlSelectionData)? onSelectionChange;

  /// Create a segmented control component
  DCFSegmentedControl({
    required this.segmentedControlProps,
    this.layout = const DCFLayout(
      height: 32,
      width: 200,
    ),
    this.styleSheet = const DCFStyleSheet(),
    this.onSelectionChange,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    Map<dynamic, dynamic> eventMap = events ?? {};

    if (onSelectionChange != null) {
      eventMap['onSelectionChange'] = (Map<dynamic, dynamic> data) {
        onSelectionChange!(DCFSegmentedControlSelectionData.fromMap(data));
      };
    }

    return DCFElement(
      type: 'SegmentedControl',
      elementProps: {
        ...segmentedControlProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        segmentedControlProps,
        layout,
        styleSheet,
        events,
        onSelectionChange,
        key,
      ];
}

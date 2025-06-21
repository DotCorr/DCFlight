/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Segmented control properties
class DCFSegmentedControlProps {
  /// The list of segment titles
  final List<String> segments;
  
  /// The list of icon assets for each segment (optional)
  /// If provided, icons will be displayed instead of or alongside text
  final List<String>? iconAssets;
  
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
    this.segments = const ['Segment 1'],
    this.iconAssets,
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
      'segments': segments,
      if (iconAssets != null) 'iconAssets': iconAssets,
      'selectedIndex': selectedIndex,
      'enabled': enabled,
      'adaptive': adaptive,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (selectedTintColor != null) 'selectedTintColor': selectedTintColor,
      if (tintColor != null) 'tintColor': tintColor,
    };
  }
}

/// A segmented control component implementation using StatelessComponent
class DCFSegmentedControl extends StatelessComponent {
  /// The segmented control properties
  final DCFSegmentedControlProps segmentedControlProps;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;
  
  /// Selection change event handler - receives Map<dynamic, dynamic> with selection data
  final Function(Map<dynamic, dynamic>)? onSelectionChange;
  
  /// Create a segmented control component
  DCFSegmentedControl({
    required this.segmentedControlProps,
    this.layout = const LayoutProps(
      height: 32,
      width: 200,
    ),
    this.styleSheet = const StyleSheet(),
    this.onSelectionChange,
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Create an events map for the onSelectionChange handler
    Map<String, dynamic> eventMap = events ?? {};
    
    if (onSelectionChange != null) {
      eventMap['onSelectionChange'] = onSelectionChange;
    }
    
    return DCFElement(
      type: 'SegmentedControl',
      props: {
        ...segmentedControlProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: [],
    );
  }
}

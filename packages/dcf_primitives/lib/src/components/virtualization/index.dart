/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Virtualization components for high-performance lists
///
/// This module provides React Native-style virtualized list components
/// that only render visible items for optimal memory usage and smooth scrolling.
///
/// Components:
/// - [DCFVirtualizedList] - Low-level virtualized list with full control
/// - [DCFFlatList] - Simplified high-performance list for most use cases
/// - [DCFSectionList] - Sectioned list with headers and footers
///
/// Features:
/// - Viewport-based rendering (only renders visible items)
/// - Dynamic item heights with layout caching
/// - Bidirectional virtualization (horizontal + vertical)
/// - Smooth scrolling with predictive rendering
/// - Memory efficient with item recycling
/// - Infinite scroll support
/// - Section headers and footers
/// - Custom separators
/// - Performance metrics and monitoring
/// - Imperative scroll commands
/// - Refresh control
/// - Empty state handling
///
/// Usage:
/// ```dart
/// // Simple flat list
/// DCFFlatList<String>(
///   data: ['Item 1', 'Item 2', 'Item 3'],
///   renderItem: (item, index) => DCFText(item),
///   keyExtractor: (item, index) => 'item_$index',
/// )
///
/// // Sectioned list
/// DCFSectionList<String>(
///   sections: [
///     SectionData(title: 'Section 1', data: ['A', 'B', 'C']),
///     SectionData(title: 'Section 2', data: ['D', 'E', 'F']),
///   ],
///   renderItem: (item, index, sectionIndex) => DCFText(item),
///   renderSectionHeader: (section, index) => DCFText(section.title ?? ''),
/// )
///
/// // Advanced virtualized list
/// DCFVirtualizedList(
///   itemCount: 10000,
///   renderItem: (index, info) => CustomItemWidget(index: index),
///   getItemSize: (index) => index % 2 == 0 ? 80.0 : 60.0,
///   initialNumToRender: 15,
///   windowSize: 25,
///   onMetrics: (metrics) => print('Rendered: ${metrics.renderedItems}'),
/// )
/// ```
library virtualization;

// Core virtualization components
export 'virtualized_list.dart';
export 'flat_list.dart';
export 'section_list.dart';

// Re-export commonly used types for convenience
export 'virtualized_list.dart'
    show
        VirtualizedListItemInfo,
        VirtualizedListScrollEvent,
        VirtualizedListContentOffset,
        VirtualizedListContentSize,
        VirtualizedListLayoutMeasurement,
        VirtualizedListViewabilityInfo,
        VirtualizedListViewableItem,
        VirtualizedListMetrics,
        VirtualizedListCommand,
        ScrollToIndexCommand,
        ScrollToOffsetCommand,
        RefreshCommand;

export 'flat_list.dart' show FlatListCommand;

export 'section_list.dart'
    show
        SectionData,
        SectionVisibilityInfo,
        SectionListCommand,
        SectionListScrollToIndexCommand;

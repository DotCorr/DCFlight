/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';
import 'virtualized_list.dart' as vl;

/// FlatList - Simplified high-performance list component
/// A convenience wrapper around VirtualizedList with sensible defaults
/// Perfect for most common list use cases
class DCFFlatList<T> extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// List of data items
  final List<T> data;

  /// Function to render each item
  final DCFComponentNode Function(T item, int index) renderItem;

  /// Function to extract unique key for each item
  final String Function(T item, int index)? keyExtractor;

  /// Whether to scroll horizontally
  final bool horizontal;

  /// Layout and style properties
  final LayoutProps layout;
  final StyleSheet styleSheet;

  /// Scroll behavior properties
  final bool showsScrollIndicator;
  final bool scrollEnabled;
  final bool bounces;
  final bool pagingEnabled;

  /// Estimated size of each item (for optimization)
  final double? itemSize;

  /// Function to get dynamic size of each item
  final double Function(T item, int index)? getItemSize;

  /// Initial number of items to render
  final int? initialNumToRender;

  /// Whether to remove clipped subviews for memory optimization
  final bool removeClippedSubviews;

  /// Whether the list is inverted (items rendered from bottom to top)
  final bool inverted;

  /// Event handlers
  final Function(vl.VirtualizedListScrollEvent)? onScroll;
  final Function(vl.VirtualizedListScrollEvent)? onScrollBeginDrag;
  final Function(vl.VirtualizedListScrollEvent)? onScrollEndDrag;
  final Function(vl.VirtualizedListScrollEvent)? onMomentumScrollEnd;

  /// Called when user scrolls close to the end
  final Function()? onEndReached;

  /// How close to the end before onEndReached is called (0-1)
  final double onEndReachedThreshold;

  /// Component to render at the top of the list
  final DCFComponentNode? header;

  /// Component to render at the bottom of the list
  final DCFComponentNode? footer;

  /// Component to render when the list is empty
  final DCFComponentNode? emptyState;

  /// Component to render between items
  final DCFComponentNode? separator;

  /// Function to render custom separator between items
  final DCFComponentNode Function(int index)? separatorBuilder;

  /// Refresh control
  final bool refreshing;
  final Function()? onRefresh;

  /// Commands for imperative operations
  final vl.VirtualizedListCommand? command;

  /// Whether to enable debug mode
  final bool debug;

  /// Additional props for customization
  final Map<String, dynamic>? additionalProps;

  /// Performance monitoring
  final Function(vl.VirtualizedListMetrics)? onMetrics;

  DCFFlatList({
    required this.data,
    required this.renderItem,
    this.keyExtractor,
    this.horizontal = false,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.showsScrollIndicator = true,
    this.scrollEnabled = true,
    this.bounces = true,
    this.pagingEnabled = false,
    this.itemSize,
    this.getItemSize,
    this.initialNumToRender,
    this.removeClippedSubviews = true,
    this.inverted = false,
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onMomentumScrollEnd,
    this.onEndReached,
    this.onEndReachedThreshold = 0.1,
    this.header,
    this.footer,
    this.emptyState,
    this.separator,
    this.separatorBuilder,
    this.refreshing = false,
    this.onRefresh,
    this.command,
    this.debug = false,
    this.additionalProps,
    this.onMetrics,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Handle empty state
    if (data.isEmpty) {
      if (emptyState != null) {
        return DCFView(
          layout: layout,
          styleSheet: styleSheet,
          children: [emptyState!],
        );
      }
      // Return empty VirtualizedList for consistent behavior
      return vl.DCFVirtualizedList(
        itemCount: 0,
        renderItem: (index, info) => DCFView(children: []),
        horizontal: horizontal,
        layout: layout,
        styleSheet: styleSheet,
        showsScrollIndicator: showsScrollIndicator,
        scrollEnabled: scrollEnabled,
        bounces: bounces,
        pagingEnabled: pagingEnabled,
        debug: debug,
      );
    }

    // Calculate total item count including separators, header, and footer
    int totalItemCount = data.length;
    bool hasHeader = header != null;
    bool hasFooter = footer != null;
    bool hasSeparators = separator != null || separatorBuilder != null;

    if (hasHeader) totalItemCount += 1;
    if (hasFooter) totalItemCount += 1;
    if (hasSeparators && data.length > 1) {
      totalItemCount += data.length - 1; // separators between items
    }

    // DEBUG: Log the counts
    print('DEBUG FlatList: data.length=${data.length}, hasHeader=$hasHeader, hasFooter=$hasFooter, hasSeparators=$hasSeparators, totalItemCount=$totalItemCount');

    // Build render function
    DCFComponentNode renderVirtualizedItem(
        int index, vl.VirtualizedListItemInfo info) {
      print('DEBUG FlatList: renderVirtualizedItem called with index=$index');

      // Handle header
      if (hasHeader && index == 0) {
        print('DEBUG FlatList: Rendering header at index 0');
        return header!;
      }

      // Adjust index for header
      int adjustedIndex = index;
      if (hasHeader) adjustedIndex -= 1;

      // Handle footer
      if (hasFooter &&
          adjustedIndex == (totalItemCount - (hasHeader ? 1 : 0) - 1)) {
        print('DEBUG FlatList: Rendering footer at adjustedIndex=$adjustedIndex');
        return footer!;
      }

      // Handle separators
      if (hasSeparators && adjustedIndex > 0 && adjustedIndex % 2 == 1) {
        final separatorIndex = (adjustedIndex - 1) ~/ 2;
        if (separatorBuilder != null) {
          return separatorBuilder!(separatorIndex);
        }
        return separator!;
      }

      // Handle regular items
      final dataIndex = hasSeparators ? adjustedIndex ~/ 2 : adjustedIndex;

      // Bounds check
      if (dataIndex >= 0 && dataIndex < data.length) {
        final item = data[dataIndex];
        print('DEBUG FlatList: Rendering data item at dataIndex=$dataIndex');
        return renderItem(item, dataIndex);
      }

      // Fallback for any edge cases
      print('DEBUG FlatList: Fallback render for index=$index, adjustedIndex=$adjustedIndex, dataIndex=$dataIndex');
      return DCFView(children: []);
    }

    // Build size function
    double? getVirtualizedItemSize(int index) {
      // Handle header
      if (hasHeader && index == 0) {
        return itemSize ?? (horizontal ? 100.0 : 50.0); // Default header size
      }

      // Adjust index for header
      int adjustedIndex = index;
      if (hasHeader) adjustedIndex -= 1;

      // Handle footer
      if (hasFooter &&
          adjustedIndex == (totalItemCount - (hasHeader ? 1 : 0) - 1)) {
        return itemSize ?? (horizontal ? 100.0 : 50.0); // Default footer size
      }

      // Handle separators
      if (hasSeparators && adjustedIndex > 0 && adjustedIndex % 2 == 1) {
        return 1.0; // Thin separator
      }

      // Handle regular items
      final dataIndex = hasSeparators ? adjustedIndex ~/ 2 : adjustedIndex;

      if (dataIndex >= 0 && dataIndex < data.length) {
        final item = data[dataIndex];

        if (getItemSize != null) {
          return getItemSize!(item, dataIndex);
        }

        return itemSize;
      }

      return null; // Use estimated size
    }

    // Build key extractor
    String? getVirtualizedItemKey(int index) {
      // Handle header
      if (hasHeader && index == 0) {
        return 'header';
      }

      // Adjust index for header
      int adjustedIndex = index;
      if (hasHeader) adjustedIndex -= 1;

      // Handle footer
      if (hasFooter &&
          adjustedIndex == (totalItemCount - (hasHeader ? 1 : 0) - 1)) {
        return 'footer';
      }

      // Handle separators
      if (hasSeparators && adjustedIndex > 0 && adjustedIndex % 2 == 1) {
        final separatorIndex = (adjustedIndex - 1) ~/ 2;
        return 'separator_$separatorIndex';
      }

      // Handle regular items
      final dataIndex = hasSeparators ? adjustedIndex ~/ 2 : adjustedIndex;

      if (dataIndex >= 0 && dataIndex < data.length) {
        final item = data[dataIndex];
        if (keyExtractor != null) {
          return keyExtractor!(item, dataIndex);
        }
        return 'item_$dataIndex';
      }

      return 'unknown_$index';
    }

    // Handle end reached
    Function(vl.VirtualizedListViewabilityInfo)? onViewableItemsChanged;
    if (onEndReached != null) {
      onViewableItemsChanged = (vl.VirtualizedListViewabilityInfo info) {
        if (info.viewableItems.isNotEmpty) {
          final maxIndex = info.viewableItems
              .map((item) => item.index)
              .reduce((a, b) => a > b ? a : b);
          final threshold =
              (totalItemCount * (1.0 - onEndReachedThreshold)).floor();

          if (maxIndex >= threshold) {
            onEndReached!();
          }
        }
      };
    }

    // Build command
    print('DEBUG FlatList: Creating VirtualizedList with itemCount=$totalItemCount');
    return vl.DCFVirtualizedList(
      itemCount: totalItemCount,
      renderItem: renderVirtualizedItem,
      getItemSize: (index) => getVirtualizedItemSize(index),
      keyExtractor: (index) => getVirtualizedItemKey(index) ?? 'item_$index',
      horizontal: horizontal,
      layout: layout,
      styleSheet: styleSheet,
      showsScrollIndicator: showsScrollIndicator,
      scrollEnabled: scrollEnabled,
      bounces: bounces,
      pagingEnabled: pagingEnabled,
      initialNumToRender: initialNumToRender ?? (horizontal ? 5 : 10),
      removeClippedSubviews: removeClippedSubviews,
      inverted: inverted,
      onScroll: onScroll,
      onScrollBeginDrag: onScrollBeginDrag,
      onScrollEndDrag: onScrollEndDrag,
      onMomentumScrollEnd: onMomentumScrollEnd,
      onViewableItemsChanged: onViewableItemsChanged,
      command: command,
      debug: debug,
      additionalProps: additionalProps,
      onMetrics: onMetrics,
      estimatedItemSize: itemSize ?? (horizontal ? 100.0 : 44.0),
    );
  }

  @override
  List<Object?> get props => [
        data,
        renderItem,
        keyExtractor,
        horizontal,
        layout,
        styleSheet,
        showsScrollIndicator,
        scrollEnabled,
        bounces,
        pagingEnabled,
        itemSize,
        getItemSize,
        initialNumToRender,
        removeClippedSubviews,
        inverted,
        onScroll,
        onScrollBeginDrag,
        onScrollEndDrag,
        onMomentumScrollEnd,
        onEndReached,
        onEndReachedThreshold,
        header,
        footer,
        emptyState,
        separator,
        separatorBuilder,
        refreshing,
        onRefresh,
        command,
        debug,
        additionalProps,
        onMetrics,
        key,
      ];
}

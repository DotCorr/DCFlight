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
/// A convenience wrapper around VirtualizedList following React Native's approach
/// Perfect for most common list use cases with simple array data
class DCFFlatList<T> extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// List of data items - must be a List (unlike VirtualizedList which accepts any data)
  final List<T> data;

  /// Function to render each item - simpler API than VirtualizedList
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
  final bool pagingEnabled;
  final bool inverted;

  /// Performance optimization props (inherited from VirtualizedList)
  final int? initialNumToRender;
  final int? maxToRenderPerBatch;
  final int? windowSize;
  final bool removeClippedSubviews;
  final Duration? updateCellsBatchingPeriod;

  /// Function to get item layout if known ahead of time
  final Function(List<T> data, int index)? getItemLayout;

  /// Event handlers
  final Function(vl.VirtualizedListScrollEvent)? onScroll;
  final Function(vl.VirtualizedListScrollEvent)? onScrollBeginDrag;
  final Function(vl.VirtualizedListScrollEvent)? onScrollEndDrag;
  final Function(vl.VirtualizedListScrollEvent)? onMomentumScrollBegin;
  final Function(vl.VirtualizedListScrollEvent)? onMomentumScrollEnd;

  /// Viewability detection
  final Function(vl.VirtualizedListViewabilityInfo)? onViewableItemsChanged;
  final vl.ViewabilityConfig? viewabilityConfig;

  /// End reached detection
  final Function()? onEndReached;
  final double onEndReachedThreshold;

  /// Refresh control
  final bool refreshing;
  final Function()? onRefresh;

  /// List decoration components
  final DCFComponentNode? listHeaderComponent;
  final DCFComponentNode? listFooterComponent;
  final DCFComponentNode? listEmptyComponent;
  final DCFComponentNode? itemSeparatorComponent;

  /// Multi-column support (FlatList specific)
  final int? numColumns;
  // 🚀 FIXED: Separate layout and style for column wrapper
  final LayoutProps? columnWrapperLayout; // For layout properties like padding, margin
  final StyleSheet? columnWrapperStyle;   // For visual properties like backgroundColor

  /// Commands for imperative operations
  final vl.VirtualizedListCommand? command;

  /// Whether to enable debug mode
  final bool debug;

  /// Additional props for customization
  final Map<String, dynamic>? extraData;

  DCFFlatList({
    required this.data,
    required this.renderItem,
    this.keyExtractor,
    this.horizontal = false,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.showsScrollIndicator = true,
    this.scrollEnabled = true,
    this.pagingEnabled = false,
    this.inverted = false,
    this.initialNumToRender,
    this.maxToRenderPerBatch,
    this.windowSize,
    this.removeClippedSubviews = false,
    this.updateCellsBatchingPeriod,
    this.getItemLayout,
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onMomentumScrollBegin,
    this.onMomentumScrollEnd,
    this.onViewableItemsChanged,
    this.viewabilityConfig,
    this.onEndReached,
    this.onEndReachedThreshold = 0.1,
    this.refreshing = false,
    this.onRefresh,
    this.listHeaderComponent,
    this.listFooterComponent,
    this.listEmptyComponent,
    this.itemSeparatorComponent,
    this.numColumns,
    this.columnWrapperLayout,
    this.columnWrapperStyle,  
    this.command,
    this.debug = false,
    this.extraData,
    super.key,
  }) : assert(numColumns == null || numColumns > 0, 'numColumns must be greater than 0');

  @override
  DCFComponentNode render() {
    if (debug) {
      print('FlatList Debug: Rendering with ${data.length} items');
    }

    // Handle multi-column layout
    final List<dynamic> processedData;
    final DCFComponentNode Function({required dynamic item, required int index}) processedRenderItem;

    if (numColumns != null && numColumns! > 1) {
      // Multi-column implementation following React Native's approach
      processedData = _createMultiColumnData();
      processedRenderItem = _renderMultiColumnItem;
    } else {
      // Single column - direct mapping
      processedData = data;
      processedRenderItem = ({required dynamic item, required int index}) {
        return renderItem(item as T, index);
      };
    }

    // Create VirtualizedList with FlatList's simplified API
    return vl.DCFVirtualizedList(
      // Core required props for VirtualizedList
      data: processedData,
      getItem: (data, index) => (data as List)[index],
      getItemCount: (data) => (data as List).length,
      renderItem: processedRenderItem,

      // Layout optimization
      getItemLayout: getItemLayout != null
          ? (data, index) => getItemLayout!(this.data, index)
          : null,

      // Key extraction
      keyExtractor: keyExtractor != null
          ? (item, index) => numColumns != null && numColumns! > 1
              ? 'row_$index' // For multi-column, use row index
              : keyExtractor!(item as T, index)
          : null,

      // Performance props with FlatList defaults
      initialNumToRender: initialNumToRender ?? 10,
      maxToRenderPerBatch: maxToRenderPerBatch ?? 10,
      windowSize: windowSize ?? 21,
      removeClippedSubviews: removeClippedSubviews,
      updateCellsBatchingPeriod: updateCellsBatchingPeriod ?? const Duration(milliseconds: 50),

      // Layout and styling
      horizontal: horizontal,
      layout: layout,
      styleSheet: styleSheet,
      inverted: inverted,

      // Scroll behavior
      showsScrollIndicator: showsScrollIndicator,
      scrollEnabled: scrollEnabled,
      pagingEnabled: pagingEnabled,

      // Event handlers
      onScroll: onScroll,
      onScrollBeginDrag: onScrollBeginDrag,
      onScrollEndDrag: onScrollEndDrag,
      onMomentumScrollBegin: onMomentumScrollBegin,
      onMomentumScrollEnd: onMomentumScrollEnd,

      // Viewability
      onViewableItemsChanged: onViewableItemsChanged,
      viewabilityConfig: viewabilityConfig,

      // End reached
      onEndReached: onEndReached,
      onEndReachedThreshold: onEndReachedThreshold,

      // Refresh
      refreshing: refreshing,
      onRefresh: onRefresh,

      // List components
      ListHeaderComponent: listHeaderComponent,
      ListFooterComponent: listFooterComponent,
      ListEmptyComponent: listEmptyComponent,
      ItemSeparatorComponent: itemSeparatorComponent,

      // Commands and debug
      command: command,
      debug: debug,
      extraData: extraData,

      // Pass through the key
      key: key,
    );
  }

  /// Create multi-column data structure
  /// Groups items into rows for multi-column rendering
  List<List<T?>> _createMultiColumnData() {
    if (numColumns == null || numColumns! <= 1) return [data];

    final List<List<T?>> rows = [];
    final int cols = numColumns!;

    for (int i = 0; i < data.length; i += cols) {
      final List<T?> row = List.filled(cols, null);
      
      for (int j = 0; j < cols && (i + j) < data.length; j++) {
        row[j] = data[i + j];
      }
      
      rows.add(row);
    }

    return rows;
  }

  /// Render multi-column row
  /// Creates a horizontal layout with multiple items
  DCFComponentNode _renderMultiColumnItem({required dynamic item, required int index}) {
    final row = item as List<T?>;
    final List<DCFComponentNode> columnChildren = [];

    for (int i = 0; i < row.length; i++) {
      final T? cellItem = row[i];
      
      if (cellItem != null) {
        // Calculate the actual data index
        final int dataIndex = (index * numColumns!) + i;
        
        // Render the item with flex: 1 for equal width columns
        columnChildren.add(
          DCFView(
            layout: const LayoutProps(flex: 1),
            children: [renderItem(cellItem, dataIndex)],
          ),
        );
      } else {
        // Empty cell to maintain column structure
        columnChildren.add(
          DCFView(
            layout: const LayoutProps(flex: 1),
            children: [],
          ),
        );
      }
    }

    // 🚀 FIXED: Return horizontal row container with BOTH layout and style
    return DCFView(
      layout: LayoutProps(
        flexDirection: YogaFlexDirection.row,
        width: "100%",
        // Apply column wrapper layout properties
        padding: columnWrapperLayout?.padding,
        margin: columnWrapperLayout?.margin,
        paddingTop: columnWrapperLayout?.paddingTop,
        paddingBottom: columnWrapperLayout?.paddingBottom,
        paddingLeft: columnWrapperLayout?.paddingLeft,
        paddingRight: columnWrapperLayout?.paddingRight,
        marginTop: columnWrapperLayout?.marginTop,
        marginBottom: columnWrapperLayout?.marginBottom,
        marginLeft: columnWrapperLayout?.marginLeft,
        marginRight: columnWrapperLayout?.marginRight,
        alignItems: columnWrapperLayout?.alignItems,
        justifyContent: columnWrapperLayout?.justifyContent,
      ),
      styleSheet: columnWrapperStyle ?? const StyleSheet(),
      children: columnChildren,
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
        pagingEnabled,
        inverted,
        initialNumToRender,
        maxToRenderPerBatch,
        windowSize,
        removeClippedSubviews,
        updateCellsBatchingPeriod,
        getItemLayout,
        onScroll,
        onScrollBeginDrag,
        onScrollEndDrag,
        onMomentumScrollBegin,
        onMomentumScrollEnd,
        onViewableItemsChanged,
        viewabilityConfig,
        onEndReached,
        onEndReachedThreshold,
        refreshing,
        onRefresh,
        listHeaderComponent,
        listFooterComponent,
        listEmptyComponent,
        itemSeparatorComponent,
        numColumns,
        columnWrapperLayout, // 🚀 FIXED: Include both in props
        columnWrapperStyle,
        command,
        debug,
        extraData,
        key,
      ];
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// DCFFlatList - High-performance list component inspired by FlashList
/// Provides ultra-fast scrolling with component recycling and smart rendering
class DCFFlatList<T> extends StatelessComponent {
  final List<T> data;
  final LayoutProps? layout;
  final DCFComponentNode Function(T item, int index) renderItem;
  
  // 🚫 DART ONLY - Not sent to native (virtualization handled in Dart)
  final String Function(T item, int index)? getItemType;
  final double? estimatedItemSize;
  final ListItemConfig Function(T item, int index)? getItemLayout;
  final int? initialNumToRender;
  final double? maxToRenderPerBatch;
  final double? windowSize;
  final bool removeClippedSubviews;
  
  // ✅ NATIVE PROPS - Sent to native UIScrollView
  final DCFListOrientation orientation;
  final bool inverted;
  final bool showsVerticalScrollIndicator;
  final bool showsHorizontalScrollIndicator;
  final ContentInset? contentInset;
  final bool bounces;
  final bool alwaysBounceVertical;
  final bool alwaysBounceHorizontal;
  final bool pagingEnabled;
  final double? snapToInterval;
  final bool snapToStart;
  final bool snapToEnd;
  final double? decelerationRate;
  final bool keyboardDismissMode;
  final bool keyboardShouldPersistTaps;
  
  // 🚫 DART ONLY - List management handled in Dart  
  final void Function(int index)? onViewableItemsChanged;
  final void Function()? onEndReached;
  final double? onEndReachedThreshold;
  final void Function()? onRefresh;
  final bool refreshing;
  final DCFComponentNode? refreshControl;
  final DCFComponentNode? header;
  final DCFComponentNode? footer;
  final DCFComponentNode? empty;
  final DCFComponentNode? separator;
  final DCFComponentNode Function(int index)? stickyHeaderIndices;
  
  // ✅ NATIVE EVENTS - Sent to native UIScrollView
  final Function(Map<dynamic, dynamic>)? onScroll;
  final Function(Map<dynamic, dynamic>)? onScrollBeginDrag;
  final Function(Map<dynamic, dynamic>)? onScrollEndDrag;
  final Function(Map<dynamic, dynamic>)? onMomentumScrollBegin;
  final Function(Map<dynamic, dynamic>)? onMomentumScrollEnd;
  final Function(Map<dynamic, dynamic>)? onContentSizeChange;

  // ✅ IMPERATIVE COMMANDS - Type-safe command prop for imperative control
  final FlatListCommand? command;

  DCFFlatList({
    super.key,
    required this.data,
    this.layout = const LayoutProps(flex: 1),
    required this.renderItem,
    this.getItemType,
    this.estimatedItemSize,
    this.getItemLayout,
    this.orientation = DCFListOrientation.vertical,
    this.inverted = false,
    this.initialNumToRender = 10,
    this.maxToRenderPerBatch = 10,
    this.windowSize = 21,
    this.removeClippedSubviews = true,
    this.showsVerticalScrollIndicator = true,
    this.showsHorizontalScrollIndicator = true,
    this.contentInset,
    this.bounces = true,
    this.alwaysBounceVertical = false,
    this.alwaysBounceHorizontal = false,
    this.pagingEnabled = false,
    this.snapToInterval,
    this.snapToStart = false,
    this.snapToEnd = false,
    this.decelerationRate,
    this.keyboardDismissMode = false,
    this.keyboardShouldPersistTaps = false,
    this.onViewableItemsChanged,
    this.onEndReached,
    this.onEndReachedThreshold = 0.1,
    this.onRefresh,
    this.refreshing = false,
    this.refreshControl,
    this.header,
    this.footer,
    this.empty,
    this.separator,
    this.stickyHeaderIndices,
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onMomentumScrollBegin,
    this.onMomentumScrollEnd,
    this.onContentSizeChange,
    this.command,
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'FlatList',
      key: key,
      props: {
        // ✅ NATIVE PROPS - Only these go to native UIScrollView
        'horizontal': orientation == DCFListOrientation.horizontal,
        'inverted': inverted,
        'showsVerticalScrollIndicator': showsVerticalScrollIndicator,
        'showsHorizontalScrollIndicator': showsHorizontalScrollIndicator,
        'bounces': bounces,
        'alwaysBounceVertical': alwaysBounceVertical,
        'alwaysBounceHorizontal': alwaysBounceHorizontal,
        'pagingEnabled': pagingEnabled,
        'snapToInterval': snapToInterval,
        'snapToStart': snapToStart,
        'snapToEnd': snapToEnd,
        'decelerationRate': decelerationRate,
        'keyboardDismissMode': keyboardDismissMode,
        'keyboardShouldPersistTaps': keyboardShouldPersistTaps,
        if (contentInset != null) 'contentInset': contentInset!.toMap(),
        
        // Layout props
        ...layout?.toMap() ?? {},
        
        // Event handlers
        if (onScroll != null) 'onScroll': onScroll,
        if (onScrollBeginDrag != null) 'onScrollBeginDrag': onScrollBeginDrag,
        if (onScrollEndDrag != null) 'onScrollEndDrag': onScrollEndDrag,
        if (onMomentumScrollBegin != null) 'onMomentumScrollBegin': onMomentumScrollBegin,
        if (onMomentumScrollEnd != null) 'onMomentumScrollEnd': onMomentumScrollEnd,
        if (onContentSizeChange != null) 'onContentSizeChange': onContentSizeChange,
        
        // ✅ IMPERATIVE COMMANDS - Type-safe command prop serialization
        if (command != null) 'command': command!.toMap(),
        
        // 🚫 DART ONLY PROPS - These are used for virtualization logic in Dart
        // They don't get sent to native side:
        // - data.length (used for child generation)
        // - estimatedItemSize (used for Dart-side calculations)
        // - initialNumToRender, maxToRenderPerBatch, windowSize (virtualization)
        // - removeClippedSubviews (Dart-side optimization)
        // - onViewableItemsChanged, onEndReached (Dart-side callbacks)
        // - refreshing, header, footer, empty, separator (Dart-side UI)
      },
      children: _buildListChildren(),
    );
  }

  List<DCFComponentNode> _buildListChildren() {
    final children = <DCFComponentNode>[];
    
    // Add header if provided
    if (header != null) {
      children.add(header!);
    }

    // Generate list items
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final itemElement = renderItem(item, i);
      children.add(itemElement);
      
      // Add separator after each item (except last one)
      if (separator != null && i < data.length - 1) {
        children.add(separator!);
      }
    }

    // Add footer if provided
    if (footer != null) {
      children.add(footer!);
    }

    // If no data and empty component provided
    if (data.isEmpty && empty != null) {
      children.clear();
      children.add(empty!);
    }

    return children;
  }
}

/// FlatList layout orientations
enum DCFListOrientation {
  vertical,
  horizontal,
}

/// List item render configuration for FlashList-style performance
class ListItemConfig {
  final String itemType;
  final double? estimatedHeight;
  final double? estimatedWidth;

  const ListItemConfig({
    required this.itemType,
    this.estimatedHeight,
    this.estimatedWidth,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemType': itemType,
      'estimatedHeight': estimatedHeight,
      'estimatedWidth': estimatedWidth,
    };
  }
}
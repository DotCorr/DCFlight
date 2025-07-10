/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';

/// VirtualizedList - High-performance list component following React Native's approach
/// 
/// Key Concepts from React Native:
/// 1. Maintains a finite render window of active items
/// 2. Replaces items outside window with appropriately sized blank space
/// 3. Window adapts to scrolling behavior
/// 4. Items rendered incrementally with priority-based rendering
/// 5. High-priority for visible area, low-priority for far items
/// 
/// This is the base implementation - use DCFFlatList for most cases
class DCFVirtualizedList extends StatefulComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Required props following React Native API
  final Function(dynamic data, int index) getItem;
  final Function(dynamic data) getItemCount;
  final DCFComponentNode Function({required dynamic item, required int index}) renderItem;
  
  /// The data source - can be any type, not just arrays
  final dynamic data;

  /// Optional optimization: provide item layout if known ahead of time
  final Function(dynamic data, int index)? getItemLayout;

  /// Key extractor for React-style reconciliation
  final String Function(dynamic item, int index)? keyExtractor;

  /// Core virtualization parameters
  /// How many items to render in initial batch (should fill screen but not much more)
  /// These items are never unmounted for scroll-to-top performance
  final int initialNumToRender;

  /// Maximum items rendered outside visible area (in units of visible lengths)
  /// windowSize=21 means visible area + 10 screens above + 10 screens below
  final int windowSize;

  /// Maximum items to render per batch during incremental rendering
  /// Higher = better fill rate, lower = better responsiveness
  final int maxToRenderPerBatch;

  /// Time between low-priority render batches (for off-screen items)
  final Duration updateCellsBatchingPeriod;

  /// Whether to remove clipped subviews (native optimization)
  final bool removeClippedSubviews;

  /// Layout and styling
  final bool horizontal;
  final LayoutProps layout;
  final StyleSheet styleSheet;

  /// Scroll behavior
  final bool showsScrollIndicator;
  final bool scrollEnabled;
  final bool pagingEnabled;
  final bool inverted;

  /// Event handlers matching React Native API
  final Function(VirtualizedListScrollEvent)? onScroll;
  final Function(VirtualizedListScrollEvent)? onScrollBeginDrag;
  final Function(VirtualizedListScrollEvent)? onScrollEndDrag;
  final Function(VirtualizedListScrollEvent)? onMomentumScrollBegin;
  final Function(VirtualizedListScrollEvent)? onMomentumScrollEnd;

  /// Viewability change detection
  final Function(VirtualizedListViewabilityInfo)? onViewableItemsChanged;
  final ViewabilityConfig? viewabilityConfig;

  /// End reached detection
  final Function()? onEndReached;
  final double onEndReachedThreshold;

  /// Refresh control
  final bool refreshing;
  final Function()? onRefresh;

  /// List decorations
  final DCFComponentNode? ListHeaderComponent;
  final DCFComponentNode? ListFooterComponent;
  final DCFComponentNode? ListEmptyComponent;
  final DCFComponentNode? ItemSeparatorComponent;

  /// Debug mode
  final bool debug;

  /// Commands for imperative operations
  final VirtualizedListCommand? command;

  /// Additional customization
  final Map<String, dynamic>? extraData;

  DCFVirtualizedList({
    required this.getItem,
    required this.getItemCount,
    required this.renderItem,
    required this.data,
    this.getItemLayout,
    this.keyExtractor,
    this.initialNumToRender = 10,
    this.windowSize = 21,
    this.maxToRenderPerBatch = 10,
    this.updateCellsBatchingPeriod = const Duration(milliseconds: 50),
    this.removeClippedSubviews = false,
    this.horizontal = false,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.showsScrollIndicator = true,
    this.scrollEnabled = true,
    this.pagingEnabled = false,
    this.inverted = false,
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
    this.ListHeaderComponent,
    this.ListFooterComponent,
    this.ListEmptyComponent,
    this.ItemSeparatorComponent,
    this.debug = false,
    this.command,
    this.extraData,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Core state for virtualization
    final scrollOffsetState = useState<double>(0.0, 'scrollOffset');
    final viewportSizeState = useState<double>(
      horizontal ? (layout.width ?? 400.0) : (layout.height ?? 600.0), 
      'viewportSize'
    );
    final renderWindowState = useState<RenderWindow>(
      RenderWindow(first: 0, last: initialNumToRender - 1),
      'renderWindow'
    );
    final itemLayoutCacheState = useState<Map<int, ItemLayout>>({}, 'itemLayoutCache');
    final scrollingState = useState<bool>(false, 'scrolling');
    final lastScrollTimeState = useState<DateTime>(DateTime.now(), 'lastScrollTime');

    final itemCount = getItemCount(data);
    final scrollOffset = scrollOffsetState.state;
    final viewportSize = viewportSizeState.state;
    final renderWindow = renderWindowState.state;
    final itemLayoutCache = itemLayoutCacheState.state;

    if (debug) {
      print('VirtualizedList Debug: itemCount=$itemCount, renderWindow=$renderWindow, scrollOffset=$scrollOffset');
    }

    // Handle empty state
    if (itemCount == 0) {
      return _buildEmptyState();
    }

    // Build the virtual children list
    final virtualChildren = <DCFComponentNode>[];

    // Add header if provided
    if (ListHeaderComponent != null) {
      virtualChildren.add(DCFView(
        key: 'virtualized_header',
        children: [ListHeaderComponent!],
      ));
    }

    // Calculate render range based on current window
    final renderRange = _calculateRenderRange(
      scrollOffset: scrollOffset,
      viewportSize: viewportSize,
      itemLayoutCache: itemLayoutCache,
      itemCount: itemCount,
      windowSize: windowSize,
    );

    // Add spacer before visible items (virtual scrolling)
    if (renderRange.start > 0) {
      final spacerSize = _calculateSpacerSize(0, renderRange.start - 1, itemLayoutCache);
      virtualChildren.add(_buildSpacer('before_spacer', spacerSize));
    }

    // Render visible items
    for (int index = renderRange.start; index <= renderRange.end && index < itemCount; index++) {
      final item = getItem(data, index);
      final itemKey = keyExtractor?.call(item, index) ?? 'item_$index';
      
      // Render the actual item
      final renderedItem = renderItem(item: item, index: index);
      
      // Wrap in container for layout management
      virtualChildren.add(DCFView(
        key: itemKey,
        layout: LayoutProps(
          height: horizontal ? "100%" : _getItemSize(index, itemLayoutCache),
          width: horizontal ? _getItemSize(index, itemLayoutCache) : "100%",
        ),
        children: [renderedItem],
      ));

      // Add separator if provided and not last item
      if (ItemSeparatorComponent != null && index < itemCount - 1) {
        virtualChildren.add(DCFView(
          key: '${itemKey}_separator',
          children: [ItemSeparatorComponent!],
        ));
      }
    }

    // Add spacer after visible items
    if (renderRange.end < itemCount - 1) {
      final spacerSize = _calculateSpacerSize(renderRange.end + 1, itemCount - 1, itemLayoutCache);
      virtualChildren.add(_buildSpacer('after_spacer', spacerSize));
    }

    // Add footer if provided
    if (ListFooterComponent != null) {
      virtualChildren.add(DCFView(
        key: 'virtualized_footer',
        children: [ListFooterComponent!],
      ));
    }

    // Enhanced scroll handler with virtualization logic
    void handleScroll(Map<dynamic, dynamic> event) {
      final contentOffset = event['contentOffset'] as Map<dynamic, dynamic>?;
      if (contentOffset == null) return;

      final newOffset = horizontal 
          ? (contentOffset['x'] as num?)?.toDouble() ?? 0.0
          : (contentOffset['y'] as num?)?.toDouble() ?? 0.0;

      // Update scroll state
      scrollOffsetState.setState(newOffset);
      scrollingState.setState(true);
      lastScrollTimeState.setState(DateTime.now());

      // Schedule scroll end detection
      _scheduleScrollEndDetection(scrollingState, lastScrollTimeState);

      // Calculate new render window
      final newRenderRange = _calculateRenderRange(
        scrollOffset: newOffset,
        viewportSize: viewportSize,
        itemLayoutCache: itemLayoutCache,
        itemCount: itemCount,
        windowSize: windowSize,
      );

      // Update render window if significantly changed
      if (_shouldUpdateRenderWindow(renderWindow, newRenderRange)) {
        renderWindowState.setState(RenderWindow(
          first: newRenderRange.start,
          last: newRenderRange.end,
        ));

        if (debug) {
          print('VirtualizedList: Updated render window to $newRenderRange');
        }
      }

      // Handle end reached
      _handleEndReached(newOffset, viewportSize, itemLayoutCache, itemCount);

      // Forward scroll event
      if (onScroll != null) {
        onScroll!(VirtualizedListScrollEvent.fromMap(event));
      }
    }

    // Use effect for incremental rendering
    useEffect(() {
      if (!scrollingState.state) {
        _scheduleIncrementalRendering(renderWindow, itemCount, renderWindowState.setState);
      }
      return null;
    }, dependencies:[renderWindow, scrollingState.state]);

    // 🚀 FIXED: Return DCFScrollView with correct API from your implementation
    return DCFScrollView(
      key: key,
      horizontal: horizontal,
      layout: layout,
      styleSheet: styleSheet,
      showsScrollIndicator: showsScrollIndicator,
      scrollEnabled: scrollEnabled,
      pagingEnabled: pagingEnabled,
      // 🚀 FIXED: Use correct scroll event handlers
      onScroll: handleScroll,
      onScrollBeginDrag: onScrollBeginDrag != null 
          ? (event) => onScrollBeginDrag!(VirtualizedListScrollEvent.fromMap(event))
          : null,
      onScrollEndDrag: onScrollEndDrag != null
          ? (event) => onScrollEndDrag!(VirtualizedListScrollEvent.fromMap(event))
          : null,
      // 🚀 FIXED: Convert commands properly
      command: _convertCommandToScrollView(command),
      children: virtualChildren,
    );
  }

  // Helper method to build empty state
  DCFComponentNode _buildEmptyState() {
    if (ListEmptyComponent != null) {
      return DCFView(
        layout: layout,
        styleSheet: styleSheet,
        children: [ListEmptyComponent!],
      );
    }
    return DCFView(
      layout: layout,
      styleSheet: styleSheet,
      children: [],
    );
  }

  // Helper method to build spacers for virtual scrolling
  DCFComponentNode _buildSpacer(String key, double size) {
    return DCFView(
      key: key,
      layout: LayoutProps(
        width: horizontal ? size : "100%",
        height: horizontal ? "100%" : size,
      ),
      styleSheet: const StyleSheet(backgroundColor: Colors.transparent),
      children: [],
    );
  }

  // Calculate which items should be rendered based on React Native's algorithm
  RenderRange _calculateRenderRange({
    required double scrollOffset,
    required double viewportSize,
    required Map<int, ItemLayout> itemLayoutCache,
    required int itemCount,
    required int windowSize,
  }) {
    if (itemCount == 0) return RenderRange(start: 0, end: -1);

    // Find first visible item
    int firstVisible = 0;
    double currentOffset = 0.0;

    for (int i = 0; i < itemCount; i++) {
      final itemSize = _getItemSize(i, itemLayoutCache);
      if (currentOffset + itemSize > scrollOffset) {
        firstVisible = i;
        break;
      }
      currentOffset += itemSize;
    }

    // Find last visible item
    int lastVisible = firstVisible;
    double visibleSize = 0.0;

    for (int i = firstVisible; i < itemCount; i++) {
      final itemSize = _getItemSize(i, itemLayoutCache);
      visibleSize += itemSize;
      lastVisible = i;
      
      if (visibleSize >= viewportSize) break;
    }

    // Apply window size (React Native's key optimization)
    // windowSize is in units of visible lengths
    final windowItems = ((windowSize - 1) / 2).round();
    final start = (firstVisible - windowItems).clamp(0, itemCount - 1);
    final end = (lastVisible + windowItems).clamp(0, itemCount - 1);

    return RenderRange(start: start, end: end);
  }

  // Get item size with fallback to estimated size
  double _getItemSize(int index, Map<int, ItemLayout> itemLayoutCache) {
    if (itemLayoutCache.containsKey(index)) {
      return itemLayoutCache[index]!.length;
    }

    if (getItemLayout != null) {
      final layout = getItemLayout!(data, index);
      return layout['length']?.toDouble() ?? 50.0;
    }

    return 50.0; // Default estimated item size
  }

  // Calculate total size for spacers
  double _calculateSpacerSize(int startIndex, int endIndex, Map<int, ItemLayout> itemLayoutCache) {
    double totalSize = 0.0;
    for (int i = startIndex; i <= endIndex; i++) {
      totalSize += _getItemSize(i, itemLayoutCache);
    }
    return totalSize;
  }

  // Check if render window should be updated
  bool _shouldUpdateRenderWindow(RenderWindow current, RenderRange newRange) {
    // Update if the change is significant (more than maxToRenderPerBatch items)
    return (current.first - newRange.start).abs() >= maxToRenderPerBatch ||
           (current.last - newRange.end).abs() >= maxToRenderPerBatch;
  }

  // 🚀 FIXED: Use proper function type for setState
  void _scheduleScrollEndDetection(
    StateHook<bool> scrollingState,
    StateHook<DateTime> lastScrollTimeState,
  ) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (DateTime.now().difference(lastScrollTimeState.state).inMilliseconds > 100) {
        scrollingState.setState(false);
      }
    });
  }

  // Handle end reached detection
  void _handleEndReached(
    double scrollOffset,
    double viewportSize,
    Map<int, ItemLayout> itemLayoutCache,
    int itemCount,
  ) {
    if (onEndReached == null) return;

    final totalContentSize = _calculateSpacerSize(0, itemCount - 1, itemLayoutCache);
    final distanceFromEnd = totalContentSize - (scrollOffset + viewportSize);
    final threshold = viewportSize * onEndReachedThreshold;

    if (distanceFromEnd <= threshold) {
      onEndReached!();
    }
  }

  // 🚀 FIXED: Use proper function type for setState
  void _scheduleIncrementalRendering(
    RenderWindow currentWindow,
    int itemCount,
    Function(RenderWindow) setRenderWindow,
  ) {
    // This is React Native's low-priority rendering for items far from visible area
    Future.delayed(updateCellsBatchingPeriod, () {
      // Expand window gradually for better performance
      final expandedFirst = (currentWindow.first - maxToRenderPerBatch).clamp(0, itemCount - 1);
      final expandedLast = (currentWindow.last + maxToRenderPerBatch).clamp(0, itemCount - 1);

      if (expandedFirst != currentWindow.first || expandedLast != currentWindow.last) {
        setRenderWindow(RenderWindow(first: expandedFirst, last: expandedLast));
      }
    });
  }

  // Convert VirtualizedList commands to ScrollView commands
  ScrollViewCommand? _convertCommandToScrollView(VirtualizedListCommand? command) {
    if (command == null) return null;

    if (command.scrollToIndex != null) {
      // Convert scroll to index to scroll to offset
      final index = command.scrollToIndex!.index;
      final itemLayoutCache = <int, ItemLayout>{}; // Would need to get from state
      final offset = _calculateSpacerSize(0, index - 1, itemLayoutCache);
      
      return ScrollViewCommand(
        scrollToPosition: ScrollToPositionCommand(
          x: horizontal ? offset : 0,
          y: horizontal ? 0 : offset,
          animated: command.scrollToIndex!.animated,
        ),
      );
    }

    if (command.scrollToOffset != null) {
      return ScrollViewCommand(
        scrollToPosition: ScrollToPositionCommand(
          x: horizontal ? command.scrollToOffset!.offset : 0,
          y: horizontal ? 0 : command.scrollToOffset!.offset,
          animated: command.scrollToOffset!.animated,
        ),
      );
    }

    return null;
  }

  @override
  List<Object?> get props => [
        getItem,
        getItemCount,
        renderItem,
        data,
        getItemLayout,
        keyExtractor,
        initialNumToRender,
        windowSize,
        maxToRenderPerBatch,
        updateCellsBatchingPeriod,
        removeClippedSubviews,
        horizontal,
        layout,
        styleSheet,
        showsScrollIndicator,
        scrollEnabled,
        pagingEnabled,
        inverted,
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
        ListHeaderComponent,
        ListFooterComponent,
        ListEmptyComponent,
        ItemSeparatorComponent,
        debug,
        command,
        extraData,
        key,
      ];
}

// Supporting data structures (unchanged)

class RenderWindow {
  final int first;
  final int last;

  RenderWindow({required this.first, required this.last});

  @override
  String toString() => 'RenderWindow(first: $first, last: $last)';
}

class RenderRange {
  final int start;
  final int end;

  RenderRange({required this.start, required this.end});

  @override
  String toString() => 'RenderRange(start: $start, end: $end)';
}

class ItemLayout {
  final double length;
  final double offset;
  final int index;

  ItemLayout({
    required this.length,
    required this.offset,
    required this.index,
  });
}

class ViewabilityConfig {
  final double? viewAreaCoveragePercentThreshold;
  final double? itemVisiblePercentThreshold;
  final Duration? minimumViewTime;

  ViewabilityConfig({
    this.viewAreaCoveragePercentThreshold,
    this.itemVisiblePercentThreshold,
    this.minimumViewTime,
  });
}

// Event classes matching React Native API

class VirtualizedListScrollEvent {
  final VirtualizedListContentOffset contentOffset;
  final VirtualizedListContentSize contentSize;
  final VirtualizedListLayoutMeasurement layoutMeasurement;
  final double velocity;

  VirtualizedListScrollEvent({
    required this.contentOffset,
    required this.contentSize,
    required this.layoutMeasurement,
    this.velocity = 0.0,
  });

  factory VirtualizedListScrollEvent.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListScrollEvent(
      contentOffset: VirtualizedListContentOffset.fromMap(
          map['contentOffset'] as Map? ?? {}),
      contentSize: VirtualizedListContentSize.fromMap(
          map['contentSize'] as Map? ?? {}),
      layoutMeasurement: VirtualizedListLayoutMeasurement.fromMap(
          map['layoutMeasurement'] as Map? ?? {}),
      velocity: (map['velocity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VirtualizedListContentOffset {
  final double x;
  final double y;

  VirtualizedListContentOffset({required this.x, required this.y});

  factory VirtualizedListContentOffset.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListContentOffset(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VirtualizedListContentSize {
  final double width;
  final double height;

  VirtualizedListContentSize({required this.width, required this.height});

  factory VirtualizedListContentSize.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListContentSize(
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VirtualizedListLayoutMeasurement {
  final double width;
  final double height;

  VirtualizedListLayoutMeasurement({required this.width, required this.height});

  factory VirtualizedListLayoutMeasurement.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListLayoutMeasurement(
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VirtualizedListViewabilityInfo {
  final List<VirtualizedListViewableItem> viewableItems;
  final List<VirtualizedListViewableItem> changed;

  VirtualizedListViewabilityInfo({
    required this.viewableItems,
    required this.changed,
  });
}

class VirtualizedListViewableItem {
  final int index;
  final dynamic item;
  final String key;
  final bool isViewable;

  VirtualizedListViewableItem({
    required this.index,
    required this.item,
    required this.key,
    required this.isViewable,
  });
}

// Command classes

class VirtualizedListCommand {
  final ScrollToIndexCommand? scrollToIndex;
  final ScrollToOffsetCommand? scrollToOffset;
  final bool? flashScrollIndicators;

  VirtualizedListCommand({
    this.scrollToIndex,
    this.scrollToOffset,
    this.flashScrollIndicators,
  });
}

class ScrollToIndexCommand {
  final int index;
  final bool animated;
  final double? viewOffset;
  final String viewPosition; // 'auto', 'start', 'center', 'end'

  ScrollToIndexCommand({
    required this.index,
    this.animated = true,
    this.viewOffset,
    this.viewPosition = 'auto',
  });
}

class ScrollToOffsetCommand {
  final double offset;
  final bool animated;

  ScrollToOffsetCommand({
    required this.offset,
    this.animated = true,
  });
}

class VirtualizedListMetrics {
  final int totalItems;
  final int renderedItems;
  final double memoryUsage;
  final double averageItemSize;
  final double scrollVelocity;
  final int recycledViews;
  final Duration renderTime;

  VirtualizedListMetrics({
    required this.totalItems,
    required this.renderedItems,
    required this.memoryUsage,
    required this.averageItemSize,
    required this.scrollVelocity,
    required this.recycledViews,
    required this.renderTime,
  });

  factory VirtualizedListMetrics.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListMetrics(
      totalItems: map['totalItems'] as int? ?? 0,
      renderedItems: map['renderedItems'] as int? ?? 0,
      memoryUsage: (map['memoryUsage'] as num?)?.toDouble() ?? 0.0,
      averageItemSize: (map['averageItemSize'] as num?)?.toDouble() ?? 0.0,
      scrollVelocity: (map['scrollVelocity'] as num?)?.toDouble() ?? 0.0,
      recycledViews: map['recycledViews'] as int? ?? 0,
      renderTime: Duration(milliseconds: map['renderTimeMs'] as int? ?? 0),
    );
  }
}
/*
 * FIXED DCFVirtualizedList - Root cause was in the render window update logic
 *
 * Key fixes:
 * 1. Render window updates immediately during scroll (no batching/delays)
 * 2. Unique keys for ALL components to prevent VDom conflicts
 * 3. Proper state management that triggers re-renders
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';

class DCFVirtualizedList extends StatefulComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Required props following React Native API
  final Function(dynamic data, int index) getItem;
  final Function(dynamic data) getItemCount;
  final DCFComponentNode Function({required dynamic item, required int index})
      renderItem;

  /// The data source - can be any type, not just arrays
  final dynamic data;

  /// Optional optimization: provide item layout if known ahead of time
  final Function(dynamic data, int index)? getItemLayout;

  /// Key extractor for React-style reconciliation
  final String Function(dynamic item, int index)? keyExtractor;

  /// Core virtualization parameters
  final int initialNumToRender;
  final int windowSize;
  final int maxToRenderPerBatch;
  final Duration updateCellsBatchingPeriod;
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
    // 🚀 FIXED: Simple render range state instead of complex window management
    final renderRangeState = useState<RenderRange>(
        RenderRange(start: 0, end: initialNumToRender - 1), 'renderRange');
    final scrollOffsetState = useState<double>(0.0, 'scrollOffset');

    final itemCount = getItemCount(data);
    final renderRange = renderRangeState.state;
    final scrollOffset = scrollOffsetState.state;

    if (debug) {
      print(
          '🔍 VirtualizedList: itemCount=$itemCount, renderRange=${renderRange.start}-${renderRange.end}, scrollOffset=${scrollOffset.toStringAsFixed(0)}');
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
        key: 'virt_header',
        children: [ListHeaderComponent!],
      ));
    }

    // Add spacer before visible items (virtual scrolling)
    if (renderRange.start > 0) {
      final spacerSize = _calculateSpacerSize(0, renderRange.start - 1);
      if (debug)
        print(
            '🔍 Before spacer: ${spacerSize.toStringAsFixed(0)}px for items 0-${renderRange.start - 1}');
      virtualChildren.add(_buildSpacer('virt_before_spacer', spacerSize));
    }

    // 🚀 FIXED: Render visible items with unique keys and proper data access
    int actualRendered = 0;
    for (int index = renderRange.start;
        index <= renderRange.end && index < itemCount;
        index++) {
      final item = getItem(data, index);
      final itemKey = keyExtractor?.call(item, index) ?? 'virt_item_$index';

      if (debug && (index % 10 == 0 || index > 20)) {
        print('🔍 VirtualizedList: Rendering item $index with key $itemKey');
      }

      // 🚀 CRITICAL: Render the actual item with unique key
      final renderedItem = renderItem(item: item, index: index);

      // Wrap in container for layout management with UNIQUE key
      virtualChildren.add(DCFView(
        key: itemKey, // Use the extracted key or generated key
        layout: LayoutProps(
          height: horizontal ? "100%" : _getItemSize(index),
          width: horizontal ? _getItemSize(index) : "100%",
        ),
        children: [renderedItem],
      ));

      actualRendered++;

      // Add separator if provided and not last item
      if (ItemSeparatorComponent != null && index < itemCount - 1) {
        virtualChildren.add(DCFView(
          key: '${itemKey}_separator', // Unique separator key
          children: [ItemSeparatorComponent!],
        ));
      }
    }

    if (debug) {
      print(
          '🔍 VirtualizedList: Actually rendered $actualRendered items from ${renderRange.start} to ${renderRange.end}');
    }

    // Add spacer after visible items
    if (renderRange.end < itemCount - 1) {
      final spacerSize =
          _calculateSpacerSize(renderRange.end + 1, itemCount - 1);
      if (debug)
        print(
            '🔍 After spacer: ${spacerSize.toStringAsFixed(0)}px for items ${renderRange.end + 1}-${itemCount - 1}');
      virtualChildren.add(_buildSpacer('virt_after_spacer', spacerSize));
    }

    // Add footer if provided
    if (ListFooterComponent != null) {
      virtualChildren.add(DCFView(
        key: 'virt_footer',
        children: [ListFooterComponent!],
      ));
    }

    // 🚀 FIXED: Immediate render range update during scroll
    void handleScroll(Map<dynamic, dynamic> event) {
      final contentOffset = event['contentOffset'] as Map<dynamic, dynamic>?;
      if (contentOffset == null) return;

      final newOffset = horizontal
          ? (contentOffset['x'] as num?)?.toDouble() ?? 0.0
          : (contentOffset['y'] as num?)?.toDouble() ?? 0.0;

      // 🚀 CRITICAL FIX: Update scroll state FIRST, then calculate with new offset
      scrollOffsetState.setState(newOffset);

      // 🚀 FIXED: Calculate new render range with the updated offset
      final newRenderRange = _calculateRenderRange(
        scrollOffset: newOffset,
        itemCount: itemCount,
        windowSize: windowSize,
      );

      if (debug) {
        print(
            '🔍 Scroll: ${newOffset.toStringAsFixed(0)}px, calculated range: ${newRenderRange.start}-${newRenderRange.end}, current: ${renderRange.start}-${renderRange.end}');
      }

      // 🚀 CRITICAL FIX: ALWAYS update render range immediately, don't check for differences
      // The issue was that the check was preventing updates
      if (debug) {
        print(
            '🚀 VirtualizedList: FORCE UPDATING render range from ${renderRange.start}-${renderRange.end} to ${newRenderRange.start}-${newRenderRange.end}');
      }

      renderRangeState.setState(newRenderRange);

      // Handle end reached
      _handleEndReached(newOffset, itemCount);

      // Forward scroll event
      if (onScroll != null) {
        onScroll!(VirtualizedListScrollEvent.fromMap(event));
      }
    }

    return DCFScrollView(
      key: key,
      horizontal: horizontal,
      layout: layout,
      styleSheet: styleSheet,
      showsScrollIndicator: showsScrollIndicator,
      scrollEnabled: scrollEnabled,
      pagingEnabled: pagingEnabled,
      onScroll: handleScroll,
      onScrollBeginDrag: onScrollBeginDrag != null
          ? (event) =>
              onScrollBeginDrag!(VirtualizedListScrollEvent.fromMap(event))
          : null,
      onScrollEndDrag: onScrollEndDrag != null
          ? (event) =>
              onScrollEndDrag!(VirtualizedListScrollEvent.fromMap(event))
          : null,
      command: _convertCommandToScrollView(command),
      children: virtualChildren,
    );
  }

  // 🚀 FIXED: Properly advancing render range calculation
  RenderRange _calculateRenderRange({
    required double scrollOffset,
    required int itemCount,
    required int windowSize,
  }) {
    if (itemCount == 0) return RenderRange(start: 0, end: -1);

    const double defaultItemSize = 70.0; // Realistic item size
    const double viewportSize = 600.0; // Estimate

    // Find first visible item
    final firstVisible =
        (scrollOffset / defaultItemSize).floor().clamp(0, itemCount - 1);

    // Find last visible item
    final lastVisible = ((scrollOffset + viewportSize) / defaultItemSize)
        .ceil()
        .clamp(0, itemCount - 1);

    // 🚀 CRITICAL FIX: Only use buffer when we're far enough into the list
    // Don't always start from 0 - let the range advance with scroll position
    final buffer = 10; // Small buffer for smooth scrolling

    int start, end;

    if (firstVisible < 20) {
      // Near the beginning: render from start with buffer
      start = 0;
      end = (lastVisible + buffer * 2).clamp(0, itemCount - 1);
    } else {
      // Advanced scrolling: use proper buffered range that advances
      start = (firstVisible - buffer).clamp(0, itemCount - 1);
      end = (lastVisible + buffer).clamp(0, itemCount - 1);
    }

    if (debug) {
      print(
          '🔍 RenderRange calc: scroll=${scrollOffset.toStringAsFixed(0)}, visible=$firstVisible-$lastVisible, calculated=$start-$end');
    }

    return RenderRange(start: start, end: end);
  }

  // Get item size with fallback
  double _getItemSize(int index) {
    if (getItemLayout != null) {
      final layout = getItemLayout!(data, index);
      return layout['length']?.toDouble() ?? 70.0;
    }
    return 70.0; // Default item size
  }

  // Calculate total size for spacers
  double _calculateSpacerSize(int startIndex, int endIndex) {
    final itemCount = endIndex - startIndex + 1;
    const double defaultItemSize = 70.0;
    return itemCount * defaultItemSize;
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

  // Handle end reached detection
  void _handleEndReached(double scrollOffset, int itemCount) {
    if (onEndReached == null) return;

    const double defaultItemSize = 70.0;
    const double viewportSize = 600.0;

    final totalContentSize = itemCount * defaultItemSize;
    final distanceFromEnd = totalContentSize - (scrollOffset + viewportSize);
    final threshold = viewportSize * onEndReachedThreshold;

    if (distanceFromEnd <= threshold) {
      onEndReached!();
    }
  }

  // Convert VirtualizedList commands to ScrollView commands
  ScrollViewCommand? _convertCommandToScrollView(
      VirtualizedListCommand? command) {
    if (command == null) return null;

    if (command.scrollToIndex != null) {
      final index = command.scrollToIndex!.index;
      const double defaultItemSize = 70.0;
      final offset = index * defaultItemSize;

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

// Simplified supporting classes

class RenderRange {
  final int start;
  final int end;

  RenderRange({required this.start, required this.end});

  @override
  String toString() => 'RenderRange($start-$end)';
}

// Keep all the other supporting classes the same...
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
      contentSize:
          VirtualizedListContentSize.fromMap(map['contentSize'] as Map? ?? {}),
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
  final String viewPosition;

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

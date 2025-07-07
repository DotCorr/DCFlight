/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';

/// VirtualizedList - High-performance list component with viewport-based rendering
/// Only renders visible items for optimal memory usage and smooth scrolling
class DCFVirtualizedList extends StatefulComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Total number of items in the list
  final int itemCount;

  /// Function to render each item
  final DCFComponentNode Function(int index, VirtualizedListItemInfo info)
      renderItem;

  /// Function to get the size of each item
  final double Function(int index)? getItemSize;

  /// Whether to scroll horizontally
  final bool horizontal;

  /// Initial number of items to render
  final int initialNumToRender;

  /// Maximum number of items to render per batch
  final int maxToRenderPerBatch;

  /// Size of the render window (in items)
  final int windowSize;

  /// Whether to remove clipped subviews for memory optimization
  final bool removeClippedSubviews;

  /// Whether to maintain visible content position during updates
  final bool maintainVisibleContentPosition;

  /// Whether the list is inverted (items rendered from bottom to top)
  final bool inverted;

  /// Estimated size of each item (used for initial calculations)
  final double estimatedItemSize;

  /// Layout and style properties
  final LayoutProps layout;
  final StyleSheet styleSheet;

  /// Scroll behavior properties
  final bool showsScrollIndicator;
  final bool scrollEnabled;
  final bool bounces;
  final bool pagingEnabled;

  /// Event handlers
  final Function(VirtualizedListScrollEvent)? onScroll;
  final Function(VirtualizedListScrollEvent)? onScrollBeginDrag;
  final Function(VirtualizedListScrollEvent)? onScrollEndDrag;
  final Function(VirtualizedListScrollEvent)? onMomentumScrollEnd;
  final Function(VirtualizedListScrollEvent)? onScrollEnd;
  final Function(VirtualizedListViewabilityInfo)? onViewableItemsChanged;
  final Function(int index)? onEndReached;
  final Function(int index)? onEndReachedThreshold;

  /// Commands for imperative operations
  final VirtualizedListCommand? command;

  /// Additional props for customization
  final Map<String, dynamic>? additionalProps;

  /// Callback for when items are rendered
  final Function(List<int> renderedIndices)? onItemsRendered;

  /// Callback for performance metrics
  final Function(VirtualizedListMetrics)? onMetrics;

  /// Key extractor for item identification
  final String Function(int index)? keyExtractor;

  /// Whether to enable debug mode
  final bool debug;

  DCFVirtualizedList({
    required this.itemCount,
    required this.renderItem,
    this.getItemSize,
    this.horizontal = false,
    this.initialNumToRender = 10,
    this.maxToRenderPerBatch = 10,
    this.windowSize = 21,
    this.removeClippedSubviews = true,
    this.maintainVisibleContentPosition = false,
    this.inverted = false,
    this.estimatedItemSize = 44.0,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.showsScrollIndicator = true,
    this.scrollEnabled = true,
    this.bounces = true,
    this.pagingEnabled = false,
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onMomentumScrollEnd,
    this.onScrollEnd,
    this.onViewableItemsChanged,
    this.onEndReached,
    this.onEndReachedThreshold,
    this.command,
    this.additionalProps,
    this.onItemsRendered,
    this.onMetrics,
    this.keyExtractor,
    this.debug = false,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final metricsState = useState<VirtualizedListMetrics?>(null, 'metrics');
    final scrollOffsetState = useState<double>(0.0, 'scrollOffset');
    final visibleItemsState = useState<List<int>>([], 'visibleItems');

    // Build event handlers
    final eventHandlers = <String, dynamic>{};

    if (onScroll != null) {
      eventHandlers['onScroll'] = (Map<dynamic, dynamic> data) {
        final event = VirtualizedListScrollEvent.fromMap(data);
        scrollOffsetState.setState(
            horizontal ? event.contentOffset.x : event.contentOffset.y);
        onScroll!(event);
      };
    }

    if (onScrollBeginDrag != null) {
      eventHandlers['onScrollBeginDrag'] = (Map<dynamic, dynamic> data) {
        final event = VirtualizedListScrollEvent.fromMap(data);
        onScrollBeginDrag!(event);
      };
    }

    if (onScrollEndDrag != null) {
      eventHandlers['onScrollEndDrag'] = (Map<dynamic, dynamic> data) {
        final event = VirtualizedListScrollEvent.fromMap(data);
        onScrollEndDrag!(event);
      };
    }

    if (onMomentumScrollEnd != null) {
      eventHandlers['onMomentumScrollEnd'] = (Map<dynamic, dynamic> data) {
        final event = VirtualizedListScrollEvent.fromMap(data);
        onMomentumScrollEnd!(event);
      };
    }

    if (onScrollEnd != null) {
      eventHandlers['onScrollEnd'] = (Map<dynamic, dynamic> data) {
        final event = VirtualizedListScrollEvent.fromMap(data);
        onScrollEnd!(event);
      };
    }

    // Performance metrics callback
    if (onMetrics != null) {
      eventHandlers['onMetrics'] = (Map<dynamic, dynamic> data) {
        final metrics = VirtualizedListMetrics.fromMap(data);
        metricsState.setState(metrics);
        onMetrics!(metrics);
      };
    }

    // Viewable items callback
    if (onViewableItemsChanged != null) {
      eventHandlers['onViewableItemsChanged'] = (Map<dynamic, dynamic> data) {
        final info = VirtualizedListViewabilityInfo.fromMap(data);
        final visibleIndices =
            info.viewableItems.map((item) => item.index).toList();
        visibleItemsState.setState(visibleIndices);
        onViewableItemsChanged!(info);
      };
    }

    // Items rendered callback
    if (onItemsRendered != null) {
      eventHandlers['onItemsRendered'] = (Map<dynamic, dynamic> data) {
        final renderedIndices =
            (data['renderedIndices'] as List?)?.cast<int>() ?? [];
        onItemsRendered!(renderedIndices);
      };
    }

    // Build props
    final props = <String, dynamic>{
      // Core virtualization props
      'itemCount': itemCount,
      'getItemSize': getItemSize?.toString() ?? '',
      'renderItem': renderItem.toString(),
      'horizontal': horizontal,
      'initialNumToRender': initialNumToRender,
      'maxToRenderPerBatch': maxToRenderPerBatch,
      'windowSize': windowSize,
      'removeClippedSubviews': removeClippedSubviews,
      'maintainVisibleContentPosition': maintainVisibleContentPosition,
      'inverted': inverted,
      'estimatedItemSize': estimatedItemSize,

      // Scroll behavior
      'showsScrollIndicator': showsScrollIndicator,
      'scrollEnabled': scrollEnabled,
      'bounces': bounces,
      'pagingEnabled': pagingEnabled,

      // Layout and style
      ...layout.toMap(),
      ...styleSheet.toMap(),

      // Event handlers
      ...eventHandlers,

      // Debug mode
      'debug': debug,

      // Key extractor
      if (keyExtractor != null) 'keyExtractor': keyExtractor.toString(),

      // Additional props
      if (additionalProps != null) ...additionalProps!,
    };

    // Add command if present
    if (command != null && command!.hasCommands) {
      props['command'] = command!.toMap();
    }

    return DCFElement(
      type: 'VirtualizedList',
      props: props,
      children: [], // VirtualizedList manages its own children
    );
  }

  @override
  List<Object?> get props => [
        itemCount,
        renderItem,
        getItemSize,
        horizontal,
        initialNumToRender,
        maxToRenderPerBatch,
        windowSize,
        removeClippedSubviews,
        maintainVisibleContentPosition,
        inverted,
        estimatedItemSize,
        layout,
        styleSheet,
        showsScrollIndicator,
        scrollEnabled,
        bounces,
        pagingEnabled,
        onScroll,
        onScrollBeginDrag,
        onScrollEndDrag,
        onMomentumScrollEnd,
        onScrollEnd,
        onViewableItemsChanged,
        onEndReached,
        onEndReachedThreshold,
        command,
        additionalProps,
        onItemsRendered,
        onMetrics,
        keyExtractor,
        debug,
        key,
      ];
}

/// Information passed to renderItem function
class VirtualizedListItemInfo {
  final int index;
  final bool isViewable;
  final double offset;
  final double size;
  final Map<String, dynamic> metadata;

  VirtualizedListItemInfo({
    required this.index,
    required this.isViewable,
    required this.offset,
    required this.size,
    this.metadata = const {},
  });

  factory VirtualizedListItemInfo.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListItemInfo(
      index: map['index'] as int,
      isViewable: map['isViewable'] as bool? ?? false,
      offset: (map['offset'] as num?)?.toDouble() ?? 0.0,
      size: (map['size'] as num?)?.toDouble() ?? 0.0,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'isViewable': isViewable,
      'offset': offset,
      'size': size,
      'metadata': metadata,
    };
  }
}

/// Scroll event data
class VirtualizedListScrollEvent {
  final VirtualizedListContentOffset contentOffset;
  final VirtualizedListContentSize contentSize;
  final VirtualizedListLayoutMeasurement layoutMeasurement;
  final double zoomScale;
  final double velocity;

  VirtualizedListScrollEvent({
    required this.contentOffset,
    required this.contentSize,
    required this.layoutMeasurement,
    this.zoomScale = 1.0,
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
      zoomScale: (map['zoomScale'] as num?)?.toDouble() ?? 1.0,
      velocity: (map['velocity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Content offset data
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

/// Content size data
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

/// Layout measurement data
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

/// Viewability information
class VirtualizedListViewabilityInfo {
  final List<VirtualizedListViewableItem> viewableItems;
  final List<VirtualizedListViewableItem> changed;

  VirtualizedListViewabilityInfo({
    required this.viewableItems,
    required this.changed,
  });

  factory VirtualizedListViewabilityInfo.fromMap(Map<dynamic, dynamic> map) {
    final viewableItemsData = map['viewableItems'] as List? ?? [];
    final changedData = map['changed'] as List? ?? [];

    return VirtualizedListViewabilityInfo(
      viewableItems: viewableItemsData
          .map((item) => VirtualizedListViewableItem.fromMap(item as Map))
          .toList(),
      changed: changedData
          .map((item) => VirtualizedListViewableItem.fromMap(item as Map))
          .toList(),
    );
  }
}

/// Viewable item data
class VirtualizedListViewableItem {
  final int index;
  final String key;
  final bool isViewable;
  final double visiblePercentage;

  VirtualizedListViewableItem({
    required this.index,
    required this.key,
    required this.isViewable,
    required this.visiblePercentage,
  });

  factory VirtualizedListViewableItem.fromMap(Map<dynamic, dynamic> map) {
    return VirtualizedListViewableItem(
      index: map['index'] as int,
      key: map['key'] as String? ?? '',
      isViewable: map['isViewable'] as bool? ?? false,
      visiblePercentage: (map['visiblePercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Performance metrics
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

  Map<String, dynamic> toMap() {
    return {
      'totalItems': totalItems,
      'renderedItems': renderedItems,
      'memoryUsage': memoryUsage,
      'averageItemSize': averageItemSize,
      'scrollVelocity': scrollVelocity,
      'recycledViews': recycledViews,
      'renderTimeMs': renderTime.inMilliseconds,
    };
  }
}

/// Commands for imperative operations
class VirtualizedListCommand {
  final ScrollToIndexCommand? scrollToIndex;
  final ScrollToOffsetCommand? scrollToOffset;
  final bool? flashScrollIndicators;
  final bool? recordInteraction;
  final RefreshCommand? refresh;

  VirtualizedListCommand({
    this.scrollToIndex,
    this.scrollToOffset,
    this.flashScrollIndicators,
    this.recordInteraction,
    this.refresh,
  });

  bool get hasCommands {
    return scrollToIndex != null ||
        scrollToOffset != null ||
        flashScrollIndicators == true ||
        recordInteraction == true ||
        refresh != null;
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> commandMap = {};

    if (scrollToIndex != null) {
      commandMap['scrollToIndex'] = scrollToIndex!.toMap();
    }

    if (scrollToOffset != null) {
      commandMap['scrollToOffset'] = scrollToOffset!.toMap();
    }

    if (flashScrollIndicators == true) {
      commandMap['flashScrollIndicators'] = true;
    }

    if (recordInteraction == true) {
      commandMap['recordInteraction'] = true;
    }

    if (refresh != null) {
      commandMap['refresh'] = refresh!.toMap();
    }

    return commandMap;
  }
}

/// Scroll to index command
class ScrollToIndexCommand {
  final int index;
  final bool animated;
  final String viewPosition; // 'auto', 'start', 'center', 'end'

  ScrollToIndexCommand({
    required this.index,
    this.animated = true,
    this.viewPosition = 'auto',
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'animated': animated,
      'viewPosition': viewPosition,
    };
  }
}

/// Scroll to offset command
class ScrollToOffsetCommand {
  final double offset;
  final bool animated;

  ScrollToOffsetCommand({
    required this.offset,
    this.animated = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'offset': offset,
      'animated': animated,
    };
  }
}

/// Refresh command
class RefreshCommand {
  final bool maintainScrollPosition;
  final List<int>? specificIndices;

  RefreshCommand({
    this.maintainScrollPosition = true,
    this.specificIndices,
  });

  Map<String, dynamic> toMap() {
    return {
      'maintainScrollPosition': maintainScrollPosition,
      if (specificIndices != null) 'specificIndices': specificIndices,
    };
  }
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'virtualization/virtualization_engine.dart';
import 'virtualization/types.dart';

/// DCFFlatList - High-performance virtualized list component
/// Uses intelligent virtualization for 60+ FPS scrolling with thousands of items
class DCFFlatList<T> extends StatefulComponent {
  final List<T> data;
  final LayoutProps? layout;
  final DCFComponentNode Function(T item, int index) renderItem;
  
  // Virtualization settings
  final String Function(T item, int index)? getItemType;
  final double? estimatedItemSize;
  final VirtualizationConfig? virtualizationConfig;
  
  // Native scroll view props
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
  
  // Event handlers
  final Function(Map<dynamic, dynamic>)? onScroll;
  final Function(Map<dynamic, dynamic>)? onScrollBeginDrag;
  final Function(Map<dynamic, dynamic>)? onScrollEndDrag;
  final Function(Map<dynamic, dynamic>)? onMomentumScrollBegin;
  final Function(Map<dynamic, dynamic>)? onMomentumScrollEnd;
  final Function(Map<dynamic, dynamic>)? onContentSizeChange;
  
  // List-specific features
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
  
  // Commands
  final FlatListCommand? command;

  DCFFlatList({
    super.key,
    required this.data,
    this.layout = const LayoutProps(flex: 1),
    required this.renderItem,
    this.getItemType,
    this.estimatedItemSize,
    this.virtualizationConfig,
    this.orientation = DCFListOrientation.vertical,
    this.inverted = false,
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
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onMomentumScrollBegin,
    this.onMomentumScrollEnd,
    this.onContentSizeChange,
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
    this.command,
  });

  @override
  DCFComponentNode render() {
    // Initialize virtualization engine
    final engine = useState<VirtualizationEngine<T>?>(null);
    final scrollOffset = useState(0.0);
    
    // Initialize engine on first render
    useEffect(() {
      if (engine.state == null) {
        final newEngine = VirtualizationEngine<T>(
          config: virtualizationConfig ??  VirtualizationConfig(),
        );
        
        // Initialize with current data
        newEngine.initialize(
          data: data,
          viewportHeight: 600.0, // Will be updated from scroll events
          viewportWidth: 400.0,   // Will be updated from scroll events
          isHorizontal: orientation == DCFListOrientation.horizontal,
          estimatedItemSize: estimatedItemSize,
          getItemType: getItemType,
        );
        
        engine.setState(newEngine);
      }
      
      return null;
    }, dependencies:[data.length]);
    
    // Handle scroll events and update virtualization
    void handleScroll(Map<dynamic, dynamic> event) {
      final contentOffset = event['contentOffset'] as Map<String, dynamic>?;
      if (contentOffset != null && engine.state != null) {
        final offset = orientation == DCFListOrientation.horizontal
            ? (contentOffset['x'] as double? ?? 0.0)
            : (contentOffset['y'] as double? ?? 0.0);
        
        scrollOffset.setState(offset);
        engine.state!.updateScrollPosition(offset);
      }
      
      // Call user's onScroll handler
      onScroll?.call(event);
    }
    
    // Build virtualized children
    final children = engine.state?.buildVirtualizedChildren<T>(
      data: data,
      renderItem: renderItem,
      getItemType: getItemType,
      header: header,
      footer: footer,
      separator: separator,
      empty: empty,
    ) ?? _buildFallbackChildren();

    return DCFElement(
      type: 'FlatList', // Use the correct registered component name
      key: key,
      props: {
        // Native scroll view props
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
        ...?layout?.toMap(),
        
        // Event handlers - onScroll is wrapped to handle virtualization
        'onScroll': handleScroll,
        if (onScrollBeginDrag != null) 'onScrollBeginDrag': onScrollBeginDrag,
        if (onScrollEndDrag != null) 'onScrollEndDrag': onScrollEndDrag,
        if (onMomentumScrollBegin != null) 'onMomentumScrollBegin': onMomentumScrollBegin,
        if (onMomentumScrollEnd != null) 'onMomentumScrollEnd': onMomentumScrollEnd,
        if (onContentSizeChange != null) 'onContentSizeChange': onContentSizeChange,
        
        // Commands
        if (command != null) 'command': command!.toMap(),
        
        // Performance optimization hints for native side
        'isVirtualized': true,
        'estimatedItemSize': estimatedItemSize ?? 50.0,
        'itemCount': data.length,
      },
      children: children,
    );
  }
  
  /// Fallback children when virtualization engine isn't ready
  List<DCFComponentNode> _buildFallbackChildren() {
    final children = <DCFComponentNode>[];
    
    // Add header
    if (header != null) {
      children.add(header!);
    }
    
    // Add first 10 items as fallback
    final itemsToShow = data.take(10);
    for (int i = 0; i < itemsToShow.length; i++) {
      final item = itemsToShow.elementAt(i);
      children.add(renderItem(item, i));
      
      // Add separator
      if (separator != null && i < itemsToShow.length - 1) {
        children.add(separator!);
      }
    }
    
    // Add footer
    if (footer != null) {
      children.add(footer!);
    }
    
    // Show empty state if no data
    if (data.isEmpty && empty != null) {
      children.clear();
      children.add(empty!);
    }
    
    return children;
  }
}

/// FlatList orientation enum
enum DCFListOrientation {
  vertical,
  horizontal,
}

/// Content insets for scroll views
class ContentInset {
  final double top;
  final double left;
  final double bottom;
  final double right;

  const ContentInset.all(double value)
      : top = value,
        left = value,
        bottom = value,
        right = value;

  const ContentInset.symmetric({
    double vertical = 0,
    double horizontal = 0,
  })  : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  const ContentInset.only({
    this.top = 0,
    this.left = 0,
    this.bottom = 0,
    this.right = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'top': top,
      'left': left,
      'bottom': bottom,
      'right': right,
    };
  }
}
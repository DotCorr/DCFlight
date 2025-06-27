/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'virtualization/virtualization_engine.dart';
import 'virtualization/types.dart';

/// FlatList orientation enum
enum DCFListOrientation {
  vertical,
  horizontal,
}

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
    final isInitialized = useState(false);
    final lastCommand = useState<FlatListCommand?>(null);
    
    // Create virtualization config
    final config = virtualizationConfig ?? VirtualizationConfig(
      windowSize: 10.5, // Larger window for smooth scrolling
      initialNumToRender: 15, // Start with more items
      maxToRenderPerBatch: 20,
      debug: true, // Enable debug for now
      defaultEstimatedItemSize: estimatedItemSize ?? 50.0,
    );
    
    // Initialize engine on first render or data change
    useEffect(() {
      print('[DCFFlatList] Initializing engine with ${data.length} items');
      
      final newEngine = VirtualizationEngine<T>(config: config);
      
      // Initialize with realistic viewport dimensions
      newEngine.initialize(
        data: data,
        viewportHeight: 600.0, // Default - will be updated from scroll events
        viewportWidth: 400.0,   // Default - will be updated from scroll events
        isHorizontal: orientation == DCFListOrientation.horizontal,
        estimatedItemSize: estimatedItemSize ?? 50.0,
        getItemType: getItemType,
      );
      
      engine.setState(newEngine);
      isInitialized.setState(true);
      
      print('[DCFFlatList] Engine initialized successfully');
      
      return null;
    }, dependencies: [data.length, data.hashCode]);
    
    // Handle scroll events and update virtualization
    void handleScroll(Map<dynamic, dynamic> event) {
      try {
        if (engine.state == null) return;
        
        // Extract scroll data
        final contentOffset = event['contentOffset'] as Map<String, dynamic>?;
        final layoutMeasurement = event['layoutMeasurement'] as Map<String, dynamic>?;
        final contentSize = event['contentSize'] as Map<String, dynamic>?;
        
        if (contentOffset != null) {
          final rawOffset = orientation == DCFListOrientation.horizontal
              ? (contentOffset['x'] as double? ?? 0.0)
              : (contentOffset['y'] as double? ?? 0.0);
          
          // Sanitize the offset
          final offset = _sanitizeDouble(rawOffset);
          
          // Update viewport dimensions if available
          if (layoutMeasurement != null) {
            final viewportHeight = _sanitizeDouble(layoutMeasurement['height'] as double? ?? 600.0);
            final viewportWidth = _sanitizeDouble(layoutMeasurement['width'] as double? ?? 400.0);
            
            // Re-initialize engine with correct dimensions if they changed significantly
            final currentEngine = engine.state!;
            if ((viewportHeight - 600.0).abs() > 50 || (viewportWidth - 400.0).abs() > 50) {
              currentEngine.initialize(
                data: data,
                viewportHeight: viewportHeight,
                viewportWidth: viewportWidth,
                isHorizontal: orientation == DCFListOrientation.horizontal,
                estimatedItemSize: estimatedItemSize ?? 50.0,
                getItemType: getItemType,
              );
            }
          }
          
          // Update scroll position - this triggers virtualization
          scrollOffset.setState(offset);
          engine.state!.updateScrollPosition(offset);
          
          print('[DCFFlatList] Scroll update - Offset: $offset');
        }
        
        // Handle end reached
        if (onEndReached != null && contentOffset != null && contentSize != null && layoutMeasurement != null) {
          final totalHeight = _sanitizeDouble(contentSize['height'] as double? ?? 0.0);
          final viewportHeight = _sanitizeDouble(layoutMeasurement['height'] as double? ?? 600.0);
          final currentOffset = _sanitizeDouble(contentOffset['y'] as double? ?? 0.0);
          
          final threshold = onEndReachedThreshold ?? 0.1;
          final endThreshold = totalHeight - (viewportHeight * (1 + threshold));
          
          if (currentOffset >= endThreshold) {
            onEndReached!();
          }
        }
        
        // Call user's onScroll handler
        onScroll?.call(event);
        
      } catch (e) {
        print('[DCFFlatList] Error in handleScroll: $e');
      }
    }
    
    // Handle commands for scrolling
    useEffect(() {
      if (command != null && command != lastCommand.state) {
        lastCommand.setState(command);
        
        // Process command after a short delay to ensure engine is ready
        Future.delayed(Duration(milliseconds: 100), () {
          _handleCommand(command!, engine.state);
        });
      }
      return null;
    }, dependencies: [command]);
    
    // Build virtualized children - this is the key fix
    List<DCFComponentNode> buildChildren() {
      if (!isInitialized.state || engine.state == null || data.isEmpty) {
        print('[DCFFlatList] Using fallback rendering - initialized: ${isInitialized.state}, engine: ${engine.state != null}, data: ${data.length}');
        return _buildFallbackChildren();
      }
      
      try {
        // Build virtualized children using the engine
        final children = engine.state!.buildVirtualizedChildren<T>(
          data: data,
          renderItem: renderItem,
          getItemType: getItemType,
          header: header,
          footer: footer,
          separator: separator,
          empty: empty,
        );
        
        print('[DCFFlatList] Built ${children.length} virtualized children');
        return children;
        
      } catch (e) {
        print('[DCFFlatList] Error building virtualized children: $e');
        return _buildFallbackChildren();
      }
    }

    return DCFElement(
      type: 'FlatList', 
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
        'estimatedItemSize': _sanitizeDouble(estimatedItemSize ?? 50.0),
        'itemCount': data.length,
        'totalContentHeight': _calculateTotalContentHeight(),
      },
      children: buildChildren(),
    );
  }
  
  /// Handle scroll commands
  void _handleCommand(FlatListCommand command, VirtualizationEngine<T>? engine) {
    if (engine == null) {
      print('[DCFFlatList] Cannot execute command - engine not ready');
      return;
    }
    
    print('[DCFFlatList] Executing command: ${command.runtimeType}');
    
    if (command is ScrollToIndexCommand) {
      final index = command.index;
      if (index >= 0 && index < data.length) {
        // Calculate approximate offset for the index
        final estimatedSize = estimatedItemSize ?? 50.0;
        final approximateOffset = index * estimatedSize;
        
        print('[DCFFlatList] Scrolling to index $index (approximate offset: $approximateOffset)');
        
        // First, update the virtualization to ensure the item will be rendered
        engine.updateScrollPosition(approximateOffset);
        
        // Note: The actual scrolling is handled by the native side through the command prop
      }
    }
    // Other commands (ScrollToTop, ScrollToBottom) are handled by native side
  }
  
  /// Calculate total content height for native side
  double _calculateTotalContentHeight() {
    if (data.isEmpty) return 0.0;
    
    final itemSize = estimatedItemSize ?? 50.0;
    var totalHeight = data.length * itemSize;
    
    // Add header/footer heights if present
    if (header != null) totalHeight += itemSize;
    if (footer != null) totalHeight += itemSize;
    
    return _sanitizeDouble(totalHeight);
  }
  
  /// Fallback children when virtualization engine isn't ready - show more items initially
  List<DCFComponentNode> _buildFallbackChildren() {
    final children = <DCFComponentNode>[];
    
    // Add header
    if (header != null) {
      children.add(header!);
    }
    
    // Show more items in fallback (30 instead of 10)
    final itemsToShow = data.take(30);
    for (int i = 0; i < itemsToShow.length; i++) {
      final item = itemsToShow.elementAt(i);
      try {
        children.add(renderItem(item, i));
        
        // Add separator
        if (separator != null && i < itemsToShow.length - 1) {
          children.add(separator!);
        }
      } catch (e) {
        print('[DCFFlatList] Error rendering fallback item $i: $e');
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
    
    print('[DCFFlatList] Built ${children.length} fallback children');
    return children;
  }
  
  /// Sanitize double values to prevent JSON serialization errors
  double _sanitizeDouble(double value) {
    if (value.isInfinite || value.isNaN) {
      return 0.0;
    }
    // Clamp very large values
    return value.clamp(-1e6, 1e6);
  }
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
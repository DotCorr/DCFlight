/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'scroll_content_view_component.dart';

/// Scroll view scroll callback data
class DCFScrollViewScrollData {
  /// Current scroll position X
  final double scrollX;
  
  /// Current scroll position Y
  final double scrollY;
  
  /// Timestamp of the scroll event
  final DateTime timestamp;

  DCFScrollViewScrollData({
    required this.scrollX,
    required this.scrollY,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFScrollViewScrollData.fromMap(Map<dynamic, dynamic> data) {
    // iOS sends contentOffset.x/y, Android should match
    final contentOffset = data['contentOffset'] as Map<dynamic, dynamic>?;
    final scrollXValue = contentOffset?['x'] ?? data['scrollX'];
    final scrollYValue = contentOffset?['y'] ?? data['scrollY'];
    
    final scrollX = (scrollXValue as num?)?.toDouble() ?? 0.0;
    final scrollY = (scrollYValue as num?)?.toDouble() ?? 0.0;
    
    return DCFScrollViewScrollData(
      scrollX: scrollX,
      scrollY: scrollY,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Scroll view drag start callback data
class DCFScrollViewDragStartData {
  /// Whether the drag was from user interaction
  final bool fromUser;
  
  /// Timestamp of the drag start
  final DateTime timestamp;

  DCFScrollViewDragStartData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFScrollViewDragStartData.fromMap(Map<dynamic, dynamic> data) {
    return DCFScrollViewDragStartData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Scroll view drag end callback data
class DCFScrollViewDragEndData {
  /// Whether the drag was from user interaction
  final bool fromUser;
  
  /// Timestamp of the drag end
  final DateTime timestamp;

  DCFScrollViewDragEndData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFScrollViewDragEndData.fromMap(Map<dynamic, dynamic> data) {
    return DCFScrollViewDragEndData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Scroll view scroll end callback data
class DCFScrollViewScrollEndData {
  /// Whether the scroll was from user interaction
  final bool fromUser;
  
  /// Timestamp of the scroll end
  final DateTime timestamp;

  DCFScrollViewScrollEndData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFScrollViewScrollEndData.fromMap(Map<dynamic, dynamic> data) {
    return DCFScrollViewScrollEndData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Scroll view content size change callback data
class DCFScrollViewContentSizeData {
  /// New content width
  final double width;
  
  /// New content height
  final double height;
  
  /// Timestamp of the content size change
  final DateTime timestamp;

  DCFScrollViewContentSizeData({
    required this.width,
    required this.height,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFScrollViewContentSizeData.fromMap(Map<dynamic, dynamic> data) {
    return DCFScrollViewContentSizeData(
      width: (data['width'] as num).toDouble(),
      height: (data['height'] as num).toDouble(),
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Scroll indicator style options
enum DCFScrollIndicatorStyle {
  defaultStyle,
  black,
  white;

  /// Convert to string value for native side
  String get value {
    switch (this) {
      case DCFScrollIndicatorStyle.defaultStyle:
        return 'default';
      case DCFScrollIndicatorStyle.black:
        return 'black';
      case DCFScrollIndicatorStyle.white:
        return 'white';
    }
  }
}

/// Snap to alignment options for scroll view
enum DCFSnapToAlignment {
  start,
  center,
  end;

  /// Convert to string value for native side
  String get value {
    switch (this) {
      case DCFSnapToAlignment.start:
        return 'start';
      case DCFSnapToAlignment.center:
        return 'center';
      case DCFSnapToAlignment.end:
        return 'end';
    }
  }
}

/// DCFScrollView - Optimized scroll view component
/// Uses your native VirtualizedScrollView for best performance
class DCFScrollView extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// Whether to scroll horizontally
  final bool horizontal;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Whether to show scrollbar
  final bool showsScrollIndicator;

  /// Content container style
  final DCFStyleSheet contentContainerStyle;

  /// Event handlers
  final Function(DCFScrollViewScrollData)? onScroll;
  final Function(DCFScrollViewDragStartData)? onScrollBeginDrag;
  final Function(DCFScrollViewDragEndData)? onScrollEndDrag;
  final Function(DCFScrollViewScrollEndData)? onScrollEnd;
  final Function(DCFScrollViewContentSizeData)? onContentSizeChange;
  final Function(DCFScrollViewScrollData)? onMomentumScrollBegin;
  final Function(DCFScrollViewScrollData)? onMomentumScrollEnd;
  
  /// Scroll event throttle (milliseconds between scroll events)
  final double? scrollEventThrottle;

  /// Scroll indicator styling
  /// NOTE: scrollIndicatorColor removed - use StyleSheet.tertiaryColor instead
  final double? scrollIndicatorSize;

  /// Scroll behavior
  final bool scrollEnabled;
  final bool alwaysBounceVertical;
  final bool alwaysBounceHorizontal;
  final bool pagingEnabled;
  final bool keyboardDismissMode;
  final bool bounces;
  final bool bouncesZoom;
  final bool canCancelContentTouches;
  final bool centerContent;
  final bool automaticallyAdjustContentInsets;
  final double? decelerationRate;
  final bool directionalLockEnabled;
  final DCFScrollIndicatorStyle? indicatorStyle;
  final double? maximumZoomScale;
  final double? minimumZoomScale;
  final bool scrollsToTop;
  final double? zoomScale;
  final int? snapToInterval;
  final DCFSnapToAlignment? snapToAlignment;
  final DCFPoint? contentOffset;

  /// Content insets
  final DCFContentInset? contentInset;
  final DCFContentInset? scrollIndicatorInsets;

  /// Command for imperative scroll operations
  final ScrollViewCommand? command;

  /// Additional event handlers map
  final Map<String, dynamic>? events;

  DCFScrollView({
    required this.children,
    this.horizontal = false,
    this.layout = const DCFLayout(flex: 1),
    this.styleSheet = const DCFStyleSheet(),
    this.showsScrollIndicator = true,
    this.contentContainerStyle = const DCFStyleSheet(),
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onScrollEnd,
    this.onContentSizeChange,
    this.onMomentumScrollBegin,
    this.onMomentumScrollEnd,
    // scrollIndicatorColor removed - use StyleSheet.tertiaryColor
    this.scrollIndicatorSize,
    this.scrollEnabled = true,
    this.alwaysBounceVertical = false,
    this.alwaysBounceHorizontal = false,
    this.pagingEnabled = false,
    this.keyboardDismissMode = false,
    this.bounces = true,
    this.bouncesZoom = true,
    this.canCancelContentTouches = true,
    this.centerContent = false,
    this.automaticallyAdjustContentInsets = true,
    this.decelerationRate,
    this.directionalLockEnabled = false,
    this.indicatorStyle,
    this.maximumZoomScale,
    this.minimumZoomScale,
    this.scrollsToTop = true,
    this.zoomScale,
    this.snapToInterval,
    this.snapToAlignment,
    this.contentOffset,
    this.contentInset = const DCFContentInset.all(0),
    this.scrollIndicatorInsets,
    this.scrollEventThrottle,
    this.command,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final eventMap = <String, dynamic>{};

    if (events != null) {
      eventMap.addAll(events!);
    }

    if (onScroll != null) {
      eventMap['onScroll'] = (Map<dynamic, dynamic> data) {
        onScroll!(DCFScrollViewScrollData.fromMap(data));
      };
    }
    if (onScrollBeginDrag != null) {
      eventMap['onScrollBeginDrag'] = (Map<dynamic, dynamic> data) {
        onScrollBeginDrag!(DCFScrollViewDragStartData.fromMap(data));
      };
    }
    if (onScrollEndDrag != null) {
      eventMap['onScrollEndDrag'] = (Map<dynamic, dynamic> data) {
        onScrollEndDrag!(DCFScrollViewDragEndData.fromMap(data));
      };
    }
    if (onScrollEnd != null) {
      eventMap['onScrollEnd'] = (Map<dynamic, dynamic> data) {
        onScrollEnd!(DCFScrollViewScrollEndData.fromMap(data));
      };
    }
    if (onContentSizeChange != null) {
      eventMap['onContentSizeChange'] = (Map<dynamic, dynamic> data) {
        onContentSizeChange!(DCFScrollViewContentSizeData.fromMap(data));
      };
    }
    if (onMomentumScrollBegin != null) {
      eventMap['onMomentumScrollBegin'] = (Map<dynamic, dynamic> data) {
        onMomentumScrollBegin!(DCFScrollViewScrollData.fromMap(data));
      };
    }
    if (onMomentumScrollEnd != null) {
      eventMap['onMomentumScrollEnd'] = (Map<dynamic, dynamic> data) {
        onMomentumScrollEnd!(DCFScrollViewScrollData.fromMap(data));
      };
    }

    final props = <String, dynamic>{
      'horizontal': horizontal,
      'showsScrollIndicator': showsScrollIndicator,
      'scrollEnabled': scrollEnabled,
      'alwaysBounceVertical': alwaysBounceVertical,
      'alwaysBounceHorizontal': alwaysBounceHorizontal,
      'pagingEnabled': pagingEnabled,
      'keyboardDismissMode': keyboardDismissMode,
      'bounces': bounces,
      'bouncesZoom': bouncesZoom,
      'canCancelContentTouches': canCancelContentTouches,
      'centerContent': centerContent,
      'automaticallyAdjustContentInsets': automaticallyAdjustContentInsets,
      'directionalLockEnabled': directionalLockEnabled,
      'scrollsToTop': scrollsToTop,

      if (decelerationRate != null) 'decelerationRate': decelerationRate,
      if (indicatorStyle != null) 'indicatorStyle': indicatorStyle!.value,
      if (maximumZoomScale != null) 'maximumZoomScale': maximumZoomScale,
      if (minimumZoomScale != null) 'minimumZoomScale': minimumZoomScale,
      if (zoomScale != null) 'zoomScale': zoomScale,
      if (snapToInterval != null) 'snapToInterval': snapToInterval,
      if (snapToAlignment != null) 'snapToAlignment': snapToAlignment!.value,
      if (contentOffset != null) 'contentOffset': contentOffset!.toMap(),
      if (contentInset != null) 'contentInset': contentInset!.toMap(),
      if (scrollIndicatorInsets != null) 'scrollIndicatorInsets': scrollIndicatorInsets!.toMap(),
      if (scrollEventThrottle != null) 'scrollEventThrottle': scrollEventThrottle,
      // scrollIndicatorColor removed - native components use StyleSheet.tertiaryColor
      if (scrollIndicatorSize != null) 'scrollIndicatorSize': scrollIndicatorSize,
      'contentContainerStyle': contentContainerStyle.toMap(),

      ...layout.toMap(),
      ...styleSheet.toMap(),

      ...eventMap,
    };

    if (command != null && command!.hasCommands) {
      props['command'] = command!.toMap();
    }

    // CRITICAL: Automatically wrap children in ScrollContentView behind the scenes
    // ScrollView automatically wraps content for proper scrolling behavior
    // Users should NOT use DCFScrollContentView directly - it's internal
    DCFComponentNode contentView;
    
    // Check if first child is already a ScrollContentView (backwards compat)
    if (children.isNotEmpty && children.first is DCFElement) {
      final firstElement = children.first as DCFElement;
      if (firstElement.type == 'ScrollContentView') {
        // User manually provided ScrollContentView - use it directly (backwards compat)
        contentView = firstElement;
      } else {
        // Wrap all children in ScrollContentView automatically
        contentView = DCFScrollContentView(
          layout: DCFLayout(
            width: '100%',
            flexDirection: DCFFlexDirection.column, // Explicitly set column layout
            flexShrink: 0, // Do not shrink, allow growing to fit content
            // CRITICAL: Do NOT set flex: 1 or height - let it grow based on children's layout
            // flex: 1 would make it fill available height, preventing scrolling
            // Setting height: '100%' would constrain it to ScrollView's height, preventing scrolling
          ),
          styleSheet: contentContainerStyle,
          children: children,
        ).render();
      }
    } else {
      // Wrap all children in ScrollContentView automatically
      contentView = DCFScrollContentView(
        layout: DCFLayout(
          width: '100%',
          // CRITICAL: Do NOT set flex: 1 or height - let it grow based on children's layout
          // flex: 1 would make it fill available height, preventing scrolling
          // Setting height: '100%' would constrain it to ScrollView's height, preventing scrolling
        ),
        styleSheet: contentContainerStyle,
        children: children,
      ).render();
    }

    return DCFElement(
      type: 'ScrollView', // Use the correct registered component name
      elementProps: props,
      children: [contentView], // ScrollView's only child is ScrollContentView (auto-wrapped)
    );
  }
}

/// Content insets for scroll views
class DCFContentInset {
  final double top;
  final double left;
  final double bottom;
  final double right;

  const DCFContentInset.all(double value)
      : top = value,
        left = value,
        bottom = value,
        right = value;

  const DCFContentInset.symmetric({
    double vertical = 0,
    double horizontal = 0,
  })  : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  const DCFContentInset.only({
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

/// Point with x and y coordinates
class DCFPoint {
  final double x;
  final double y;

  const DCFPoint({
    required this.x,
    required this.y,
  });

  const DCFPoint.zero()
      : x = 0,
        y = 0;

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
    };
  }
}

/// Command to scroll to a specific position
class ScrollToPositionCommand {
  final double x;
  final double y;
  final bool animated;

  const ScrollToPositionCommand({
    required this.x,
    required this.y,
    this.animated = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'animated': animated,
    };
  }
}

/// Command to scroll to the top of the scroll view
class ScrollToTopCommand {
  final bool animated;

  const ScrollToTopCommand({this.animated = true});

  Map<String, dynamic> toMap() {
    return {
      'animated': animated,
    };
  }
}

/// Command to scroll to the bottom of the scroll view
class ScrollToBottomCommand {
  final bool animated;

  const ScrollToBottomCommand({this.animated = true});

  Map<String, dynamic> toMap() {
    return {
      'animated': animated,
    };
  }
}

/// Command to set explicit content size (for VirtualizedScrollView)
class SetContentSizeCommand {
  final double width;
  final double height;

  const SetContentSizeCommand({
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
    };
  }
}

/// Command to flash scroll indicators to indicate scrollable content
class FlashScrollIndicatorsCommand {
  const FlashScrollIndicatorsCommand();

  Map<String, dynamic> toMap() {
    return {
      'type': 'flashScrollIndicators',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is FlashScrollIndicatorsCommand;
  }

  @override
  int get hashCode => 'flashScrollIndicators'.hashCode;
}

/// Composite command class for multiple scroll actions
class ScrollViewCommand {
  final ScrollToPositionCommand? scrollToPosition;
  final ScrollToTopCommand? scrollToTop;
  final ScrollToBottomCommand? scrollToBottom;
  final bool? flashScrollIndicators;
  final bool? updateContentSize;
  final SetContentSizeCommand? setContentSize;

  const ScrollViewCommand({
    this.scrollToPosition,
    this.scrollToTop,
    this.scrollToBottom,
    this.flashScrollIndicators,
    this.updateContentSize,
    this.setContentSize,
  });

  /// Convert command to props map for native consumption
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> commandMap = {};

    if (scrollToPosition != null) {
      commandMap['scrollToPosition'] = scrollToPosition!.toMap();
    }

    if (scrollToTop != null) {
      commandMap['scrollToTop'] = scrollToTop!.toMap();
    }

    if (scrollToBottom != null) {
      commandMap['scrollToBottom'] = scrollToBottom!.toMap();
    }

    if (flashScrollIndicators == true) {
      commandMap['flashScrollIndicators'] = true;
    }

    if (updateContentSize == true) {
      commandMap['updateContentSize'] = true;
    }

    if (setContentSize != null) {
      commandMap['setContentSize'] = setContentSize!.toMap();
    }

    return commandMap;
  }

  /// Check if this command has any actions to execute
  bool get hasCommands {
    return scrollToPosition != null ||
        scrollToTop != null ||
        scrollToBottom != null ||
        flashScrollIndicators == true ||
        updateContentSize == true ||
        setContentSize != null;
  }
}
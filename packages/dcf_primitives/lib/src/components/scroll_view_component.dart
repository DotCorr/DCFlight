/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// Edge insets configuration for scroll views
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

/// A scroll view component implementation using StatelessComponent
class DCFScrollView extends StatelessComponent {
  /// Child nodes
  final List<DCFComponentNode> children;
  
  /// Whether to scroll horizontally
  final bool horizontal;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties
  final StyleSheet styleSheet;
  
  /// Whether to show scrollbar
  final bool showsScrollIndicator;
  
  /// Content container style
  final StyleSheet contentContainerStyle;
  
  /// Event handlers - using Map<dynamic, dynamic> for maximum type safety
  final Map<String, dynamic>? events;
  
  /// Scroll event handler - receives Map<dynamic, dynamic> with contentOffset, contentSize data
  final Function(Map<dynamic, dynamic>)? onScroll;
  
  /// Scroll begin drag event handler - receives Map<dynamic, dynamic> with contentOffset
  final Function(Map<dynamic, dynamic>)? onScrollBeginDrag;
  
  /// Scroll end drag event handler - receives Map<dynamic, dynamic> with contentOffset, willDecelerate
  final Function(Map<dynamic, dynamic>)? onScrollEndDrag;
  
  /// Scroll end event handler - receives Map<dynamic, dynamic> with contentOffset
  final Function(Map<dynamic, dynamic>)? onScrollEnd;
  
  /// Content size change event handler - receives Map<dynamic, dynamic> with width, height
  final Function(Map<dynamic, dynamic>)? onContentSizeChange;
  
  /// Scroll indicator color
  final Color? scrollIndicatorColor;
  
  /// Scroll indicator size/thickness
  final double? scrollIndicatorSize;
  
  /// Whether scrolling is enabled
  final bool scrollEnabled;
  
  /// Whether to always bounce vertically
  final bool alwaysBounceVertical;
  
  /// Whether to always bounce horizontally  
  final bool alwaysBounceHorizontal;
  
  /// Whether to enable paging
  final bool pagingEnabled;
  
  /// Whether to dismiss keyboard on drag
  final bool keyboardDismissMode;
  
  /// Content insets
  final ContentInset? contentInset;
  
  /// Create a scroll view component
  DCFScrollView({
    required this.children,
    this.horizontal = false,
    this.layout = const LayoutProps(padding: 8),
    this.styleSheet = const StyleSheet(),
    this.showsScrollIndicator = true,
    this.contentContainerStyle = const StyleSheet(),
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onScrollEnd,
    this.onContentSizeChange,
    this.scrollIndicatorColor,
    this.scrollIndicatorSize,
    this.scrollEnabled = true,
    this.alwaysBounceVertical = false,
    this.alwaysBounceHorizontal = false,
    this.pagingEnabled = false,
    this.keyboardDismissMode = false,
    this.contentInset,
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Create a comprehensive events map for all callbacks
    Map<String, dynamic> eventMap = <String, dynamic>{};
    
    // Add base events if provided
    if (events != null) {
      eventMap.addAll(events!);
    }
    
    // Add specific event handlers with consistent Map<String, dynamic> signature
    if (onScroll != null) {
      eventMap['onScroll'] = onScroll;
    }
    
    if (onScrollBeginDrag != null) {
      eventMap['onScrollBeginDrag'] = onScrollBeginDrag;
    }
    
    if (onScrollEndDrag != null) {
      eventMap['onScrollEndDrag'] = onScrollEndDrag;
    }
    
    if (onScrollEnd != null) {
      eventMap['onScrollEnd'] = onScrollEnd;
    }
    
    if (onContentSizeChange != null) {
      eventMap['onContentSizeChange'] = onContentSizeChange;
    }

    return DCFElement(
      type: 'ScrollView',
      props: {
        'horizontal': horizontal,
        'showsScrollIndicator': showsScrollIndicator,
        'scrollEnabled': scrollEnabled,
        'alwaysBounceVertical': alwaysBounceVertical,
        'alwaysBounceHorizontal': alwaysBounceHorizontal,
        'pagingEnabled': pagingEnabled,
        'keyboardDismissMode': keyboardDismissMode,
        if (contentInset != null) 'contentInset': contentInset!.toMap(),
        if (scrollIndicatorColor != null) 'scrollIndicatorColor': '#${scrollIndicatorColor!.value.toRadixString(16).padLeft(8, '0')}',
        'scrollIndicatorSize': scrollIndicatorSize,
        'contentContainerStyle': contentContainerStyle.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: children,
    );
  }
}

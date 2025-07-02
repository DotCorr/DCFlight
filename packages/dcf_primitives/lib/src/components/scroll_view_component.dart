/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';

/// DCFScrollView - Optimized scroll view component
/// Uses your native VirtualizedScrollView for best performance
class DCFScrollView extends StatelessComponent with EquatableMixin {
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
  
  /// Event handlers
  final Function(Map<dynamic, dynamic>)? onScroll;
  final Function(Map<dynamic, dynamic>)? onScrollBeginDrag;
  final Function(Map<dynamic, dynamic>)? onScrollEndDrag;
  final Function(Map<dynamic, dynamic>)? onScrollEnd;
  final Function(Map<dynamic, dynamic>)? onContentSizeChange;
  
  /// Scroll indicator styling
  final Color? scrollIndicatorColor;
  final double? scrollIndicatorSize;
  
  /// Scroll behavior
  final bool scrollEnabled;
  final bool alwaysBounceVertical;
  final bool alwaysBounceHorizontal;
  final bool pagingEnabled;
  final bool keyboardDismissMode;
  
  /// Content insets
  final ContentInset? contentInset;
  
  /// Command for imperative scroll operations
  final ScrollViewCommand? command;
  
  /// Additional event handlers map
  final Map<String, dynamic>? events;
  
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
    this.command,
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Build comprehensive events map
    final eventMap = <String, dynamic>{};
    
    // Add base events if provided
    if (events != null) {
      eventMap.addAll(events!);
    }
    
    // Add specific event handlers
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

    // Build props map
    final props = <String, dynamic>{
      // Scroll behavior
      'horizontal': horizontal,
      'showsScrollIndicator': showsScrollIndicator,
      'scrollEnabled': scrollEnabled,
      'alwaysBounceVertical': alwaysBounceVertical,
      'alwaysBounceHorizontal': alwaysBounceHorizontal,
      'pagingEnabled': pagingEnabled,
      'keyboardDismissMode': keyboardDismissMode,
      
      // Styling
      if (contentInset != null) 'contentInset': contentInset!.toMap(),
      if (scrollIndicatorColor != null) 
        'scrollIndicatorColor': '#${scrollIndicatorColor!.value.toRadixString(16).padLeft(8, '0')}',
      'scrollIndicatorSize': scrollIndicatorSize,
      'contentContainerStyle': contentContainerStyle.toMap(),
      
      // Layout and style
      ...layout.toMap(),
      ...styleSheet.toMap(),
      
      // Events
      ...eventMap,
    };
    
    // Add command props if command has actions
    if (command != null && command!.hasCommands) {
      props['command'] = command!.toMap();
    }

    return DCFElement(
      type: 'ScrollView', // Use the correct registered component name
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        children,
        horizontal,
        layout,
        styleSheet,
        showsScrollIndicator,
        contentContainerStyle,
        onScroll,
        onScrollBeginDrag,
        onScrollEndDrag,
        onScrollEnd,
        onContentSizeChange,
        scrollIndicatorColor,
        scrollIndicatorSize,
        scrollEnabled,
        alwaysBounceVertical,
        alwaysBounceHorizontal,
        pagingEnabled,
        keyboardDismissMode,
        contentInset,
        command,
        events,
        key,
      ];
}

/// Content insets for scroll views
class ContentInset extends Equatable {
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

  @override
  List<Object?> get props => [top, left, bottom, right];
}
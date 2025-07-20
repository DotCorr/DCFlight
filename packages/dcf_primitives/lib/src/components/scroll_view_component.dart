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
class DCFScrollView extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

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
  final DCFContentInset? contentInset;

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
        'scrollIndicatorColor':
            '#${scrollIndicatorColor!.value.toRadixString(16).padLeft(8, '0')}',
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
class DCFContentInset extends Equatable {
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

  @override
  List<Object?> get props => [top, left, bottom, right];
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

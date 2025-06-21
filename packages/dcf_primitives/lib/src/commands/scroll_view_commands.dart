/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Commands for controlling ScrollView and VirtualizedScrollView behavior
/// These are declarative commands passed as props to trigger imperative actions

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

/// Main command class for ScrollView and VirtualizedScrollView
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

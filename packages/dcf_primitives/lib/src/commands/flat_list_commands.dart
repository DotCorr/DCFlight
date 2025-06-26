/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for FlatList imperative control
/// These commands are passed as props and trigger native actions without callbacks

/// Base class for all FlatList commands
abstract class FlatListCommand {
  const FlatListCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to scroll to a specific position in the FlatList
class FlatListScrollToPositionCommand extends FlatListCommand {
  final double x;
  final double y;
  final bool animated;
  
  const FlatListScrollToPositionCommand({
    required this.x,
    required this.y,
    this.animated = true,
  });
  
  @override
  String get type => 'scrollToPosition';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'x': x,
    'y': y,
    'animated': animated,
  };
}

/// Command to scroll to the top of the FlatList
class FlatListScrollToTopCommand extends FlatListCommand {
  final bool animated;
  
  const FlatListScrollToTopCommand({this.animated = true});
  
  @override
  String get type => 'scrollToTop';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'animated': animated,
  };
}

/// Command to scroll to the bottom of the FlatList
class FlatListScrollToBottomCommand extends FlatListCommand {
  final bool animated;
  
  const FlatListScrollToBottomCommand({this.animated = true});
  
  @override
  String get type => 'scrollToBottom';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'animated': animated,
  };
}

/// Command to scroll to a specific item index in the FlatList
class ScrollToIndexCommand extends FlatListCommand {
  final int index;
  final bool animated;
  
  const ScrollToIndexCommand({
    required this.index,
    this.animated = true,
  });
  
  @override
  String get type => 'scrollToIndex';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'index': index,
    'animated': animated,
  };
}

/// Command to scroll to a specific item index in the FlatList (prefixed version)
class FlatListScrollToIndexCommand extends FlatListCommand {
  final int index;
  final bool animated;
  
  const FlatListScrollToIndexCommand({
    required this.index,
    this.animated = true,
  });
  
  @override
  String get type => 'scrollToIndex';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'index': index,
    'animated': animated,
  };
}

/// Command to flash the scroll indicators
class FlatListFlashScrollIndicatorsCommand extends FlatListCommand {
  const FlatListFlashScrollIndicatorsCommand();
  
  @override
  String get type => 'flashScrollIndicators';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
  };
}

/// Command to update content size from layout
class FlatListUpdateContentSizeCommand extends FlatListCommand {
  const FlatListUpdateContentSizeCommand();
  
  @override
  String get type => 'updateContentSize';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
  };
}

/// Command to set explicit content size
class FlatListSetContentSizeCommand extends FlatListCommand {
  final double width;
  final double height;
  
  const FlatListSetContentSizeCommand({
    required this.width,
    required this.height,
  });
  
  @override
  String get type => 'setContentSize';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'width': width,
    'height': height,
  };
}

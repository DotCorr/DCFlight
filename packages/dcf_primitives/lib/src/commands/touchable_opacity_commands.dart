/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for TouchableOpacity imperative control
/// These commands are passed as props and trigger native actions without callbacks

/// Base class for all TouchableOpacity commands
abstract class TouchableOpacityCommand {
  const TouchableOpacityCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to set the opacity of the TouchableOpacity
class SetOpacityCommand extends TouchableOpacityCommand {
  final double opacity;
  final double? duration; // Animation duration in seconds
  
  const SetOpacityCommand({
    required this.opacity,
    this.duration,
  });
  
  @override
  String get type => 'setOpacity';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'opacity': opacity,
      if (duration != null) 'duration': duration,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetOpacityCommand && 
           other.opacity == opacity &&
           other.duration == duration;
  }
  
  @override
  int get hashCode => Object.hash(opacity, duration);
  
  @override
  String toString() => 'SetOpacityCommand(opacity: $opacity, duration: $duration)';
}

/// Command to set the highlighted state of the TouchableOpacity
class SetTouchableHighlightedCommand extends TouchableOpacityCommand {
  final bool highlighted;
  
  const SetTouchableHighlightedCommand({
    required this.highlighted,
  });
  
  @override
  String get type => 'setHighlighted';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'highlighted': highlighted,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetTouchableHighlightedCommand && 
           other.highlighted == highlighted;
  }
  
  @override
  int get hashCode => highlighted.hashCode;
  
  @override
  String toString() => 'SetTouchableHighlightedCommand(highlighted: $highlighted)';
}

/// Command to programmatically trigger a press on the TouchableOpacity
class PerformPressCommand extends TouchableOpacityCommand {
  const PerformPressCommand();
  
  @override
  String get type => 'performPress';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerformPressCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'PerformPressCommand()';
}

/// Command to animate the TouchableOpacity to a specific state
class AnimateToStateCommand extends TouchableOpacityCommand {
  final double opacity;
  final double duration; // Animation duration in seconds
  final String curve; // Animation curve (ease, linear, easeIn, easeOut, etc.)
  
  const AnimateToStateCommand({
    required this.opacity,
    this.duration = 0.2,
    this.curve = 'easeInOut',
  });
  
  @override
  String get type => 'animateToState';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'opacity': opacity,
      'duration': duration,
      'curve': curve,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimateToStateCommand && 
           other.opacity == opacity &&
           other.duration == duration &&
           other.curve == curve;
  }
  
  @override
  int get hashCode => Object.hash(opacity, duration, curve);
  
  @override
  String toString() => 'AnimateToStateCommand(opacity: $opacity, duration: $duration, curve: $curve)';
}

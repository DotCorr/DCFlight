/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for Text imperative control
/// These commands are passed as props and trigger native text actions without callbacks

/// Base class for all Text commands
abstract class TextCommand {
  const TextCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to update the text content
class SetTextCommand extends TextCommand {
  final String text;
  final bool? animated; // Whether to animate the text change
  final double? duration; // Animation duration in seconds
  
  const SetTextCommand({
    required this.text,
    this.animated,
    this.duration,
  });
  
  @override
  String get type => 'setText';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'text': text,
      if (animated != null) 'animated': animated,
      if (duration != null) 'duration': duration,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetTextCommand && 
           other.text == text &&
           other.animated == animated &&
           other.duration == duration;
  }
  
  @override
  int get hashCode => Object.hash(text, animated, duration);
  
  @override
  String toString() => 'SetTextCommand(text: $text, animated: $animated, duration: $duration)';
}

/// Command to update the text color
class SetTextColorCommand extends TextCommand {
  final String color; // Hex color string
  final bool? animated; // Whether to animate the color change
  final double? duration; // Animation duration in seconds
  
  const SetTextColorCommand({
    required this.color,
    this.animated,
    this.duration,
  });
  
  @override
  String get type => 'setTextColor';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'color': color,
      if (animated != null) 'animated': animated,
      if (duration != null) 'duration': duration,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetTextColorCommand && 
           other.color == color &&
           other.animated == animated &&
           other.duration == duration;
  }
  
  @override
  int get hashCode => Object.hash(color, animated, duration);
  
  @override
  String toString() => 'SetTextColorCommand(color: $color, animated: $animated, duration: $duration)';
}

/// Command to update the font size
class SetFontSizeCommand extends TextCommand {
  final double fontSize;
  final bool? animated; // Whether to animate the font size change
  final double? duration; // Animation duration in seconds
  
  const SetFontSizeCommand({
    required this.fontSize,
    this.animated,
    this.duration,
  });
  
  @override
  String get type => 'setFontSize';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'fontSize': fontSize,
      if (animated != null) 'animated': animated,
      if (duration != null) 'duration': duration,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetFontSizeCommand && 
           other.fontSize == fontSize &&
           other.animated == animated &&
           other.duration == duration;
  }
  
  @override
  int get hashCode => Object.hash(fontSize, animated, duration);
  
  @override
  String toString() => 'SetFontSizeCommand(fontSize: $fontSize, animated: $animated, duration: $duration)';
}

/// Command to animate text appearance
class AnimateTextCommand extends TextCommand {
  final String animationType; // fade, slide, scale, etc.
  final double duration; // Animation duration in seconds
  final String? direction; // For slide animations (up, down, left, right)
  
  const AnimateTextCommand({
    required this.animationType,
    this.duration = 0.3,
    this.direction,
  });
  
  @override
  String get type => 'animateText';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'animationType': animationType,
      'duration': duration,
      if (direction != null) 'direction': direction,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimateTextCommand && 
           other.animationType == animationType &&
           other.duration == duration &&
           other.direction == direction;
  }
  
  @override
  int get hashCode => Object.hash(animationType, duration, direction);
  
  @override
  String toString() => 'AnimateTextCommand(animationType: $animationType, duration: $duration, direction: $direction)';
}

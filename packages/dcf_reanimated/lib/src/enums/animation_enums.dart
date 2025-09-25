/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Easing curves for animations.
/// 
/// Defines how the animation progresses over time from start to finish.
/// Each curve provides different visual characteristics suitable for different use cases.
enum AnimationCurve {
  /// Constant speed throughout the animation
  /// Best for: Loading indicators, continuous rotations
  linear('linear'),
  
  /// Slow start, accelerating towards the end
  /// Best for: Elements entering the screen, zoom-in effects
  easeIn('easeIn'),
  
  /// Fast start, decelerating towards the end  
  /// Best for: Elements leaving the screen, zoom-out effects
  easeOut('easeOut'),
  
  /// Slow start and end, fast in the middle
  /// Best for: General UI transitions, most versatile option
  easeInOut('easeInOut'),
  
  /// Natural spring physics with bounce
  /// Best for: Interactive elements, playful animations
  spring('spring'),
  
  /// Quick bounce at the beginning
  /// Best for: Attention-grabbing elements, error states
  bounceIn('bounceIn'),
  
  /// Quick bounce at the end
  /// Best for: Success confirmations, completed actions
  bounceOut('bounceOut'),
  
  /// Elastic stretch at the beginning
  /// Best for: Playful UI elements, game interfaces
  elasticIn('elasticIn'),
  
  /// Elastic stretch at the end
  /// Best for: Button presses, interactive feedback
  elasticOut('elasticOut');

  const AnimationCurve(this.value);
  
  /// The string value used internally by the animation system
  final String value;
  
  @override
  String toString() => value;
}

/// Direction for slide animations
enum SlideDirection {
  /// Slide from/to the left
  left('left'),
  
  /// Slide from/to the right
  right('right'),
  
  /// Slide from/to the top
  up('up'),
  
  /// Slide from/to the bottom
  down('down');

  const SlideDirection(this.value);
  
  /// The string value used internally by the animation system
  final String value;
  
  @override
  String toString() => value;
}

/// Repeat behavior for looping animations
enum RepeatMode {
  /// Don't repeat the animation
  none('none'),
  
  /// Repeat the animation from the beginning
  restart('restart'),
  
  /// Reverse the animation direction on each repeat
  reverse('reverse'),
  
  /// Repeat indefinitely
  infinite('infinite');

  const RepeatMode(this.value);
  
  /// The string value used internally by the animation system
  final String value;
  
  @override
  String toString() => value;
}

/// Animation fill modes (how the animation behaves before/after execution)
enum FillMode {
  /// No special behavior
  none('none'),
  
  /// Keep the final animation state after completion
  forwards('forwards'),
  
  /// Apply the initial animation state before starting
  backwards('backwards'),
  
  /// Apply both forwards and backwards behavior
  both('both');

  const FillMode(this.value);
  
  /// The string value used internally by the animation system
  final String value;
  
  @override
  String toString() => value;
}

/// Extension to easily convert AnimationCurve to String for backwards compatibility
extension AnimationCurveExtension on AnimationCurve {
  /// Get the string representation for use in animation configurations
  String get stringValue => value;
}

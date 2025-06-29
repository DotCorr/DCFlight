/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for AnimatedView imperative control
/// These commands are passed as props and trigger native animations without callbacks

/// Base class for all AnimatedView commands
abstract class AnimatedViewCommand {
  const AnimatedViewCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to start an animation with specified parameters
class AnimateCommand extends AnimatedViewCommand {
  final double? duration; // Animation duration in seconds
  final String? curve; // Animation curve (ease, linear, easeIn, easeOut, etc.)
  final double? toScale; // Target scale value
  final double? toOpacity; // Target opacity value
  final double? toTranslateX; // Target X translation
  final double? toTranslateY; // Target Y translation
  final double? toRotation; // Target rotation in radians
  final bool? repeat; // Whether animation should repeat
  final double? delay; // Animation delay in seconds
  
  const AnimateCommand({
    this.duration,
    this.curve,
    this.toScale,
    this.toOpacity,
    this.toTranslateX,
    this.toTranslateY,
    this.toRotation,
    this.repeat,
    this.delay,
  });
  
  @override
  String get type => 'animate';
  
  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': type};
    if (duration != null) map['duration'] = (duration! * 1000).round(); // Convert to ms
    if (curve != null) map['curve'] = curve;
    if (toScale != null) map['toScale'] = toScale;
    if (toOpacity != null) map['toOpacity'] = toOpacity;
    if (toTranslateX != null) map['toTranslateX'] = toTranslateX;
    if (toTranslateY != null) map['toTranslateY'] = toTranslateY;
    if (toRotation != null) map['toRotation'] = toRotation;
    if (repeat != null) map['repeat'] = repeat;
    if (delay != null) map['delay'] = (delay! * 1000).round(); // Convert to ms
    return map;
  }
}

/// Command to reset animation to initial state
class ResetAnimationCommand extends AnimatedViewCommand {
  final bool animated; // Whether to animate back to initial state
  
  const ResetAnimationCommand({this.animated = false});
  
  @override
  String get type => 'reset';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'animated': animated,
  };
}

/// Command to pause current animation
class PauseAnimationCommand extends AnimatedViewCommand {
  const PauseAnimationCommand();
  
  @override
  String get type => 'pause';
  
  @override
  Map<String, dynamic> toMap() => {'type': type};
}

/// Command to resume paused animation
class ResumeAnimationCommand extends AnimatedViewCommand {
  const ResumeAnimationCommand();
  
  @override
  String get type => 'resume';
  
  @override
  Map<String, dynamic> toMap() => {'type': type};
}

/// Command to stop animation at current position
class StopAnimationCommand extends AnimatedViewCommand {
  const StopAnimationCommand();
  
  @override
  String get type => 'stop';
  
  @override
  Map<String, dynamic> toMap() => {'type': type};
}

/// Common animation presets for convenience
class AnimationPresets {
  static const AnimateCommand fadeIn = AnimateCommand(
    toOpacity: 1.0,
    duration: 0.3,
    curve: 'easeOut',
  );
  
  static const AnimateCommand fadeOut = AnimateCommand(
    toOpacity: 0.0,
    duration: 0.3,
    curve: 'easeIn',
  );
  
  static const AnimateCommand scaleUp = AnimateCommand(
    toScale: 1.2,
    duration: 0.2,
    curve: 'easeOut',
  );
  
  static const AnimateCommand scaleDown = AnimateCommand(
    toScale: 0.8,
    duration: 0.2,
    curve: 'easeIn',
  );
  
  static const AnimateCommand slideInFromLeft = AnimateCommand(
    toTranslateX: 0,
    duration: 0.4,
    curve: 'easeOut',
  );
  
  static const AnimateCommand slideOutToRight = AnimateCommand(
    toTranslateX: 300,
    duration: 0.4,
    curve: 'easeIn',
  );
  
  static const AnimateCommand bounce = AnimateCommand(
    toScale: 1.1,
    duration: 0.6,
    curve: 'elasticOut',
    repeat: false,
  );
  
  static const AnimateCommand pulse = AnimateCommand(
    toScale: 1.05,
    toOpacity: 0.8,
    duration: 1.0,
    curve: 'easeInOut',
    repeat: true,
  );
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

import 'dart:math' as math;
import '../enums/animation_enums.dart';

/// Core animation values for DCF Reanimated

/// Pure animation value configuration that runs entirely on the UI thread.
/// 
/// [ReanimatedValue] defines how a single property should be animated,
/// including start/end values, duration, curve, and repeat behavior.
/// 
/// Supports keyframe animations via [keyframes] parameter.
/// 
/// Example:
/// ```dart
/// ReanimatedValue(
///   from: 0.0,
///   to: 1.0,
///   duration: 300,
///   curve: 'easeInOut',
/// )
/// ```
/// 
/// Example with keyframes:
/// ```dart
/// ReanimatedValue(
///   keyframes: [0.0, 1.0, 0.0],
///   duration: 300,
///   repeat: true,
/// )
/// ```
class ReanimatedValue {
  /// Starting value for the animation
  final double? from;
  
  /// Ending value for the animation
  final double? to;
  
  /// Keyframe values for multi-step animations
  /// If provided, [from] and [to] are ignored
  final List<double>? keyframes;
  
  /// Animation duration in milliseconds
  final int duration;
  
  /// Easing curve that defines animation progression
  /// 
  /// Use [AnimationCurve] enum for type safety:
  /// - [AnimationCurve.linear]: Constant speed
  /// - [AnimationCurve.easeIn]: Slow start, fast end  
  /// - [AnimationCurve.easeOut]: Fast start, slow end
  /// - [AnimationCurve.easeInOut]: Slow start and end
  /// - [AnimationCurve.spring]: Natural spring motion
  final AnimationCurve curve;
  
  /// Delay before animation starts in milliseconds
  final int delay;
  
  /// Whether the animation should repeat
  final bool repeat;
  
  /// Number of repetitions (null = infinite)
  final int? repeatCount;

  /// Creates a new animation value configuration.
  /// 
  /// Either provide [from] and [to], or [keyframes], but not both.
  const ReanimatedValue({
    this.from,
    this.to,
    this.keyframes,
    this.duration = 300,
    this.curve = AnimationCurve.easeInOut,
    this.delay = 0,
    this.repeat = false,
    this.repeatCount,
  }) : assert(
    (from != null && to != null && keyframes == null) ||
    (keyframes != null && from == null && to == null),
    'Must provide either (from, to) or keyframes, but not both',
  );

  /// Converts this animation configuration to a map for native bridge communication.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'duration': duration,
      'curve': curve.value,
      'delay': delay,
      'repeat': repeat,
      if (repeatCount != null) 'repeatCount': repeatCount,
    };
    
    if (keyframes != null) {
      map['keyframes'] = keyframes;
    } else {
      map['from'] = from;
      map['to'] = to;
    }
    
    return map;
  }
}

/// A reactive animation value that can be animated on the pure UI thread.
/// 
/// [SharedValue] provides a way to create animations that respond to
/// state changes and can be smoothly interpolated between values.
/// 
/// Example:
/// ```dart
/// final opacity = useSharedValue(0.0);
/// final animation = opacity.withTiming(toValue: 1.0, duration: 500);
/// ```
class SharedValue {
  final String _id;
  final ReanimatedValue _config;

  SharedValue._(this._id, this._config);

  /// Creates a new shared value with the given initial value.
  /// 
  /// The [initialValue] will be the starting point for all animations.
  factory SharedValue(double initialValue) {
    final id = 'shared_${DateTime.now().microsecondsSinceEpoch}';
    return SharedValue._(
        id, ReanimatedValue(from: initialValue, to: initialValue));
  }

  /// Unique identifier for this shared value
  String get id => _id;
  
  /// Current animation configuration
  ReanimatedValue get config => _config;

  /// Creates a timing-based animation to the specified value.
  /// 
  /// This is the most common animation type, providing smooth transitions
  /// between the current value and [toValue].
  /// 
  /// Example:
  /// ```dart
  /// scale.withTiming(toValue: 1.2, duration: 200, curve: AnimationCurve.easeOut)
  /// ```
  ReanimatedValue withTiming({
    required double toValue,
    int duration = 300,
    AnimationCurve curve = AnimationCurve.easeInOut,
    int delay = 0,
  }) {
    return ReanimatedValue(
      from: _config.to ?? _config.keyframes?.last,
      to: toValue,
      duration: duration,
      curve: curve,
      delay: delay,
    );
  }

  /// Creates a spring-based animation to the specified value.
  /// 
  /// Spring animations provide natural, physics-based motion that feels
  /// more organic than timing-based animations.
  /// 
  /// - [damping]: Controls how quickly the spring settles (higher = less bounce)
  /// - [stiffness]: Controls spring responsiveness (higher = faster)
  /// 
  /// Example:
  /// ```dart
  /// position.withSpring(toValue: 100.0, damping: 15, stiffness: 150)
  /// ```
  ReanimatedValue withSpring({
    required double toValue,
    double damping = 10,
    double stiffness = 100,
    int delay = 0,
  }) {
    return ReanimatedValue(
      from: _config.to ?? _config.keyframes?.last,
      to: toValue,
      duration: _calculateSpringDuration(damping, stiffness),
      curve: AnimationCurve.spring,
      delay: delay,
    );
  }

  /// Creates a repeating animation between current and target values.
  /// 
  /// - [reverse]: If true, animation will go back and forth (A→B→A→B...)
  /// - [numberOfReps]: Number of repetitions (null = infinite)
  /// 
  /// Example:
  /// ```dart
  /// rotation.withRepeat(
  ///   toValue: 6.28, // Full rotation
  ///   duration: 1000,
  ///   reverse: false, // Don't reverse, keep spinning
  /// )
  /// ```
  ReanimatedValue withRepeat({
    required double toValue,
    int duration = 300,
    AnimationCurve curve = AnimationCurve.easeInOut,
    bool reverse = true,
    int? numberOfReps,
  }) {
    return ReanimatedValue(
      from: _config.to ?? _config.keyframes?.last,
      to: toValue,
      duration: duration,
      curve: curve,
      repeat: true,
      repeatCount: numberOfReps,
    );
  }

  /// Calculates appropriate duration for spring animations based on physics parameters.
  static int _calculateSpringDuration(double damping, double stiffness) {
    // Simplified spring duration calculation
    // In a real implementation, this would use proper physics equations
    final dampingRatio = damping / (2 * math.sqrt(stiffness * 1.0));
    if (dampingRatio < 1.0) {
      // Underdamped - has oscillations
      return (1000 * (6.0 / math.sqrt(stiffness / 10))).round();
    } else {
      // Overdamped - no oscillations
      return (1000 * (4.0 / math.sqrt(stiffness / 10))).round();
    }
  }
}

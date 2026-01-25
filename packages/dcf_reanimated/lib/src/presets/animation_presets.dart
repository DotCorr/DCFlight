/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import '../values/animation_values.dart';
import '../styles/animated_style.dart';
import '../enums/animation_enums.dart';

/// Pre-configured animation presets for common UI patterns.
/// 
/// The [Reanimated] class provides ready-to-use animations that cover
/// the most common use cases like entrance/exit animations, loading states,
/// and interactive feedback.
/// 
/// All presets return [AnimatedStyle] objects that can be used directly
/// with [ReanimatedView] components.
/// 
/// Example:
/// ```dart
/// ReanimatedView(
///   animatedStyle: Reanimated.fadeIn(duration: 500),
///   children: [DCFText(content: "Hello!")],
/// )
/// ```
class Reanimated {
  // Private constructor to prevent instantiation
  Reanimated._();

  // ============================================================================
  // ENTRANCE ANIMATIONS
  // ============================================================================

  /// Creates a fade-in animation from transparent to opaque.
  /// 
  /// Perfect for revealing content smoothly. The element starts at 0% opacity
  /// and animates to 100% opacity over the specified duration.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.fadeIn(duration: 300),
  ///   children: [DCFText(content: "I fade in!")],
  /// )
  /// ```
  static AnimatedStyle fadeIn({
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeInOut,
  }) {
    return AnimatedStyle().opacity(ReanimatedValue(
      from: 0.0,
      to: 1.0,
      duration: duration,
      delay: delay,
      curve: curve,
    ));
  }

  /// Creates a scale-in animation from small to normal size.
  /// 
  /// The element starts at [fromScale] and animates to [toScale].
  /// Commonly used for modal dialogs, buttons, and popup content.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.scaleIn(fromScale: 0.8, toScale: 1.0),
  ///   children: [DCFView(/* modal content */)],
  /// )
  /// ```
  static AnimatedStyle scaleIn({
    double fromScale = 0.0,
    double toScale = 1.0,
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeOut,
  }) {
    return AnimatedStyle().transform(
      scale: ReanimatedValue(
        from: fromScale,
        to: toScale,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  /// Creates a slide-in animation from the right edge.
  /// 
  /// The element starts [distance] pixels to the right of its final position
  /// and slides into place. Perfect for drawer navigation or card reveals.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.slideInRight(distance: 100.0),
  ///   children: [DCFView(/* sliding content */)],
  /// )
  /// ```
  static AnimatedStyle slideInRight({
    double distance = 100.0,
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeOut,
  }) {
    return AnimatedStyle().transform(
      translateX: ReanimatedValue(
        from: distance,
        to: 0.0,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  /// Creates a slide-in animation from the left edge.
  /// 
  /// The element starts [distance] pixels to the left of its final position
  /// and slides into place. Mirror of [slideInRight].
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.slideInLeft(distance: 100.0),
  ///   children: [DCFView(/* sliding content */)],
  /// )
  /// ```
  static AnimatedStyle slideInLeft({
    double distance = 100.0,
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeOut,
  }) {
    return AnimatedStyle().transform(
      translateX: ReanimatedValue(
        from: -distance,
        to: 0.0,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  /// Creates a slide-in animation from the top.
  /// 
  /// Perfect for notification banners, dropdowns, and alerts that appear
  /// from the top of the screen.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.slideInTop(distance: 50.0),
  ///   children: [DCFView(/* notification banner */)],
  /// )
  /// ```
  static AnimatedStyle slideInTop({
    double distance = 100.0,
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeOut,
  }) {
    return AnimatedStyle().transform(
      translateY: ReanimatedValue(
        from: -distance,
        to: 0.0,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  /// Creates a slide-in animation from the bottom.
  /// 
  /// Commonly used for bottom sheets, action sheets, and content that
  /// slides up from the bottom edge.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.slideInBottom(distance: 150.0),
  ///   children: [DCFView(/* bottom sheet */)],
  /// )
  /// ```
  static AnimatedStyle slideInBottom({
    double distance = 100.0,
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeOut,
  }) {
    return AnimatedStyle().transform(
      translateY: ReanimatedValue(
        from: distance,
        to: 0.0,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  // ============================================================================
  // EXIT ANIMATIONS
  // ============================================================================

  /// Creates a fade-out animation from opaque to transparent.
  /// 
  /// The reverse of [fadeIn]. Element becomes progressively more transparent
  /// until completely invisible.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.fadeOut(duration: 200),
  ///   children: [DCFView(/* disappearing content */)],
  /// )
  /// ```
  static AnimatedStyle fadeOut({
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeInOut,
  }) {
    return AnimatedStyle().opacity(ReanimatedValue(
      from: 1.0,
      to: 0.0,
      duration: duration,
      delay: delay,
      curve: curve,
    ));
  }

  /// Creates a scale-out animation from normal to small size.
  /// 
  /// Element shrinks from current size to [toScale]. Often combined with
  /// fade-out for smooth disappearing effects.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.scaleOut(toScale: 0.0),
  ///   children: [DCFView(/* shrinking content */)],
  /// )
  /// ```
  static AnimatedStyle scaleOut({
    double fromScale = 1.0,
    double toScale = 0.0,
    int duration = 300,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeIn,
  }) {
    return AnimatedStyle().transform(
      scale: ReanimatedValue(
        from: fromScale,
        to: toScale,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  // ============================================================================
  // CONTINUOUS ANIMATIONS
  // ============================================================================

  /// Creates a bouncing animation that scales up and down repeatedly.
  /// 
  /// Perfect for drawing attention to buttons, notifications, or loading states.
  /// The element scales from 1.0 to [bounceScale] and back.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.bounce(
  ///     bounceScale: 1.2,
  ///     repeatCount: 3,
  ///   ),
  ///   children: [DCFButton(/* bouncing button */)],
  /// )
  /// ```
  static AnimatedStyle bounce({
    double bounceScale = 1.2,
    int duration = 600,
    int delay = 0,
    bool repeat = true,
    int? repeatCount,
  }) {
    return AnimatedStyle().transform(
      scale: ReanimatedValue(
        from: 1.0,
        to: bounceScale,
        duration: duration,
        delay: delay,
        curve: AnimationCurve.easeInOut,
        repeat: repeat,
        repeatCount: repeatCount,
      ),
    );
  }

  /// Creates a pulsing opacity animation.
  /// 
  /// Element fades between [minOpacity] and [maxOpacity] repeatedly.
  /// Great for loading indicators, notifications, or breathing effects.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.pulse(duration: 1000),
  ///   children: [DCFIcon(icon: "loading")],
  /// )
  /// ```
  static AnimatedStyle pulse({
    double minOpacity = 0.5,
    double maxOpacity = 1.0,
    int duration = 1000,
    int delay = 0,
    bool repeat = true,
    int? repeatCount,
  }) {
    return AnimatedStyle().opacity(ReanimatedValue(
      from: maxOpacity,
      to: minOpacity,
      duration: duration,
      delay: delay,
      curve: AnimationCurve.easeInOut,
      repeat: repeat,
      repeatCount: repeatCount,
    ));
  }

  /// Creates a continuous rotation animation.
  /// 
  /// Element rotates from [fromRotation] to [toRotation] (in radians).
  /// Use `2 * π` (6.28) for a full 360-degree rotation.
  /// 
  /// Perfect for loading spinners, logos, or decorative elements.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.rotate(
  ///     toRotation: 6.28, // Full rotation
  ///     duration: 2000,
  ///   ),
  ///   children: [DCFIcon(icon: "spinner")],
  /// )
  /// ```
  static AnimatedStyle rotate({
    double fromRotation = 0.0,
    double toRotation = 6.28, // 2π (full rotation)
    int duration = 1000,
    int delay = 0,
    bool repeat = true,
    int? repeatCount,
  }) {
    return AnimatedStyle().transform(
      rotation: ReanimatedValue(
        from: fromRotation,
        to: toRotation,
        duration: duration,
        delay: delay,
        curve: AnimationCurve.linear, // Linear for smooth continuous rotation
        repeat: repeat,
        repeatCount: repeatCount,
      ),
    );
  }

  // ============================================================================
  // COMPLEX COMBINED ANIMATIONS
  // ============================================================================

  /// Creates a combined slide, scale, and fade-in animation.
  /// 
  /// This premium entrance animation combines multiple effects:
  /// - Slides in from [slideDistance] pixels away
  /// - Scales from [fromScale] to [toScale]
  /// - Fades from [fromOpacity] to [toOpacity]
  /// 
  /// Perfect for hero content, modal dialogs, and premium UI elements.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.slideScaleFadeIn(
  ///     slideDistance: 50.0,
  ///     fromScale: 0.9,
  ///     duration: 400,
  ///   ),
  ///   children: [DCFView(/* hero content */)],
  /// )
  /// ```
  static AnimatedStyle slideScaleFadeIn({
    double slideDistance = 50.0,
    double fromScale = 0.8,
    double toScale = 1.0,
    double fromOpacity = 0.0,
    double toOpacity = 1.0,
    int duration = 400,
    int delay = 0,
    AnimationCurve curve = AnimationCurve.easeOut,
  }) {
    return AnimatedStyle()
        .transform(
          translateY: ReanimatedValue(
            from: slideDistance,
            to: 0.0,
            duration: duration,
            delay: delay,
            curve: curve,
          ),
          scale: ReanimatedValue(
            from: fromScale,
            to: toScale,
            duration: duration,
            delay: delay,
            curve: curve,
          ),
        )
        .opacity(ReanimatedValue(
          from: fromOpacity,
          to: toOpacity,
          duration: duration,
          delay: delay,
          curve: curve,
        ));
  }

  /// Creates a wiggle animation that rotates back and forth.
  /// 
  /// Element rotates between negative and positive [wiggleAngle] (in radians).
  /// Great for error states, notifications, or playful interactions.
  /// 
  /// Example:
  /// ```dart
  /// ReanimatedView(
  ///   animatedStyle: Reanimated.wiggle(
  ///     wiggleAngle: 0.1, // Small wiggle
  ///     repeatCount: 3,
  ///   ),
  ///   children: [DCFTextField(/* error field */)],
  /// )
  /// ```
  static AnimatedStyle wiggle({
    double wiggleAngle = 0.05, // ~3 degrees
    int duration = 100,
    int delay = 0,
    bool repeat = true,
    int? repeatCount = 4,
  }) {
    return AnimatedStyle().transform(
      rotation: ReanimatedValue(
        from: -wiggleAngle,
        to: wiggleAngle,
        duration: duration,
        delay: delay,
        curve: AnimationCurve.easeInOut,
        repeat: repeat,
        repeatCount: repeatCount,
      ),
    );
  }
}

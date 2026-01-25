/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import '../values/animation_values.dart';
import '../enums/animation_enums.dart';

/// Container for multiple property animations that run on the UI thread.
/// 
/// [AnimatedStyle] allows you to combine multiple animation properties
/// (transforms, opacity, colors, layout) into a single configuration
/// that gets sent to the native animation engine.
/// 
/// Example:
/// ```dart
/// AnimatedStyle()
///   .transform(scale: ReanimatedValue(from: 0, to: 1))
///   .opacity(ReanimatedValue(from: 0, to: 1))
///   .backgroundColor(ReanimatedValue(from: 0, to: 1));
/// ```
class AnimatedStyle {
  final Map<String, ReanimatedValue> _animations = {};
  final Map<String, dynamic> _config = {};
  
  /// Configures transform animations (scale, translate, rotate).
  /// 
  /// Transform animations are the most performant since they run entirely
  /// on the compositor thread without triggering layout calculations.
  /// 
  /// All rotation values are in radians (use `2 * π` for full rotation).
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().transform(
  ///   scale: ReanimatedValue(from: 0.8, to: 1.0),
  ///   rotation: ReanimatedValue(from: 0, to: 6.28), // Full rotation
  ///   translateX: ReanimatedValue(from: -100, to: 0),
  /// )
  /// ```
  AnimatedStyle transform({
    ReanimatedValue? scale,     // Uniform scale factor
    ReanimatedValue? scaleX,    // X-axis scale factor  
    ReanimatedValue? scaleY,    // Y-axis scale factor
    ReanimatedValue? translateX, // X-axis translation in logical pixels
    ReanimatedValue? translateY, // Y-axis translation in logical pixels
    ReanimatedValue? translateZ, // Z-axis translation in logical pixels (3D)
    ReanimatedValue? rotation,   // Z-axis rotation in radians
    ReanimatedValue? rotationX,  // X-axis rotation in radians
    ReanimatedValue? rotationY,  // Y-axis rotation in radians
    ReanimatedValue? rotationZ,  // Z-axis rotation in radians (3D)
    double? perspective,         // Perspective distance for 3D transforms
    bool? preserve3d,           // Enable preserve-3d transform style
  }) {
    if (scale != null) _animations['scale'] = scale;
    if (scaleX != null) _animations['scaleX'] = scaleX;
    if (scaleY != null) _animations['scaleY'] = scaleY;
    if (translateX != null) _animations['translateX'] = translateX;
    if (translateY != null) _animations['translateY'] = translateY;
    if (translateZ != null) _animations['translateZ'] = translateZ;
    if (rotation != null) _animations['rotation'] = rotation;
    if (rotationX != null) _animations['rotationX'] = rotationX;
    if (rotationY != null) _animations['rotationY'] = rotationY;
    if (rotationZ != null) _animations['rotationZ'] = rotationZ;
    if (perspective != null) _config['perspective'] = perspective;
    if (preserve3d != null) _config['preserve3d'] = preserve3d;
    return this;
  }

  /// Configures opacity animation.
  /// 
  /// Opacity animations are highly performant and run on the compositor.
  /// Values should be between 0.0 (fully transparent) and 1.0 (fully opaque).
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().opacity(
  ///   ReanimatedValue(from: 0.0, to: 1.0, duration: 300)
  /// )
  /// ```
  AnimatedStyle opacity(ReanimatedValue value) {
    _animations['opacity'] = value;
    return this;
  }

  /// Configures background color animation.
  /// 
  /// The animation value represents a hue shift from 0.0 to 1.0,
  /// which will be interpreted as a color transition by the native layer.
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().backgroundColor(
  ///   ReanimatedValue(from: 0.0, to: 0.5, duration: 500)
  /// )
  /// ```
  AnimatedStyle backgroundColor(ReanimatedValue value) {
    _animations['backgroundColor'] = value;
    return this;
  }

  /// Configures layout property animations (width, height, positioning).
  /// 
  /// Layout animations are more expensive than transform/opacity animations
  /// since they may trigger layout recalculations. Use sparingly and prefer
  /// transform animations when possible.
  /// 
  /// All values are in logical pixels.
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().layout(
  ///   width: ReanimatedValue(from: 0, to: 200),
  ///   height: ReanimatedValue(from: 50, to: 100),
  /// )
  /// ```
  AnimatedStyle layout({
    ReanimatedValue? width,   // Width in logical pixels
    ReanimatedValue? height,  // Height in logical pixels
    ReanimatedValue? top,     // Top position in logical pixels
    ReanimatedValue? left,    // Left position in logical pixels
    ReanimatedValue? right,   // Right position in logical pixels
    ReanimatedValue? bottom,  // Bottom position in logical pixels
  }) {
    if (width != null) _animations['width'] = width;
    if (height != null) _animations['height'] = height;
    if (top != null) _animations['top'] = top;
    if (left != null) _animations['left'] = left;
    if (right != null) _animations['right'] = right;
    if (bottom != null) _animations['bottom'] = bottom;
    return this;
  }

  // ============================================================================
  // SIMPLIFIED SHARED VALUE API - NO MANUAL ReanimatedValue CONSTRUCTION
  // ============================================================================
  
  /// Simple opacity animation from shared value.
  /// 
  /// Automatically handles real-time updates without manual ReanimatedValue construction.
  /// Perfect for slider-controlled animations or gesture-driven opacity changes.
  /// 
  /// Example:
  /// ```dart
  /// final opacity = useState(0.5);
  /// AnimatedStyle().opacityValue(opacity.state); // Real-time opacity tracking
  /// ```
  AnimatedStyle opacityValue(double sharedValue) {
    _animations['opacity'] = ReanimatedValue(
      from: sharedValue,
      to: sharedValue,
      duration: 1, // Instant for real-time tracking
      curve: AnimationCurve.linear,
    );
    return this;
  }
  
  /// Simple width animation with automatic pixel/percentage handling.
  /// 
  /// Supports both pixel values and percentage conversion:
  /// - [asPercentage] = false: Direct pixel values
  /// - [asPercentage] = true: Converts 0.0→1.0 to 0%→100%
  /// 
  /// Example:
  /// ```dart
  /// // Pixel-based width
  /// AnimatedStyle().widthValue(sliderValue * 300); // 0px → 300px
  /// 
  /// // Percentage-based width
  /// AnimatedStyle().widthValue(sliderValue, asPercentage: true); // 0% → 100%
  /// ```
  AnimatedStyle widthValue(double sharedValue, {bool asPercentage = false}) {
    final finalValue = asPercentage ? sharedValue * 100 : sharedValue;
    _animations['width'] = ReanimatedValue(
      from: finalValue,
      to: finalValue,
      duration: 1, // Instant for real-time tracking  
      curve: AnimationCurve.linear,
    );
    return this;
  }
  
  /// Simple height animation with automatic pixel/percentage handling.
  /// 
  /// Works identically to [widthValue] but for height properties.
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().heightValue(gestureValue * 200);
  /// ```
  AnimatedStyle heightValue(double sharedValue, {bool asPercentage = false}) {
    final finalValue = asPercentage ? sharedValue * 100 : sharedValue;
    _animations['height'] = ReanimatedValue(
      from: finalValue,
      to: finalValue,
      duration: 1, // Instant for real-time tracking
      curve: AnimationCurve.linear,
    );
    return this;
  }
  
  /// Simple scale animation from shared value.
  /// 
  /// Perfect for button press animations or interactive scaling.
  /// Values typically range from 0.0 to 2.0 (0% to 200% scale).
  /// 
  /// Example:
  /// ```dart
  /// final isPressed = useState(false);
  /// final scale = isPressed.state ? 0.95 : 1.0;
  /// AnimatedStyle().scaleValue(scale); // Button press effect
  /// ```
  AnimatedStyle scaleValue(double sharedValue) {
    _animations['scale'] = ReanimatedValue(
      from: sharedValue,
      to: sharedValue,
      duration: 1, // Instant for real-time tracking
      curve: AnimationCurve.linear,
    );
    return this;
  }
  
  /// Simple X-axis translation animation from shared value.
  /// 
  /// Values are in logical pixels. Positive values move right, negative left.
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().translateXValue(dragGesture.translationX);
  /// ```
  AnimatedStyle translateXValue(double sharedValue) {
    _animations['translateX'] = ReanimatedValue(
      from: sharedValue,
      to: sharedValue,
      duration: 1, // Instant for real-time tracking
      curve: AnimationCurve.linear,
    );
    return this;
  }
  
  /// Simple Y-axis translation animation from shared value.
  /// 
  /// Values are in logical pixels. Positive values move down, negative up.
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle().translateYValue(dragGesture.translationY);
  /// ```
  AnimatedStyle translateYValue(double sharedValue) {
    _animations['translateY'] = ReanimatedValue(
      from: sharedValue,
      to: sharedValue,
      duration: 1, // Instant for real-time tracking
      curve: AnimationCurve.linear,
    );
    return this;
  }

  /// Simple Z-axis translation animation from shared value (3D).
  /// 
  /// Values are in logical pixels. Positive values move forward, negative backward.
  /// Requires perspective to be set for visible effect.
  /// 
  /// Example:
  /// ```dart
  /// AnimatedStyle()
  ///   .transform(perspective: 1000)
  ///   .transform(translateZValue: depthValue);
  /// ```
  AnimatedStyle translateZValue(double sharedValue) {
    _animations['translateZ'] = ReanimatedValue(
      from: sharedValue,
      to: sharedValue,
      duration: 1, // Instant for real-time tracking
      curve: AnimationCurve.linear,
    );
    return this;
  }

  /// Converts all animation configurations to a map for native bridge communication.
  /// 
  /// This method is called internally when the animated style is sent to
  /// the native animation engine. Each animation property is serialized
  /// with its configuration parameters.
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{
      'animations': _animations.map((key, value) => MapEntry(key, value.toMap())),
      ..._config,
    };
    return result;
  }
}

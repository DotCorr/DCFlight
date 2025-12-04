/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Type-safe animation properties for Motion and ReanimatedView.
/// 
/// Instead of using Map<String, dynamic> with string keys like {'opacity': 1, 'y': 20},
/// use this class for full type safety and IDE autocomplete.
/// 
/// Example:
/// ```dart
/// Motion(
///   initial: AnimationProperties(opacity: 0, y: 20),
///   animate: AnimationProperties(opacity: 1, y: 0),
///   transition: Transition(duration: 800),
///   children: [...],
/// )
/// ```
class AnimationProperties {
  /// Opacity value (0.0 to 1.0)
  final double? opacity;
  
  /// Scale value (1.0 = normal size)
  final double? scale;
  
  /// Scale on X axis
  final double? scaleX;
  
  /// Scale on Y axis
  final double? scaleY;
  
  /// Translation on X axis (in logical pixels)
  final double? x;
  
  /// Translation on Y axis (in logical pixels)
  final double? y;
  
  /// Translation on Z axis (in logical pixels, requires 3D perspective)
  final double? z;
  
  /// Rotation in radians (Z axis, same as rotateZ)
  final double? rotate;
  
  /// Rotation on X axis in radians
  final double? rotateX;
  
  /// Rotation on Y axis in radians
  final double? rotateY;
  
  /// Rotation on Z axis in radians
  final double? rotateZ;
  
  /// Translation on X axis (alias for x)
  final double? translateX;
  
  /// Translation on Y axis (alias for y)
  final double? translateY;
  
  /// Translation on Z axis (alias for z)
  final double? translateZ;
  
  /// Keyframe values for any property (for complex animations)
  /// Use this for multi-step animations like [0, 1, 0.5, 1]
  final Map<String, List<double>>? keyframes;
  
  const AnimationProperties({
    this.opacity,
    this.scale,
    this.scaleX,
    this.scaleY,
    this.x,
    this.y,
    this.z,
    this.rotate,
    this.rotateX,
    this.rotateY,
    this.rotateZ,
    this.translateX,
    this.translateY,
    this.translateZ,
    this.keyframes,
  });
  
  /// Converts to the internal Map format for backwards compatibility
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (opacity != null) map['opacity'] = opacity;
    if (scale != null) map['scale'] = scale;
    if (scaleX != null) map['scaleX'] = scaleX;
    if (scaleY != null) map['scaleY'] = scaleY;
    if (x != null) map['x'] = x;
    if (y != null) map['y'] = y;
    if (z != null) map['z'] = z;
    if (rotate != null) map['rotate'] = rotate;
    if (rotateX != null) map['rotateX'] = rotateX;
    if (rotateY != null) map['rotateY'] = rotateY;
    if (rotateZ != null) map['rotateZ'] = rotateZ;
    if (translateX != null) map['translateX'] = translateX;
    if (translateY != null) map['translateY'] = translateY;
    if (translateZ != null) map['translateZ'] = translateZ;
    
    // Handle keyframes - if a property has keyframes, use the keyframes instead
    if (keyframes != null) {
      keyframes!.forEach((key, values) {
        map[key] = values;
      });
    }
    
    return map;
  }
  
  /// Creates from a Map (for backwards compatibility)
  factory AnimationProperties.fromMap(Map<String, dynamic> map) {
    return AnimationProperties(
      opacity: map['opacity'] as double?,
      scale: map['scale'] as double?,
      scaleX: map['scaleX'] as double?,
      scaleY: map['scaleY'] as double?,
      x: map['x'] as double?,
      y: map['y'] as double?,
      z: map['z'] as double?,
      rotate: map['rotate'] as double?,
      rotateX: map['rotateX'] as double?,
      rotateY: map['rotateY'] as double?,
      rotateZ: map['rotateZ'] as double?,
      translateX: map['translateX'] as double?,
      translateY: map['translateY'] as double?,
      translateZ: map['translateZ'] as double?,
    );
  }
}


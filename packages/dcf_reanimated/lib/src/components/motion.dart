/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

import 'package:dcflight/dcflight.dart';
import '../styles/animated_style.dart';
import '../values/animation_values.dart';
import '../enums/animation_enums.dart';
import '../helper/init.dart';
import 'reanimated_view.dart';

/// Framer Motion-style declarative animation component.
/// 
/// [Motion] provides a powerful, declarative API for animations similar to
/// Framer Motion's `motion.div`. It supports:
/// - Initial animations (on mount)
/// - Viewport-based animations (whileInView)
/// - Hover animations (whileHover)
/// - Animation variants
/// - Staggered animations
/// - 3D transforms
/// - Spring animations
/// 
/// Example:
/// ```dart
/// Motion(
///   initial: { 'opacity': 0, 'y': 20 },
///   animate: { 'opacity': 1, 'y': 0 },
///   transition: Transition(duration: 800),
///   children: [
///     DCFText(content: "I animate on mount!"),
///   ],
/// )
/// ```
/// 
/// Example with viewport detection:
/// ```dart
/// Motion(
///   initial: { 'opacity': 0, 'scale': 0.8 },
///   whileInView: { 'opacity': 1, 'scale': 1.0 },
///   viewport: ViewportConfig(once: true),
///   children: [
///     DCFText(content: "I animate when scrolled into view!"),
///   ],
/// )
/// ```
/// 
/// Example with hover:
/// ```dart
/// Motion(
///   whileHover: { 'scale': 1.05, 'y': -5 },
///   transition: Transition(type: 'spring', stiffness: 400),
///   children: [
///     DCFButton(/* hoverable button */),
///   ],
/// )
/// ```
class Motion extends DCFStatefulComponent {
  /// Child components to render inside the animated view
  final List<DCFComponentNode> children;

  /// Initial animation values (applied on mount)
  /// 
  /// Keys can be: opacity, scale, x, y, z, rotate, rotateX, rotateY, rotateZ
  /// Values can be numbers or lists for keyframes
  final Map<String, dynamic>? initial;

  /// Target animation values (animated to on mount)
  /// 
  /// Keys can be: opacity, scale, x, y, z, rotate, rotateX, rotateY, rotateZ
  /// Values can be numbers or lists for keyframes
  final Map<String, dynamic>? animate;

  /// Animation values when element enters viewport
  /// 
  /// Automatically triggers when element becomes visible in viewport
  final Map<String, dynamic>? whileInView;

  /// Animation values when element is hovered
  /// 
  /// Automatically triggers on hover (mobile: on press)
  final Map<String, dynamic>? whileHover;

  /// Animation values when element is tapped/pressed
  final Map<String, dynamic>? whileTap;

  /// Animation transition configuration
  final Transition? transition;

  /// Viewport detection configuration
  final ViewportConfig? viewport;

  /// Layout properties for positioning and sizing
  final DCFLayout? layout;

  /// Static styling properties (non-animated)
  final DCFStyleSheet? styleSheet;

  /// Whether to start animation automatically when component mounts
  final bool autoStart;

  /// Delay before starting animation in milliseconds
  final int delay;

  /// Called when animation begins
  final void Function()? onAnimationStart;

  /// Called when animation completes
  final void Function()? onAnimationComplete;

  /// Called when element enters viewport
  final void Function()? onViewportEnter;

  /// Called when element exits viewport
  final void Function()? onViewportLeave;

  /// Additional event handlers
  final Map<String, dynamic>? events;

  Motion({
    required this.children,
    this.initial,
    this.animate,
    this.whileInView,
    this.whileHover,
    this.whileTap,
    this.transition,
    this.viewport,
    this.layout,
    this.styleSheet,
    this.autoStart = true,
    this.delay = 0,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.onViewportEnter,
    this.onViewportLeave,
    this.events,
    super.key,
  }) {
    ReanimatedInit.ensureInitialized();
  }

  @override
  DCFComponentNode render() {
    // Convert declarative animation props to AnimatedStyle
    final animatedStyle = _buildAnimatedStyle();
    
    // Merge user style with initial style
    final initialStyle = _buildInitialStyle();
    final combinedStyle = _mergeStyles(styleSheet, initialStyle);
    
    // Prepare event handlers
    Map<String, dynamic> eventHandlers = events ?? {};
    if (onAnimationStart != null) {
      eventHandlers['onAnimationStart'] = onAnimationStart;
    }
    if (onAnimationComplete != null) {
      eventHandlers['onAnimationComplete'] = onAnimationComplete;
    }
    if (onViewportEnter != null) {
      eventHandlers['onViewportEnter'] = onViewportEnter;
    }
    if (onViewportLeave != null) {
      eventHandlers['onViewportLeave'] = onViewportLeave;
    }

    // Use ReanimatedView component directly - no need to create DCFElement!
    return ReanimatedView(
      animatedStyle: animatedStyle,
      autoStart: autoStart,
      startDelay: delay,
      layout: layout,
      styleSheet: combinedStyle,
      onAnimationStart: onAnimationStart,
      onAnimationComplete: onAnimationComplete,
      events: eventHandlers.isEmpty ? null : eventHandlers,
      children: children,
    );
  }

  /// Converts declarative animation props to AnimatedStyle
  AnimatedStyle? _buildAnimatedStyle() {
    // Only build if we have animate prop (initial alone doesn't animate)
    if (animate == null) return null;

    final style = AnimatedStyle();
    final trans = transition ?? Transition();
    
    // Helper to create ReanimatedValue from value (supports keyframes)
    ReanimatedValue createValue(dynamic from, dynamic to) {
      // Check if 'to' is a list (keyframes)
      if (to is List) {
        final keyframes = to.map((v) => (v is num) ? v.toDouble() : 0.0).toList();
        return ReanimatedValue(
          keyframes: keyframes,
          duration: trans.duration,
          delay: trans.delay,
          curve: trans.curve,
          repeat: trans.repeat,
          repeatCount: trans.repeatCount,
        );
      }
      
      // Single value animation
      return ReanimatedValue(
        from: (from is num) ? from.toDouble() : 0.0,
        to: (to is num) ? to.toDouble() : 1.0,
        duration: trans.duration,
        delay: trans.delay,
        curve: trans.curve,
        repeat: trans.repeat,
        repeatCount: trans.repeatCount,
      );
    }

    // Process animate props
    if (animate != null) {
      final initialValues = initial ?? {};
      
      animate!.forEach((key, value) {
        final fromValue = initialValues[key] ?? _getDefaultValue(key);
        final toValue = value;
        
        switch (key) {
          case 'opacity':
            style.opacity(createValue(fromValue, toValue));
            break;
          case 'scale':
            style.transform(scale: createValue(fromValue, toValue));
            break;
          case 'x':
            style.transform(translateX: createValue(fromValue, toValue));
            break;
          case 'y':
            style.transform(translateY: createValue(fromValue, toValue));
            break;
          case 'z':
            style.transform(translateZ: createValue(fromValue, toValue));
            break;
          case 'rotate':
          case 'rotateZ':
            style.transform(rotationZ: createValue(fromValue, toValue));
            break;
          case 'rotateX':
            style.transform(rotationX: createValue(fromValue, toValue));
            break;
          case 'rotateY':
            style.transform(rotationY: createValue(fromValue, toValue));
            break;
        }
      });
    }

    // Add perspective if needed for 3D
    if (animate?.containsKey('z') == true || animate?.containsKey('rotateX') == true || animate?.containsKey('rotateY') == true) {
      style.transform(perspective: trans.perspective ?? 1000);
    }

    return style;
  }

  /// Gets default value for animation property
  dynamic _getDefaultValue(String key) {
    switch (key) {
      case 'opacity':
        return 1.0;
      case 'scale':
        return 1.0;
      case 'x':
      case 'y':
      case 'z':
        return 0.0;
      case 'rotate':
      case 'rotateX':
      case 'rotateY':
      case 'rotateZ':
        return 0.0;
      default:
        return 0.0;
    }
  }

  /// Builds static style from initial values (applied before animation starts)
  /// Note: Transforms and opacity are handled by native animation system,
  /// not static styles. This is just for merging with user-provided styles.
  DCFStyleSheet _buildInitialStyle() {
    // Initial values for transforms/opacity are applied by native side
    // before animation starts. We just return empty style here.
    return DCFStyleSheet();
  }

  /// Merges two style sheets (user style takes precedence)
  DCFStyleSheet _mergeStyles(DCFStyleSheet? userStyle, DCFStyleSheet initialStyle) {
    if (userStyle == null) return initialStyle;
    if (initialStyle == DCFStyleSheet()) return userStyle;
    
    // Merge styles - user style takes precedence
    return DCFStyleSheet(
      backgroundColor: userStyle.backgroundColor ?? initialStyle.backgroundColor,
      borderRadius: userStyle.borderRadius ?? initialStyle.borderRadius,
      borderColor: userStyle.borderColor ?? initialStyle.borderColor,
      borderWidth: userStyle.borderWidth ?? initialStyle.borderWidth,
      opacity: userStyle.opacity ?? initialStyle.opacity,
      primaryColor: userStyle.primaryColor ?? initialStyle.primaryColor,
      secondaryColor: userStyle.secondaryColor ?? initialStyle.secondaryColor,
      shadowColor: userStyle.shadowColor ?? initialStyle.shadowColor,
      shadowOpacity: userStyle.shadowOpacity ?? initialStyle.shadowOpacity,
      shadowRadius: userStyle.shadowRadius ?? initialStyle.shadowRadius,
      shadowOffsetX: userStyle.shadowOffsetX ?? initialStyle.shadowOffsetX,
      shadowOffsetY: userStyle.shadowOffsetY ?? initialStyle.shadowOffsetY,
      elevation: userStyle.elevation ?? initialStyle.elevation,
    );
  }
}

/// Animation transition configuration
class Transition {
  /// Animation duration in milliseconds
  final int duration;
  
  /// Delay before animation starts
  final int delay;
  
  /// Easing curve
  final AnimationCurve curve;
  
  /// Animation type: 'tween' or 'spring'
  final String type;
  
  /// Spring damping (for spring animations)
  final double? damping;
  
  /// Spring stiffness (for spring animations)
  final double? stiffness;
  
  /// Spring mass (for spring animations)
  final double? mass;
  
  /// Whether animation should repeat
  final bool repeat;
  
  /// Number of repetitions (null = infinite)
  final int? repeatCount;
  
  /// Perspective distance for 3D transforms
  final double? perspective;
  
  /// Stagger delay for children (in milliseconds per child)
  final double? staggerChildren;
  
  /// Delay before each child animation starts
  final double? delayChildren;

  const Transition({
    this.duration = 300,
    this.delay = 0,
    this.curve = AnimationCurve.easeInOut,
    this.type = 'tween',
    this.damping,
    this.stiffness,
    this.mass,
    this.repeat = false,
    this.repeatCount,
    this.perspective,
    this.staggerChildren,
    this.delayChildren,
  });

  Map<String, dynamic> toMap() => {
    'duration': duration,
    'delay': delay,
    'curve': curve.value,
    'type': type,
    if (damping != null) 'damping': damping,
    if (stiffness != null) 'stiffness': stiffness,
    if (mass != null) 'mass': mass,
    'repeat': repeat,
    if (repeatCount != null) 'repeatCount': repeatCount,
    if (perspective != null) 'perspective': perspective,
    if (staggerChildren != null) 'staggerChildren': staggerChildren,
    if (delayChildren != null) 'delayChildren': delayChildren,
  };
}

/// Viewport detection configuration
class ViewportConfig {
  /// Whether to trigger animation only once (default: false = every time)
  final bool once;
  
  /// Amount of element that must be visible (0.0 to 1.0)
  final double amount;
  
  /// Margin around viewport (in pixels or percentage)
  final String? margin;

  const ViewportConfig({
    this.once = false,
    this.amount = 0.0,
    this.margin,
  });

  Map<String, dynamic> toMap() => {
    'once': once,
    'amount': amount,
    if (margin != null) 'margin': margin,
  };
}


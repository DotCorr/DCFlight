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
import '../types/animation_properties.dart';
import '../helper/init.dart';
import 'motion.dart';

/// The main animated view component that runs animations purely on the UI thread.
///
/// [ReanimatedView] is a drop-in replacement for [DCFView] that adds animation
/// capabilities without sacrificing performance. All animations are configured
/// via props and run natively without bridge calls.
///
/// Key features:
/// - Pure UI thread execution (60fps)
/// - Zero bridge calls during animation
/// - Automatic initialization
/// - Event callbacks for animation lifecycle
/// - Unique animation IDs for debugging
///
/// Example with animatedStyle:
/// ```dart
/// ReanimatedView(
///   animatedStyle: Reanimated.fadeIn(duration: 500),
///   onAnimationComplete: () => print("Fade complete!"),
///   children: [
///     DCFText(content: "I animate smoothly!"),
///   ],
/// )
/// ```
///
/// Example with worklet:
/// ```dart
/// @Worklet
/// double customAnimation(double time) => time * 2;
///
/// ReanimatedView(
///   worklet: customAnimation,
///   workletConfig: {'duration': 2000},
///   children: [
///     DCFText(content: "Custom worklet animation!"),
///   ],
/// )
/// ```
class ReanimatedView extends DCFStatelessComponent {
  /// Child components to render inside the animated view
  final List<DCFComponentNode> children;

  /// Initial animation values (applied on mount)
  /// 
  /// Use [AnimationProperties] for type safety, or Map<String, dynamic> for backwards compatibility
  final AnimationProperties? initial;
  
  /// Initial animation values (legacy Map format)
  final Map<String, dynamic>? _initialMap;

  /// Target animation values (animated to on mount)
  /// 
  /// Use [AnimationProperties] for type safety, or Map<String, dynamic> for backwards compatibility
  final AnimationProperties? animate;
  
  /// Target animation values (legacy Map format)
  final Map<String, dynamic>? _animateMap;
  
  /// Gets the initial values as a Map (for internal use)
  Map<String, dynamic>? get _initialMapValue {
    return initial?.toMap() ?? _initialMap;
  }
  
  /// Gets the animate values as a Map (for internal use)
  Map<String, dynamic>? get _animateMapValue {
    return animate?.toMap() ?? _animateMap;
  }

  /// Animation transition configuration (used with initial/animate)
  final Transition? transition;

  /// Animation configuration that runs on UI thread
  final AnimatedStyle? animatedStyle;

  /// Worklet function to execute on UI thread (takes precedence over animatedStyle)
  final Function? worklet;

  /// Worklet execution configuration (duration, parameters, etc.)
  final Map<String, dynamic>? workletConfig;

  /// Layout properties for positioning and sizing
  final DCFLayout? layout;

  /// Static styling properties (non-animated)
  final DCFStyleSheet? styleSheet;

  /// Whether to start animation automatically when component mounts.
  /// Set to `false` to control animation manually via prop updates.
  final bool autoStart;

  /// Delay before starting animation in milliseconds
  final int startDelay;

  /// Called when animation begins
  final void Function()? onAnimationStart;

  /// Called when animation completes
  final void Function()? onAnimationComplete;

  /// Called when animation repeats (for repeating animations)
  final void Function()? onAnimationRepeat;

  /// Additional event handlers
  final Map<String, dynamic>? events;

  /// Creates a new animated view component.
  ///
  /// The [children] parameter is required, all others have sensible defaults.
  /// Animation initialization is handled automatically.
  // Default layouts and styles for ReanimatedView (registered for bridge efficiency)
  // ignore: deprecated_member_use - Using DCFLayout()/DCFStyleSheet() inside create() is the correct pattern
  static final _reanimatedLayouts = DCFLayout.create({
    'default': DCFLayout(),
  });

  static final _reanimatedStyles = DCFStyleSheet.create({
    'default': DCFStyleSheet(),
  });

  ReanimatedView({
    required this.children,
    this.initial,
    this.animate,
    // Legacy Map support (for backwards compatibility)
    Map<String, dynamic>? initialMap,
    Map<String, dynamic>? animateMap,
    this.transition,
    this.animatedStyle,
    this.worklet,
    this.workletConfig,
    this.layout,
    this.styleSheet,
    this.autoStart = false,
    this.startDelay = 0,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.onAnimationRepeat,
    this.events,
    super.key,
  }) : _initialMap = initialMap,
       _animateMap = animateMap {
    // Ensure DCF Reanimated is initialized before first use
    ReanimatedInit.ensureInitialized();
  }

  @override
  DCFComponentNode render() {
    // Prepare event handlers map
    Map<String, dynamic> eventHandlers = events ?? {};

    // Add lifecycle callbacks to event handlers
    if (onAnimationStart != null) {
      eventHandlers['onAnimationStart'] = onAnimationStart;
    }
    if (onAnimationComplete != null) {
      eventHandlers['onAnimationComplete'] = onAnimationComplete;
    }
    if (onAnimationRepeat != null) {
      eventHandlers['onAnimationRepeat'] = onAnimationRepeat;
    }

    // Build props map for native bridge communication
    Map<String, dynamic> props = {
      // Animation configuration
      'autoStart': autoStart,
      'startDelay': startDelay,
      'isPureReanimated': true, // Flag for native to use pure animation mode

      // Layout and styling
      ...(layout ?? _reanimatedLayouts['default']).toMap(),
      ...(styleSheet ?? _reanimatedStyles['default']).toMap(),

      // Event handlers
      ...eventHandlers,
    };

    // Configure worklet if provided (takes precedence over everything)
    if (worklet != null) {
      final workletConfig = WorkletExecutor.serialize(worklet!);
      props['worklet'] = workletConfig.toMap();
      if (this.workletConfig != null) {
        props['workletConfig'] = this.workletConfig;
      }
    } else if (animate != null) {
      // Convert initial/animate to AnimatedStyle
      final convertedStyle = _buildAnimatedStyleFromInitialAnimate();
      if (convertedStyle != null) {
        props['animatedStyle'] = convertedStyle.toMap();
      }
    } else if (animatedStyle != null) {
      // Fall back to animated style if no worklet or initial/animate
      props['animatedStyle'] = animatedStyle!.toMap();
    }

    // Create DCF element that will be rendered by native component
    return DCFElement(
      type: 'ReanimatedView', // Must match native component registration
      elementProps: props,
      children: children,
    );
  }

  /// Converts initial/animate props to AnimatedStyle (similar to Motion component)
  AnimatedStyle? _buildAnimatedStyleFromInitialAnimate() {
    final animateMap = _animateMapValue;
    if (animateMap == null) return null;

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
    final initialValues = _initialMapValue ?? {};
    
    animateMap.forEach((key, value) {
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
        case 'translateX':
          style.transform(translateX: createValue(fromValue, toValue));
          break;
        case 'translateY':
          style.transform(translateY: createValue(fromValue, toValue));
          break;
        case 'translateZ':
          style.transform(translateZ: createValue(fromValue, toValue));
          break;
        default:
          break;
      }
    });

    return style;
  }

  /// Get default value for animation property
  dynamic _getDefaultValue(String key) {
    switch (key) {
      case 'opacity':
        return 1.0;
      case 'scale':
      case 'x':
      case 'y':
      case 'z':
      case 'translateX':
      case 'translateY':
      case 'translateZ':
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
}
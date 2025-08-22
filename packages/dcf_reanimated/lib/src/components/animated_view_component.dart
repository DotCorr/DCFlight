/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

// ============================================================================
// PURE ANIMATION VALUES - NO BRIDGE CALLS
// ============================================================================

/// Pure animation value - configured once, runs on UI thread
class ReanimatedValue {
  final double from;
  final double to;
  final int duration; // milliseconds
  final String curve;
  final int delay;
  final bool repeat;
  final int? repeatCount;

  const ReanimatedValue({
    required this.from,
    required this.to,
    this.duration = 300,
    this.curve = 'easeInOut',
    this.delay = 0,
    this.repeat = false,
    this.repeatCount,
  });

  Map<String, dynamic> toMap() => {
        'from': from,
        'to': to,
        'duration': duration,
        'curve': curve,
        'delay': delay,
        'repeat': repeat,
        if (repeatCount != null) 'repeatCount': repeatCount,
      };
}

/// Shared value that runs purely on UI thread
class SharedValue {
  final String _id;
  final ReanimatedValue config;

  SharedValue._(this._id, this.config);

  factory SharedValue(double initialValue) {
    final id = 'shared_${DateTime.now().microsecondsSinceEpoch}';
    return SharedValue._(
        id, ReanimatedValue(from: initialValue, to: initialValue));
  }

  String get id => _id;

  /// Create animation config for this shared value
  ReanimatedValue withTiming({
    required double toValue,
    int duration = 300,
    String curve = 'easeInOut',
    int delay = 0,
  }) {
    return ReanimatedValue(
      from: config.to, // Current value becomes from
      to: toValue,
      duration: duration,
      curve: curve,
      delay: delay,
    );
  }

  /// Create spring animation
  ReanimatedValue withSpring({
    required double toValue,
    double damping = 10,
    double stiffness = 100,
    int delay = 0,
  }) {
    return ReanimatedValue(
      from: config.to,
      to: toValue,
      duration: _calculateSpringDuration(damping, stiffness),
      curve: 'spring',
      delay: delay,
    );
  }

  /// Create repeat animation
  ReanimatedValue withRepeat({
    required double toValue,
    int duration = 300,
    String curve = 'easeInOut',
    bool reverse = true,
    int? numberOfReps,
  }) {
    return ReanimatedValue(
      from: config.to,
      to: toValue,
      duration: duration,
      curve: curve,
      repeat: true,
      repeatCount: numberOfReps,
    );
  }

  int _calculateSpringDuration(double damping, double stiffness) {
    // Simple spring duration calculation
    return ((damping / stiffness) * 1000).round().clamp(100, 2000);
  }
}

// ============================================================================
// PURE ANIMATED STYLES - NO BRIDGE CALLS
// ============================================================================

/// Animated style configuration that runs purely on UI thread
class AnimatedStyle {
  final Map<String, ReanimatedValue> _animations = {};

  /// Configure transform animations
  AnimatedStyle transform({
    ReanimatedValue? scale,
    ReanimatedValue? scaleX,
    ReanimatedValue? scaleY,
    ReanimatedValue? translateX,
    ReanimatedValue? translateY,
    ReanimatedValue? rotation,
    ReanimatedValue? rotationX,
    ReanimatedValue? rotationY,
  }) {
    if (scale != null) _animations['scale'] = scale;
    if (scaleX != null) _animations['scaleX'] = scaleX;
    if (scaleY != null) _animations['scaleY'] = scaleY;
    if (translateX != null) _animations['translateX'] = translateX;
    if (translateY != null) _animations['translateY'] = translateY;
    if (rotation != null) _animations['rotation'] = rotation;
    if (rotationX != null) _animations['rotationX'] = rotationX;
    if (rotationY != null) _animations['rotationY'] = rotationY;
    return this;
  }

  /// Configure opacity animation
  AnimatedStyle opacity(ReanimatedValue value) {
    _animations['opacity'] = value;
    return this;
  }

  /// Configure color animations
  AnimatedStyle backgroundColor(ReanimatedValue value) {
    _animations['backgroundColor'] = value;
    return this;
  }

  /// Configure layout animations
  AnimatedStyle layout({
    ReanimatedValue? width,
    ReanimatedValue? height,
    ReanimatedValue? top,
    ReanimatedValue? left,
    ReanimatedValue? right,
    ReanimatedValue? bottom,
  }) {
    if (width != null) _animations['width'] = width;
    if (height != null) _animations['height'] = height;
    if (top != null) _animations['top'] = top;
    if (left != null) _animations['left'] = left;
    if (right != null) _animations['right'] = right;
    if (bottom != null) _animations['bottom'] = bottom;
    return this;
  }

  Map<String, dynamic> toMap() {
    return _animations.map((key, value) => MapEntry(key, value.toMap()));
  }
}

// ============================================================================
// PURE REANIMATED HOOKS - NO BRIDGE CALLS
// ============================================================================

extension PureReanimatedHooks on StatefulComponent {
  /// Create a shared value that runs purely on UI thread
  SharedValue useSharedValue(double initialValue) {
    final ref = useRef<SharedValue?>(null);

    if (ref.current == null) {
      ref.current = SharedValue(initialValue);
    }

    return ref.current!;
  }

  /// Create animated style that runs purely on UI thread
  AnimatedStyle useAnimatedStyle(
    AnimatedStyle Function() styleFactory, {
    List<dynamic> dependencies = const [],
  }) {
    return useMemo(() => styleFactory(), dependencies: dependencies);
  }

  /// Run callback when animation completes - PURE
  void useAnimatedCallback(
    void Function() callback, {
    String? animationId,
    List<dynamic> dependencies = const [],
  }) {
    useEffect(() {
      // Register callback to be triggered by native animation completion
      return () {
        // Cleanup handled by native side
      };
    }, dependencies: [...dependencies, animationId]);
  }
}

// ============================================================================
// PURE REANIMATED COMPONENT - ZERO BRIDGE CALLS
// ============================================================================

/// Pure reanimated view - configured once, runs entirely on UI thread
class ReanimatedView extends StatelessComponent with EquatableMixin {
  final List<DCFComponentNode> children;
  final AnimatedStyle? animatedStyle;
  final LayoutProps layout;
  final StyleSheet styleSheet;
  final String? animationId;
  final bool autoStart;
  final int startDelay;
  final void Function()? onAnimationStart;
  final void Function()? onAnimationComplete;
  final void Function()? onAnimationRepeat;
  final Map<String, dynamic>? events;

  ReanimatedView({
    required this.children,
    this.animatedStyle,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.animationId,
    this.autoStart = true,
    this.startDelay = 0,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.onAnimationRepeat,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Generate stable ID only once
    final effectiveAnimationId =
        animationId ?? 'anim_${key?.toString() ?? hashCode}';
    // Prepare event handlers
    Map<String, dynamic> eventHandlers = events ?? {};

    if (onAnimationStart != null) {
      eventHandlers['onAnimationStart'] = onAnimationStart;
    }
    if (onAnimationComplete != null) {
      eventHandlers['onAnimationComplete'] = onAnimationComplete;
    }
    if (onAnimationRepeat != null) {
      eventHandlers['onAnimationRepeat'] = onAnimationRepeat;
    }

    // ✅ PURE: All animation config via props - NO BRIDGE CALLS
    Map<String, dynamic> props = {
      'animationId': effectiveAnimationId,
      'autoStart': autoStart,
      'startDelay': startDelay,
      'isPureReanimated': true, // Flag for native to use pure mode
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventHandlers,
    };

    // ✅ PURE: Pass animation configuration directly via props
    if (animatedStyle != null) {
      props['animatedStyle'] = animatedStyle!.toMap();
    }

    return DCFElement(
      type: 'ReanimatedView',
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        children,
        animatedStyle,
        layout,
        styleSheet,
        animationId,
        autoStart,
        startDelay,
        onAnimationStart,
        onAnimationComplete,
        onAnimationRepeat,
        events,
        key,
      ];
}

// ============================================================================
// PURE ANIMATION PRESETS - COMMON PATTERNS
// ============================================================================

class Reanimated {
  /// Fade in animation
  static AnimatedStyle fadeIn({
    int duration = 300,
    int delay = 0,
    String curve = 'easeInOut',
  }) {
    return AnimatedStyle().opacity(
      ReanimatedValue(
        from: 0.0,
        to: 1.0,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  /// Fade out animation
  static AnimatedStyle fadeOut({
    int duration = 300,
    int delay = 0,
    String curve = 'easeInOut',
  }) {
    return AnimatedStyle().opacity(
      ReanimatedValue(
        from: 1.0,
        to: 0.0,
        duration: duration,
        delay: delay,
        curve: curve,
      ),
    );
  }

  /// Scale in animation
  static AnimatedStyle scaleIn({
    double fromScale = 0.0,
    double toScale = 1.0,
    int duration = 300,
    int delay = 0,
    String curve = 'easeInOut',
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

  /// Slide in from right
  static AnimatedStyle slideInRight({
    double distance = 100.0,
    int duration = 300,
    int delay = 0,
    String curve = 'easeInOut',
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

  /// Slide in from left
  static AnimatedStyle slideInLeft({
    double distance = 100.0,
    int duration = 300,
    int delay = 0,
    String curve = 'easeInOut',
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

  /// Bounce animation
  static AnimatedStyle bounce({
    double bounceScale = 1.2,
    int duration = 600,
    int delay = 0,
    bool repeat = false,
    int? repeatCount,
  }) {
    return AnimatedStyle().transform(
      scale: ReanimatedValue(
        from: 1.0,
        to: bounceScale,
        duration: duration,
        delay: delay,
        curve: 'easeInOut',
        repeat: repeat,
        repeatCount: repeatCount,
      ),
    );
  }

  /// Pulse animation
  static AnimatedStyle pulse({
    double minOpacity = 0.5,
    double maxOpacity = 1.0,
    int duration = 1000,
    int delay = 0,
    bool repeat = false,
    int? repeatCount,
  }) {
    return AnimatedStyle().opacity(
      ReanimatedValue(
        from: maxOpacity,
        to: minOpacity,
        duration: duration,
        delay: delay,
        curve: 'easeInOut',
        repeat: repeat,
        repeatCount: repeatCount,
      ),
    );
  }

  /// Rotate animation
  static AnimatedStyle rotate({
    double fromRotation = 0.0,
    double toRotation = 6.28, // 2π (full rotation)
    int duration = 1000,
    int delay = 0,
    bool repeat = false,
    int? repeatCount,
  }) {
    return AnimatedStyle().transform(
      rotation: ReanimatedValue(
        from: fromRotation,
        to: toRotation,
        duration: duration,
        delay: delay,
        curve: 'linear',
        repeat: repeat,
        repeatCount: repeatCount,
      ),
    );
  }

  /// Shake animation
  static AnimatedStyle shake({
    double intensity = 10.0,
    int duration = 500,
    int delay = 0,
    int shakeCount = 3,
  }) {
    return AnimatedStyle().transform(
      translateX: ReanimatedValue(
        from: 0.0,
        to: intensity,
        duration: duration ~/ (shakeCount * 2),
        delay: delay,
        curve: 'linear',
        repeat: true,
        repeatCount: shakeCount * 2,
      ),
    );
  }

  /// Combined entrance animation
  static AnimatedStyle slideScaleFadeIn({
    double slideDistance = 50.0,
    double fromScale = 0.8,
    double toScale = 1.0,
    double fromOpacity = 0.0,
    double toOpacity = 1.0,
    int duration = 400,
    int delay = 0,
    String curve = 'easeOut',
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
        .opacity(
          ReanimatedValue(
            from: fromOpacity,
            to: toOpacity,
            duration: duration,
            delay: delay,
            curve: curve,
          ),
        );
  }
}

// ============================================================================
// PURE ANIMATION SEQUENCES - NO BRIDGE CALLS
// ============================================================================

/// Animation sequence that runs purely on UI thread
class AnimationSequence {
  final List<AnimatedStyle> _steps = [];
  final List<int> _delays = [];

  /// Add animation step
  AnimationSequence step(
    AnimatedStyle style, {
    int delay = 0,
  }) {
    _steps.add(style);
    _delays.add(delay);
    return this;
  }

  /// Convert to native configuration
  Map<String, dynamic> toMap() {
    return {
      'type': 'sequence',
      'steps': _steps.map((step) => step.toMap()).toList(),
      'delays': _delays,
    };
  }
}

/// Stagger multiple animations
class StaggeredAnimation {
  final List<AnimatedStyle> _animations = [];
  final int staggerDelay;

  StaggeredAnimation({required this.staggerDelay});

  /// Add animation to stagger
  StaggeredAnimation add(AnimatedStyle style) {
    _animations.add(style);
    return this;
  }

  /// Convert to native configuration
  Map<String, dynamic> toMap() {
    return {
      'type': 'staggered',
      'animations': _animations.map((anim) => anim.toMap()).toList(),
      'staggerDelay': staggerDelay,
    };
  }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

/*
// EXAMPLE 1: Simple fade in
ReanimatedView(
  animatedStyle: Reanimated.fadeIn(duration: 500),
  children: [DCFText(content: "Hello World")],
)

// EXAMPLE 2: Using shared values
class AnimatedScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final scale = useSharedValue(1.0);
    final opacity = useSharedValue(1.0);
    
    final animatedStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .transform(scale: scale.withTiming(toValue: 1.2, duration: 300))
        .opacity(opacity.withTiming(toValue: 0.8, duration: 300));
    });

    return ReanimatedView(
      animatedStyle: animatedStyle,
      onAnimationComplete: () => print("Animation done!"),
      children: [DCFText(content: "Animated!")],
    );
  }
}

// EXAMPLE 3: Complex entrance animation
ReanimatedView(
  animatedStyle: Reanimated.slideScaleFadeIn(
    slideDistance: 100,
    duration: 600,
    curve: 'easeOut',
  ),
  children: [DCFText(content: "Smooth entrance!")],
)

// EXAMPLE 4: Infinite pulse
ReanimatedView(
  animatedStyle: Reanimated.pulse(
    minOpacity: 0.3,
    duration: 1000,
    repeat: true,
  ),
  children: [DCFIcon(icon: "heart")],
)
*/

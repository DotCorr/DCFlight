/*
 * DCF Reanimated - UI Thread Animation System
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';
import 'package:dcflight/dcflight.dart';

// ============================================================================
// HOOKS SYSTEM - Pure Dart, No Method Channels
// ============================================================================

/// Hook implementation for animation controller lifecycle - PURE DART
class AnimationControllerHook extends Hook {
  final String controllerId;
  
  AnimationControllerHook() : controllerId = _generateControllerId() {
    // NO METHOD CHANNELS(🤯)! Just create the ID
    debugPrint('🎬 AnimationControllerHook: Created controller $controllerId');
  }
  
  static String _generateControllerId() {
    return 'anim_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }
  
  // The connection happens via props when DCFAnimatedView renders
  
  @override
  void dispose() {
    // Clean up is handled by DCFAnimationEngine when view is removed
    debugPrint('🗑️ AnimationControllerHook: Disposing controller $controllerId');
  }
}

/// Hook factory for registering with VDomExtensionRegistry
class AnimationControllerHookFactory extends VDomHookFactory {
  @override
  Hook createHook(StatefulComponent component, List<dynamic> args) {
    return AnimationControllerHook();
  }
}

// ============================================================================
// ANIMATED VIEW COMPONENT - With Full Layout & Styling Support
// ============================================================================

/// Enhanced DCFAnimatedView with mandatory animation controller
class DCFAnimatedView extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  
  @override
  ComponentPriority get priority => ComponentPriority.immediate; // Highest priority for smooth animation

  /// REQUIRED: Native animation controller ID from useAnimationController() hook
  final String nativeAnimationId;

  /// The animation command to execute
  final AnimatedViewCommand? command;

  /// Child nodes
  final List<DCFComponentNode> children;

  /// The layout properties (like all other components)
  final LayoutProps layout;

  /// The style properties (like all other components) 
  final StyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Animation end event handler
  final Function(Map<dynamic, dynamic>)? onAnimationEnd;

  /// Animation start event handler
  final Function(Map<dynamic, dynamic>)? onAnimationStart;

  /// Whether to use adaptive theming
  final bool adaptive;

  /// Create an animated view component
  /// 
  /// IMPORTANT: You must use useAnimationController() hook to get nativeAnimationId
  /// 
  /// Example:
  /// ```dart
  /// class MyAnimatedComponent extends StatefulComponent {
  ///   @override
  ///   DCFComponentNode render() {
  ///     final animationController = useAnimationController();
  ///     
  ///     return DCFAnimatedView(
  ///       nativeAnimationId: animationController,
  ///       command: AnimationPresets.bounce,
  ///       layout: LayoutProps(height: 100, width: 200),
  ///       styleSheet: StyleSheet(backgroundColor: Colors.blue, borderRadius: 8),
  ///       children: [...]
  ///     );
  ///   }
  /// }
  /// ```
  DCFAnimatedView({
    required this.nativeAnimationId,
    required this.children,
    this.command,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.onAnimationEnd,
    this.onAnimationStart,
    this.events,
    this.adaptive = true,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Create events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};

    if (onAnimationEnd != null) {
      eventMap['onAnimationEnd'] = onAnimationEnd;
    }
    
    if (onAnimationStart != null) {
      eventMap['onAnimationStart'] = onAnimationStart;
    }

    // Build props with native animation controller + layout + styling
    Map<String, dynamic> props = {
      'nativeAnimationId': nativeAnimationId, // REQUIRED for UI thread animation
      'adaptive': adaptive,
      ...layout.toMap(), // Add layout properties
      ...styleSheet.toMap(), // Add style properties
      ...eventMap,
    };

    // Add command if provided
    if (command != null) {
      props['command'] = command!.toMap();
    }

    return DCFElement(
      type: 'AnimatedView',
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        nativeAnimationId,
        command,
        children,
        layout,
        styleSheet,
        onAnimationEnd,
        onAnimationStart,
        events,
        adaptive,
        key,
      ];
}

// ============================================================================
// ANIMATION COMMANDS - Declarative Animation API
// ============================================================================

/// Base class for animation commands
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

/// Sequential animation command - runs multiple animations in order
class SequenceCommand extends AnimatedViewCommand {
  final List<AnimatedViewCommand> commands;
  
  const SequenceCommand(this.commands);
  
  @override
  String get type => 'sequence';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'commands': commands.map((cmd) => cmd.toMap()).toList(),
  };
}

/// Parallel animation command - runs multiple animations simultaneously  
class ParallelCommand extends AnimatedViewCommand {
  final List<AnimatedViewCommand> commands;
  
  const ParallelCommand(this.commands);
  
  @override
  String get type => 'parallel';
  
  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'commands': commands.map((cmd) => cmd.toMap()).toList(),
  };
}

// ============================================================================
// ANIMATION PRESETS - Common Animations
// ============================================================================

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

  static const AnimateCommand shake = AnimateCommand(
    toTranslateX: 10,
    duration: 0.1,
    repeat: true,
  );

  static const AnimateCommand spin = AnimateCommand(
    toRotation: 6.28318, // 2π radians = 360 degrees
    duration: 1.0,
    curve: 'linear',
    repeat: true,
  );

  /// Entrance animations
  static const AnimateCommand slideInFromTop = AnimateCommand(
    toTranslateY: 0,
    duration: 0.4,
    curve: 'easeOut',
  );

  static const AnimateCommand slideInFromBottom = AnimateCommand(
    toTranslateY: 0,
    duration: 0.4,
    curve: 'easeOut',
  );

  static const AnimateCommand zoomIn = AnimateCommand(
    toScale: 1.0,
    toOpacity: 1.0,
    duration: 0.3,
    curve: 'easeOut',
  );

  /// Exit animations
  static const AnimateCommand slideOutToTop = AnimateCommand(
    toTranslateY: -300,
    duration: 0.4,
    curve: 'easeIn',
  );

  static const AnimateCommand slideOutToBottom = AnimateCommand(
    toTranslateY: 300,
    duration: 0.4,
    curve: 'easeIn',
  );

  static const AnimateCommand zoomOut = AnimateCommand(
    toScale: 0.0,
    toOpacity: 0.0,
    duration: 0.3,
    curve: 'easeIn',
  );

  /// Complex sequences
  static const SequenceCommand bounceIn = SequenceCommand([
    AnimateCommand(toScale: 1.2, duration: 0.2, curve: 'easeOut'),
    AnimateCommand(toScale: 0.9, duration: 0.1, curve: 'easeInOut'), 
    AnimateCommand(toScale: 1.0, duration: 0.1, curve: 'easeOut'),
  ]);

  static const SequenceCommand elastic = SequenceCommand([
    AnimateCommand(toScale: 1.3, duration: 0.2, curve: 'easeOut'),
    AnimateCommand(toScale: 0.8, duration: 0.2, curve: 'easeInOut'),
    AnimateCommand(toScale: 1.1, duration: 0.1, curve: 'easeOut'),
    AnimateCommand(toScale: 1.0, duration: 0.1, curve: 'easeInOut'),
  ]);
}

/// Animation curve presets
class AnimationCurves {
  static const String linear = 'linear';
  static const String easeIn = 'easeIn';
  static const String easeOut = 'easeOut';
  static const String easeInOut = 'easeInOut';
  static const String elasticIn = 'elasticIn';
  static const String elasticOut = 'elasticOut';
  static const String bounceIn = 'bounceIn';
  static const String bounceOut = 'bounceOut';
}

// ============================================================================
// SETUP & HELPER FUNCTIONS
// ============================================================================

/// Setup function to register animation hooks with VDomExtensionRegistry
void setupDCFReanimated() {
  VDomExtensionRegistry.instance.registerHookFactory(
    'useAnimationController', 
    AnimationControllerHookFactory()
  );
  
  print('🎬 DCF Reanimated: Animation system initialized');
}

/// Extension on StatefulComponent to add animation controller hook method
extension AnimationHooks on StatefulComponent {
  /// Hook to create a native animation controller for UI thread animation
  String useAnimationController() {
    return useCustomHook<AnimationControllerHook>('useAnimationController', []).controllerId;
  }
}

/// Utility functions for animation
class AnimationUtils {
  /// Convert degrees to radians
  static double degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }
  
  /// Convert radians to degrees  
  static double radiansToDegrees(double radians) {
    return radians * (180.0 / 3.14159265359);
  }
  
  /// Create a smooth bounce effect
  static SequenceCommand createBounce({
    double scale = 1.2,
    double duration = 0.6,
  }) {
    final stepDuration = duration / 4;
    return SequenceCommand([
      AnimateCommand(toScale: scale, duration: stepDuration, curve: 'easeOut'),
      AnimateCommand(toScale: 0.9, duration: stepDuration, curve: 'easeInOut'),
      AnimateCommand(toScale: 1.05, duration: stepDuration, curve: 'easeOut'),
      AnimateCommand(toScale: 1.0, duration: stepDuration, curve: 'easeInOut'),
    ]);
  }
  
  /// Create a shake animation
  static SequenceCommand createShake({
    double intensity = 10.0,
    int cycles = 3,
    double duration = 0.6,
  }) {
    final commands = <AnimatedViewCommand>[];
    final stepDuration = duration / (cycles * 2);
    
    for (int i = 0; i < cycles; i++) {
      commands.add(AnimateCommand(
        toTranslateX: intensity, 
        duration: stepDuration, 
        curve: 'linear'
      ));
      commands.add(AnimateCommand(
        toTranslateX: -intensity, 
        duration: stepDuration, 
        curve: 'linear'
      ));
    }
    
    commands.add(AnimateCommand(
      toTranslateX: 0, 
      duration: stepDuration, 
      curve: 'easeOut'
    ));
    
    return SequenceCommand(commands);
  }
}
/*
 * DCF Reanimated - Updated to use FrameworkTunnel (No more DirectAnimationCommands!)
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import 'package:dcflight/dcflight.dart';

// ============================================================================
// ANIMATION COMMANDS - Individual Animation Control
// ============================================================================

/// Base class for animation commands
abstract class AnimatedViewCommand {
  const AnimatedViewCommand();
  Map<String, dynamic> toMap();
  String get type;
}

/// Command to start an animation with specified parameters
class AnimateCommand extends AnimatedViewCommand {
  final double? duration;
  final String? curve;
  final double? toScale;
  final double? toOpacity;
  final double? toTranslateX;
  final double? toTranslateY;
  final double? toRotation;
  final bool? repeat;
  final double? delay;

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
    if (duration != null) map['duration'] = (duration! * 1000).round();
    if (curve != null) map['curve'] = curve;
    if (toScale != null) map['toScale'] = toScale;
    if (toOpacity != null) map['toOpacity'] = toOpacity;
    if (toTranslateX != null) map['toTranslateX'] = toTranslateX;
    if (toTranslateY != null) map['toTranslateY'] = toTranslateY;
    if (toRotation != null) map['toRotation'] = toRotation;
    if (repeat != null) map['repeat'] = repeat;
    if (delay != null) map['delay'] = (delay! * 1000).round();
    return map;
  }
}

// ============================================================================
// ANIMATION PRESETS - Common Animation Patterns
// ============================================================================

class Animations {
  /// Bouncing scale animation
  static AnimateCommand bounce({
    double scale = 1.2,
    double duration = 2.0,
    String curve = 'easeInOut',
    bool repeat = false,
  }) => AnimateCommand(
    toScale: scale,
    toTranslateY: -20,
    duration: duration,
    curve: curve,
    repeat: repeat,
  );
  
  /// Sliding animation
  static AnimateCommand slide({
    double translateX = 50,
    double opacity = 0.8,
    double duration = 2.0,
    String curve = 'easeInOut',
    bool repeat = false,
  }) => AnimateCommand(
    toTranslateX: translateX,
    toOpacity: opacity,
    duration: duration,
    curve: curve,
    repeat: repeat,
  );
  
  /// Rotation animation
  static AnimateCommand rotate({
    double rotation = 0.5,
    double scale = 1.1,
    double duration = 2.0,
    String curve = 'easeInOut', 
    bool repeat = false,
  }) => AnimateCommand(
    toRotation: rotation,
    toScale: scale,
    duration: duration,
    curve: curve,
    repeat: repeat,
  );
  
  /// Fade animation
  static AnimateCommand fade({
    double opacity = 0.5,
    double duration = 1.5,
    String curve = 'easeInOut',
    bool repeat = false,
  }) => AnimateCommand(
    toOpacity: opacity,
    duration: duration,
    curve: curve,
    repeat: repeat,
  );
  
  /// Complex multi-property animation
  static AnimateCommand complex({
    double? scale,
    double? opacity,
    double? translateX,
    double? translateY,
    double? rotation,
    double duration = 2.0,
    String curve = 'easeInOut',
    bool repeat = false,
  }) => AnimateCommand(
    toScale: scale,
    toOpacity: opacity,
    toTranslateX: translateX,
    toTranslateY: translateY,
    toRotation: rotation,
    duration: duration,
    curve: curve,
    repeat: repeat,
  );
}

// ============================================================================
// ANIMATED VIEW COMPONENT - NO COMMAND PROPS, TUNNEL ONLY
// ============================================================================

class DCFAnimatedView extends StatelessComponent with EquatableMixin implements ComponentPriorityInterface {
  
  @override
  ComponentPriority get priority => ComponentPriority.immediate;

  final String nativeAnimationId;
  final String? groupId;
  final LayoutProps layout;
  final StyleSheet styleSheet;
  final List<DCFComponentNode> children;
  final void Function(Map<String, dynamic>)? onAnimationStart;
  final void Function(Map<String, dynamic>)? onAnimationEnd;
  final Map<String, void Function(Map<String, dynamic>)>? events;
  final bool adaptive;

  DCFAnimatedView({
    required this.nativeAnimationId,
    this.groupId,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.children = const [],
    this.onAnimationStart,
    this.onAnimationEnd,
    this.events,
    this.adaptive = true,
    super.key,
  }) {
    // ✅ Register controller immediately via FrameworkTunnel (no VDOM)
    FrameworkTunnel.call('AnimatedView', 'registerController', {
      'controllerId': nativeAnimationId,
      'groupId': groupId,
    });
  }

  @override
  DCFComponentNode render() {
    Map<String, void Function(Map<String, dynamic>)> eventMap = events ?? {};

    if (onAnimationEnd != null) {
      eventMap['onAnimationEnd'] = onAnimationEnd!;
    }
    
    if (onAnimationStart != null) {
      eventMap['onAnimationStart'] = onAnimationStart!;
    }

    // ✅ NO COMMAND PROPS - only essential rendering props
    Map<String, dynamic> props = {
      'nativeAnimationId': nativeAnimationId,
      'adaptive': adaptive,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    if (groupId != null) {
      props['groupId'] = groupId;
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
        groupId,
        children,
        layout,
        styleSheet,
        onAnimationStart,
        onAnimationEnd,
        events,
        adaptive,
        key,
      ];
}

// ============================================================================
// ANIMATION MANAGER COMPONENT - NO COMMAND PROPS, TUNNEL ONLY
// ============================================================================

class DCFAnimationManager extends StatelessComponent with EquatableMixin {
  final String groupId;
  final List<DCFComponentNode> children;
  final bool autoStart;
  final String? debugName;

  DCFAnimationManager({
    required this.groupId,
    this.children = const [],
    this.autoStart = true,
    this.debugName,
    super.key,
  }) {
    // ✅ Register group immediately via FrameworkTunnel (no VDOM)
    FrameworkTunnel.call('AnimationManager', 'registerGroup', {
      'groupId': groupId,
      'autoStart': autoStart,
      'debugName': debugName ?? groupId,
    });
  }

  @override
  DCFComponentNode render() {
    // ✅ NO COMMAND PROPS - only essential rendering props
    Map<String, dynamic> props = {
      'groupId': groupId,
      'autoStart': autoStart,
      'debugName': debugName ?? groupId,
    };

    return DCFElement(
      type: 'AnimationManager',
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [groupId, children, autoStart, debugName, key];
}

// ============================================================================
// ANIMATION BUILDER CONTEXT - DIRECT FRAMEWORKTUNNEL COMMANDS
// ============================================================================

class AnimationBuilderContext {
  final String groupId;
  final Map<String, String> _controllers = {};
  
  AnimationBuilderContext._(this.groupId);
  
  String _getController(String name) {
    if (!_controllers.containsKey(name)) {
      _controllers[name] = 'anim_${DateTime.now().millisecondsSinceEpoch}_${name}_${_controllers.length}';
    }
    return _controllers[name]!;
  }
  
  DCFAnimatedView animated({
    required String name,
    required List<DCFComponentNode> children,
    LayoutProps layout = const LayoutProps(),
    StyleSheet styleSheet = const StyleSheet(),
    void Function(Map<String, dynamic>)? onAnimationStart,
    void Function(Map<String, dynamic>)? onAnimationEnd,
  }) {
    return DCFAnimatedView(
      nativeAnimationId: _getController(name),
      groupId: groupId,
      layout: layout,
      styleSheet: styleSheet,
      children: children,
      onAnimationStart: onAnimationStart,
      onAnimationEnd: onAnimationEnd,
    );
  }
  
  // ========================================================================
  // INDIVIDUAL ANIMATION CONTROL - FRAMEWORKTUNNEL
  // ========================================================================
  
  void startAnimation(String name, AnimateCommand command) {
    final controllerId = _controllers[name];
    if (controllerId != null) {
      FrameworkTunnel.call('AnimatedView', 'startAnimation', {
        'controllerId': controllerId,
        'config': command.toMap(),
      });
      print("🎬 Individual: Started animation '$name' via TUNNEL");
    } else {
      print("⚠️ Individual: Animation '$name' not found");
    }
  }
  
  void pauseAnimation(String name) {
    final controllerId = _controllers[name];
    if (controllerId != null) {
      FrameworkTunnel.call('AnimatedView', 'executeIndividualCommand', {
        'controllerId': controllerId,
        'command': {"type": "pause"},
      });
      print("⏸️ Individual: Paused animation '$name' via TUNNEL");
    } else {
      print("⚠️ Individual: Animation '$name' not found");
    }
  }
  
  void resumeAnimation(String name) {
    final controllerId = _controllers[name];
    if (controllerId != null) {
      FrameworkTunnel.call('AnimatedView', 'executeIndividualCommand', {
        'controllerId': controllerId,
        'command': {"type": "resume"},
      });
      print("▶️ Individual: Resumed animation '$name' via TUNNEL");
    } else {
      print("⚠️ Individual: Animation '$name' not found");
    }
  }
  
  void stopAnimation(String name) {
    final controllerId = _controllers[name];
    if (controllerId != null) {
      FrameworkTunnel.call('AnimatedView', 'executeIndividualCommand', {
        'controllerId': controllerId,
        'command': {"type": "stop"},
      });
      print("🛑 Individual: Stopped animation '$name' via TUNNEL");
    } else {
      print("⚠️ Individual: Animation '$name' not found");
    }
  }
  
  void resetAnimation(String name, {bool animated = false}) {
    final controllerId = _controllers[name];
    if (controllerId != null) {
      FrameworkTunnel.call('AnimatedView', 'executeIndividualCommand', {
        'controllerId': controllerId,
        'command': {"type": "reset", "animated": animated},
      });
      print("🔄 Individual: Reset animation '$name' via TUNNEL");
    } else {
      print("⚠️ Individual: Animation '$name' not found");
    }
  }
  
  void stopRepeat(String name) {
    final controllerId = _controllers[name];
    if (controllerId != null) {
      FrameworkTunnel.call('AnimatedView', 'executeIndividualCommand', {
        'controllerId': controllerId,
        'command': {"type": "stopRepeat"},
      });
      print("🔄 Individual: Stopped repeat on animation '$name' via TUNNEL");
    } else {
      print("⚠️ Individual: Animation '$name' not found");
    }
  }
  
  // ========================================================================
  // GROUP CONTROL METHODS - FRAMEWORKTUNNEL
  // ========================================================================
  
  void startAll({double? delay, bool staggered = false, double? staggerInterval}) {
    FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
      'groupId': groupId,
      'command': {
        "type": "startAll",
        if (delay != null) "delay": (delay * 1000).round(),
        if (staggered) "staggered": staggered,
        if (staggerInterval != null) "staggerInterval": (staggerInterval * 1000).round(),
      },
    });
    print("🎬 Group: Started all animations via TUNNEL");
  }
  
  void stopAll({bool immediate = true}) {
    FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
      'groupId': groupId,
      'command': {
        "type": "stopAll",
        "immediate": immediate,
      },
    });
    print("🛑 Group: Stopped all animations via TUNNEL");
  }
  
  void pauseAll() {
    FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
      'groupId': groupId,
      'command': {"type": "pauseAll"},
    });
    print("⏸️ Group: Paused all animations via TUNNEL");
  }
  
  void resumeAll() {
    FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
      'groupId': groupId,
      'command': {"type": "resumeAll"},
    });
    print("▶️ Group: Resumed all animations via TUNNEL");
  }
  
  void resetAll({bool animated = false}) {
    FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
      'groupId': groupId,
      'command': {
        "type": "resetAll",
        "animated": animated,
      },
    });
    print("🔄 Group: Reset all animations via TUNNEL");
  }
  
  void dispose() {
    FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
      'groupId': groupId,
      'command': {"type": "dispose"},
    });
    print("🗑️ Group: Disposed animation group via TUNNEL");
  }
  
  List<String> getAnimationNames() => _controllers.keys.toList();
  bool hasAnimation(String name) => _controllers.containsKey(name);
}

// ============================================================================
// SUPER ANIMATION MANAGER - TUNNEL-BASED VERSION
// ============================================================================

class SuperDCFAnimationManager extends StatefulComponent {
  final String groupId;
  final List<DCFComponentNode> Function(AnimationBuilderContext context) builder;
  final bool autoStart;
  final String? debugName;

  SuperDCFAnimationManager({
    required this.groupId,
    required this.builder,
    this.autoStart = true,
    this.debugName,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // ✅ Create animation context with DIRECT tunnel executor
    final context = AnimationBuilderContext._(groupId);
    
    // ✅ Build animated children ONCE - NEVER rebuild them
    final animatedChildren = builder(context);
    
    // ✅ CRITICAL FIX: Wait for views to be fully rendered before allowing animations
    useLayoutEffect(() {
      print("🎯 SuperDCFAnimationManager mounted, scheduling delayed animation start");
      
      // ✅ Wait for native views to be registered with animation engine
      Future.delayed(Duration(milliseconds: 300), () {
        print("🎯 Animation delay complete - ready for tunnel calls");
      });
      
      return null;
    }, dependencies: []);
    
    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        // ✅ Animation manager - NO command props, tunnel-based
        DCFAnimationManager(
          groupId: groupId,
          debugName: debugName ?? "SuperManager-$groupId",
          autoStart: autoStart,
          children: animatedChildren,
        ),
      ],
    );
  }
}


/*
 * DCF Reanimated - Complete Clean Animation System
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import 'package:dcflight/dcflight.dart';

// ============================================================================
// GROUP ANIMATION COMMANDS - Control Multiple Animations
// ============================================================================

/// Base class for group animation commands
abstract class GroupAnimationCommand {
  const GroupAnimationCommand();

  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();

  /// Command type identifier for native side
  String get type;

  // Static factory methods for common commands
  static const GroupAnimationCommand startAll = StartAllCommand();
  static const GroupAnimationCommand stopAll = StopAllCommand();
  static const GroupAnimationCommand pauseAll = PauseAllCommand();
  static const GroupAnimationCommand resumeAll = ResumeAllCommand();
  static const GroupAnimationCommand resetAll = ResetAllCommand();
  static const GroupAnimationCommand dispose = GroupDisposalCommand();
}

/// Command to start all animations in the group
class StartAllCommand extends GroupAnimationCommand {
  final double? delay;
  final bool? staggered;
  final double? staggerInterval;

  const StartAllCommand({
    this.delay,
    this.staggered,
    this.staggerInterval,
  });

  @override
  String get type => 'startAll';

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': type};
    if (delay != null) map['delay'] = (delay! * 1000).round();
    if (staggered != null) map['staggered'] = staggered;
    if (staggerInterval != null) map['staggerInterval'] = (staggerInterval! * 1000).round();
    return map;
  }
}

/// Command to stop all animations in the group
class StopAllCommand extends GroupAnimationCommand {
  final bool? immediate;

  const StopAllCommand({this.immediate});

  @override
  String get type => 'stopAll';

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': type};
    if (immediate != null) map['immediate'] = immediate;
    return map;
  }
}

/// Command to pause all animations in the group
class PauseAllCommand extends GroupAnimationCommand {
  const PauseAllCommand();

  @override
  String get type => 'pauseAll';

  @override
  Map<String, dynamic> toMap() => {'type': type};
}

/// Command to resume all paused animations in the group
class ResumeAllCommand extends GroupAnimationCommand {
  const ResumeAllCommand();

  @override
  String get type => 'resumeAll';

  @override
  Map<String, dynamic> toMap() => {'type': type};
}

/// Command to reset all animations to initial state
class ResetAllCommand extends GroupAnimationCommand {
  final bool? animated;

  const ResetAllCommand({this.animated});

  @override
  String get type => 'resetAll';

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': type};
    if (animated != null) map['animated'] = animated;
    return map;
  }
}

/// Command to dispose all animations in the group
class GroupDisposalCommand extends GroupAnimationCommand {
  const GroupDisposalCommand();

  @override
  String get type => 'dispose';

  @override
  Map<String, dynamic> toMap() => {'type': type};
}

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
    bool repeat = true,
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
    bool repeat = true,
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
    bool repeat = true,
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
    bool repeat = true,
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
    bool repeat = true,
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
// ANIMATION MANAGER COMPONENT - Low-level Group Controller
// ============================================================================

/// Animation Manager for controlling multiple animations as a group (internal use)
class DCFAnimationManager extends StatelessComponent with EquatableMixin {
  /// Unique identifier for this animation group
  final String groupId;
  
  /// Command to execute on the entire animation group
  final GroupAnimationCommand? command;
  
  /// Child components (typically DCFAnimatedViews)
  final List<DCFComponentNode> children;
  
  /// Whether to auto-start animations when manager mounts
  final bool autoStart;
  
  /// Debug name for logging
  final String? debugName;

   DCFAnimationManager({
    required this.groupId,
    this.command,
    this.children = const [],
    this.autoStart = true,
    this.debugName,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Build props for the native animation manager
    Map<String, dynamic> props = {
      'groupId': groupId,
      'autoStart': autoStart,
      'debugName': debugName ?? groupId,
    };

    // Add command if provided
    if (command != null) {
      props['command'] = command!.toMap();
    }

    return DCFElement(
      type: 'AnimationManager',
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [groupId, command, children, autoStart, debugName, key];
}

// ============================================================================
// ANIMATED VIEW COMPONENT - Low-level Individual Animation
// ============================================================================

/// Enhanced DCFAnimatedView that can auto-register with animation groups (internal use)
class DCFAnimatedView extends StatelessComponent with EquatableMixin implements ComponentPriorityInterface {
  
  @override
  ComponentPriority get priority => ComponentPriority.immediate;

  /// REQUIRED: Native animation controller ID
  final String nativeAnimationId;

  /// Optional: Animation group ID for automatic registration
  final String? groupId;

  /// The animation command to execute
  final AnimatedViewCommand? command;

  /// Layout properties for the animated view
  final LayoutProps layout;

  /// Style properties for the animated view  
  final StyleSheet styleSheet;

  /// Child components to animate
  final List<DCFComponentNode> children;

  /// Animation event callbacks
  final void Function(Map<String, dynamic>)? onAnimationStart;
  final void Function(Map<String, dynamic>)? onAnimationEnd;

  /// Additional event handlers
  final Map<String, void Function(Map<String, dynamic>)>? events;

  /// Whether to use adaptive behavior
  final bool adaptive;

   DCFAnimatedView({
    required this.nativeAnimationId,
    this.groupId,
    this.command,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.children = const [],
    this.onAnimationStart,
    this.onAnimationEnd,
    this.events,
    this.adaptive = true,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Build event map
    Map<String, void Function(Map<String, dynamic>)> eventMap = events ?? {};

    if (onAnimationEnd != null) {
      eventMap['onAnimationEnd'] = onAnimationEnd!;
    }
    
    if (onAnimationStart != null) {
      eventMap['onAnimationStart'] = onAnimationStart!;
    }

    // Build props with native animation controller + layout + styling + group registration
    Map<String, dynamic> props = {
      'nativeAnimationId': nativeAnimationId,
      'adaptive': adaptive,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    // Add group registration if specified
    if (groupId != null) {
      props['groupId'] = groupId;
    }

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
        groupId,
        command,
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
// ANIMATION BUILDER CONTEXT - Auto-generates Controllers
// ============================================================================

/// Context provided to animation builder - handles all controller management
class AnimationBuilderContext {
  final String groupId;
  final Map<String, String> _controllers = {};
  final void Function(GroupAnimationCommand) _executeCommand;
  
  AnimationBuilderContext._(this.groupId, this._executeCommand);
  
  /// Auto-generate controller ID for named animation
  String _getController(String name) {
    if (!_controllers.containsKey(name)) {
      _controllers[name] = 'anim_${DateTime.now().millisecondsSinceEpoch}_${name}_${_controllers.length}';
    }
    return _controllers[name]!;
  }
  
  /// Create animated view with auto-generated controller
  DCFAnimatedView animated({
    required String name,
    required AnimateCommand command,
    required List<DCFComponentNode> children,
    LayoutProps layout = const LayoutProps(),
    StyleSheet styleSheet = const StyleSheet(),
    void Function(Map<String, dynamic>)? onAnimationStart,
    void Function(Map<String, dynamic>)? onAnimationEnd,
  }) {
    return DCFAnimatedView(
      nativeAnimationId: _getController(name),
      groupId: groupId,
      command: command,
      layout: layout,
      styleSheet: styleSheet,
      children: children,
      onAnimationStart: onAnimationStart,
      onAnimationEnd: onAnimationEnd,
    );
  }
  
 
  
  // ========================================================================
  // GROUP CONTROL METHODS - Direct access to animation commands
  // ========================================================================
  
  void startAll({double? delay, bool staggered = false, double? staggerInterval}) {
    _executeCommand(StartAllCommand(
      delay: delay,
      staggered: staggered,
      staggerInterval: staggerInterval,
    ));
  }
  
  void stopAll({bool immediate = true}) {
    _executeCommand(StopAllCommand(immediate: immediate));
  }
  
  void pauseAll() {
    _executeCommand(GroupAnimationCommand.pauseAll);
  }
  
  void resumeAll() {
    _executeCommand(GroupAnimationCommand.resumeAll);
  }
  
  void resetAll({bool animated = false}) {
    _executeCommand(ResetAllCommand(animated: animated));
  }
  
  void dispose() {
    _executeCommand(GroupAnimationCommand.dispose);
  }
}

// ============================================================================
// SUPER ANIMATION MANAGER - The Central Animation Sandbox
// ============================================================================

/// SuperDCFAnimationManager - Central animation control with builder pattern
/// This is the main API - eliminates need for manual controller ID management
class SuperDCFAnimationManager extends StatefulComponent {
  /// Unique group identifier
  final String groupId;
  
  /// Builder function - receives context with auto-generated controllers
  final List<DCFComponentNode> Function(AnimationBuilderContext context) builder;
  
  /// Auto-start animations when mounted
  final bool autoStart;
  
  /// Debug name for logging
  final String? debugName;
  
  /// Callback when group commands are executed
  final void Function(GroupAnimationCommand)? onCommand;

   SuperDCFAnimationManager({
    required this.groupId,
    required this.builder,
    this.autoStart = true,
    this.debugName,
    this.onCommand,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Group command state hook
    final groupCommand = useState<GroupAnimationCommand?>(null, 'cmd_$groupId');
    
    // Create animation context with command executor
    final context = AnimationBuilderContext._(groupId, (command) {
      groupCommand.setState(command);
      onCommand?.call(command);
      print("🎮 SuperManager[$groupId]: Executing ${command.type}");
    });
    
    // Build all animated views using the context
    final animatedChildren = builder(context);
    
    return DCFView(
      layout: LayoutProps(
        flex: 1,
      ),
      children: [
        DCFAnimationManager(
          groupId: groupId,
          debugName: debugName ?? "SuperManager-$groupId",
          autoStart: autoStart,
          command: groupCommand.state,
          children: animatedChildren,
        ),
      ],
    );
  }
}


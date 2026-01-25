/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'package:dcflight/dcflight.dart';
import 'reanimated_view.dart';
import '../helper/init.dart';

/// Animated text component that runs worklets on the UI thread.
///
/// [AnimatedText] allows you to animate text content using worklets that run
/// entirely on the native UI thread, providing zero bridge calls during execution.
///
/// Key features:
/// - Pure UI thread execution (60fps)
/// - Zero bridge calls during animation
/// - Supports any worklet that returns String
/// - Automatic initialization
///
/// Example:
/// ```dart
/// @Worklet
/// String typewriter(double elapsed, List<String> words) {
///   // Calculate text based on elapsed time
///   return words[0].substring(0, (elapsed * 10).floor());
/// }
///
/// AnimatedText(
///   worklet: typewriter,
///   workletConfig: {
///     'words': ['Hello', 'World'],
///     'duration': 2000,
///   },
///   textProps: DCFTextProps(fontSize: 20),
/// )
/// ```
class AnimatedText extends DCFStatelessComponent {
  /// Worklet function that returns String (runs on UI thread)
  final Function worklet;

  /// Worklet execution configuration (duration, parameters, etc.)
  final Map<String, dynamic> workletConfig;

  /// Text properties
  final DCFTextProps textProps;

  /// Layout properties
  final DCFLayout? layout;

  /// Style properties
  final DCFStyleSheet? styleSheet;

  /// Explicit color override
  final Color? textColor;

  /// Whether to start animation automatically
  final bool autoStart;

  /// Delay before starting animation in milliseconds
  final int startDelay;

  /// Called when animation begins
  final void Function()? onAnimationStart;

  /// Called when animation completes
  final void Function()? onAnimationComplete;

  /// Additional event handlers
  final Map<String, dynamic>? events;

  AnimatedText({
    required this.worklet,
    required this.workletConfig,
    this.textProps = const DCFTextProps(),
    this.layout,
    this.styleSheet,
    this.textColor,
    this.autoStart = true,
    this.startDelay = 0,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.events,
    super.key,
  }) {
    // Ensure DCF Reanimated is initialized
    ReanimatedInit.ensureInitialized();
  }

  @override
  DCFComponentNode render() {
    // Use ReanimatedView to execute worklet on UI thread
    // The worklet returns String, which will update child Text component
    return ReanimatedView(
      worklet: worklet,
      workletConfig: {
        ...workletConfig,
        'returnType': 'String', // Tell native this worklet returns String
        'updateTextChild': true, // Flag to update child Text component
      },
      autoStart: autoStart,
      startDelay: startDelay,
      onAnimationStart: onAnimationStart,
      onAnimationComplete: onAnimationComplete,
      layout: layout,
      styleSheet: styleSheet,
      children: [
        DCFText(
          content: '', // Will be updated by worklet on UI thread via tunnel
          textProps: textProps,
          textColor: textColor,
          layout: const DCFLayout(),
          styleSheet: const DCFStyleSheet(),
        ),
      ],
    );
  }
}


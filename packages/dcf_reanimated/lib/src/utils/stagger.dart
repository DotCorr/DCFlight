/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import '../components/motion.dart';
import '../enums/animation_enums.dart';

/// Utilities for creating staggered animations
/// 
/// Staggered animations create sequential animations for lists of elements,
/// where each element starts its animation slightly after the previous one.
/// 
/// Example:
/// ```dart
/// final stagger = Stagger(delay: 0.1); // 100ms between each child
/// 
/// children.map((child, index) => Motion(
///   initial: { 'opacity': 0, 'y': 20 },
///   animate: { 'opacity': 1, 'y': 0 },
///   transition: stagger.transition(index),
///   children: [child],
/// ))
/// ```
class Stagger {
  /// Delay between each child animation (in seconds)
  final double delay;
  
  /// Delay before first child animation starts (in seconds)
  final double delayChildren;
  
  /// Animation duration for each child
  final int duration;
  
  /// Easing curve
  final AnimationCurve curve;

  const Stagger({
    this.delay = 0.1,
    this.delayChildren = 0.0,
    this.duration = 300,
    this.curve = AnimationCurve.easeOut,
  });

  /// Creates a transition with stagger delay for the given index
  Transition transition(int index) {
    return Transition(
      duration: duration,
      delay: ((delayChildren * 1000) + (delay * index * 1000)).round(),
      curve: curve,
    );
  }

  /// Creates a transition with stagger delay and spring animation
  Transition springTransition(int index, {
    double? damping,
    double? stiffness,
  }) {
    return Transition(
      type: 'spring',
      damping: damping ?? 20,
      stiffness: stiffness ?? 300,
      delay: ((delayChildren * 1000) + (delay * index * 1000)).round(),
    );
  }
}


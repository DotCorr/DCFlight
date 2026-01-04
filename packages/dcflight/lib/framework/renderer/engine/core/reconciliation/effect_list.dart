/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/src/components/component_node.dart';

/// Side effect types (matching React Fiber's effect tags)
enum EffectType {
  placement, // Insert new node
  update, // Update existing node
  deletion, // Delete node
  lifecycle, // Lifecycle method call
}

/// Represents a side effect to be applied during commit phase
class Effect {
  final DCFComponentNode node;
  final EffectType type;
  final Map<String, dynamic>? payload;
  Effect? nextEffect;
  
  Effect({
    required this.node,
    required this.type,
    this.payload,
  });
}

/// Effect list manager for efficient commit phase
class EffectList {
  Effect? _firstEffect;
  Effect? _lastEffect;
  
  /// Add an effect to the list
  void addEffect(Effect effect) {
    if (_lastEffect == null) {
      _firstEffect = effect;
      _lastEffect = effect;
    } else {
      _lastEffect!.nextEffect = effect;
      _lastEffect = effect;
    }
  }
  
  /// Get all effects as a list
  List<Effect> getEffects() {
    final effects = <Effect>[];
    var current = _firstEffect;
    while (current != null) {
      effects.add(current);
      current = current.nextEffect;
    }
    return effects;
  }
  
  /// Clear all effects
  void clear() {
    _firstEffect = null;
    _lastEffect = null;
  }
  
  /// Check if list is empty
  bool get isEmpty => _firstEffect == null;
  
  /// Get first effect
  Effect? get first => _firstEffect;
}


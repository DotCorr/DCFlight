/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/src/components/component_node.dart';

/// Component priority levels for update scheduling
enum ComponentPriority {
  immediate, // Text inputs, scroll events, touch interactions
  high, // Buttons, navigation, modals
  normal, // Regular views, text, images
  low, // Analytics, background tasks
  idle; // Debug panels, dev tools

  /// Delay in milliseconds for this priority level
  int get delayMs {
    switch (this) {
      case immediate:
        return 0; // Process immediately
      case high:
        return 1; // 1ms delay
      case normal:
        return 2; // 2ms delay
      case low:
        return 5; // 5ms delay
      case idle:
        return 16; // 16ms delay (next frame)
    }
  }

  /// Weight for sorting (lower = higher priority)
  int get weight {
    switch (this) {
      case immediate:
        return 1;
      case high:
        return 2;
      case normal:
        return 3;
      case low:
        return 4;
      case idle:
        return 5;
    }
  }
}

/// Interface for components to declare their priority
abstract class ComponentPriorityInterface {
  ComponentPriority get priority;
}

/// Helper class for priority-related utilities
class PriorityUtils {
  /// Get component priority from component (if it implements the interface)
  static ComponentPriority getComponentPriority(DCFComponentNode component) {
    if (component is ComponentPriorityInterface) {
      return component.priority;
    }

    final typeName = component.runtimeType.toString().toLowerCase();

    if (typeName.contains('input') ||
        typeName.contains('textfield') ||
        typeName.contains('scroll')) {
      return ComponentPriority.immediate;
    }

    if (typeName.contains('button') ||
        typeName.contains('touchable') ||
        typeName.contains('modal') ||
        typeName.contains('navigation')) {
      return ComponentPriority.high;
    }

    if (typeName.contains('background') ||
        typeName.contains('analytics') ||
        typeName.contains('cache')) {
      return ComponentPriority.low;
    }

    if (typeName.contains('debug') || typeName.contains('dev')) {
      return ComponentPriority.idle;
    }

    return ComponentPriority.normal;
  }

  /// Sort component IDs by priority
  static List<String> sortByPriority(
      List<String> componentIds, Map<String, ComponentPriority> priorities) {
    final sorted = List<String>.from(componentIds);
    sorted.sort((a, b) {
      final aPriority = priorities[a] ?? ComponentPriority.normal;
      final bPriority = priorities[b] ?? ComponentPriority.normal;
      return aPriority.weight.compareTo(bPriority.weight);
    });
    return sorted;
  }

  /// Get the highest priority from a list of priorities
  static ComponentPriority getHighestPriority(
      List<ComponentPriority> priorities) {
    if (priorities.isEmpty) return ComponentPriority.normal;

    return priorities.reduce((a, b) => a.weight < b.weight ? a : b);
  }

  /// Check if priority should interrupt current processing
  static bool shouldInterrupt(
      ComponentPriority newPriority, ComponentPriority? currentPriority) {
    if (currentPriority == null) return true;
    return newPriority.weight < currentPriority.weight;
  }
}


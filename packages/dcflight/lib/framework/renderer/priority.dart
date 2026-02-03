/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/src/components/component_node.dart';

/// Component priority levels for update scheduling (used by the engine)
enum ComponentPriority {
  immediate,
  high,
  normal,
  low,
  idle;

  int get delayMs {
    switch (this) {
      case ComponentPriority.immediate:
        return 0;
      case ComponentPriority.high:
        return 1;
      case ComponentPriority.normal:
        return 2;
      case ComponentPriority.low:
        return 5;
      case ComponentPriority.idle:
        return 16;
    }
  }

  int get weight {
    switch (this) {
      case ComponentPriority.immediate:
        return 1;
      case ComponentPriority.high:
        return 2;
      case ComponentPriority.normal:
        return 3;
      case ComponentPriority.low:
        return 4;
      case ComponentPriority.idle:
        return 5;
    }
  }
}

/// Interface for components to declare their priority
abstract class ComponentPriorityInterface {
  ComponentPriority get priority;
}

class PriorityUtils {
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
}

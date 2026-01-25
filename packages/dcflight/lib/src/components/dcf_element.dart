/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';

/// Represents an element in the Virtual DOM tree
class DCFElement extends DCFComponentNode {
  /// Type of the element (e.g., 'View', 'Text', 'Button')
  final String type;

  /// Properties of the element
  final Map<String, dynamic> elementProps;
  
  /// Child nodes
  final List<DCFComponentNode> children;

  DCFElement({
    required this.type,
    super.key,
    required this.elementProps,
    this.children = const [],
  }) {
    for (var child in children) {
      child.parent = this;
    }
  }

  @override
  DCFComponentNode clone() {
    return DCFElement(
      type: type,
      key: key,
      elementProps: Map<String, dynamic>.from(elementProps),
      children: children.map((child) => child.clone()).toList(),
    );
  }

  @override
  String toString() {
    return 'VDomElement(type: $type, key: $key, elementProps: ${elementProps.length}, children: ${children.length})';
  }

  /// Get all descendant nodes flattened into a list
  List<DCFComponentNode> get allDescendants {
    final result = <DCFComponentNode>[];
    for (final child in children) {
      result.add(child);
      if (child is DCFElement) {
        result.addAll(child.allDescendants);
      }
    }
    return result;
  }

  /// Get list of event types from elementProps
  /// 
  /// 🔥 NEW: Returns ALL function props as potential events (no prefix guessing)
  /// Supports both "onPress" and "scrolled" style names
  /// Native side queries the registry to know what events are available
  List<String> get eventTypes {
    final List<String> types = [];

    // Extract ALL function props as events - no prefix requirement
    // This supports both "onPress" and "scrolled" style names
    for (final key in elementProps.keys) {
      if (elementProps[key] is Function) {
        types.add(key); // Register exact prop name as event type
      }
    }

    return types;
  }
  
  /// Get event handlers map (eventType -> handler function)
  /// 
  /// 🔥 NEW: Returns exact mapping of event names to handlers
  /// No prefix guessing - native queries this registry
  Map<String, Function> get eventHandlers {
    final Map<String, Function> handlers = {};
    
    for (final key in elementProps.keys) {
      if (elementProps[key] is Function) {
        handlers[key] = elementProps[key] as Function;
      }
    }
    
    return handlers;
  }

  @override
  void mount(DCFComponentNode? parent) {
    this.parent = parent;

    for (final child in children) {
      child.mount(this);
    }
  }

  @override
  void unmount() {
    for (final child in children) {
      child.unmount();
    }
  }
}


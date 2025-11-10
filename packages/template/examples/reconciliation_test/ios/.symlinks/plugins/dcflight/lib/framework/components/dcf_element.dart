/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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

  /// EquatableMixin props for equality comparison
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
  List<String> get eventTypes {
    final List<String> types = [];

    for (final key in elementProps.keys) {
      if (elementProps[key] is Function) {
        if (key.startsWith('on') && key.length > 2) {
          types.add(key);
          
          final eventName = key.substring(2, 3).toLowerCase() + key.substring(3);
          if (!types.contains(eventName)) {
            types.add(eventName);
          }
        }
      }
    }

    return types;
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


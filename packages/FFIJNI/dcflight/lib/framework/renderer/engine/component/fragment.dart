/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'component_node.dart';
import 'package:equatable/equatable.dart';

/// Fragment component that renders its children without creating a wrapper element
/// Similar to React.Fragment - useful for grouping elements without adding extra DOM nodes
class DCFFragment extends DCFComponentNode with EquatableMixin {
  /// Children to be rendered directly to the parent
  final List<DCFComponentNode> children;
  
  /// Optional metadata for framework-level processing (e.g., portal information)
  final Map<String, dynamic>? metadata;

  /// Whether this fragment has been mounted
  bool _isMounted = false;
  
  /// Child view IDs for cleanup tracking
  List<String> childViewIds = [];

  DCFFragment({
    required this.children,
    this.metadata,
    super.key,
  });

  /// EquatableMixin props for equality comparison
  @override
  List<Object?> get props => [children, metadata, key];

  /// Whether this fragment is mounted
  bool get isMounted => _isMounted;

  @override
  DCFComponentNode clone() {
    return DCFFragment(
      children: children.map((child) => child.clone()).toList(),
      metadata: metadata,
      key: key,
    );
  }

  @override
  void mount(DCFComponentNode? parent) {
    this.parent = parent;
    _isMounted = true;
    
    for (final child in children) {
      child.mount(this);
    }
  }

  @override
  void unmount() {
    _isMounted = false;
    
    for (final child in children) {
      child.unmount();
    }
    
    childViewIds.clear();
  }

  /// Fragments don't have their own native view ID - they're transparent
  @override
  String? get effectiveNativeViewId => null;

  @override
  String toString() {
    return 'DCFFragment(children: ${children.length})';
  }
}

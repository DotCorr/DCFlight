/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/foundation.dart';
import 'package:dcflight/framework/components/component.dart';
import 'package:dcflight/framework/components/dcf_element.dart';
import 'package:dcflight/framework/components/component_node.dart';

/// Global registry for PortalTarget components
/// This allows Portal components to find their target by ID
class PortalTargetRegistry {
  static final PortalTargetRegistry _instance = PortalTargetRegistry._internal();
  factory PortalTargetRegistry() => _instance;
  PortalTargetRegistry._internal();
  
  /// Map of PortalTarget ID to component instance
  final Map<String, DCFPortalTarget> _targets = {};
  
  /// Register a PortalTarget component
  void register(String id, DCFPortalTarget target) {
    _targets[id] = target;
    if (kDebugMode) {
      print('✅ PortalTargetRegistry: Registered target "$id"');
    }
  }
  
  /// Unregister a PortalTarget component
  void unregister(String id) {
    _targets.remove(id);
    if (kDebugMode) {
      print('🗑️ PortalTargetRegistry: Unregistered target "$id"');
    }
  }
  
  /// Get a PortalTarget by ID
  DCFPortalTarget? get(String id) {
    return _targets[id];
  }
  
  /// Get the view ID of a PortalTarget by its ID
  String? getViewId(String id) {
    final target = _targets[id];
    if (target == null) {
      if (kDebugMode) {
        print('⚠️ PortalTargetRegistry: Target "$id" not found');
      }
      return null;
    }
    return target.targetViewId;
  }
  
  /// Check if a target exists
  bool has(String id) {
    return _targets.containsKey(id);
  }
}

/// PortalTarget component that provides a mount point for Portal children
/// 
/// PortalTarget creates a view in the VDOM tree that Portal components can target.
/// This is the proper way to use Portal - instead of targeting native 'root',
/// target a PortalTarget component by its ID.
/// 
/// Usage:
/// ```dart
/// // Place PortalTarget in your tree
/// DCFPortalTarget(
///   id: 'modal-root',
///   child: DCFView(...),
/// )
/// 
/// // Then Portal can target it
/// DCFPortal(
///   target: 'modal-root',
///   children: [...],
/// )
/// ```
class DCFPortalTarget extends DCFStatelessComponent {
  /// Unique identifier for this PortalTarget
  /// Portal components use this ID to target this component
  final String id;
  
  /// Optional child to render inside the PortalTarget
  final DCFComponentNode? child;
  
  DCFPortalTarget({
    required this.id,
    this.child,
    super.key,
  }) {
    if (child != null) {
      child!.parent = this;
    }
  }
  
  @override
  DCFComponentNode render() {
    // PortalTarget renders as a View element
    // The view ID will be used by Portal components to target this location
    return DCFElement(
      type: 'View',
      elementProps: {},
      children: child != null ? [child!] : [],
      key: 'portal_target_$id',
    );
  }
  
  /// Get the view ID of this PortalTarget
  /// This is used by Portal to find where to render its children
  String? get targetViewId {
    final rendered = renderedNode;
    if (rendered is DCFElement) {
      return rendered.nativeViewId;
    }
    return contentViewId;
  }
  
  @override
  void componentDidMount() {
    super.componentDidMount();
    // Register this PortalTarget in the global registry
    PortalTargetRegistry().register(id, this);
  }
  
  @override
  void componentWillUnmount() {
    super.componentWillUnmount();
    // Unregister when component is unmounted
    PortalTargetRegistry().unregister(id);
  }
}


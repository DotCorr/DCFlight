/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/components/component.dart';
import 'package:dcflight/framework/components/fragment.dart';
import 'package:dcflight/framework/renderer/engine/index.dart';

/// Portal component that renders children into a different part of the view tree
/// Similar to React's Portal - allows rendering children outside the normal parent hierarchy
/// 
/// Usage:
/// ```dart
/// DCFPortal(
///   target: 'modal-root',
///   children: [
///     DCFText(content: 'This renders in modal-root, not here'),
///   ],
/// )
/// ```
class DCFPortal extends DCFStatefulComponent {
  /// Target view ID where children should be rendered
  final String target;
  
  /// Children to render into the target
  final List<DCFComponentNode> children;
  
  /// Track rendered child view IDs for cleanup
  List<String> _renderedChildViewIds = [];
  
  /// Previous target for change detection
  String? _prevTarget;
  
  DCFPortal({
    required this.target,
    required this.children,
    super.key,
  }) {
    for (var child in children) {
      child.parent = this;
    }
  }
  
  @override
  List<Object?> get props => [target, children, key];
  
  @override
  DCFComponentNode render() {
    // Portal doesn't render itself - it renders children to target
    // Return empty fragment as placeholder
    return DCFFragment(children: []);
  }
  
  @override
  void componentDidMount() {
    super.componentDidMount();
    _prevTarget = target;
    // Use microtask to ensure engine is ready
    Future.microtask(() => _renderChildrenToTarget());
  }
  
  @override
  void componentDidUpdate(Map<String, dynamic> prevProps) {
    super.componentDidUpdate(prevProps);
    
    // If target changed, re-render children to new target
    if (_prevTarget != target) {
      _cleanupChildren();
      _prevTarget = target;
      Future.microtask(() => _renderChildrenToTarget());
    } else {
      // Target unchanged, just update children
      Future.microtask(() => _updateChildren());
    }
  }
  
  @override
  void componentWillUnmount() {
    super.componentWillUnmount();
    _cleanupChildren();
  }
  
  /// Render children to the target view ID
  Future<void> _renderChildrenToTarget() async {
    try {
      final engine = DCFEngineAPI.instance;
      await engine.isReady;
      
      _renderedChildViewIds.clear();
      
      // Render each child to the target view
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        final childViewId = await engine.renderToNative(
          child,
          parentViewId: target,
          index: i,
        );
        
        if (childViewId != null && childViewId.isNotEmpty) {
          _renderedChildViewIds.add(childViewId);
        }
      }
    } catch (e) {
      print('❌ DCFPortal: Error rendering children to target $target: $e');
    }
  }
  
  /// Update existing children in target
  Future<void> _updateChildren() async {
    try {
      // For now, re-render all children
      // In the future, we could optimize this with reconciliation
      _cleanupChildren();
      await _renderChildrenToTarget();
    } catch (e) {
      print('❌ DCFPortal: Error updating children: $e');
    }
  }
  
  /// Clean up rendered children
  Future<void> _cleanupChildren() async {
    try {
      // Children will be cleaned up automatically when:
      // 1. The portal unmounts (parent component tree cleanup)
      // 2. The target view is deleted
      // 3. The native bridge handles view lifecycle
      
      // Clear our tracking list
      _renderedChildViewIds.clear();
    } catch (e) {
      print('❌ DCFPortal: Error cleaning up children: $e');
    }
  }
}


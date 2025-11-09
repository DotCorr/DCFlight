/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/foundation.dart';
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
  
  /// Previous children for change detection
  List<DCFComponentNode>? _prevChildren;
  
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
    _prevChildren = List.from(children);
    // Render immediately - don't defer with microtask
    _renderChildrenToTarget();
  }
  
  @override
  void componentDidUpdate(Map<String, dynamic> prevProps) {
    super.componentDidUpdate(prevProps);
    
    // Check if children actually changed
    final childrenChanged = _prevChildren == null || 
        _prevChildren!.length != children.length ||
        !_childrenEqual(_prevChildren!, children);
    
    // If target changed OR children changed, re-render
    if (_prevTarget != target || childrenChanged) {
      if (kDebugMode) {
        print('🔄 DCFPortal: Updating - target changed: ${_prevTarget != target}, children changed: $childrenChanged');
        print('🔄 DCFPortal: Old children count: ${_prevChildren?.length ?? 0}, New: ${children.length}');
      }
      
      _cleanupChildren();
      _prevTarget = target;
      _prevChildren = List.from(children);
      // Render immediately - don't defer
      _renderChildrenToTarget();
    } else {
      // Nothing changed, skip update
      if (kDebugMode) {
        print('⏭️ DCFPortal: Skipping update - no changes detected');
      }
    }
  }
  
  /// Check if two children lists are equal (by reference, not deep equality)
  bool _childrenEqual(List<DCFComponentNode> old, List<DCFComponentNode> new_) {
    if (old.length != new_.length) return false;
    for (int i = 0; i < old.length; i++) {
      // Compare by reference - if same instances, they're equal
      // If different instances, they're different (even if content is same)
      if (old[i] != new_[i]) return false;
    }
    return true;
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
      
      if (kDebugMode) {
        print('🎯 DCFPortal: Rendering ${children.length} children to target "$target"');
      }
      
      // Clean up old children first
      await _cleanupChildren();
      
      _renderedChildViewIds.clear();
      
      // If no children, we're done (already cleaned up)
      if (children.isEmpty) {
        if (kDebugMode) {
          print('✅ DCFPortal: No children to render, cleanup complete');
        }
        return;
      }
      
      // Start batch update for atomic operation
      await engine.startBatchUpdate();
      
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
          if (kDebugMode) {
            print('✅ DCFPortal: Rendered child $i with viewId: $childViewId');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ DCFPortal: Failed to render child $i - no viewId returned');
          }
        }
      }
      
      // Commit batch update
      await engine.commitBatchUpdate();
      
      if (kDebugMode) {
        print('✅ DCFPortal: Successfully rendered ${_renderedChildViewIds.length} children to target "$target"');
      }
    } catch (e, stackTrace) {
      print('❌ DCFPortal: Error rendering children to target $target: $e');
      if (kDebugMode) {
        print('Stack trace: $stackTrace');
      }
    }
  }
  
  /// Clean up rendered children
  Future<void> _cleanupChildren() async {
    try {
      if (_renderedChildViewIds.isEmpty) {
        return;
      }
      
      if (kDebugMode) {
        print('🧹 DCFPortal: Cleaning up ${_renderedChildViewIds.length} children from target "$target"');
      }
      
      final engine = DCFEngineAPI.instance;
      await engine.isReady;
      
      // Start batch update for atomic cleanup
      await engine.startBatchUpdate();
      
      // Delete all rendered children
      for (final viewId in _renderedChildViewIds) {
        await engine.deleteView(viewId);
        if (kDebugMode) {
          print('🗑️ DCFPortal: Deleted child view: $viewId');
        }
      }
      
      // Commit batch update
      await engine.commitBatchUpdate();
      
      // Clear our tracking list
      _renderedChildViewIds.clear();
      
      if (kDebugMode) {
        print('✅ DCFPortal: Cleanup complete');
      }
    } catch (e, stackTrace) {
      print('❌ DCFPortal: Error cleaning up children: $e');
      if (kDebugMode) {
        print('Stack trace: $stackTrace');
      }
      // Clear list even on error to prevent stale references
      _renderedChildViewIds.clear();
    }
  }
}


/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/framework/utils/dcf_dart_compat.dart' show kDebugMode;
import 'package:dcflight/src/components/component.dart';
import 'package:dcflight/src/components/fragment.dart';
import 'package:dcflight/framework/renderer/engine/index.dart';
import 'package:dcflight/src/components/portal/dcf_portal_target.dart';

/// Portal component that renders children into a different part of the view tree
/// Allows rendering children outside the normal parent hierarchy.
/// Set [_verbose] to true to log portal updates (noisy).
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
  List<int> _renderedChildViewIds = [];
  
  /// Previous target for change detection
  String? _prevTarget;
  
  /// Previous children for change detection
  List<DCFComponentNode>? _prevChildren;

  static const bool _verbose = false;

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
    // Render immediately - no cleanup needed on mount
    _renderChildrenToTarget();
  }
  
  @override
  void componentDidUpdate(Map<String, dynamic> prevProps) {
    super.componentDidUpdate(prevProps);
    
    // Check if children actually changed by comparing content, not just reference
    // Portal's children list is often recreated on each render, so we need deeper comparison
    final childrenChanged = _prevChildren == null || 
        _prevChildren!.length != children.length ||
        !_childrenEqual(_prevChildren!, children);
    
    // Also check if target changed
    final targetChanged = _prevTarget != target;
    
    // Only update if something actually changed
    if (targetChanged || childrenChanged) {
      if (kDebugMode && _verbose) {
        print('🔄 DCFPortal: Updating - target changed: $targetChanged, children changed: $childrenChanged');
        print('🔄 DCFPortal: Old children count: ${_prevChildren?.length ?? 0}, New: ${children.length}');
      }
      
      // Update tracking BEFORE cleanup to avoid issues
      _prevTarget = target;
      _prevChildren = List.from(children);
      
      // CRITICAL: Don't defer - execute immediately to prevent race conditions
      // The batch updates in _cleanupAndRender ensure atomicity
      // Deferring with Future.microtask can cause freezes when Portal content changes
      if (isMounted) {
        _cleanupAndRender();
      }
    } else {
      if (kDebugMode && _verbose) print('⏭️ DCFPortal: Skipping update - no changes detected');
    }
  }
  
  /// Cleanup and render in one atomic operation
  /// CRITICAL: Render new views BEFORE deleting old ones to prevent freezes
  /// _renderChildrenToTarget now handles cleanup internally, so we just call it
  Future<void> _cleanupAndRender() async {
    // Render new children first, which also handles cleanup of old ones
    // This prevents white screen/freeze when switching Portal content
    await _renderChildrenToTarget();
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
      
      if (kDebugMode && _verbose) print('🎯 DCFPortal: Rendering ${children.length} children to target "$target"');
      
      // CRITICAL: Don't clear _renderedChildViewIds here - we need to track old IDs
      // for cleanup. Only clear after new children are successfully rendered.
      // Store old IDs for cleanup
      final oldRenderedChildViewIds = List<int>.from(_renderedChildViewIds);
      
      // Prepare new list for tracking
      final newRenderedChildViewIds = <int>[];
      
      // If no children, cleanup old views and return
      if (children.isEmpty) {
        if (kDebugMode && _verbose) print('✅ DCFPortal: No children to render, cleaning up old views');
        // Still need to cleanup old views
        _renderedChildViewIds = [];
        if (oldRenderedChildViewIds.isNotEmpty) {
          await engine.startBatchUpdate();
          for (final viewId in oldRenderedChildViewIds) {
            await engine.deleteView(viewId);
          }
          await engine.commitBatchUpdate();
        }
        return;
      }
      
      // Start batch update for atomic operation
      await engine.startBatchUpdate();
      
      // CRITICAL: Resolve target to actual view ID
      // First check if it's a PortalTarget ID, otherwise use as-is (for backward compatibility)
      int? actualTargetViewId;
      
      // Check PortalTarget registry first
      if (PortalTargetRegistry().has(target)) {
        final viewId = PortalTargetRegistry().getViewId(target);
        if (viewId == null) {
          if (kDebugMode && _verbose) print('⚠️ DCFPortal: PortalTarget "$target" exists but has no view ID yet. Waiting for mount...');
          // Target exists but not mounted yet - wait a bit and retry
          await Future.delayed(const Duration(milliseconds: 50));
          final retryViewId = PortalTargetRegistry().getViewId(target);
          if (retryViewId == null) {
            if (kDebugMode && _verbose) print('❌ DCFPortal: PortalTarget "$target" still has no view ID after wait');
            await engine.commitBatchUpdate();
            return;
          }
          actualTargetViewId = retryViewId;
        } else {
          actualTargetViewId = viewId;
        }
        if (kDebugMode && _verbose) print('✅ DCFPortal: Resolved target "$target" to view ID "$actualTargetViewId"');
      } else {
        if (target == 'root') {
          if (kDebugMode && _verbose) print('⚠️ DCFPortal: Using "root" as target is not recommended. Use DCFPortalTarget instead.');
          actualTargetViewId = 0; // Root is tag 0
        } else {
          // Try to parse as int for backward compatibility
          actualTargetViewId = int.tryParse(target);
          if (actualTargetViewId == null) {
            if (kDebugMode && _verbose) print('❌ DCFPortal: Target "$target" is not a valid PortalTarget ID or view ID');
            await engine.commitBatchUpdate();
            return;
          }
        }
      }
      
      // Render each child to the target view
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        
        // CRITICAL: Ensure child has parent set for proper tree structure
        child.parent = this;
        
        final childViewId = await engine.renderToNative(
          child,
          parentViewId: actualTargetViewId,
          index: i,
        );
        
        if (childViewId != null) {
          newRenderedChildViewIds.add(childViewId);
          if (kDebugMode && _verbose) print('✅ DCFPortal: Rendered child $i with viewId: $childViewId');
        } else {
          if (kDebugMode && _verbose) print('⚠️ DCFPortal: Failed to render child $i - no viewId returned');
        }
      }
      
      // Commit batch update
      await engine.commitBatchUpdate();
      
      // CRITICAL: Only update tracking AFTER successful render
      // This ensures we don't lose track of old views if render fails
      _renderedChildViewIds = newRenderedChildViewIds;
      
      // Clean up old views that are no longer needed
      // Filter out view IDs that are still in use
      final viewsToCleanup = oldRenderedChildViewIds
          .where((oldId) => !newRenderedChildViewIds.contains(oldId))
          .toList();
      
      if (viewsToCleanup.isNotEmpty) {
        if (kDebugMode && _verbose) print('🧹 DCFPortal: Cleaning up ${viewsToCleanup.length} old children');
        await engine.startBatchUpdate();
        for (final viewId in viewsToCleanup) {
          await engine.deleteView(viewId);
        }
        await engine.commitBatchUpdate();
      }
      
      if (kDebugMode && _verbose) print('✅ DCFPortal: Successfully rendered ${_renderedChildViewIds.length} children to target "$target"');
    } catch (e, stackTrace) {
      print('❌ DCFPortal: Error rendering children to target $target: $e');
      if (kDebugMode && _verbose) print('Stack trace: $stackTrace');
    }
  }
  
  /// Clean up rendered children
  Future<void> _cleanupChildren() async {
    try {
      if (_renderedChildViewIds.isEmpty) {
        return;
      }
      
      if (kDebugMode && _verbose) print('🧹 DCFPortal: Cleaning up ${_renderedChildViewIds.length} children from target "$target"');
      
      final engine = DCFEngineAPI.instance;
      await engine.isReady;
      
      // Start batch update for atomic cleanup
      await engine.startBatchUpdate();
      
      // Delete all rendered children
      for (final viewId in _renderedChildViewIds) {
        await engine.deleteView(viewId);
        if (kDebugMode && _verbose) print('🗑️ DCFPortal: Deleted child view: $viewId');
      }
      
      await engine.commitBatchUpdate();
      _renderedChildViewIds.clear();
      
      if (kDebugMode && _verbose) print('✅ DCFPortal: Cleanup complete');
    } catch (e, stackTrace) {
      print('❌ DCFPortal: Error cleaning up children: $e');
      if (kDebugMode && _verbose) print('Stack trace: $stackTrace');
      // Clear list even on error to prevent stale references
      _renderedChildViewIds.clear();
    }
  }
}


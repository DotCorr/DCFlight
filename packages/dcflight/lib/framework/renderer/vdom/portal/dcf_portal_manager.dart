/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dcflight/framework/renderer/vdom/component/component_node.dart';
import 'package:dcflight/framework/renderer/vdom/vdom_api.dart';

import 'dcf_portal.dart' as portal_impl;
import 'dcf_portal_container.dart' as container_impl;

/// Simple implementation for auto-created portal containers
class _SimplePortalContainer extends container_impl.DCFPortalContainer {
  _SimplePortalContainer({
    required super.targetId,
    required super.nativeViewId,
  });
}

/// Manages all portals in the application
/// This class extends the VDOM to ensure all portal operations go through proper VDOM tracking
class DCFPortalManager {
  static final DCFPortalManager _instance = DCFPortalManager._internal();
  static DCFPortalManager get instance => _instance;
  DCFPortalManager._internal();

  /// Access to the VDOM API for proper portal operations
  VDomAPI get _vdomApi => VDomAPI.instance;

  /// Map of target IDs to their portal containers
  final Map<String, container_impl.DCFPortalContainer> _portalContainers = {};
  
  /// Map of portal instances to their current target
  final Map<String, portal_impl.DCFPortal> _activePortals = {};
  
  /// Map of portaled content nodes (for proper VDOM tracking)
  final Map<String, List<DCFComponentNode>> _portaledNodes = {};

  /// Map of portal instances to their rendered view IDs (for cleanup)
  final Map<String, List<String>> _portalViewIds = {};

  /// Map of queued portals waiting for their targets
  final Map<String, List<portal_impl.DCFPortal>> _queuedPortals = {};

  /// Register a portal container as a target
  void registerContainer(String targetId, container_impl.DCFPortalContainer container) {
    if (kDebugMode) {
      print('🎯 DCFPortalManager: Registering container for targetId: $targetId');
    }
    
    _portalContainers[targetId] = container;
    _processQueuedPortals(targetId);
  }

  /// Unregister a portal container
  void unregisterContainer(String targetId) {
    if (kDebugMode) {
      print('🗑️ DCFPortalManager: Unregistering container for targetId: $targetId');
    }
    
    _portalContainers.remove(targetId);
    _cleanupPortalsForTarget(targetId);
  }

  /// Register a portal for rendering
  Future<void> registerPortal(portal_impl.DCFPortal portal) async {
    if (kDebugMode) {
      print('🚀 DCFPortalManager: Registering portal ${portal.instanceId} for target: ${portal.targetId}');
    }
    
    _activePortals[portal.instanceId] = portal;
    await _renderPortalContent(portal);
  }

  /// Update portal content when portal changes
  Future<void> updatePortalContent(portal_impl.DCFPortal portal) async {
    if (kDebugMode) {
      print('🔄 DCFPortalManager: Updating portal content for ${portal.instanceId}');
    }
    
    // Clean up existing content first
    await _cleanupPortalContent(portal);
    
    // Re-render with new content
    await _renderPortalContent(portal);
  }

  /// Unregister and cleanup a portal
  Future<void> unregisterPortal(portal_impl.DCFPortal portal) async {
    if (kDebugMode) {
      print('🗑️ DCFPortalManager: Unregistering portal ${portal.instanceId}');
    }
    
    await _cleanupPortalContent(portal);
    _activePortals.remove(portal.instanceId);
  }

  /// Render portal content to target using VDOM methods
  Future<void> _renderPortalContent(portal_impl.DCFPortal portal) async {
    var container = _portalContainers[portal.targetId];
    
    if (container == null) {
      if (portal.createTarget) {
        await _createPortalTarget(portal.targetId);
        // Refresh container reference after creation
        container = _portalContainers[portal.targetId];
      } else {
        // Queue for later if target doesn't exist
        _queuePortal(portal);
        return;
      }
    }

    try {
      // Store portal nodes for proper VDOM tracking
      _portaledNodes[portal.instanceId] = List.from(portal.children);
      
      final targetViewId = container?.nativeViewId ?? portal.targetId;
      
      if (kDebugMode) {
        print('🎯 DCFPortalManager: Rendering ${portal.children.length} children to target: $targetViewId');
      }
      
      // CORRECT APPROACH: Render portal children as cohesive trees
      // The framework is designed to render component trees, not individual elements
      final childViewIds = <String>[];
      
      for (int i = 0; i < portal.children.length; i++) {
        final child = portal.children[i];
        try {
          // Render each portal child as a complete tree with target as parent
          // This preserves the framework's tree-based architecture
          final childViewId = await _vdomApi.renderToNative(
            child, 
            parentViewId: targetViewId,
            index: null  // Will be positioned by the portal manager
          );
          
          if (childViewId != null && childViewId.isNotEmpty) {
            childViewIds.add(childViewId);
            if (kDebugMode) {
              print('✅ DCFPortalManager: Rendered portal tree $i to target with root view ID: $childViewId');
            }
          } else {
            if (kDebugMode) {
              print('❌ DCFPortalManager: Failed to render portal tree $i to target');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ DCFPortalManager: Error rendering portal tree $i to target: $e');
          }
        }
      }
      
      // Get existing children and append portal trees
      if (childViewIds.isNotEmpty) {
        // Store portal view IDs for cleanup later
        _portalViewIds[portal.instanceId] = List.from(childViewIds);
        
        // Get existing children from the target container
        final existingChildren = _vdomApi.getCurrentChildren(targetViewId);
        
        // Create new children list by appending portal trees to existing content
        final newChildren = [...existingChildren, ...childViewIds];
        
        if (kDebugMode) {
          print('🔄 DCFPortalManager: Appending ${childViewIds.length} portal trees to ${existingChildren.length} existing children');
          print('🔄 DCFPortalManager: Target view ID: $targetViewId');
          print('🔄 DCFPortalManager: Existing children: $existingChildren');
          print('🔄 DCFPortalManager: Portal trees: $childViewIds');
          print('🔄 DCFPortalManager: New children list: $newChildren');
        }
        
        // Update target container with combined children
        await _vdomApi.updateTargetChildren(targetViewId, newChildren);
        
        if (kDebugMode) {
          print('✅ DCFPortalManager: Successfully updated target container with ${newChildren.length} total children (${existingChildren.length} existing + ${childViewIds.length} portal trees)');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ DCFPortalManager: No portal trees rendered for portal ${portal.instanceId}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DCFPortalManager: Error rendering portal content: $e');
      }
    }
  }

  /// Create a portal target if it doesn't exist using VDOM methods
  Future<void> _createPortalTarget(String targetId) async {
    try {
      if (kDebugMode) {
        print('🆕 DCFPortalManager: Creating portal target: $targetId');
      }
      
      // Use the VDOM API createPortal method which ensures proper tracking
      await _vdomApi.createPortal(targetId, 
        parentViewId: 'root',
        props: {
          'isPortalTarget': true,
        },
        index: 0,
      );
      
      // Create a simple container record
      final container = _SimplePortalContainer(targetId: targetId, nativeViewId: targetId);
      _portalContainers[targetId] = container;
      
      if (kDebugMode) {
        print('✅ DCFPortalManager: Successfully created portal target: $targetId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DCFPortalManager: Error creating portal target: $e');
      }
    }
  }

  /// Queue a portal for later processing
  void _queuePortal(portal_impl.DCFPortal portal) {
    final targetId = portal.targetId;
    if (!_queuedPortals.containsKey(targetId)) {
      _queuedPortals[targetId] = [];
    }
    _queuedPortals[targetId]!.add(portal);
    
    if (kDebugMode) {
      print('⏳ DCFPortalManager: Queued portal ${portal.instanceId} for target: $targetId');
    }
  }

  /// Clean up portal content using VDOM tracking
  Future<void> _cleanupPortalContent(portal_impl.DCFPortal portal) async {
    final portaledNodes = _portaledNodes[portal.instanceId];
    final portalViewIds = _portalViewIds[portal.instanceId];
    
    if (portaledNodes != null && portaledNodes.isNotEmpty && portalViewIds != null) {
      try {
        if (kDebugMode) {
          print('🧹 DCFPortalManager: Cleaning up ${portaledNodes.length} portaled nodes (${portalViewIds.length} view IDs) for ${portal.instanceId}');
        }
        
        final container = _portalContainers[portal.targetId];
        if (container != null) {
          final targetViewId = container.nativeViewId ?? portal.targetId;
          
          // Get current children and remove only the portal children
          final currentChildren = _vdomApi.getCurrentChildren(targetViewId);
          final remainingChildren = currentChildren.where((viewId) => !portalViewIds.contains(viewId)).toList();
          
          if (kDebugMode) {
            print('🧹 DCFPortalManager: Current children: $currentChildren');
            print('🧹 DCFPortalManager: Portal view IDs to remove: $portalViewIds');
            print('🧹 DCFPortalManager: Remaining children after cleanup: $remainingChildren');
          }
          
          // Update target container with remaining children (excluding portal content)
          await _vdomApi.updateTargetChildren(targetViewId, remainingChildren);
          
          if (kDebugMode) {
            print('✅ DCFPortalManager: Updated target container, removed ${portalViewIds.length} portal children, kept ${remainingChildren.length} existing children');
          }
        }
        
        // Remove from our tracking
        _portaledNodes.remove(portal.instanceId);
        _portalViewIds.remove(portal.instanceId);
        
        if (kDebugMode) {
          print('✅ DCFPortalManager: Portal content cleanup completed for ${portal.instanceId}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ DCFPortalManager: Error cleaning up portal content: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('⚠️ DCFPortalManager: No portal content to clean up for ${portal.instanceId}');
      }
    }
  }

  /// Process any queued portals for a target
  Future<void> _processQueuedPortals(String targetId) async {
    final queuedPortals = _queuedPortals[targetId];
    if (queuedPortals != null && queuedPortals.isNotEmpty) {
      if (kDebugMode) {
        print('🔄 DCFPortalManager: Processing ${queuedPortals.length} queued portals for target: $targetId');
      }
      
      for (final portal in queuedPortals) {
        await _renderPortalContent(portal);
      }
      
      _queuedPortals.remove(targetId);
    }
  }

  /// Clean up portals for a target
  Future<void> _cleanupPortalsForTarget(String targetId) async {
    final portalsToCleanup = _activePortals.values
        .where((portal) => portal.targetId == targetId)
        .toList();
    
    if (kDebugMode && portalsToCleanup.isNotEmpty) {
      print('🧹 DCFPortalManager: Cleaning up ${portalsToCleanup.length} portals for target: $targetId');
    }
    
    for (final portal in portalsToCleanup) {
      await _cleanupPortalContent(portal);
    }
    
    // Also clean up queued portals
    _queuedPortals.remove(targetId);
  }

  /// Get debug information about active portals
  Map<String, dynamic> getDebugInfo() {
    return {
      'activePortals': _activePortals.length,
      'portalContainers': _portalContainers.length,
      'queuedPortals': _queuedPortals.values.fold(0, (sum, list) => sum + list.length),
      'portaledNodes': _portaledNodes.length,
    };
  }
}

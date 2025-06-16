/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/renderer/vdom/component/component_node.dart';
import 'package:dcflight/framework/renderer/vdom/portal/enhanced_portal_manager.dart';
import 'package:dcflight/framework/renderer/vdom/portal/dcf_portal.dart';

/// High-level Portal API for easier portal management
/// Provides React-like createPortal functionality
class DCFPortalAPI {
  static final DCFPortalAPI _instance = DCFPortalAPI._internal();
  static DCFPortalAPI get instance => _instance;
  DCFPortalAPI._internal();

  /// Access to the enhanced portal manager
  EnhancedPortalManager get _portalManager => EnhancedPortalManager.instance;

  /// Create a portal to render children into a target
  /// Similar to React's createPortal(children, container)
  static DCFPortal createPortal(
    List<DCFComponentNode> children,
    String targetId, {
    int priority = 0,
    Map<String, dynamic>? metadata,
    bool createTargetIfMissing = false,
    Function(String portalId)? onMount,
    Function(String portalId)? onUnmount,
  }) {
    return DCFPortal(
      targetId: targetId,
      children: children,
      priority: priority,
      metadata: metadata,
      createTargetIfMissing: createTargetIfMissing,
      onMount: onMount,
      onUnmount: onUnmount,
    );
  }

  /// Create a portal target container
  static DCFPortalTarget createPortalTarget(
    String targetId, {
    String? nativeViewId,
    Map<String, dynamic>? metadata,
    int priority = 0,
    List<DCFComponentNode> children = const [],
  }) {
    return DCFPortalTarget(
      targetId: targetId,
      nativeViewId: nativeViewId,
      metadata: metadata,
      priority: priority,
      children: children,
    );
  }

  /// Get information about all active portals
  Map<String, dynamic> getPortalInfo() {
    return _portalManager.getPortalInfo();
  }

  /// Check if a portal target exists
  bool hasTarget(String targetId) {
    return _portalManager.hasTarget(targetId);
  }

  /// Get all portal IDs for a target
  List<String> getPortalIdsForTarget(String targetId) {
    return _portalManager.getPortalIdsForTarget(targetId);
  }

  /// Register a portal target programmatically
  void registerTarget({
    required String targetId,
    required String nativeViewId,
    Map<String, dynamic>? metadata,
    int priority = 0,
  }) {
    _portalManager.registerTarget(
      targetId: targetId,
      nativeViewId: nativeViewId,
      metadata: metadata,
      priority: priority,
    );
  }

  /// Unregister a portal target
  Future<void> unregisterTarget(String targetId) {
    return _portalManager.unregisterTarget(targetId);
  }
}

/// Extension methods for easier portal usage
extension DCFPortalExtensions on List<DCFComponentNode> {
  /// Create a portal from a list of components
  DCFPortal portalTo(
    String targetId, {
    int priority = 0,
    Map<String, dynamic>? metadata,
    bool createTargetIfMissing = false,
    Function(String portalId)? onMount,
    Function(String portalId)? onUnmount,
  }) {
    return DCFPortalAPI.createPortal(
      this,
      targetId,
      priority: priority,
      metadata: metadata,
      createTargetIfMissing: createTargetIfMissing,
      onMount: onMount,
      onUnmount: onUnmount,
    );
  }
}

/// Common portal target IDs for standard UI patterns
class DCFPortalTargets {
  /// Standard modal/overlay container
  static const String modalRoot = 'modal-root';
  
  /// Notification/toast container
  static const String notificationRoot = 'notification-root';
  
  /// Tooltip container
  static const String tooltipRoot = 'tooltip-root';
  
  /// Dropdown/popover container
  static const String dropdownRoot = 'dropdown-root';
  
  /// Global overlay container (highest z-index)
  static const String overlayRoot = 'overlay-root';
  
  /// App header portal (for status indicators, etc.)
  static const String headerRoot = 'header-root';
  
  /// App footer portal
  static const String footerRoot = 'footer-root';
  
  /// Sidebar portal
  static const String sidebarRoot = 'sidebar-root';
}

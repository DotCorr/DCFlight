/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';


/// A portal component that renders its children into a different part of the component tree
class DCFPortal extends StatefulComponent {
  /// The target container ID where children will be portaled
  final String targetId;
  
  /// Children to be portaled
  final List<DCFComponentNode> children;
  
  /// Whether to create the target if it doesn't exist
  final bool createTarget;
  
  /// Optional callback when portal is mounted
  final Function(String targetId)? onPortalMount;
  
  /// Optional callback when portal is unmounted  
  final Function(String targetId)? onPortalUnmount;

  /// Stable portal ID that persists across component recreations
  late final String _stablePortalId;

  DCFPortal({
    super.key,
    required this.targetId,
    required this.children,
    this.createTarget = false,
    this.onPortalMount,
    this.onPortalUnmount,
  }) {
    // CRITICAL FIX: Create a stable portal ID based on target and key
    // This ensures the same portal (same target + key) always gets the same instance ID
    // preventing portal re-registration issues during reconciliation
    final keyPart = key ?? 'default';
    _stablePortalId = 'portal_${targetId}_${keyPart}_${runtimeType.toString().hashCode}';
  }

  /// Get the stable portal ID for manager operations
  String get portalId => _stablePortalId;

  @override
  DCFComponentNode render() {
    // CRITICAL FIX: Always register portal on render to handle reconciliation edge cases
    // This ensures portal registration happens even when componentDidMount isn't called
    // during reconciliation (which is the root cause of the second-time failure)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePortalRegistered();
    });
    
    // Portal renders as a pure fragment - no native view created
    // All portal metadata stays in the framework layer
    return DCFFragment(
      // Portal metadata handled purely in VDOM layer
      metadata: {
        'isPortalPlaceholder': true,
        'targetId': targetId,
        'portalId': portalId, // Use stable portal ID
        'createTarget': createTarget,
        'childrenCount': children.length,
      },
      children: [], // No children in placeholder - they go to the portal target
    );
  }

  @override
  void componentDidMount() {
    super.componentDidMount();
    // Register portal with the portal manager
    _registerPortal();
    onPortalMount?.call(targetId);
  }

  @override
  void componentDidUpdate(Map<String, dynamic> prevProps) {
    super.componentDidUpdate(prevProps);
    // CRITICAL FIX: Always ensure portal is registered and content is updated
    // This handles cases where portal is recreated during reconciliation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePortalRegistered();
    });
  }

  @override
  void componentWillUnmount() {
    // Unregister portal and clean up
    _unregisterPortal();
    onPortalUnmount?.call(targetId);
    super.componentWillUnmount();
  }

  /// Register this portal with the manager
  void _registerPortal() {
    PortalSystem.instance.registerPortal(this);
  }

  /// Ensure portal is registered (safe to call multiple times)
  void _ensurePortalRegistered() {
    // Use the portal system to check and register if needed
    PortalSystem.instance.ensurePortalRegistered(this);
  }

  /// Unregister this portal
  void _unregisterPortal() {
    PortalSystem.instance.unregisterPortal(this);
  }
}

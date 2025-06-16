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

  DCFPortal({
    super.key,
    required this.targetId,
    required this.children,
    this.createTarget = false,
    this.onPortalMount,
    this.onPortalUnmount,
  });

  @override
  DCFComponentNode render() {
    // Portal renders as a pure fragment - no native view created
    // All portal metadata stays in the framework layer
    return DCFFragment(
      // Portal metadata handled purely in VDOM layer
      metadata: {
        'isPortalPlaceholder': true,
        'targetId': targetId,
        'portalId': instanceId,
        'createTarget': createTarget,
        'childrenCount': children.length,
      },
      children: [], // No children in placeholder - they go to the portal target
    );
  }

  @override
  void componentDidMount() {
    super.componentDidMount();
    // Register portal with the portal manager (will be implemented via exports)
    _registerPortal();
    onPortalMount?.call(targetId);
  }

  @override
  void componentDidUpdate(Map<String, dynamic> prevProps) {
    super.componentDidUpdate(prevProps);
    // Update portal content when children or target changes
    _updatePortalContent();
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

  /// Update portal content
  void _updatePortalContent() {
    PortalSystem.instance.updatePortalContent(this);
  }

  /// Unregister this portal
  void _unregisterPortal() {
    PortalSystem.instance.unregisterPortal(this);
  }
}

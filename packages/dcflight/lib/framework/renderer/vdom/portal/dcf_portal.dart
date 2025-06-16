/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/renderer/vdom/component/component.dart';
import 'package:dcflight/framework/renderer/vdom/component/component_node.dart';
import 'package:dcflight/framework/renderer/vdom/component/fragment.dart';
import 'package:dcflight/framework/renderer/vdom/portal/enhanced_portal_manager.dart';
import 'package:flutter/foundation.dart';

/// DCFPortal component for rendering children into a different DOM tree location
/// Similar to React's createPortal, this allows rendering components outside 
/// their normal parent-child hierarchy
class DCFPortal extends StatefulComponent {
  final String targetId;
  final List<DCFComponentNode> children;
  final Map<String, dynamic>? metadata;
  final int priority;
  final bool createTargetIfMissing;
  final Function(String portalId)? onMount;
  final Function(String portalId)? onUnmount;

  DCFPortal({
    required this.targetId,
    required this.children,
    this.metadata,
    this.priority = 0,
    this.createTargetIfMissing = false,
    this.onMount,
    this.onUnmount,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final portalIdState = useState<String?>(null, 'portalId');
    final portalManager = EnhancedPortalManager.instance;

    // Effect to create portal on mount and handle updates
    useEffect(() {
      Future<void> createPortal() async {
        try {
          final portalId = await portalManager.createPortal(
            targetId: targetId,
            children: children,
            metadata: metadata,
            priority: priority,
            createTargetIfMissing: createTargetIfMissing,
            onMount: onMount,
            onUnmount: onUnmount,
          );
          
          portalIdState.setState(portalId);
        } catch (e) {
          if (kDebugMode) {
            print('❌ DCFPortal: Failed to create portal: $e');
          }
        }
      }

      createPortal();

      // Cleanup function
      return () {
        if (portalIdState.state != null) {
          portalManager.removePortal(portalIdState.state!).catchError((e) {
            if (kDebugMode) {
              print('❌ DCFPortal: Failed to destroy portal: $e');
            }
          });
        }
      };
    }, dependencies: [targetId]); // Re-run when targetId changes

    // Effect to update portal when children or properties change
    useEffect(() {
      if (portalIdState.state != null) {
        try {
          portalManager.updatePortal(
            portalId: portalIdState.state!,
            children: children,
            metadata: metadata,
            priority: priority,
          );
        } catch (e) {
          if (kDebugMode) {
            print('❌ DCFPortal: Failed to update portal: $e');
          }
        }
      }
      return null; // No cleanup needed for this effect
    }, dependencies: [children, metadata, priority]); // Re-run when these change

    // Return a placeholder fragment that doesn't render anything
    // The actual content is rendered through the portal system
    return DCFFragment(
      children: [],
      metadata: {
        'isPortalPlaceholder': true,
        'targetId': targetId,
        'portalId': portalIdState.state,
      },
    );
  }
}

/// DCFPortalTarget component for creating portal targets
class DCFPortalTarget extends StatefulComponent {
  final String targetId;
  final String? nativeViewId;
  final Map<String, dynamic>? metadata;
  final int priority;
  final List<DCFComponentNode> children;

  DCFPortalTarget({
    required this.targetId,
    this.nativeViewId,
    this.metadata,
    this.priority = 0,
    this.children = const [],
    super.key,
  });

  @override
  DCFComponentNode render() {
    final portalManager = EnhancedPortalManager.instance;

    // Effect to register/unregister target
    useEffect(() {
      portalManager.registerTarget(
        targetId: targetId,
        nativeViewId: nativeViewId ?? targetId,
        metadata: metadata,
        priority: priority,
      );

      // Cleanup function
      return () {
        portalManager.unregisterTarget(targetId);
      };
    }, dependencies: [targetId, nativeViewId, priority]); // Re-run when these change

    // Return the children wrapped in a container that serves as the portal target
    return DCFFragment(
      children: children,
      metadata: {
        'isPortalTarget': true,
        'targetId': targetId,
      },
    );
  }
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'package:dcflight/framework/renderer/engine/component/component.dart';
import 'package:dcflight/framework/renderer/engine/component/component_node.dart';
import 'package:dcflight/framework/renderer/engine/component/fragment.dart';
import 'package:dcflight/framework/renderer/engine/component/dcf_element.dart';
import 'package:dcflight/framework/renderer/engine/core/concurrency/priority.dart';
import 'package:dcflight/framework/renderer/engine/portal/enhanced_portal_manager.dart';
import 'package:flutter/foundation.dart';

/// DCFPortal component for rendering children into a different DOM tree location
/// Similar to React's createPortal, this allows rendering components outside
/// their normal parent-child hierarchy
class DCFPortal extends DCFStatefulComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  final String targetId;
  final List<DCFComponentNode> children;
  final Map<String, dynamic>? metadata;
  final bool createTargetIfMissing;
  final Function(String portalId)? onMount;
  final Function(String portalId)? onUnmount;

  @override
  List<Object?> get props => [
        targetId,
        children,
        metadata,
        createTargetIfMissing,
        onMount,
        onUnmount,
      ];

  DCFPortal({
    required this.targetId,
    required this.children,
    this.metadata,
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
            createTargetIfMissing: createTargetIfMissing,
            onMount: onMount,
            onUnmount: onUnmount,
          );

          portalIdState.setState(portalId);
        } catch (e) {}
      }

      createPortal();

      // Cleanup function
      return () {
        if (portalIdState.state != null) {
          portalManager.removePortal(portalIdState.state!).catchError((e) {});
        }
      };
    }, dependencies: []); // Only run once on mount/unmount

    // Separate effect to update portal when properties change
    useEffect(() {
      if (portalIdState.state != null) {
        // Use a microtask to ensure the update happens after the current render cycle
        Future.microtask(() {
          try {
            portalManager.updatePortal(
              portalId: portalIdState.state!,
              children: children,
              metadata: metadata,
            );
          } catch (e) {
            throw Exception('Failed to update portal: $e');
          }
        });
      }

      // Return cleanup function for this effect
      return () {};
    }, dependencies: [
      '${children.length}-${children.map((c) => c.runtimeType).join(',')}'
    ]); // Use string-based dependency that changes with content

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
class DCFPortalTarget extends DCFStatefulComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  final String targetId;
  final Map<String, dynamic>? metadata;
  final List<DCFComponentNode> children;

  @override
  List<Object?> get props => [
        targetId,
        metadata,
        children,
      ];

  DCFPortalTarget({
    required this.targetId,
    this.metadata,
    this.children = const [],
    super.key,
  });

  @override
  DCFComponentNode render() {
    final portalManager = EnhancedPortalManager.instance;
    final elementRef = useRef<DCFElement?>(null);
    final isRegisteredRef = useRef<bool>(false);

    // Effect to register/unregister target after the element is created and has a view ID
    useEffect(() {
      void attemptRegistration() {
        final isRegistered = isRegisteredRef.current ?? false;
        final element = elementRef.current;

        if (!isRegistered && element?.nativeViewId != null) {
          final actualViewId = element!.nativeViewId!;

          portalManager.registerTarget(
            targetId: targetId,
            nativeViewId: actualViewId,
            metadata: metadata,
          );

          isRegisteredRef.current = true;
        }
      }

      // Try to register immediately if view ID is already available
      attemptRegistration();

      // Set up a polling mechanism to check for view ID assignment
      // This is necessary because the view ID is assigned asynchronously during rendering
      Timer? pollTimer;
      final isRegistered = isRegisteredRef.current ?? false;
      if (!isRegistered) {
        pollTimer = Timer.periodic(Duration(milliseconds: 10), (timer) {
          attemptRegistration();
          final currentRegistered = isRegisteredRef.current ?? false;
          if (currentRegistered) {
            timer.cancel();
          }
        });

        // Cancel polling after 1 second to avoid infinite polling
        Timer(Duration(seconds: 1), () {
          pollTimer?.cancel();
          final finalRegistered = isRegisteredRef.current ?? false;
          if (!finalRegistered && kDebugMode) {}
        });
      }

      // Cleanup function
      return () {
        pollTimer?.cancel();
        final isRegistered = isRegisteredRef.current ?? false;
        if (isRegistered) {
          // Delay unregistration to allow portal cleanup to complete
          Future.microtask(() {
            portalManager.unregisterTarget(targetId);
          });
          isRegisteredRef.current = false;
        }
      };
    }, dependencies: [targetId]); // Only depend on targetId

    // Create the element that will be our portal target
    final element = DCFElement(
      type: 'View', // Use View component to create a native container
      elementProps: {
        'isPortalTarget': true,
        'targetId': targetId,
        'backgroundColor': 'transparent',
        'flex': 1,
        "width": "100%",
        "height": "100%",
      },
      children: children,
    );

    // Store reference to the element so we can access its view ID later
    elementRef.current = element;

    return element;
  }
}
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

      return () {
        if (portalIdState.state != null) {
          portalManager.removePortal(portalIdState.state!).catchError((e) {});
        }
      };
    }, dependencies: []); // Only run once on mount/unmount

    useEffect(() {
      if (portalIdState.state != null) {
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

      return () {};
    }, dependencies: [
      '${children.length}-${children.map((c) => c.runtimeType).join(',')}'
    ]); // Use string-based dependency that changes with content

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

      attemptRegistration();

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

        Timer(Duration(seconds: 1), () {
          pollTimer?.cancel();
          final finalRegistered = isRegisteredRef.current ?? false;
          if (!finalRegistered && kDebugMode) {}
        });
      }

      return () {
        pollTimer?.cancel();
        final isRegistered = isRegisteredRef.current ?? false;
        if (isRegistered) {
          Future.microtask(() {
            portalManager.unregisterTarget(targetId);
          });
          isRegisteredRef.current = false;
        }
      };
    }, dependencies: [targetId]); // Only depend on targetId

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

    elementRef.current = element;

    return element;
  }
}
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// A container component that can host portaled content
class DCFPortalContainer extends StatefulComponent {
  /// Unique identifier for this portal container
  final String targetId;
  
  /// Initial children (non-portaled content)
  final List<DCFComponentNode> children;
  
  /// Layout properties
  final LayoutProps layout;
  
  /// Style properties
  final StyleSheet styleSheet;

  /// Native view ID for this container (if already created)
  String? nativeViewId;

  DCFPortalContainer({
    super.key,
    required this.targetId,
    this.children = const [],
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.nativeViewId,
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'View', 
      props: {
        // Only send layout/style props to native - no portal metadata
        ...layout.toMap(),
        ...styleSheet.toMap(),
      },
      // Portal metadata handled in framework layer via registration
      children: children, // Initial children, portaled content added dynamically
    );
  }

  @override
  void componentDidMount() {
    super.componentDidMount();
    // Get the native view ID from the component's effective native view ID
    nativeViewId = effectiveNativeViewId;
    if (kDebugMode) {
      print('🎯 DCFPortalContainer: Got native view ID: $nativeViewId for target: $targetId');
    }
    // Portal manager registration will be handled via a global registry
    _registerWithPortalManager();
  }

  @override
  void componentWillUnmount() {
    // Unregister container
    _unregisterWithPortalManager();
    super.componentWillUnmount();
  }

  /// Register with portal manager - will be connected when portal system is initialized
  void _registerWithPortalManager() {
    PortalSystem.instance.registerContainer(targetId, this);
  }

  /// Unregister with portal manager
  void _unregisterWithPortalManager() {
    PortalSystem.instance.unregisterContainer(targetId);
  }

  /// Get existing child view IDs
  List<String> get existingChildIds {
    return children
        .map((child) => child.effectiveNativeViewId)
        .where((id) => id != null)
        .cast<String>()
        .toList();
  }

  /// Update the native view ID after the container is rendered
  void updateNativeViewId(String viewId) {
    nativeViewId = viewId;
  }
}

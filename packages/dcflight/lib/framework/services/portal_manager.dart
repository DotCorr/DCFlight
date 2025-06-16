/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:flutter/foundation.dart';
import 'package:dcflight/framework/utilities/flutter_framework_interop.dart';
import 'package:dcflight/framework/renderer/vdom/component/component_node.dart';

/// Portal Manager service for handling content teleportation between screen hosts
/// 
/// This service provides a general-purpose content management system that allows
/// any wrapper component (modal, alert, popover, etc.) to own and manage its content
/// without component-specific hacks in the VDOM or bridge.
/// 
/// Portal system but adapted for DCFlight's architecture.
class PortalManager {
  static final PortalManager _instance = PortalManager._internal();
  factory PortalManager() => _instance;
  PortalManager._internal();

  /// Map of host names to their content lists
  final Map<String, List<DCFComponentNode>> _screens = {};
  
  /// Map of host names to their update callbacks
  final Map<String, void Function()> _hostCallbacks = {};

  /// Register a screen host with the manager
  /// 
  /// [hostName] - Unique identifier for this host
  /// [onUpdate] - Callback to trigger when this host's content changes
  void registerHost(String hostName, void Function() onUpdate) {
    _hostCallbacks[hostName] = onUpdate;
    if (!_screens.containsKey(hostName)) {
      _screens[hostName] = [];
    }
    
    // If there's already content for this host, trigger update immediately
    if (_screens[hostName]!.isNotEmpty) {
      if (kDebugMode) {
        print('📺 ScreenManager: Host "$hostName" registered with existing content, triggering update');
      }
      onUpdate();
    }
    
    if (kDebugMode) {
      print('📺 ScreenManager: Registered host "$hostName"');
    }
  }

  /// Unregister a screen host from the manager
  /// 
  /// [hostName] - Host identifier to unregister
  void unregisterHost(String hostName) {
    _hostCallbacks.remove(hostName);
    _screens.remove(hostName);
    
    if (kDebugMode) {
      print('📺 ScreenManager: Unregistered host "$hostName"');
    }
  }

  /// Add content to a screen host
  /// 
  /// [hostName] - Target host identifier
  /// [screenId] - Unique identifier for this content (for replacement)
  /// [content] - The content node to teleport to the host
  void addToScreen(String hostName, String screenId, DCFComponentNode content) {
    if (!_screens.containsKey(hostName)) {
      _screens[hostName] = [];
    }
    
    // Remove existing content with same ID
    _screens[hostName]!.removeWhere((node) => node.key == screenId);
    
    // Add new content
    _screens[hostName]!.add(content);
    
    if (kDebugMode) {
      print('📺 ScreenManager: Added content "$screenId" to host "$hostName"');
      print('📺   Total content for host: ${_screens[hostName]!.length}');
      print('📺   Has callback registered: ${_hostCallbacks.containsKey(hostName)}');
    }
    
    // Notify host to update
    _hostCallbacks[hostName]?.call();
  }

  /// Remove content from a screen host
  /// 
  /// [hostName] - Host identifier
  /// [screenId] - Content identifier to remove
  void removeFromScreen(String hostName, String screenId) {
    final beforeCount = _screens[hostName]?.length ?? 0;
    _screens[hostName]?.removeWhere((node) => node.key == screenId);
    final afterCount = _screens[hostName]?.length ?? 0;
    
    if (kDebugMode && beforeCount > afterCount) {
      if (kDebugMode) {
        print('📺 ScreenManager: Removed content "$screenId" from host "$hostName"');
      }
    }
    
    _hostCallbacks[hostName]?.call();
  }

  /// Get all content for a specific host
  /// 
  /// [hostName] - Host identifier
  /// Returns list of content nodes for this host
  List<DCFComponentNode> getScreenContent(String hostName) {
    return List.from(_screens[hostName] ?? []);
  }

  /// Get list of all registered hosts (for debugging)
  List<String> get registeredHosts => _hostCallbacks.keys.toList();

  /// Clear all content for a host (for cleanup)
  void clearHost(String hostName) {
    _screens[hostName]?.clear();
    _hostCallbacks[hostName]?.call();
    
    if (kDebugMode) {
      print('📺 ScreenManager: Cleared all content from host "$hostName"');
    }
  }
}

/// Type alias for update callback
typedef ScreenUpdateCallback = void Function();

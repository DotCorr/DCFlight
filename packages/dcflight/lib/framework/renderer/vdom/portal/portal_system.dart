/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:flutter/foundation.dart';
import 'dcf_portal.dart' as portal_comp;
import 'dcf_portal_manager.dart';
import 'dcf_portal_container.dart' as container_comp;

/// Global portal system that connects all portal components
class PortalSystem {
  static final PortalSystem _instance = PortalSystem._internal();
  static PortalSystem get instance => _instance;
  PortalSystem._internal();

  /// Whether the portal system has been initialized
  bool _initialized = false;

  /// Initialize the portal system
  void initialize() {
    if (_initialized) return;
    
    if (kDebugMode) {
      print('🎯 PortalSystem: Initializing portal system');
    }
    
    _initialized = true;
  }

  /// Register a portal with the manager
  Future<void> registerPortal(portal_comp.DCFPortal portal) async {
    if (!_initialized) {
      if (kDebugMode) {
        print('⚠️ PortalSystem: Auto-initializing portal system');
      }
      initialize();
    }
    
    return DCFPortalManager.instance.registerPortal(portal);
  }

  /// Ensure a portal is registered (safe to call multiple times)
  Future<void> ensurePortalRegistered(portal_comp.DCFPortal portal) async {
    if (!_initialized) {
      if (kDebugMode) {
        print('⚠️ PortalSystem: Auto-initializing portal system');
      }
      initialize();
    }
    
    return DCFPortalManager.instance.ensurePortalRegistered(portal);
  }

  /// Update portal content
  Future<void> updatePortalContent(portal_comp.DCFPortal portal) async {
    return DCFPortalManager.instance.updatePortalContent(portal);
  }

  /// Unregister a portal
  Future<void> unregisterPortal(portal_comp.DCFPortal portal) async {
    return DCFPortalManager.instance.unregisterPortal(portal);
  }

  /// Register a portal container
  void registerContainer(String targetId, container_comp.DCFPortalContainer container) {
    if (!_initialized) {
      if (kDebugMode) {
        print('⚠️ PortalSystem: Auto-initializing portal system');
      }
      initialize();
    }
    
    DCFPortalManager.instance.registerContainer(targetId, container);
  }

  /// Unregister a portal container
  void unregisterContainer(String targetId) {
    DCFPortalManager.instance.unregisterContainer(targetId);
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'initialized': _initialized,
      ...DCFPortalManager.instance.getDebugInfo(),
    };
  }
}

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'package:dcflight/framework/renderer/interface/interface_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'interface.dart';

/// Method channel-based implementation of NativeBridge
class PlatformInterfaceImpl implements PlatformInterface {
  // Method channels
  static const MethodChannel bridgeChannel = MethodChannel('com.dcmaui.bridge');
  static const MethodChannel eventChannel = MethodChannel('com.dcmaui.events');
  static const MethodChannel layoutChannel = MethodChannel('com.dcmaui.layout');

  // Add batch update state
  bool _batchUpdateInProgress = false;
  final List<Map<String, dynamic>> _pendingBatchUpdates = [];

  // Map to store callbacks for each view and event type
  final Map<String, Map<String, Function>> _eventCallbacks = {};
  
  // Global event handler for fallback when a specific callback isn't found
  Function(String viewId, String eventType, Map<String, dynamic> eventData)? _eventHandler;

  // Sets up communication with native code
  PlatformInterfaceImpl() {
    // Set up method channels for events
    _setupMethodChannelEventHandling();
  }

  // Set up method channel for event handling
  void _setupMethodChannelEventHandling() {
    eventChannel.setMethodCallHandler((call) async {
      if (call.method == 'onEvent') {
        final Map<dynamic, dynamic> args = call.arguments;
        final String viewId = args['viewId'];
        final String eventType = args['eventType'];
        final Map<dynamic, dynamic> eventData = args['eventData'] ?? {};

        // Convert dynamic map to String, dynamic map
        final typedEventData = eventData.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );

        // Forward the event to the handler
        handleNativeEvent(viewId, eventType, typedEventData);
      }
      return null;
    });
  }

  @override
  Future<bool> initialize() async {
    try {
      final result = await bridgeChannel.invokeMethod<bool>('initialize');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> createView(
      String viewId, String type, Map<String, dynamic> props) async {
    // Track operation for batch updates if needed
    if (_batchUpdateInProgress) {
      _pendingBatchUpdates.add({
        'operation': 'createView',
        'viewId': viewId,
        'viewType': type,
        'props': props,
      });
      return true;
    }

    try {
      // Preprocess props to handle special types before encoding to JSON
      final processedProps = preprocessProps(props);

      final result = await bridgeChannel.invokeMethod<bool>('createView', {
        'viewId': viewId,
        'viewType': type,
        'props': processedProps,
      });

      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> updateView(
      String viewId, Map<String, dynamic> propPatches) async {
    // Track operation for batch updates if needed
    if (_batchUpdateInProgress) {
      _pendingBatchUpdates.add({
        'operation': 'updateView',
        'viewId': viewId,
        'props': propPatches,
      });
      return true;
    }

    try {
      // Process props for updates
      final processedProps = preprocessProps(propPatches);

      // Special case for text content updates to ensure they're always propagated
      if (propPatches.containsKey('content')) {
      }
      
      // Make sure prop updates are properly queued even if many updates happen quickly
      final result = await bridgeChannel.invokeMethod<bool>('updateView', {
        'viewId': viewId,
        'props': processedProps,
      });

      if (result != true && kDebugMode) {
      }

      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteView(String viewId) async {
    try {
      final result = await bridgeChannel.invokeMethod<bool>('deleteView', {
        'viewId': viewId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> detachView(String viewId) async {
    try {
      final result = await bridgeChannel.invokeMethod<bool>('detachView', {
        'viewId': viewId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> attachView(String childId, String parentId, int index) async {
    try {
      final result = await bridgeChannel.invokeMethod<bool>('attachView', {
        'childId': childId,
        'parentId': parentId,
        'index': index,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> setChildren(String viewId, List<String> childrenIds) async {
    try {
      // Add debug for Modal specifically
      
      final result = await bridgeChannel.invokeMethod<bool>('setChildren', {
        'viewId': viewId,
        'childrenIds': childrenIds,
      });
      
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> addEventListeners(String viewId, List<String> eventTypes) async {
    try {
      await eventChannel.invokeMethod('addEventListeners', {
        'viewId': viewId,
        'eventTypes': eventTypes,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> removeEventListeners(
      String viewId, List<String> eventTypes) async {
    try {
      final result =
          await eventChannel.invokeMethod<bool>('removeEventListeners', {
        'viewId': viewId,
        'eventTypes': eventTypes,
      });

      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  void setEventHandler(
      Function(String viewId, String eventType, Map<String, dynamic> eventData)
          handler) {
    _eventHandler = handler;
  }

  // REMOVED: updateViewLayout and calculateLayout methods
  // Layout is now calculated automatically when layout props change

  // REMOVED: callComponentMethod - replaced with prop-based commands
  // Components now handle imperative operations through command props

  @override
  Future<bool> startBatchUpdate() async {
    if (_batchUpdateInProgress) {
      return false;
    }

    _batchUpdateInProgress = true;
    _pendingBatchUpdates.clear();
    return true;
  }

  @override
  Future<bool> commitBatchUpdate() async {
    if (!_batchUpdateInProgress) {
      return false;
    }

    try {
      final success =
          await bridgeChannel.invokeMethod<bool>('commitBatchUpdate', {
        'updates': _pendingBatchUpdates,
      });

      _batchUpdateInProgress = false;
      _pendingBatchUpdates.clear();
      return success ?? false;
    } catch (e) {
      _batchUpdateInProgress = false;
      _pendingBatchUpdates.clear();
      return false;
    }
  }

  @override
  Future<bool> cancelBatchUpdate() async {
    if (!_batchUpdateInProgress) {
      return false;
    }

    _batchUpdateInProgress = false;
    _pendingBatchUpdates.clear();
    return true;
  }

  @override
  void registerEventCallback(
      String viewId, String eventType, Function callback) {
    _eventCallbacks[viewId] ??= {};
    _eventCallbacks[viewId]![eventType] = callback;
  }

  @override
  void handleNativeEvent(
      String viewId, String eventType, Map<String, dynamic> eventData) {
    // First try to find a specific callback for this view and event
    final callback = _eventCallbacks[viewId]?[eventType];
    if (callback != null) {
      try {
        // Handle parameter count mismatch by checking function parameters
        final Function func = callback;
        if (func is Function()) {
          func();
        } else if (func is Function(Map<String, dynamic>)) {
          func(eventData);
        } else {
          Function.apply(callback, [], {});
        }
        return;
      } catch (e) {
        print(e);
      }
    }
    
    // If no specific callback found, use the global event handler as fallback
    if (_eventHandler != null) {
      try {
        _eventHandler!(viewId, eventType, eventData);
      } catch (e) {
        print(e);
      }
    }
  }
   @override
  Future<dynamic> tunnel(String componentType, String method, Map<String, dynamic> params) async {
    try {
      final result = await bridgeChannel.invokeMethod('tunnel', {
        'componentType': componentType,
        'method': method,
        'params': params,
      });
      print("🚇 Tunnel: Called $method on $componentType - Success");
      return result;
    } catch (e) {
      print("❌ Tunnel: Failed to call $method on $componentType - Error: $e");
      return null;
    }
  }
}


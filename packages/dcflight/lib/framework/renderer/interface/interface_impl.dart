/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:io';
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

  // Platform-specific batching behavior
  // IMPORTANT: We disable platform-level batching on Android due to implementation issues
  // with the native batch commit system. The VDOM-level batching in DCFEngine still works
  // and provides the primary performance benefits. This is a temporary workaround until
  // the Android batch implementation is fixed.

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
    print('🔥 DCF_ENGINE: Setting up method channel event handling');
    print('🔥 DCF_ENGINE: Event channel name: ${eventChannel.name}');
    
    // Test if the channel exists and is accessible
    eventChannel.setMethodCallHandler((call) async {
      print('🔥 DCF_ENGINE: ✅ METHOD CHANNEL HANDLER CALLED!');
      print('🔥 DCF_ENGINE: Method channel received call: ${call.method}');
      print('🔥 DCF_ENGINE: Method channel args: ${call.arguments}');
      if (call.method == 'onEvent') {
        final Map<dynamic, dynamic> args = call.arguments;
        print('🔥 DCF_ENGINE: onEvent args: $args');
        final String viewId = args['viewId'];
        final String eventType = args['eventType'];
        final Map<dynamic, dynamic> eventData = args['eventData'] ?? {};

        print('🔥 DCF_ENGINE: Processing event - viewId: $viewId, eventType: $eventType, eventData: $eventData');

        // Convert dynamic map to String, dynamic map
        final typedEventData = eventData.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );

        // Forward the event to the handler
        print('🔥 DCF_ENGINE: Forwarding to handleNativeEvent');
        handleNativeEvent(viewId, eventType, typedEventData);
      }
      return null;
    });
    
    print('🔥 DCF_ENGINE: ✅ Method channel handler SET SUCCESSFULLY!');
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
    // Platform-aware batch handling - re-enable for testing
    if (_batchUpdateInProgress) {
      // CRITICAL FIX: Preprocess props BEFORE adding to batch to remove closures
      final processedProps = preprocessProps(props);
      _pendingBatchUpdates.add({
        'operation': 'createView',
        'viewId': viewId,
        'viewType': type,
        'props': processedProps,
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
    print('🔥 FLUTTER_BRIDGE: updateView called - viewId: $viewId, props: $propPatches');
    
    // Platform-aware batching: Re-enable for testing with fixed Android implementation
    if (_batchUpdateInProgress) {
      print('🔥 FLUTTER_BRIDGE: Adding updateView to batch - viewId: $viewId');
      // CRITICAL FIX: Preprocess props BEFORE adding to batch to remove closures
      final processedProps = preprocessProps(propPatches);
      _pendingBatchUpdates.add({
        'operation': 'updateView',
        'viewId': viewId,
        'props': processedProps,
      });
      return true;
    }

    try {
      // Process props for updates
      final processedProps = preprocessProps(propPatches);
      print('🔥 FLUTTER_BRIDGE: Processed props for $viewId: $processedProps');

      // Special case for text content updates to ensure they're always propagated
      if (propPatches.containsKey('content')) {
        print('🔥 FLUTTER_BRIDGE: Content update detected for $viewId: ${propPatches['content']}');
      }
      
      // Make sure prop updates are properly queued even if many updates happen quickly
      print('🔥 FLUTTER_BRIDGE: Calling method channel updateView for $viewId');
      final result = await bridgeChannel.invokeMethod<bool>('updateView', {
        'viewId': viewId,
        'props': processedProps,
      });
      print('🔥 FLUTTER_BRIDGE: Method channel result for $viewId: $result');

      if (result != true && kDebugMode) {
        print('🔥 FLUTTER_BRIDGE: WARNING - updateView returned false for $viewId');
      }

      return result ?? false;
    } catch (e) {
      print('🔥 FLUTTER_BRIDGE: ERROR - updateView failed for $viewId: $e');
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
    // CRITICAL FIX: Queue attachView in batch like createView and updateView
    // Attachments MUST happen AFTER views are created!
    if (_batchUpdateInProgress) {
      print('🔥 FLUTTER_BRIDGE: Adding attachView to batch - child: $childId, parent: $parentId, index: $index');
      _pendingBatchUpdates.add({
        'operation': 'attachView',
        'childId': childId,
        'parentId': parentId,
        'index': index,
      });
      return true;
    }

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
    // CRITICAL FIX: Queue event listener registration in batch
    // Event listeners must be registered AFTER views are created
    if (_batchUpdateInProgress) {
      print('🔥 FLUTTER_BRIDGE: Adding addEventListeners to batch - viewId: $viewId, eventTypes: $eventTypes');
      _pendingBatchUpdates.add({
        'operation': 'addEventListeners',
        'viewId': viewId,
        'eventTypes': eventTypes,
      });
      return true;
    }
    
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
      print('🔥 FLUTTER_BRIDGE: startBatchUpdate called but batch already in progress');
      return false;
    }

    print('🔥 FLUTTER_BRIDGE: startBatchUpdate called - starting new batch');
    _batchUpdateInProgress = true;
    _pendingBatchUpdates.clear();
    return true;
  }

  @override
  Future<bool> commitBatchUpdate() async {
    if (!_batchUpdateInProgress) {
      return false;
    }

    print('🔥 FLUTTER_BRIDGE: commitBatchUpdate called with ${_pendingBatchUpdates.length} updates');
    
    try {
      // Platform-specific parameter names: iOS expects 'updates', Android expects 'operations'
      final paramKey = Platform.isIOS ? 'updates' : 'operations';
      final success =
          await bridgeChannel.invokeMethod<bool>('commitBatchUpdate', {
        paramKey: _pendingBatchUpdates,
      });

      print('🔥 FLUTTER_BRIDGE: commitBatchUpdate native call result: $success');
      
      _batchUpdateInProgress = false;
      _pendingBatchUpdates.clear();
      return success ?? false;
    } catch (e) {
      print('🔥 FLUTTER_BRIDGE: commitBatchUpdate error: $e');
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
    print('🔥 DCF_ENGINE: handleNativeEvent received - viewId: $viewId, eventType: $eventType, data: $eventData');
    
    // First try to find a specific callback for this view and event
    final callback = _eventCallbacks[viewId]?[eventType];
    if (callback != null) {
      print('🔥 DCF_ENGINE: Found specific callback for $viewId.$eventType');
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
        print('🔥 DCF_ENGINE: Error in specific callback: $e');
      }
    }
    
    // If no specific callback found, use the global event handler as fallback
    if (_eventHandler != null) {
      print('🔥 DCF_ENGINE: Forwarding to global event handler');
      try {
        _eventHandler!(viewId, eventType, eventData);
      } catch (e) {
        print('🔥 DCF_ENGINE: Error in global event handler: $e');
      }
    } else {
      print('🔥 DCF_ENGINE: No global event handler set!');
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


/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dcflight/framework/renderer/interface/interface_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'interface.dart';

/// Method channel-based implementation of NativeBridge
class PlatformInterfaceImpl implements PlatformInterface {
  static const MethodChannel bridgeChannel = MethodChannel('com.dcmaui.bridge');
  static const MethodChannel eventChannel = MethodChannel('com.dcmaui.events');
  static const MethodChannel layoutChannel = MethodChannel('com.dcmaui.layout');

  bool _batchUpdateInProgress = false;
  final List<Map<String, dynamic>> _pendingBatchUpdates = [];

  // IMPORTANT: We disable platform-level batching on Android due to implementation issues

  final Map<String, Map<String, Function>> _eventCallbacks = {};
  
  Function(String viewId, String eventType, Map<String, dynamic> eventData)? _eventHandler;

  PlatformInterfaceImpl() {
    _setupMethodChannelEventHandling();
  }

  void _setupMethodChannelEventHandling() {
    print('🔥 DCF_ENGINE: Setting up method channel event handling');
    print('🔥 DCF_ENGINE: Event channel name: ${eventChannel.name}');
    
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

        final typedEventData = eventData.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );

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
    if (_batchUpdateInProgress) {
      final processedProps = preprocessProps(props);
      // ⭐ OPTIMIZATION: Pre-serialize to JSON on Dart side to avoid native JSON parsing
      final propsJson = jsonEncode(processedProps);
      _pendingBatchUpdates.add({
        'operation': 'createView',
        'viewId': viewId,
        'viewType': type,
        'propsJson': propsJson,  // Pre-serialized JSON string
      });
      return true;
    }

    try {
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
    
    if (_batchUpdateInProgress) {
      print('🔥 FLUTTER_BRIDGE: Adding updateView to batch - viewId: $viewId');
      final processedProps = preprocessProps(propPatches);
      // ⭐ OPTIMIZATION: Pre-serialize to JSON on Dart side to avoid native JSON parsing
      final propsJson = jsonEncode(processedProps);
      _pendingBatchUpdates.add({
        'operation': 'updateView',
        'viewId': viewId,
        'propsJson': propsJson,  // Pre-serialized JSON string
      });
      return true;
    }

    try {
      final processedProps = preprocessProps(propPatches);
      print('🔥 FLUTTER_BRIDGE: Processed props for $viewId: $processedProps');

      if (propPatches.containsKey('content')) {
        print('🔥 FLUTTER_BRIDGE: Content update detected for $viewId: ${propPatches['content']}');
      }
      
      print('🔥 FLUTTER_BRIDGE: Calling method channel updateView for $viewId');
      final result = await bridgeChannel.invokeMethod<bool>('updateView', {
        'viewId': viewId,
        'props': processedProps,
      });
      print('🔥 FLUTTER_BRIDGE: Method channel result for $viewId: $result');

      if (result != true) {
        print('🔥 FLUTTER_BRIDGE: WARNING - updateView returned false for $viewId, view may not exist in registry');
        // If updateView fails, the view might not exist - this is a framework issue
        // The Android bridge should handle this via createView → updateView redirect
        return false;
      }

      return true;
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
    if (_batchUpdateInProgress) {
      print('🔥 FLUTTER_BRIDGE: Adding attachView to batch - child: $childId, parent: $parentId, index: $index');
      // No props serialization needed for attachView - just metadata
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
    
    final callback = _eventCallbacks[viewId]?[eventType];
    if (callback != null) {
      print('🔥 DCF_ENGINE: Found specific callback for $viewId.$eventType');
      try {
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


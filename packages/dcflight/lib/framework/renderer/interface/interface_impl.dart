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
import 'package:dcflight/framework/events/event_registry.dart';
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

  // 🔥 NEW: Use centralized EventRegistry instead of fragile callbacks
  final EventRegistry _eventRegistry = EventRegistry();

  PlatformInterfaceImpl() {
    _setupMethodChannelEventHandling();
  }

  /// Sets up method channel event handling for native-to-Dart communication.
  void _setupMethodChannelEventHandling() {
    eventChannel.setMethodCallHandler((call) async {
      if (call.method == 'onEvent') {
        print('🎯 Dart Bridge: Received onEvent');
        final Map<dynamic, dynamic> args = call.arguments;
        print('🎯 Dart Bridge: args = $args');

        final int viewId = args['viewId'] is int
            ? args['viewId']
            : int.parse(args['viewId'].toString());
        final String eventType = args['eventType'];
        final Map<dynamic, dynamic> eventData = args['eventData'] ?? {};

        print('🎯 Dart Bridge: Processing event $eventType for view $viewId');
        
        // 🔥 NEW: Use centralized EventRegistry - clean, no fallbacks
        final handled = _eventRegistry.handleEvent(viewId, eventType, Map<String, dynamic>.from(eventData));
        if (!handled) {
          print('⚠️ Dart Bridge: Event $eventType for view $viewId not registered - ignoring (fail-fast)');
        }
      } else {
        print('⚠️ Dart Bridge: Unknown method ${call.method}');
      }
      return null;
    });
  }

  /// Initializes the native bridge.
  ///
  /// Returns `true` if initialization succeeded, `false` otherwise.
  @override
  Future<bool> initialize() async {
    try {
      final result = await bridgeChannel.invokeMethod<bool>('initialize');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Creates a new native view with the specified type and properties.
  ///
  /// If batch updates are in progress, the operation is queued for later execution.
  /// Otherwise, it's executed immediately via the method channel.
  ///
  /// - [viewId]: Unique identifier for the view
  /// - [type]: Component type (e.g., "View", "Text", "Button")
  /// - [props]: Properties to apply to the view
  /// - Returns: `true` if the view was created successfully, `false` otherwise
  @override
  Future<bool> createView(
      int viewId, String type, Map<String, dynamic> props) async {
    if (_batchUpdateInProgress) {
      final processedProps = preprocessProps(props);
      // Pre-serialize to JSON on Dart side to avoid native JSON parsing overhead
      final propsJson = jsonEncode(processedProps);
      _pendingBatchUpdates.add({
        'operation': 'createView',
        'viewId': viewId,
        'viewType': type,
        'propsJson': propsJson, // Pre-serialized JSON string
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

  /// Updates properties of an existing native view.
  ///
  /// If batch updates are in progress, the operation is queued for later execution.
  /// Otherwise, it's executed immediately via the method channel.
  ///
  /// - [viewId]: Unique identifier for the view to update
  /// - [propPatches]: Map of property changes to apply
  /// - Returns: `true` if the view was updated successfully, `false` otherwise
  @override
  Future<bool> updateView(int viewId, Map<String, dynamic> propPatches) async {
    if (_batchUpdateInProgress) {
      final processedProps = preprocessProps(propPatches);
      // Pre-serialize to JSON on Dart side to avoid native JSON parsing overhead
      final propsJson = jsonEncode(processedProps);
      _pendingBatchUpdates.add({
        'operation': 'updateView',
        'viewId': viewId,
        'propsJson': propsJson,
      });
      return true;
    }

    try {
      final processedProps = preprocessProps(propPatches);
      final result = await bridgeChannel.invokeMethod<bool>('updateView', {
        'viewId': viewId,
        'props': processedProps,
      });

      if (result != true) {
        // If updateView fails, the view might not exist - this is a framework issue
        // The Android bridge should handle this via createView → updateView redirect
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a native view from the view hierarchy.
  ///
  /// - [viewId]: Unique identifier for the view to delete
  /// - Returns: `true` if the view was deleted successfully, `false` otherwise
  @override
  Future<bool> deleteView(int viewId) async {
    // 🔧 FIX: Queue delete operation if batch update is in progress
    // This ensures delete is processed BEFORE create in the batch commit,
    // preventing both old and new views from being in the layout tree simultaneously
    if (_batchUpdateInProgress) {
      print('🗑️ QUEUE_DELETE: Queuing deleteView($viewId) for batch commit');
      _pendingBatchUpdates.add({
        'operation': 'deleteView',
        'viewId': viewId,
      });
      return true;
    }

    try {
      final result = await bridgeChannel.invokeMethod<bool>('deleteView', {
        'viewId': viewId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Detaches a view from its parent without deleting it.
  ///
  /// - [viewId]: Unique identifier for the view to detach
  /// - Returns: `true` if the view was detached successfully, `false` otherwise
  @override
  Future<bool> detachView(int viewId) async {
    try {
      final result = await bridgeChannel.invokeMethod<bool>('detachView', {
        'viewId': viewId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Attaches a child view to a parent view at the specified index.
  ///
  /// If batch updates are in progress, the operation is queued for later execution.
  ///
  /// - [childId]: Unique identifier for the child view
  /// - [parentId]: Unique identifier for the parent view
  /// - [index]: Position in the parent's child list
  /// - Returns: `true` if the view was attached successfully, `false` otherwise
  @override
  Future<bool> attachView(int childId, int parentId, int index) async {
    print(
        '🔥 attachView: childId=$childId, parentId=$parentId, _batchUpdateInProgress=$_batchUpdateInProgress');
    if (_batchUpdateInProgress) {
      // No props serialization needed for attachView - just metadata
      _pendingBatchUpdates.add({
        'operation': 'attachView',
        'childId': childId,
        'parentId': parentId,
        'index': index,
      });
      print(
          '🔥 attachView: Queued attach operation (total queued: ${_pendingBatchUpdates.length})');
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

  /// Sets the children of a view, replacing any existing children.
  ///
  /// - [viewId]: Unique identifier for the parent view
  /// - [childrenIds]: List of child view identifiers in order
  /// - Returns: `true` if children were set successfully, `false` otherwise
  @override
  Future<bool> setChildren(int viewId, List<int> childrenIds) async {
    if (_batchUpdateInProgress) {
      _pendingBatchUpdates.add({
        'operation': 'setChildren',
        'viewId': viewId,
        'childrenIds': childrenIds,
      });
      return true;
    }

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

  /// Registers event listeners for a view.
  ///
  /// If batch updates are in progress, the operation is queued for later execution.
  ///
  /// - [viewId]: Unique identifier for the view
  /// - [eventTypes]: List of event types to listen for (e.g., ["onPress", "onChange"])
  /// - Returns: `true` if listeners were added successfully, `false` otherwise
  @override
  Future<bool> addEventListeners(int viewId, List<String> eventTypes) async {
    if (_batchUpdateInProgress) {
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

  /// Removes event listeners from a view.
  ///
  /// - [viewId]: Unique identifier for the view
  /// - [eventTypes]: List of event types to remove
  /// - Returns: `true` if listeners were removed successfully, `false` otherwise
  @override
  Future<bool> removeEventListeners(int viewId, List<String> eventTypes) async {
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

  /// Sets the global event handler for native events.
  ///
  /// - [handler]: Function to call when native events are received
  @override
  void setEventHandler(
      Function(int viewId, String eventType, Map<String, dynamic> eventData)
          handler) {
    // 🔥 NEW: Use EventRegistry for global handler
    _eventRegistry.setGlobalHandler(handler);
    print('✅ PlatformInterface: Event handler set successfully (using EventRegistry)');
  }

  /// Starts a batch update operation.
  ///
  /// When batch updates are active, all view operations are queued and executed
  /// atomically when [commitBatchUpdate] is called.
  ///
  /// - Returns: `true` if batch update started successfully, `false` if one is already in progress
  @override
  Future<bool> startBatchUpdate() async {
    if (_batchUpdateInProgress) {
      return false;
    }

    _batchUpdateInProgress = true;
    _pendingBatchUpdates.clear();
    return true;
  }

  /// Commits all queued batch update operations atomically.
  ///
  /// All operations queued since [startBatchUpdate] was called are sent to the
  /// native bridge in a single call for optimal performance.
  ///
  /// - Returns: `true` if the batch was committed successfully, `false` otherwise
  @override
  Future<bool> commitBatchUpdate() async {
    if (!_batchUpdateInProgress) {
      print('⚠️ commitBatchUpdate: No batch update in progress');
      return false;
    }

    try {
      final paramKey = Platform.isIOS ? 'updates' : 'operations';
      final attachCount = _pendingBatchUpdates
          .where((op) => op['operation'] == 'attachView')
          .length;
      final createCount = _pendingBatchUpdates
          .where((op) => op['operation'] == 'createView')
          .length;
      print(
          '🔥 commitBatchUpdate: Sending ${_pendingBatchUpdates.length} operations (${createCount} creates, ${attachCount} attaches)');
      if (attachCount > 0) {
        print(
            '🔥 commitBatchUpdate: Attach operations: ${_pendingBatchUpdates.where((op) => op['operation'] == 'attachView').map((op) => '${op['childId']}->${op['parentId']}').join(', ')}');
      }
      final success =
          await bridgeChannel.invokeMethod<bool>('commitBatchUpdate', {
        paramKey: _pendingBatchUpdates,
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

  /// Cancels the current batch update operation, discarding all queued operations.
  ///
  /// - Returns: `true` if a batch was cancelled, `false` if no batch was in progress
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
  void registerEventCallback(int viewId, String eventType, Function callback) {
    // 🔥 NEW: Use EventRegistry instead of fragile callbacks
    _eventRegistry.register(viewId, {eventType: callback});
  }

  /// Handles native events received from the platform bridge.
  ///
  /// Handle event from native - uses centralized EventRegistry
  ///
  /// - [viewId]: Unique identifier for the view that triggered the event
  /// - [eventType]: Type of event (e.g., "onPress", "onChange")
  /// - [eventData]: Event data dictionary
  @override
  void handleNativeEvent(
      int viewId, String eventType, Map<String, dynamic> eventData) {
    // 🔥 NEW: Use centralized EventRegistry - clean, no fallbacks
    final handled = _eventRegistry.handleEvent(viewId, eventType, eventData);
    if (!handled) {
      print('⚠️ PlatformInterface: Event $eventType for view $viewId not registered - ignoring (fail-fast)');
    }
  }
  
  /// Register events for a view - uses centralized EventRegistry
  void registerEvents(int viewId, Map<String, Function> events) {
    _eventRegistry.register(viewId, events);
  }
  
  /// Unregister events for a view (called automatically on view removal)
  void unregisterEvents(int viewId) {
    _eventRegistry.unregister(viewId);
  }
  
  /// Set global event handler (optional - for debugging)
  void setGlobalEventHandler(void Function(int viewId, String eventType, Map<String, dynamic> eventData)? handler) {
    _eventRegistry.setGlobalHandler(handler);
  }

  /// Calls a method on a native component via the tunnel mechanism.
  ///
  /// - [componentType]: Type of component to call the method on
  /// - [method]: Method name to call
  /// - [params]: Parameters for the method call
  /// - Returns: Result from the native method, or `null` if it failed
  @override
  Future<dynamic> tunnel(
      String componentType, String method, Map<String, dynamic> params) async {
    try {
      final result = await bridgeChannel.invokeMethod('tunnel', {
        'componentType': componentType,
        'method': method,
        'params': params,
      });
      return result;
    } catch (e) {
      return null;
    }
  }
}

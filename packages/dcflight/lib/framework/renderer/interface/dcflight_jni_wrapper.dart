/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:developer';
import 'dart:convert';

import 'package:jni/jni.dart' as jni;
import 'src/generated/dcflight_jni.dart';
import 'interface.dart';
import 'interface_util.dart';
import '../../events/event_registry.dart';

/// Wrapper for Android DCFlight bridge using JNI.
///
/// This demonstrates direct JNI access to Android bridge APIs
/// without using Flutter's platform channels.
///
/// Usage:
/// ```dart
/// final bridge = DCFlightJniWrapper();
/// await bridge.initialize();
/// ```
class DCFlightJniWrapper implements PlatformInterface {
  static DCFlightJni? _jniInstance;
  static final EventRegistry _eventRegistry = EventRegistry();
  static void Function(Map<String, dynamic>)? _screenDimensionsChangeHandler;
  
  bool _batchUpdateInProgress = false;
  final List<Map<String, dynamic>> _pendingBatchUpdates = [];

  /// Lazy initialization - creates the JNI instance on first use
  DCFlightJni get _instance {
    if (_jniInstance == null) {
      throw UnimplementedError('JNI bindings not generated. Run: dart run jnigen --config jnigen.yaml');
    }
    return _jniInstance!;
  }
  
  /// Native screen dimensions callback function
  /// This is called from native code (potentially from UI thread)
  /// We use scheduleMicrotask to ensure it runs on the Dart isolate thread
  static void _onScreenDimensionsChanged(jni.JString dimensionsJson) {
    // Copy string immediately while we're in the callback context
    final dimensionsJsonStr = dimensionsJson.toDartString();
    
    // Schedule the actual handling on the Dart isolate thread
    scheduleMicrotask(() {
      try {
        final dimensions = jsonDecode(dimensionsJsonStr) as Map<String, dynamic>;
        _screenDimensionsChangeHandler?.call(dimensions);
      } catch (e) {
        log('Error handling screen dimensions change: $e');
      }
    });
  }

  /// Native event callback function
  /// This is called from native code (potentially from UI thread)
  /// We use scheduleMicrotask to ensure it runs on the Dart isolate thread
  static void _onNativeEvent(int viewId, jni.JString eventType, jni.JString eventDataJson) {
    // Copy strings immediately while we're in the callback context
    final eventTypeStr = eventType.toDartString();
    final eventDataJsonStr = eventDataJson.toDartString();
    
    // Schedule the actual event handling on the Dart isolate thread
    scheduleMicrotask(() {
      try {
        Map<String, dynamic> eventData = {};
        if (eventDataJsonStr.isNotEmpty && eventDataJsonStr != 'null') {
          try {
            eventData = jsonDecode(eventDataJsonStr) as Map<String, dynamic>;
          } catch (e) {
            log('Error parsing event data JSON: $e');
          }
        }
        
        _eventRegistry.handleEvent(viewId, eventTypeStr, eventData);
      } catch (e) {
        log('Error handling native event: $e');
      }
    });
  }

  @override
  Future<bool> initialize() async {
    try {
      final result = _instance.initialize();
      if (result) {
        final callback = _DCFlightJniEventCallback(_onNativeEvent);
        DCFlightJni.setEventCallback(callback);
        
        final dimensionsCallback = _DCFlightJniScreenDimensionsCallback(_onScreenDimensionsChanged);
        DCFlightJni.setScreenDimensionsCallback(dimensionsCallback);
      }
      return result;
    } catch (e) {
      log('Error initializing DCFlight bridge via JNI: $e');
      return false;
    }
  }

  @override
  Future<bool> createView(int viewId, String type, Map<String, dynamic> props) async {
    final processedProps = preprocessProps(props);
    
    if (_batchUpdateInProgress) {
      final propsJson = jsonEncode(processedProps);
      _pendingBatchUpdates.add({
        'operation': 'createView',
        'viewId': viewId,
        'viewType': type,
        'propsJson': propsJson,
      });
      return true;
    }
    
    try {
      final propsJson = jsonEncode(processedProps);
      final jType = jni.JString.fromString(type);
      final jPropsJson = jni.JString.fromString(propsJson);
      try {
        return _instance.createView(viewId, jType, jPropsJson);
      } finally {
        jType.release();
        jPropsJson.release();
      }
    } catch (e) {
      log('Error creating view via JNI: $e');
      return false;
    }
  }

  @override
  Future<bool> updateView(int viewId, Map<String, dynamic> propPatches) async {
    final processedProps = preprocessProps(propPatches);
    
    if (_batchUpdateInProgress) {
      final propsJson = jsonEncode(processedProps);
      _pendingBatchUpdates.add({
        'operation': 'updateView',
        'viewId': viewId,
        'propsJson': propsJson,
      });
      return true;
    }
    
    try {
      final propsJson = jsonEncode(processedProps);
      final jPropsJson = jni.JString.fromString(propsJson);
      try {
        return _instance.updateView(viewId, jPropsJson);
      } finally {
        jPropsJson.release();
      }
    } catch (e) {
      log('Error updating view via JNI: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteView(int viewId) async {
    if (_batchUpdateInProgress) {
      _pendingBatchUpdates.add({
        'operation': 'deleteView',
        'viewId': viewId,
      });
      return true;
    }
    
    try {
      return _instance.deleteView(viewId);
    } catch (e) {
      log('Error deleting view via JNI: $e');
      return false;
    }
  }

  @override
  Future<bool> detachView(int viewId) async {
    try {
      return _instance.detachView(viewId);
    } catch (e) {
      log('Error detaching view via JNI: $e');
      return false;
    }
  }

  @override
  Future<bool> attachView(int childId, int parentId, int index) async {
    if (_batchUpdateInProgress) {
      _pendingBatchUpdates.add({
        'operation': 'attachView',
        'childId': childId,
        'parentId': parentId,
        'index': index,
      });
      return true;
    }
    
    try {
      return _instance.attachView(childId, parentId, index);
    } catch (e) {
      log('Error attaching view via JNI: $e');
      return false;
    }
  }

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
      // Convert List<int> to JSON string
      final childrenIdsJson = jsonEncode(childrenIds);
      final jChildrenIdsJson = childrenIdsJson.toJString();
      try {
        return _instance.setChildren(viewId, jChildrenIdsJson);
      } finally {
        jChildrenIdsJson.release();
      }
    } catch (e) {
      log('Error setting children via JNI: $e');
      return false;
    }
  }

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
      final eventTypesStr = jsonEncode(eventTypes);
      final jEventTypesStr = jni.JString.fromString(eventTypesStr);
      try {
        return _instance.addEventListeners(viewId, jEventTypesStr);
      } finally {
        jEventTypesStr.release();
      }
    } catch (e) {
      log('Error adding event listeners via JNI: $e');
      return false;
    }
  }

  @override
  Future<bool> removeEventListeners(int viewId, List<String> eventTypes) async {
    try {
      final eventTypesStr = jsonEncode(eventTypes);
      final jEventTypesStr = jni.JString.fromString(eventTypesStr);
      try {
        return _instance.removeEventListeners(viewId, jEventTypesStr);
      } finally {
        jEventTypesStr.release();
      }
    } catch (e) {
      log('Error removing event listeners via JNI: $e');
      return false;
    }
  }

  @override
  void registerEventCallback(int viewId, String eventType, Function callback) {
    _eventRegistry.register(viewId, {eventType: callback});
  }

  @override
  void setEventHandler(Function(int viewId, String eventType, Map<String, dynamic> eventData) handler) {
    _eventRegistry.setGlobalHandler(handler);
  }

  @override
  Future<bool> startBatchUpdate() async {
    if (_batchUpdateInProgress) {
      return false;
    }
    
    _batchUpdateInProgress = true;
    _pendingBatchUpdates.clear();
    
    try {
      return _instance.startBatchUpdate();
    } catch (e) {
      log('Error starting batch update via JNI: $e');
      _batchUpdateInProgress = false;
      return false;
    }
  }

  @override
  Future<bool> commitBatchUpdate() async {
    if (!_batchUpdateInProgress) {
      return false;
    }
    
    try {
      final operationsJson = jsonEncode(_pendingBatchUpdates);
      final jOperationsJson = jni.JString.fromString(operationsJson);
      try {
        final success = _instance.commitBatchUpdate(jOperationsJson);
        _batchUpdateInProgress = false;
        _pendingBatchUpdates.clear();
        return success;
      } finally {
        jOperationsJson.release();
      }
    } catch (e) {
      log('Error committing batch update via JNI: $e');
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
    
    try {
      return _instance.cancelBatchUpdate();
    } catch (e) {
      log('Error cancelling batch update via JNI: $e');
      return false;
    }
  }

  @override
  void handleNativeEvent(int viewId, String eventType, Map<String, dynamic> eventData) {
    _eventRegistry.handleEvent(viewId, eventType, eventData);
  }

  @override
  Future<dynamic> tunnel(String componentType, String method, Map<String, dynamic> params) async {
    try {
      final paramsJson = jsonEncode(params);
      final jComponentType = jni.JString.fromString(componentType);
      final jMethod = jni.JString.fromString(method);
      final jParamsJson = jni.JString.fromString(paramsJson);
      try {
        final jResultJson = _instance.tunnel(jComponentType, jMethod, jParamsJson);
        try {
          final resultJson = jResultJson.toDartString();
          if (resultJson.isEmpty || resultJson == 'null') {
            return null;
          }
          return jsonDecode(resultJson);
        } finally {
          jResultJson.release();
        }
      } finally {
        jComponentType.release();
        jMethod.release();
        jParamsJson.release();
      }
    } catch (e) {
      log('Error calling tunnel via JNI: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getScreenDimensions() async {
    try {
      if (_jniInstance == null) {
        final wrapper = DCFlightJniWrapper();
        await wrapper.initialize();
      }
      final jDimensionsJson = _jniInstance!.getScreenDimensions();
      try {
        final dimensionsJson = jDimensionsJson.toDartString();
        if (dimensionsJson.isEmpty) {
          return null;
        }
        return jsonDecode(dimensionsJson) as Map<String, dynamic>;
      } finally {
        jDimensionsJson.release();
      }
    } catch (e) {
      log('Error getting screen dimensions: $e');
      return null;
    }
  }
  
  static void setScreenDimensionsChangeHandler(void Function(Map<String, dynamic>) handler) {
    _screenDimensionsChangeHandler = handler;
  }
  
  static Future<String?> getSessionToken() async {
    try {
      if (_jniInstance == null) {
        final wrapper = DCFlightJniWrapper();
        await wrapper.initialize();
      }
      final jToken = _jniInstance!.getSessionToken();
      try {
        return jToken.toDartString();
      } finally {
        jToken.release();
      }
    } catch (e) {
      log('Error getting session token: $e');
      return null;
    }
  }
  
  static Future<String?> createSessionToken() async {
    try {
      if (_jniInstance == null) {
        final wrapper = DCFlightJniWrapper();
        await wrapper.initialize();
      }
      final jToken = _jniInstance!.createSessionToken();
      try {
        return jToken.toDartString();
      } finally {
        jToken.release();
      }
    } catch (e) {
      log('Error creating session token: $e');
      return null;
    }
  }
  
  static Future<bool> clearSessionToken() async {
    try {
      if (_jniInstance == null) {
        final wrapper = DCFlightJniWrapper();
        await wrapper.initialize();
      }
      _jniInstance!.clearSessionToken();
      return true;
    } catch (e) {
      log('Error clearing session token: $e');
      return false;
    }
  }
  
  static Future<bool> cleanupViews() async {
    try {
      if (_jniInstance == null) {
        final wrapper = DCFlightJniWrapper();
        await wrapper.initialize();
      }
      _jniInstance!.cleanupViews();
      return true;
    } catch (e) {
      log('Error cleaning up views: $e');
      return false;
    }
  }
}

/// JNI event callback class
class _DCFlightJniEventCallback extends jni.JObject implements DCFlightJniEventCallback {
  final void Function(int viewId, jni.JString eventType, jni.JString eventDataJson) _callback;
  
  _DCFlightJniEventCallback(this._callback) : super.fromReference(throw UnimplementedError('JNI bindings not generated'));
  
  @override
  void onEvent(int viewId, jni.JString eventType, jni.JString eventDataJson) {
    _callback(viewId, eventType, eventDataJson);
  }
}

/// JNI screen dimensions callback class
class _DCFlightJniScreenDimensionsCallback extends jni.JObject implements DCFlightJniScreenDimensionsCallback {
  final void Function(jni.JString dimensionsJson) _callback;
  
  _DCFlightJniScreenDimensionsCallback(this._callback) : super.fromReference(throw UnimplementedError('JNI bindings not generated'));
  
  @override
  void onDimensionsChanged(jni.JString dimensionsJson) {
    _callback(dimensionsJson);
  }
}



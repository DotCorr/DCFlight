/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:developer';
import 'package:ffi/ffi.dart';

import 'src/generated/dcflight_ffi_bindings.dart';
import 'interface.dart';
import 'interface_util.dart';
import '../../events/event_registry.dart';

/// Wrapper for iOS DCFlight bridge using FFI.
///
/// This demonstrates direct FFI access to iOS native bridge APIs via C functions
/// without using Flutter's platform channels.
///
/// Usage:
/// ```dart
/// final bridge = DCFlightFfiWrapper();
/// await bridge.initialize();
/// ```
class DCFlightFfiWrapper implements PlatformInterface {
  static DCFlightFfi? _bindings;
  static final EventRegistry _eventRegistry = EventRegistry();
  static DCFlightEventCallback? _eventCallback;
  static DCFlightScreenDimensionsCallback? _screenDimensionsCallback;
  static void Function(Map<String, dynamic>)? _screenDimensionsChangeHandler;
  
  bool _batchUpdateInProgress = false;
  final List<Map<String, dynamic>> _pendingBatchUpdates = [];

  /// Gets the FFI bindings instance.
  ///
  /// Loads the native library on first access.
  DCFlightFfi get _ffi {
    if (_bindings == null) {
      if (!Platform.isIOS) {
        throw UnsupportedError('DCFlightFfiWrapper only supports iOS');
      }

      // On iOS, the library is statically linked into the app
      final dylib = ffi.DynamicLibrary.process();
      _bindings = DCFlightFfi(dylib);
      
      // Set up event callback
      _setupEventCallback();
    }
    return _bindings!;
  }

  /// Sets up the event callback for native-to-Dart communication
  void _setupEventCallback() {
    if (_eventCallback != null) {
      return; // Already set up
    }
    
    _eventCallback = ffi.Pointer.fromFunction<DCFlightEventCallbackFunction>(
      _onNativeEvent,
    );
    _ffi.dcflight_set_event_callback(_eventCallback!);
    
    _screenDimensionsCallback = ffi.Pointer.fromFunction<DCFlightScreenDimensionsCallbackFunction>(
      _onScreenDimensionsChanged,
    );
    _ffi.dcflight_set_screen_dimensions_callback(_screenDimensionsCallback!);
  }
  
  /// Native screen dimensions callback function
  /// This is called from native code (potentially from UI thread)
  /// We use scheduleMicrotask to ensure it runs on the Dart isolate thread
  static void _onScreenDimensionsChanged(ffi.Pointer<ffi.Char> dimensionsJson) {
    // Copy string immediately while we're in the callback context
    final dimensionsJsonStr = dimensionsJson.cast<Utf8>().toDartString();
    
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
  
  /// Static method to get screen dimensions (for ScreenUtilities)
  static Future<Map<String, dynamic>?> getScreenDimensions() async {
    try {
      if (_bindings == null) {
        final wrapper = DCFlightFfiWrapper();
        await wrapper.initialize();
      }
      final resultBuffer = malloc<ffi.Uint8>(1024);
      try {
        final success = _bindings!.dcflight_get_screen_dimensions(
          resultBuffer.cast(),
          1024,
        ) == 1;
        
        if (!success) {
          return null;
        }
        
        final dimensionsStr = resultBuffer.cast<Utf8>().toDartString();
        return jsonDecode(dimensionsStr) as Map<String, dynamic>;
      } finally {
        malloc.free(resultBuffer);
      }
    } catch (e) {
      log('Error getting screen dimensions: $e');
      return null;
    }
  }
  
  static void setScreenDimensionsChangeHandler(void Function(Map<String, dynamic>) handler) {
    _screenDimensionsChangeHandler = handler;
  }
  
  static Future<dynamic> getSessionToken() async {
    try {
      if (_bindings == null) {
        final wrapper = DCFlightFfiWrapper();
        await wrapper.initialize();
      }
      final resultBuffer = malloc<ffi.Char>(256);
      try {
        // Zero-initialize buffer using Uint8 view
        resultBuffer.cast<ffi.Uint8>().asTypedList(256).fillRange(0, 256, 0);
        
        log('🔥 DCFlightFfiWrapper: Calling dcflight_get_session_token...');
        final success = _bindings!.dcflight_get_session_token(
          resultBuffer,
          256,
        );
        
        log('🔥 DCFlightFfiWrapper: dcflight_get_session_token returned: success=$success');
        
        if (!success) {
          log('❌ DCFlightFfiWrapper: Failed to get session token');
          return null;
        }
        
        final tokenStr = resultBuffer.cast<Utf8>().toDartString();
        log('🔥 DCFlightFfiWrapper: Token from native: "$tokenStr" (length: ${tokenStr.length})');
        return tokenStr.isEmpty ? null : tokenStr;
      } finally {
        malloc.free(resultBuffer);
      }
    } catch (e) {
      log('Error getting session token: $e');
      return null;
    }
  }
  
  static Future<String> createSessionToken() async {
    try {
      if (_bindings == null) {
        final wrapper = DCFlightFfiWrapper();
        await wrapper.initialize();
      }
      final resultBuffer = malloc<ffi.Char>(256);
      try {
        // Zero-initialize buffer using Uint8 view
        resultBuffer.cast<ffi.Uint8>().asTypedList(256).fillRange(0, 256, 0);
        
        log('🔥 DCFlightFfiWrapper: Calling dcflight_create_session_token...');
        final success = _bindings!.dcflight_create_session_token(
          resultBuffer,
          256,
        );
        
        log('🔥 DCFlightFfiWrapper: dcflight_create_session_token returned: success=$success');
        
        if (!success) {
          log('❌ DCFlightFfiWrapper: Failed to create session token');
          // Check buffer contents even on failure
          final bufferHex = resultBuffer.cast<ffi.Uint8>().asTypedList(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          log('⚠️ DCFlightFfiWrapper: Buffer contents on failure: $bufferHex');
          return '';
        }
        
        final tokenStr = resultBuffer.cast<Utf8>().toDartString();
        log('🔥 DCFlightFfiWrapper: Token from native: "$tokenStr" (length: ${tokenStr.length})');
        
        if (tokenStr.isEmpty) {
          final bufferHex = resultBuffer.cast<ffi.Uint8>().asTypedList(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          log('⚠️ DCFlightFfiWrapper: Token is empty! Buffer contents: $bufferHex');
          // Try reading as raw bytes to see what's there
          final rawBytes = resultBuffer.cast<ffi.Uint8>().asTypedList(50).where((b) => b != 0).toList();
          log('⚠️ DCFlightFfiWrapper: Non-zero bytes in buffer: $rawBytes');
        }
        
        return tokenStr;
      } finally {
        malloc.free(resultBuffer);
      }
    } catch (e, stackTrace) {
      log('❌ DCFlightFfiWrapper: Error creating session token: $e');
      log('Stack trace: $stackTrace');
      return '';
    }
  }
  
  static Future<void> clearSessionToken() async {
    try {
      if (_bindings == null) {
        final wrapper = DCFlightFfiWrapper();
        await wrapper.initialize();
      }
      _bindings!.dcflight_clear_session_token();
    } catch (e) {
      log('Error clearing session token: $e');
    }
  }
  
  static Future<void> cleanupViews() async {
    try {
      if (_bindings == null) {
        final wrapper = DCFlightFfiWrapper();
        await wrapper.initialize();
      }
      
      // CRITICAL: Call cleanup synchronously (SAFE_MAIN_THREAD_EXEC ensures main thread)
      _bindings!.dcflight_cleanup_views();
      
      // Small delay to ensure cleanup completes on native side
      await Future.delayed(const Duration(milliseconds: 50));
      
      log('✅ DCFlightFfiWrapper: Cleanup completed');
    } catch (e) {
      log('❌ DCFlightFfiWrapper: Error cleaning up views: $e');
    }
  }

  /// Native event callback function
  /// This is called from native code (potentially from UI thread)
  /// We use scheduleMicrotask to ensure it runs on the Dart isolate thread
  static void _onNativeEvent(int viewId, ffi.Pointer<ffi.Char> eventType, ffi.Pointer<ffi.Char> eventDataJson) {
    // Copy strings immediately while we're in the callback context
    final eventTypeStr = eventType.cast<Utf8>().toDartString();
    final eventDataJsonStr = eventDataJson.cast<Utf8>().toDartString();
    
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
      log('🔄 DCFlightFfiWrapper: Calling dcflight_initialize()');
      final result = _ffi.dcflight_initialize();
      log('✅ DCFlightFfiWrapper: dcflight_initialize() returned: $result (type: ${result.runtimeType})');
      // FFI maps C bool to Dart bool, so we can use it directly
      if (!result) {
        log('❌ DCFlightFfiWrapper: Initialization failed - dcflight_initialize returned false');
      } else {
        log('✅ DCFlightFfiWrapper: Initialization succeeded');
        // Start polling for queued events from native threads
        _startEventPoller();
      }
      return result;
    } catch (e, stackTrace) {
      log('❌ DCFlightFfiWrapper: Error initializing DCFlight bridge via FFI: $e');
      log('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Start polling for queued events from native threads
  /// Since FFI callbacks can't be called from native threads, we use polling
  void _startEventPoller() {
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      try {
        // Poll for queued events
        final eventsJsonPtr = _ffi.dcflight_get_queued_events();
        if (eventsJsonPtr != ffi.nullptr) {
          try {
            final eventsJson = eventsJsonPtr.cast<Utf8>().toDartString();
            final events = jsonDecode(eventsJson) as List<dynamic>;
            for (final event in events) {
              final eventMap = event as Map<String, dynamic>;
              final viewId = eventMap['viewId'] as int;
              final eventType = eventMap['eventType'] as String;
              final eventDataJson = eventMap['eventDataJson'] as String;
              
              Map<String, dynamic> eventData = {};
              if (eventDataJson.isNotEmpty && eventDataJson != 'null') {
                try {
                  eventData = jsonDecode(eventDataJson) as Map<String, dynamic>;
                } catch (e) {
                  log('Error parsing event data JSON: $e');
                }
              }
              
              _eventRegistry.handleEvent(viewId, eventType, eventData);
            }
            // Free the memory allocated by native code (strdup)
            malloc.free(eventsJsonPtr);
          } catch (e) {
            log('Error processing queued events: $e');
          }
        }
        
        // Poll for queued screen dimensions changes
        final dimensionsJsonPtr = _ffi.dcflight_get_queued_screen_dimensions();
        if (dimensionsJsonPtr != ffi.nullptr) {
          try {
            final dimensionsJson = dimensionsJsonPtr.cast<Utf8>().toDartString();
            final dimensions = jsonDecode(dimensionsJson) as Map<String, dynamic>;
            _screenDimensionsChangeHandler?.call(dimensions);
            // Free the memory allocated by native code (strdup)
            malloc.free(dimensionsJsonPtr);
          } catch (e) {
            log('Error processing queued screen dimensions: $e');
          }
        }
      } catch (e) {
        // Ignore errors in polling - it's best effort
      }
    });
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
      final viewTypePtr = type.toNativeUtf8();
      final propsJsonPtr = propsJson.toNativeUtf8();
      try {
        return _ffi.dcflight_create_view(viewId, viewTypePtr.cast(), propsJsonPtr.cast()) == 1;
      } finally {
        malloc.free(viewTypePtr);
        malloc.free(propsJsonPtr);
      }
    } catch (e) {
      log('Error creating view via FFI: $e');
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
      final propsJsonPtr = propsJson.toNativeUtf8();
      try {
        return _ffi.dcflight_update_view(viewId, propsJsonPtr.cast()) == 1;
      } finally {
        malloc.free(propsJsonPtr);
      }
    } catch (e) {
      log('Error updating view via FFI: $e');
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
      return _ffi.dcflight_delete_view(viewId) == 1;
    } catch (e) {
      log('Error deleting view via FFI: $e');
      return false;
    }
  }

  @override
  Future<bool> detachView(int viewId) async {
    try {
      return _ffi.dcflight_detach_view(viewId) == 1;
    } catch (e) {
      log('Error detaching view via FFI: $e');
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
      return _ffi.dcflight_attach_view(childId, parentId, index) == 1;
    } catch (e) {
      log('Error attaching view via FFI: $e');
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
      final childrenArray = childrenIds.map((id) => id).toList();
      final pointer = malloc<ffi.Int32>(ffi.sizeOf<ffi.Int32>() * childrenIds.length);
      for (int i = 0; i < childrenIds.length; i++) {
        pointer[i] = childrenIds[i];
      }
      try {
        return _ffi.dcflight_set_children(viewId, pointer, childrenIds.length) == 1;
      } finally {
        malloc.free(pointer);
      }
    } catch (e) {
      log('Error setting children via FFI: $e');
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
      final eventTypesStr = eventTypes.join(',');
      final eventTypesPtr = eventTypesStr.toNativeUtf8();
      try {
        return _ffi.dcflight_add_event_listeners(viewId, eventTypesPtr.cast()) == 1;
      } finally {
        malloc.free(eventTypesPtr);
      }
    } catch (e) {
      log('Error adding event listeners via FFI: $e');
      return false;
    }
  }

  @override
  Future<bool> removeEventListeners(int viewId, List<String> eventTypes) async {
    try {
      final eventTypesStr = eventTypes.join(',');
      final eventTypesPtr = eventTypesStr.toNativeUtf8();
      try {
        return _ffi.dcflight_remove_event_listeners(viewId, eventTypesPtr.cast()) == 1;
      } finally {
        malloc.free(eventTypesPtr);
      }
    } catch (e) {
      log('Error removing event listeners via FFI: $e');
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
      return _ffi.dcflight_start_batch_update() == 1;
    } catch (e) {
      log('Error starting batch update via FFI: $e');
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
      final operationsJsonPtr = operationsJson.toNativeUtf8();
      try {
        final success = _ffi.dcflight_commit_batch_update(operationsJsonPtr.cast()) == 1;
        
        _batchUpdateInProgress = false;
        _pendingBatchUpdates.clear();
        return success;
      } finally {
        malloc.free(operationsJsonPtr);
      }
    } catch (e) {
      log('Error committing batch update via FFI: $e');
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
      return _ffi.dcflight_cancel_batch_update() == 1;
    } catch (e) {
      log('Error cancelling batch update via FFI: $e');
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
      final componentTypePtr = componentType.toNativeUtf8();
      final methodPtr = method.toNativeUtf8();
      final paramsJsonPtr = paramsJson.toNativeUtf8();
      final resultBuffer = malloc<ffi.Uint8>(4096);
      try {
        final success = _ffi.dcflight_tunnel(
          componentTypePtr.cast(),
          methodPtr.cast(),
          paramsJsonPtr.cast(),
          resultBuffer.cast(),
          4096,
        ) == 1;
        
        if (!success) {
          return null;
        }
        
        final resultStr = resultBuffer.cast<Utf8>().toDartString();
        if (resultStr == 'null') {
          return null;
        }
        
        return jsonDecode(resultStr);
      } finally {
        malloc.free(resultBuffer);
        malloc.free(componentTypePtr);
        malloc.free(methodPtr);
        malloc.free(paramsJsonPtr);
      }
    } catch (e) {
      log('Error calling tunnel via FFI: $e');
      return null;
    }
  }
}



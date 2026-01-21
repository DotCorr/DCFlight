/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'package:dcflight/framework/renderer/interface/interface.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_ffi_wrapper.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_jni_wrapper.dart';

/// FFI/JNI-based implementation of PlatformInterface
/// 
class NativePlatform implements PlatformInterface {
  static PlatformInterface? _instance;
  final PlatformInterface _delegate;

  NativePlatform._(this._delegate);

  /// Factory constructor that creates the appropriate implementation based on platform
  factory NativePlatform() {
    if (_instance != null) {
      return _instance as NativePlatform;
    }

    PlatformInterface delegate;
    if (Platform.isIOS) {
      delegate = DCFlightFfiWrapper();
    } else if (Platform.isAndroid) {
      delegate = DCFlightJniWrapper();
    } else {
      throw UnsupportedError('DCFlight only supports iOS and Android platforms');
    }

    final instance = NativePlatform._(delegate);
    _instance = instance;
    return instance;
  }

  @override
  Future<bool> initialize() => _delegate.initialize();

  @override
  Future<bool> createView(int viewId, String type, Map<String, dynamic> props) =>
      _delegate.createView(viewId, type, props);

  @override
  Future<bool> updateView(int viewId, Map<String, dynamic> propPatches) =>
      _delegate.updateView(viewId, propPatches);

  @override
  Future<bool> deleteView(int viewId) => _delegate.deleteView(viewId);

  @override
  Future<bool> detachView(int viewId) => _delegate.detachView(viewId);

  @override
  Future<bool> attachView(int childId, int parentId, int index) =>
      _delegate.attachView(childId, parentId, index);

  @override
  Future<bool> setChildren(int viewId, List<int> childrenIds) =>
      _delegate.setChildren(viewId, childrenIds);

  @override
  Future<bool> addEventListeners(int viewId, List<String> eventTypes) =>
      _delegate.addEventListeners(viewId, eventTypes);

  @override
  Future<bool> removeEventListeners(int viewId, List<String> eventTypes) =>
      _delegate.removeEventListeners(viewId, eventTypes);

  @override
  void registerEventCallback(int viewId, String eventType, Function callback) =>
      _delegate.registerEventCallback(viewId, eventType, callback);

  @override
  void setEventHandler(
      Function(int viewId, String eventType, Map<String, dynamic> eventData) handler) =>
      _delegate.setEventHandler(handler);

  @override
  Future<bool> startBatchUpdate() => _delegate.startBatchUpdate();

  @override
  Future<bool> commitBatchUpdate() => _delegate.commitBatchUpdate();

  @override
  Future<bool> cancelBatchUpdate() => _delegate.cancelBatchUpdate();

  @override
  void handleNativeEvent(int viewId, String eventType, Map<String, dynamic> eventData) =>
      _delegate.handleNativeEvent(viewId, eventType, eventData);

  @override
  Future<dynamic> tunnel(String componentType, String method, Map<String, dynamic> params) =>
      _delegate.tunnel(componentType, method, params);
}

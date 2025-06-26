/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Utility class for handling screen dimensions and orientation changes
class ScreenUtilities {
  /// Singleton instance
  static final ScreenUtilities instance = ScreenUtilities._();

  /// Method channel for communication with native side
  final _methodChannel = const MethodChannel('com.dcmaui.screen_dimensions');

  /// Stream of dimension change events
  final _dimensionController = StreamController<void>.broadcast();

  /// List of callbacks for dimension changes
  final List<Function()> _dimensionChangeListeners = [];

  /// Current screen width
  double _screenWidth = 0.0;

  /// Current screen height
  double _screenHeight = 0.0;

  /// Scale factor from native side
  double _scaleFactor = 1.0;

  /// Status bar height
  double _statusBarHeight = 0.0;

  /// Safe area insets
  double _safeAreaTop = 0.0;
  double _safeAreaBottom = 0.0;
  double _safeAreaLeft = 0.0;
  double _safeAreaRight = 0.0;

  /// Private constructor
  ScreenUtilities._() {
    // Set up the method channel handler
    _methodChannel.setMethodCallHandler(_handleMethodCall);

    // Initial refresh
    refreshDimensions();
  }

  /// Handle method calls from the native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'dimensionsChanged':
        // Update dimensions from native values
        final Map<dynamic, dynamic> args = call.arguments;

        _screenWidth = args['width'] as double;
        _screenHeight = args['height'] as double;
        _scaleFactor = args['scale'] as double;
        _statusBarHeight = args['statusBarHeight'] as double;
        _safeAreaTop = args['safeAreaTop'] as double? ?? 0.0;
        _safeAreaBottom = args['safeAreaBottom'] as double? ?? 0.0;
        _safeAreaLeft = args['safeAreaLeft'] as double? ?? 0.0;
        _safeAreaRight = args['safeAreaRight'] as double? ?? 0.0;

        // Log the change
        developer.log(
            'Screen dimensions changed: $_screenWidth x $_screenHeight',
            name: 'ScreenUtilities');

        // Notify listeners
        _notifyDimensionChangeListeners();
        return null;
      default:
        return null;
    }
  }

  /// Refresh dimensions from native side
  Future<void> refreshDimensions() async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, dynamic>('getScreenDimensions');
      if (result != null) {
        _screenWidth = result['width'] as double;
        _screenHeight = result['height'] as double;
        _scaleFactor = result['scale'] as double;
        _statusBarHeight = result['statusBarHeight'] as double;
        _safeAreaTop = result['safeAreaTop'] as double? ?? 0.0;
        _safeAreaBottom = result['safeAreaBottom'] as double? ?? 0.0;
        _safeAreaLeft = result['safeAreaLeft'] as double? ?? 0.0;
        _safeAreaRight = result['safeAreaRight'] as double? ?? 0.0;

        developer.log(
            'Screen dimensions updated: $_screenWidth x $_screenHeight',
            name: 'ScreenUtilities');

        _notifyDimensionChangeListeners();
      }
    } catch (e) {

      // Fallback to reasonable defaults if needed
      if (_screenWidth == 0 || _screenHeight == 0) {
        _screenWidth = 400;
        _screenHeight = 800;
        _scaleFactor = 2.0;
      }
    }
  }

  /// Add a listener for dimension changes
  void addDimensionChangeListener(Function() listener) {
    _dimensionChangeListeners.add(listener);
  }

  /// Remove a dimension change listener
  void removeDimensionChangeListener(Function() listener) {
    _dimensionChangeListeners.remove(listener);
  }

  /// Notify all dimension change listeners
  void _notifyDimensionChangeListeners() {
    for (var listener in _dimensionChangeListeners) {
      listener();
    }
    _dimensionController.add(null);
  }

  /// Get the current screen width
  double get screenWidth => _screenWidth;

  /// Get the current screen height
  double get screenHeight => _screenHeight;

  /// Get the scale factor
  double get scaleFactor => _scaleFactor;

  /// Get the status bar height
  double get statusBarHeight => _statusBarHeight;

  /// Get a stream of dimension changes
  Stream<void> get dimensionChanges => _dimensionController.stream;

  /// Check if the device is in landscape mode
  bool get isLandscape => _screenWidth > _screenHeight;

  /// Check if the device is in portrait mode
  bool get isPortrait => !isLandscape;

  /// Get the safe area top inset
  double get safeAreaTop => _safeAreaTop;

  /// Get the safe area bottom inset
  double get safeAreaBottom => _safeAreaBottom;

  /// Get the safe area left inset
  double get safeAreaLeft => _safeAreaLeft;

  /// Get the safe area right inset
  double get safeAreaRight => _safeAreaRight;
}

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
/// Enhanced with window size change detection for iPad multitasking
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

  /// Track previous dimensions to detect actual changes
  double _previousWidth = 0.0;
  double _previousHeight = 0.0;

  /// Private constructor
  ScreenUtilities._() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);

    refreshDimensions();
  }

  /// Handle method calls from the native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'dimensionsChanged':
        final Map<dynamic, dynamic> args = call.arguments;

        final newWidth = args['width'] as double;
        final newHeight = args['height'] as double;

        if (newWidth != _screenWidth || newHeight != _screenHeight) {
          _previousWidth = _screenWidth;
          _previousHeight = _screenHeight;

          _screenWidth = newWidth;
          _screenHeight = newHeight;
          _scaleFactor = args['scale'] as double;
          _statusBarHeight = args['statusBarHeight'] as double;
          _safeAreaTop = args['safeAreaTop'] as double? ?? 0.0;
          _safeAreaBottom = args['safeAreaBottom'] as double? ?? 0.0;
          _safeAreaLeft = args['safeAreaLeft'] as double? ?? 0.0;
          _safeAreaRight = args['safeAreaRight'] as double? ?? 0.0;

          final changeType = _determineChangeType();
          developer.log(
              'Screen dimensions changed ($changeType): ${_previousWidth.toInt()}x${_previousHeight.toInt()} → ${_screenWidth.toInt()}x${_screenHeight.toInt()}',
              name: 'ScreenUtilities');

          _notifyDimensionChangeListeners();
        }
        return null;
        
      case 'onDimensionChange':
        final Map<dynamic, dynamic> args = call.arguments;
        
        final newWidth = args['width'] as double;
        final newHeight = args['height'] as double;
        
        if (newWidth != _screenWidth || newHeight != _screenHeight) {
          _previousWidth = _screenWidth;
          _previousHeight = _screenHeight;

          _screenWidth = newWidth;
          _screenHeight = newHeight;
          _scaleFactor = args['scale'] as double;
          _safeAreaTop = args['safeAreaTop'] as double? ?? 0.0;
          _safeAreaBottom = args['safeAreaBottom'] as double? ?? 0.0;
          _safeAreaLeft = args['safeAreaLeft'] as double? ?? 0.0;
          _safeAreaRight = args['safeAreaRight'] as double? ?? 0.0;

          developer.log(
              'Window size changed: ${_previousWidth.toInt()}x${_previousHeight.toInt()} → ${_screenWidth.toInt()}x${_screenHeight.toInt()}',
              name: 'ScreenUtilities');

          _notifyDimensionChangeListeners();
        }
        return null;
        
      default:
        return null;
    }
  }

  /// Determine the type of screen change that occurred
  String _determineChangeType() {
    if (_previousWidth == 0 && _previousHeight == 0) {
      return 'initial';
    }
    
    final wasLandscape = _previousWidth > _previousHeight;
    final isLandscape = _screenWidth > _screenHeight;
    
    if (wasLandscape != isLandscape) {
      return 'orientation';
    } else {
      return 'window resize';
    }
  }

  /// Refresh dimensions from native side
  Future<void> refreshDimensions() async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, dynamic>('getScreenDimensions');
      if (result != null) {
        _previousWidth = _screenWidth;
        _previousHeight = _screenHeight;
        
        _screenWidth = result['width'] as double;
        _screenHeight = result['height'] as double;
        _scaleFactor = result['scale'] as double;
        _statusBarHeight = result['statusBarHeight'] as double;
        _safeAreaTop = result['safeAreaTop'] as double? ?? 0.0;
        _safeAreaBottom = result['safeAreaBottom'] as double? ?? 0.0;
        _safeAreaLeft = result['safeAreaLeft'] as double? ?? 0.0;
        _safeAreaRight = result['safeAreaRight'] as double? ?? 0.0;

        developer.log(
            'Screen dimensions refreshed: $_screenWidth x $_screenHeight',
            name: 'ScreenUtilities');

        if (_previousWidth != _screenWidth || _previousHeight != _screenHeight) {
          _notifyDimensionChangeListeners();
        }
      }
    } catch (e) {
      developer.log('Failed to refresh screen dimensions: $e', name: 'ScreenUtilities');
      
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

  /// Clear all dimension change listeners
  void clearDimensionChangeListeners() {
    _dimensionChangeListeners.clear();
  }

  /// Notify all dimension change listeners
  void _notifyDimensionChangeListeners() {
    for (var listener in _dimensionChangeListeners) {
      try {
        listener();
      } catch (e) {
        developer.log('Error in dimension change listener: $e', name: 'ScreenUtilities');
      }
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

  /// Get the previous screen dimensions (useful for detecting change type)
  double get previousWidth => _previousWidth;
  double get previousHeight => _previousHeight;

  /// Check if this was an orientation change vs window resize
  bool get wasOrientationChange {
    if (_previousWidth == 0 && _previousHeight == 0) return false;
    
    final wasLandscape = _previousWidth > _previousHeight;
    final isLandscape = _screenWidth > _screenHeight;
    
    return wasLandscape != isLandscape;
  }

  /// Check if this was a window resize (iPad multitasking)
  bool get wasWindowResize {
    if (_previousWidth == 0 && _previousHeight == 0) return false;
    
    final wasLandscape = _previousWidth > _previousHeight;
    final isLandscape = _screenWidth > _screenHeight;
    
    return wasLandscape == isLandscape && 
           (_previousWidth != _screenWidth || _previousHeight != _screenHeight);
  }

  /// Dispose of resources
  void dispose() {
    _dimensionController.close();
    clearDimensionChangeListeners();
  }
}
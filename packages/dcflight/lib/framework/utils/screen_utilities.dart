/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dcflight/framework/utils/system_state_manager.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_ffi_wrapper.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_jni_wrapper.dart' show DCFlightJniWrapper;

/// Utility class for handling screen dimensions and orientation changes
class ScreenUtilities {
  /// Singleton instance
  static final ScreenUtilities instance = ScreenUtilities._();

  /// Stream of dimension change events
  final _dimensionController = StreamController<void>.broadcast();

  /// List of callbacks for dimension changes
  final List<Function()> _dimensionChangeListeners = [];

  /// Current screen width
  double _screenWidth = 0.0;

  /// Current screen height
  double _screenHeight = 0.0;

  /// Scale factor from native side (pixel ratio)
  double _scaleFactor = 1.0;

  /// Font scale factor (system font size preference)
  double _fontScale = 1.0;

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
    _setupDimensionCallback();
    // CRITICAL: Don't call refreshDimensions() immediately in constructor
    // During hot restart, native side might not be ready yet
    // refreshDimensions() will be called explicitly from DCFlight._initialize()
    // after bridge.initialize() completes
  }

  /// Set up dimension change callback via FFI/JNI
  void _setupDimensionCallback() {
    if (Platform.isIOS) {
      // iOS: Set up FFI callback for dimension changes
      DCFlightFfiWrapper.setScreenDimensionsChangeHandler(_handleDimensionChange);
    } else if (Platform.isAndroid) {
      // Android: Set up JNI callback for dimension changes
      // The callback is set up in DCFlightJniWrapper._setupEventCallback
      // We'll register our handler there
      DCFlightJniWrapper.setScreenDimensionsChangeHandler(_handleDimensionChange);
    }
  }

  /// Handle dimension change from native (called via FFI/JNI callback)
  void _handleDimensionChange(Map<String, dynamic> dimensions) {
    final newWidth = dimensions['width'] as double? ?? 0.0;
    final newHeight = dimensions['height'] as double? ?? 0.0;
    final oldFontScale = _fontScale;
    final newFontScale = dimensions['fontScale'] as double? ?? 1.0;
    final newSafeAreaTop = dimensions['safeAreaTop'] as double? ?? 0.0;
    final newSafeAreaBottom = dimensions['safeAreaBottom'] as double? ?? 0.0;
    final newSafeAreaLeft = dimensions['safeAreaLeft'] as double? ?? 0.0;
    final newSafeAreaRight = dimensions['safeAreaRight'] as double? ?? 0.0;
    final safeAreaChanged = newSafeAreaTop != _safeAreaTop || 
                           newSafeAreaBottom != _safeAreaBottom ||
                           newSafeAreaLeft != _safeAreaLeft ||
                           newSafeAreaRight != _safeAreaRight;

    if (newWidth != _screenWidth || newHeight != _screenHeight) {
      _previousWidth = _screenWidth;
      _previousHeight = _screenHeight;

      _screenWidth = newWidth;
      _screenHeight = newHeight;
      _scaleFactor = dimensions['scale'] as double? ?? 1.0;
      _fontScale = newFontScale;
      _statusBarHeight = dimensions['statusBarHeight'] as double? ?? 0.0;
      _safeAreaTop = newSafeAreaTop;
      _safeAreaBottom = newSafeAreaBottom;
      _safeAreaLeft = newSafeAreaLeft;
      _safeAreaRight = newSafeAreaRight;

      final changeType = _determineChangeType();
      developer.log(
          'Screen dimensions changed ($changeType): ${_previousWidth.toInt()}x${_previousHeight.toInt()} → ${_screenWidth.toInt()}x${_screenHeight.toInt()}, safeAreaTop: $_safeAreaTop',
          name: 'ScreenUtilities');

      _notifyDimensionChangeListeners();
    } else if (oldFontScale != newFontScale || safeAreaChanged) {
      // Font scale or safe area changed without dimension change
      final fontScaleChanged = oldFontScale != newFontScale;
      
      _fontScale = newFontScale;
      _safeAreaTop = newSafeAreaTop;
      _safeAreaBottom = newSafeAreaBottom;
      _safeAreaLeft = newSafeAreaLeft;
      _safeAreaRight = newSafeAreaRight;
      
      developer.log(
          'Safe area or font scale changed: safeAreaTop=$_safeAreaTop, fontScale=$_fontScale',
          name: 'ScreenUtilities');
      
      // CRITICAL: Notify SystemStateManager if font scale changed
      // This triggers CoreWrapper to re-render, which will cause all components
      // to re-render with new _systemVersion, ensuring font scale changes are reflected
      if (fontScaleChanged) {
      SystemStateManager.onSystemChange(fontScale: true);
        developer.log(
            'Font scale changed: $oldFontScale → $newFontScale - triggering app re-render',
            name: 'ScreenUtilities');
      }
      
      _notifyDimensionChangeListeners();
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

  /// Refresh dimensions from native side via FFI/JNI
  /// Includes retry logic to handle cases where native isn't ready yet
  /// During hot restart, native side may need more time to initialize
  Future<void> refreshDimensions() async {
    const maxRetries = 5; // Increased from 3 to 5 for hot restart scenarios
    const retryDelays = [100, 200, 400, 600, 800]; // milliseconds - longer delays for later attempts
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // On first attempt, add a small delay to allow native side to initialize
        // This is especially important during hot restart
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
      Map<String, dynamic>? result;
      
      if (Platform.isIOS) {
        result = await DCFlightFfiWrapper.getScreenDimensions();
      } else if (Platform.isAndroid) {
        result = await DCFlightJniWrapper.getScreenDimensions();
      }
      
      if (result != null) {
        _previousWidth = _screenWidth;
        _previousHeight = _screenHeight;
        
        _screenWidth = result['width'] as double? ?? 0.0;
        _screenHeight = result['height'] as double? ?? 0.0;
        _scaleFactor = result['scale'] as double? ?? 1.0;
        _fontScale = result['fontScale'] as double? ?? 1.0;
        _statusBarHeight = result['statusBarHeight'] as double? ?? 0.0;
        _safeAreaTop = result['safeAreaTop'] as double? ?? 0.0;
        _safeAreaBottom = result['safeAreaBottom'] as double? ?? 0.0;
        _safeAreaLeft = result['safeAreaLeft'] as double? ?? 0.0;
        _safeAreaRight = result['safeAreaRight'] as double? ?? 0.0;

        developer.log(
              'Screen dimensions refreshed: $_screenWidth x $_screenHeight, safeAreaTop: $_safeAreaTop',
            name: 'ScreenUtilities');

        if (_previousWidth != _screenWidth || _previousHeight != _screenHeight) {
          _notifyDimensionChangeListeners();
        }
          return; // Success - exit retry loop
        } else {
          // Result is null - retry if we have attempts left
          if (attempt < maxRetries - 1) {
            developer.log(
                'Failed to refresh screen dimensions: result is null (attempt ${attempt + 1}/$maxRetries), retrying in ${retryDelays[attempt]}ms...',
                name: 'ScreenUtilities');
            await Future.delayed(Duration(milliseconds: retryDelays[attempt]));
            continue;
          } else {
            developer.log(
                'Failed to refresh screen dimensions: result is null after $maxRetries attempts',
                name: 'ScreenUtilities');
          }
        }
      } catch (e) {
        // Error occurred - retry if we have attempts left
        if (attempt < maxRetries - 1) {
          developer.log(
              'Failed to refresh screen dimensions: $e (attempt ${attempt + 1}/$maxRetries), retrying in ${retryDelays[attempt]}ms...',
              name: 'ScreenUtilities');
          await Future.delayed(Duration(milliseconds: retryDelays[attempt]));
          continue;
        } else {
          developer.log('Failed to refresh screen dimensions after $maxRetries attempts: $e', name: 'ScreenUtilities');
        }
      }
    }
    
    // If we get here, all retries failed - use fallback values
      if (_screenWidth == 0 || _screenHeight == 0) {
      developer.log('Using fallback screen dimensions: 400x800', name: 'ScreenUtilities');
        _screenWidth = 400;
        _screenHeight = 800;
        _scaleFactor = 2.0;
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

  /// Get the scale factor (pixel ratio)
  double get scaleFactor => _scaleFactor;

  /// Get the font scale factor (system font size preference)
  /// Similar to React Native's PixelRatio.getFontScale()
  double get fontScale => _fontScale;

  /// Get scale (alias for scaleFactor, matches React Native's useWindowDimensions)
  double get scale => _scaleFactor;

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

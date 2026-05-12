/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dcflight/framework/utils/system_state_manager.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_ffi_wrapper.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_jni_wrapper.dart' show DCFlightJniWrapper;

/// Epsilon for dimension/safe area comparisons to avoid re-notifying on float noise
const double _kDimensionEpsilon = 0.5;

bool _dimensionChanged(double a, double b) => (a - b).abs() > _kDimensionEpsilon;

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return fallback;
}

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
    final newWidth = _asDouble(dimensions['width']);
    final newHeight = _asDouble(dimensions['height']);
    final hasValidSize = newWidth > _kDimensionEpsilon && newHeight > _kDimensionEpsilon;
    final oldFontScale = _fontScale;
    final newFontScale = _asDouble(dimensions['fontScale'], 1.0);
    final newSafeAreaTop = _asDouble(dimensions['safeAreaTop']);
    final newSafeAreaBottom = _asDouble(dimensions['safeAreaBottom']);
    final newSafeAreaLeft = _asDouble(dimensions['safeAreaLeft']);
    final newSafeAreaRight = _asDouble(dimensions['safeAreaRight']);
    final safeAreaChanged = _dimensionChanged(newSafeAreaTop, _safeAreaTop) ||
                           _dimensionChanged(newSafeAreaBottom, _safeAreaBottom) ||
                           _dimensionChanged(newSafeAreaLeft, _safeAreaLeft) ||
                           _dimensionChanged(newSafeAreaRight, _safeAreaRight);
    final sizeChanged = _dimensionChanged(newWidth, _screenWidth) ||
                        _dimensionChanged(newHeight, _screenHeight);
    final fontScaleChanged = _dimensionChanged(newFontScale, oldFontScale);

    if (sizeChanged && hasValidSize) {
      _previousWidth = _screenWidth;
      _previousHeight = _screenHeight;

      _screenWidth = newWidth;
      _screenHeight = newHeight;
      _scaleFactor = _asDouble(dimensions['scale'], 1.0);
      _fontScale = newFontScale;
      _statusBarHeight = _asDouble(dimensions['statusBarHeight']);
      _safeAreaTop = newSafeAreaTop;
      _safeAreaBottom = newSafeAreaBottom;
      _safeAreaLeft = newSafeAreaLeft;
      _safeAreaRight = newSafeAreaRight;

      final changeType = _determineChangeType();
      developer.log(
          'Screen dimensions changed ($changeType): ${_previousWidth.toInt()}x${_previousHeight.toInt()} → ${_screenWidth.toInt()}x${_screenHeight.toInt()}, safeAreaTop: $_safeAreaTop',
          name: 'ScreenUtilities');

      SystemStateManager.onSystemChange(layoutMetrics: true);

      _notifyDimensionChangeListeners();
    } else if (sizeChanged && !hasValidSize) {
      // Ignore transient invalid snapshots from native bridge (e.g. 0x0 during relayout).
      // Keeping the last known good dimensions prevents full-layout collapse.
      developer.log(
          'Ignored invalid dimension snapshot from native: ${newWidth.toStringAsFixed(2)}x${newHeight.toStringAsFixed(2)}',
          name: 'ScreenUtilities');

      if (fontScaleChanged || safeAreaChanged) {
        _fontScale = newFontScale;
        _safeAreaTop = newSafeAreaTop;
        _safeAreaBottom = newSafeAreaBottom;
        _safeAreaLeft = newSafeAreaLeft;
        _safeAreaRight = newSafeAreaRight;

        if (safeAreaChanged) {
          SystemStateManager.onSystemChange(layoutMetrics: true);
        }
        if (fontScaleChanged) {
          SystemStateManager.onSystemChange(fontScale: true);
        }
        _notifyDimensionChangeListeners();
      }
    } else if (fontScaleChanged || safeAreaChanged) {
      // Font scale or safe area changed without size change
      
      _fontScale = newFontScale;
      _safeAreaTop = newSafeAreaTop;
      _safeAreaBottom = newSafeAreaBottom;
      _safeAreaLeft = newSafeAreaLeft;
      _safeAreaRight = newSafeAreaRight;
      
      developer.log(
          'Safe area or font scale changed: safeAreaTop=$_safeAreaTop, fontScale=$_fontScale',
          name: 'ScreenUtilities');

      // Trigger a root re-render for safe area and font scale changes.
      if (safeAreaChanged) {
        SystemStateManager.onSystemChange(layoutMetrics: true);
      }

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

  /// Refresh dimensions from native side via FFI/JNI.
  /// Single retry; on failure keep existing values (dimension callback may have already delivered).
  Future<void> refreshDimensions() async {
    const maxRetries = 2;
    const retryDelayMs = 100;
    
    developer.log(
        '📐 refreshDimensions() called - current state: ${_screenWidth.toInt()}x${_screenHeight.toInt()} (valid: ${_screenWidth > _kDimensionEpsilon && _screenHeight > _kDimensionEpsilon})',
        name: 'ScreenUtilities');
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          await Future.delayed(const Duration(milliseconds: retryDelayMs));
        }
        
      Map<String, dynamic>? result;
      
      if (Platform.isIOS) {
        result = await DCFlightFfiWrapper.getScreenDimensions();
      } else if (Platform.isAndroid) {
        result = await DCFlightJniWrapper.getScreenDimensions();
      }
      
      if (result != null) {
        final incomingWidth = _asDouble(result['width']);
        final incomingHeight = _asDouble(result['height']);
        final hasValidSize =
            incomingWidth > _kDimensionEpsilon && incomingHeight > _kDimensionEpsilon;

        developer.log(
            '📐 Native dimension result (attempt $attempt): ${incomingWidth.toInt()}x${incomingHeight.toInt()} (valid: $hasValidSize)',
            name: 'ScreenUtilities');

        if (!hasValidSize) {
          if (_screenWidth > _kDimensionEpsilon && _screenHeight > _kDimensionEpsilon) {
            // Keep existing good values; native can temporarily report 0x0 during transitions.
            developer.log(
                '⚠️  Native returned invalid size, keeping cached: ${_screenWidth.toInt()}x${_screenHeight.toInt()}',
                name: 'ScreenUtilities');
            continue;
          }
          if (attempt < maxRetries - 1) continue;
          // Final attempt still invalid and no cached dimensions; fall back below.
          break;
        }

        final oldWidth = _screenWidth;
        final oldHeight = _screenHeight;
        final oldSafeAreaTop = _safeAreaTop;
        final oldSafeAreaBottom = _safeAreaBottom;
        final oldSafeAreaLeft = _safeAreaLeft;
        final oldSafeAreaRight = _safeAreaRight;
        final oldFontScale = _fontScale;

        _previousWidth = _screenWidth;
        _previousHeight = _screenHeight;
        
        _screenWidth = incomingWidth;
        _screenHeight = incomingHeight;
        _scaleFactor = _asDouble(result['scale'], 1.0);
        _fontScale = _asDouble(result['fontScale'], 1.0);
        _statusBarHeight = _asDouble(result['statusBarHeight']);
        _safeAreaTop = _asDouble(result['safeAreaTop']);
        _safeAreaBottom = _asDouble(result['safeAreaBottom']);
        _safeAreaLeft = _asDouble(result['safeAreaLeft']);
        _safeAreaRight = _asDouble(result['safeAreaRight']);

        developer.log(
            '✅ Dimensions refreshed: ${oldWidth.toInt()}x${oldHeight.toInt()} → ${_screenWidth.toInt()}x${_screenHeight.toInt()}',
            name: 'ScreenUtilities');

        final sizeChanged = _dimensionChanged(oldWidth, _screenWidth) ||
            _dimensionChanged(oldHeight, _screenHeight);
        final safeAreaChanged = _dimensionChanged(oldSafeAreaTop, _safeAreaTop) ||
            _dimensionChanged(oldSafeAreaBottom, _safeAreaBottom) ||
            _dimensionChanged(oldSafeAreaLeft, _safeAreaLeft) ||
            _dimensionChanged(oldSafeAreaRight, _safeAreaRight);
        final fontScaleChanged = _dimensionChanged(oldFontScale, _fontScale);

        if (sizeChanged || safeAreaChanged || fontScaleChanged) {
          if (sizeChanged || safeAreaChanged) {
            SystemStateManager.onSystemChange(layoutMetrics: true);
          }
          if (fontScaleChanged) {
            SystemStateManager.onSystemChange(fontScale: true);
          }
          _notifyDimensionChangeListeners();
        }
          return; // Success - exit retry loop
        } else {
          if (attempt < maxRetries - 1) continue;
          // Native not ready yet (e.g. right after hot restart); skip silently.
          developer.log(
              '⚠️  Native not ready on final attempt, skipping refresh',
              name: 'ScreenUtilities');
        }
      } catch (e) {
        developer.log(
            '❌ Exception during refreshDimensions (attempt $attempt): $e',
            name: 'ScreenUtilities');
        if (attempt < maxRetries - 1) continue;
        // Skip silently; set verboseLogging to log.
      }
    }
    if (_screenWidth <= _kDimensionEpsilon || _screenHeight <= _kDimensionEpsilon) {
      final view = ui.PlatformDispatcher.instance.views.isNotEmpty
          ? ui.PlatformDispatcher.instance.views.first
          : null;
      if (view != null && view.devicePixelRatio > 0) {
        _screenWidth = view.physicalSize.width / view.devicePixelRatio;
        _screenHeight = view.physicalSize.height / view.devicePixelRatio;
        _scaleFactor = view.devicePixelRatio;
        developer.log(
            '⚠️  Fell back to Flutter view dimensions: ${_screenWidth.toInt()}x${_screenHeight.toInt()}',
            name: 'ScreenUtilities');
      } else {
        _screenWidth = 400;
        _screenHeight = 800;
        _scaleFactor = 2.0;
        developer.log(
            '⚠️  Fell back to default dimensions: ${_screenWidth.toInt()}x${_screenHeight.toInt()}',
            name: 'ScreenUtilities');
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

  /// Get the scale factor (pixel ratio)
  double get scaleFactor => _scaleFactor;

  /// Get the font scale factor (system font size preference)
  /// Similar to React Native's PixelRatio.getFontScale()
  double get fontScale => _fontScale;

  /// Get scale (alias for scaleFactor, matches React Native's useWindowDimensions)
  double get scale => _scaleFactor;

  /// Get the status bar height.
  /// Fallback to Flutter view padding when native status bar height is unavailable.
  double get statusBarHeight {
    if (_statusBarHeight > 0) return _statusBarHeight;
    final view = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first
        : null;
    if (view == null || view.devicePixelRatio == 0) return 0.0;
    return view.viewPadding.top / view.devicePixelRatio;
  }

  /// Get a stream of dimension changes
  Stream<void> get dimensionChanges => _dimensionController.stream;

  /// Check if the device is in landscape mode
  bool get isLandscape => _screenWidth > _screenHeight;

  /// Check if the device is in portrait mode
  bool get isPortrait => !isLandscape;

  /// Get the safe area top inset.
  /// Fallback order: native safe area -> native status bar -> Flutter view padding -> platform baseline.
  ///
  /// The platform baseline prevents nav/status overlap when native telemetry is temporarily 0.
  double get safeAreaTop {
    if (_safeAreaTop > 0) return _safeAreaTop;
    if (_statusBarHeight > 0) return _statusBarHeight;

    final view = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first
        : null;
    if (view != null && view.devicePixelRatio > 0) {
      final paddingTop = view.viewPadding.top / view.devicePixelRatio;
      if (paddingTop > 0) return paddingTop;
    }

    if (Platform.isIOS) return 47.0;
    if (Platform.isAndroid) return 24.0;
    return 0.0;
  }

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


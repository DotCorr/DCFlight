/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter

class DCFScreenUtilities {
    static let shared = DCFScreenUtilities()
    
    // Store the Flutter binary messenger
    private var flutterBinaryMessenger: FlutterBinaryMessenger?
    private var methodChannel: FlutterMethodChannel?
    
    // CRITICAL FIX: Store current dimensions that can be updated dynamically
    private var _screenWidth: CGFloat = 0
    private var _screenHeight: CGFloat = 0
    private var _safeAreaTop: CGFloat = 0
    private var _safeAreaBottom: CGFloat = 0
    private var _safeAreaLeft: CGFloat = 0
    private var _safeAreaRight: CGFloat = 0
    
    // CRITICAL FIX: Dimension change listeners for reactive updates
    private var dimensionChangeListeners: [() -> Void] = []
    
    private init() {
        // Initialize with current dimensions
        updateScreenDimensions()
        
        // Method channel will be set up later when binary messenger is available
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    // Initialize with a binary messenger from the Flutter app delegate
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        self.flutterBinaryMessenger = binaryMessenger
        
        // Now create the method channel with the provided messenger
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.screen_dimensions",
            binaryMessenger: binaryMessenger
        )
        
        setupMethodChannel()
        print("✅ DCFScreenUtilities: Initialized with method channel")
    }
    
    // CRITICAL FIX: Update screen dimensions (called when window size changes)
    func updateScreenDimensions(width: CGFloat? = nil, height: CGFloat? = nil) {
        let oldWidth = _screenWidth
        let oldHeight = _screenHeight
        
        // Get current window bounds if not provided
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            _screenWidth = width ?? window.bounds.width
            _screenHeight = height ?? window.bounds.height
            
            // Update safe area insets
            if #available(iOS 11.0, *) {
                _safeAreaTop = window.safeAreaInsets.top
                _safeAreaBottom = window.safeAreaInsets.bottom
                _safeAreaLeft = window.safeAreaInsets.left
                _safeAreaRight = window.safeAreaInsets.right
            } else {
                // Fallback for older iOS versions
                _safeAreaTop = UIApplication.shared.statusBarFrame.height
                _safeAreaBottom = 0
                _safeAreaLeft = 0
                _safeAreaRight = 0
            }
        } else {
            // Fallback to UIScreen if window is not available
            let bounds = UIScreen.main.bounds
            _screenWidth = width ?? bounds.width
            _screenHeight = height ?? bounds.height
            
            _safeAreaTop = UIApplication.shared.statusBarFrame.height
            _safeAreaBottom = 0
            _safeAreaLeft = 0
            _safeAreaRight = 0
        }
        
        // Notify listeners if size actually changed
        if oldWidth != _screenWidth || oldHeight != _screenHeight {
            print("📱 DCFScreenUtilities: Screen dimensions updated to \(_screenWidth)x\(_screenHeight)")
            notifyDimensionChangeListeners()
            
            // Also notify Dart side if method channel is available
            notifyDartOfDimensionChange()
        }
    }
    
    // CRITICAL FIX: Add listener for dimension changes
    func addDimensionChangeListener(_ listener: @escaping () -> Void) {
        dimensionChangeListeners.append(listener)
    }
    
    // CRITICAL FIX: Remove dimension change listener
    func removeDimensionChangeListener(_ listener: @escaping () -> Void) {
        // Note: This is a simplified removal - in production you might want to use a more sophisticated approach
        // For now, we'll clear all listeners when needed
    }
    
    // CRITICAL FIX: Clear all dimension change listeners
    func clearDimensionChangeListeners() {
        dimensionChangeListeners.removeAll()
    }
    
    // CRITICAL FIX: Notify all listeners of dimension changes
    private func notifyDimensionChangeListeners() {
        for listener in dimensionChangeListeners {
            listener()
        }
    }
    
    // CRITICAL FIX: Notify Dart side of dimension changes
    private func notifyDartOfDimensionChange() {
        guard let methodChannel = methodChannel else { return }
        
        let dimensionData: [String: Any] = [
            "width": _screenWidth,
            "height": _screenHeight,
            "scale": UIScreen.main.scale,
            "statusBarHeight": UIApplication.shared.statusBarFrame.height,
            "safeAreaTop": _safeAreaTop,
            "safeAreaBottom": _safeAreaBottom,
            "safeAreaLeft": _safeAreaLeft,
            "safeAreaRight": _safeAreaRight
        ]
        
        methodChannel.invokeMethod("dimensionsChanged", arguments: dimensionData)
    }
    
    private func setupMethodChannel() {
        guard let methodChannel = methodChannel else { return }
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE",
                                   message: "Screen utilities not available",
                                   details: nil))
                return
            }
            
            if call.method == "getScreenDimensions" {
                // Return current screen dimensions (now using stored values)
                result([
                    "width": self._screenWidth,
                    "height": self._screenHeight,
                    "scale": UIScreen.main.scale,
                    "statusBarHeight": UIApplication.shared.statusBarFrame.height,
                    "safeAreaTop": self._safeAreaTop,
                    "safeAreaBottom": self._safeAreaBottom,
                    "safeAreaLeft": self._safeAreaLeft,
                    "safeAreaRight": self._safeAreaRight
                ])
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    @objc private func orientationChanged() {
        print("🔄 DCFScreenUtilities: Device orientation changed")
        
        // Update dimensions first
        updateScreenDimensions()
        
        // Legacy notification (kept for compatibility)
        guard let methodChannel = methodChannel else { return }
        
        // Allow a moment for the UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Post notification to Flutter about updated dimensions
            self.notifyDartOfDimensionChange()
        }
    }
    
    // CRITICAL FIX: Updated properties to use stored values
    var screenWidth: CGFloat {
        return _screenWidth
    }
    
    var screenHeight: CGFloat {
        return _screenHeight
    }
    
    var safeAreaTop: CGFloat {
        return _safeAreaTop
    }
    
    var safeAreaBottom: CGFloat {
        return _safeAreaBottom
    }
    
    var safeAreaLeft: CGFloat {
        return _safeAreaLeft
    }
    
    var safeAreaRight: CGFloat {
        return _safeAreaRight
    }
    
    // Get safe area insets (legacy method, now uses stored values)
    private func getSafeAreaInsets() -> UIEdgeInsets {
        return UIEdgeInsets(
            top: _safeAreaTop,
            left: _safeAreaLeft,
            bottom: _safeAreaBottom,
            right: _safeAreaRight
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        clearDimensionChangeListeners()
    }
}
